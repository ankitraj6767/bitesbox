/**
 * POST /functions/v1/scheduled-jobs
 *
 * Cadence runner. pg_cron drives the Postgres-side jobs directly; this function
 * exists for the work that needs the network:
 *
 *   · draining the notification queue (FCM / SMS / email)
 *   · polling Razorpay for payments that captured but never produced a webhook,
 *     or that are stuck in "created" long after checkout closed
 *
 * It also invokes public.run_scheduled_jobs() so a deployment without pg_cron
 * (self-hosted, or a project where the extension is unavailable) still runs the
 * full schedule from an external cron caller.
 *
 * Request { cadence: "MINUTE" | "HOURLY" | "DAILY", include_db_jobs?: boolean }
 *
 * Authentication: service-role key only. This is not a user-facing endpoint.
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import { rpc, serviceClient } from "../_shared/supabase.ts";
import { v } from "../_shared/validate.ts";
import { AppError } from "../_shared/errors.ts";
import { extractMethodDetail, fromPaise, mapPaymentMethod, razorpay } from "../_shared/razorpay.ts";
import { env } from "../_shared/env.ts";
import { logger, reportToSentry } from "../_shared/logger.ts";

interface UnreconciledPayment {
    payment_id: string;
    order_id: string;
    order_number: string;
    provider_order_id: string | null;
    provider_payment_id: string | null;
    status: string;
    amount: number;
    verified_by_callback: boolean;
    verified_by_webhook: boolean;
    created_at: string;
}

serveFunction("scheduled-jobs", async ({ req, requestId, origin }) => {
    // Only trusted server code may drive the scheduler.
    const authorization = req.headers.get("Authorization") ?? "";
    if (!authorization.includes(env.serviceRoleKey)) {
        throw new AppError(
            "PERMISSION_DENIED",
            "Scheduled jobs may only be triggered by trusted server code.",
        );
    }

    const body = await readJson<Record<string, unknown>>(req);
    const cadence = v.enumValue(body, "cadence", ["MINUTE", "HOURLY", "DAILY"] as const, "MINUTE");
    const includeDbJobs = v.boolean(body, "include_db_jobs", true);

    const admin = serviceClient();
    const results: Record<string, unknown> = {};

    // ── 1. Postgres-side jobs ──
    if (includeDbJobs) {
        try {
            results["db_jobs"] = await rpc(admin, "run_scheduled_jobs", { p_cadence: cadence });
        } catch (error) {
            logger.error("scheduler.db_jobs_failed", {
                request_id: requestId,
                error: String(error),
            });
            results["db_jobs"] = { error: String(error) };
        }
    }

    // ── 2. Notification queue ──
    if (cadence === "MINUTE" || cadence === "HOURLY") {
        try {
            results["notifications"] = await drainNotifications(
                req,
                cadence === "MINUTE" ? 100 : 200,
            );
        } catch (error) {
            logger.error("scheduler.notifications_failed", {
                request_id: requestId,
                error: String(error),
            });
            results["notifications"] = { error: String(error) };
        }
    }

    // ── 3. Payment reconciliation ──
    if (cadence === "HOURLY" || cadence === "MINUTE") {
        try {
            results["reconciliation"] = await reconcilePayments(admin, requestId);
        } catch (error) {
            logger.error("scheduler.reconciliation_failed", {
                request_id: requestId,
                error: String(error),
            });
            await reportToSentry(error, { fn: "scheduled-jobs", stage: "reconciliation" });
            results["reconciliation"] = { error: String(error) };
        }
    }

    logger.info("scheduler.completed", { request_id: requestId, cadence, results });

    return jsonResponse({ cadence, ran_at: new Date().toISOString(), results }, {
        origin,
        requestId,
    });
});

/** Calls the notification worker with the service key. */
async function drainNotifications(req: Request, limit: number): Promise<unknown> {
    const url = new URL(req.url);
    const endpoint = `${url.origin}/functions/v1/send-notification`;

    const response = await fetch(endpoint, {
        method: "POST",
        headers: {
            Authorization: `Bearer ${env.serviceRoleKey}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({ mode: "DRAIN", limit }),
    });

    return await response.json();
}

/**
 * Closes the gap between our records and Razorpay.
 *
 * Two failure modes matter in production:
 *   1. The customer paid, the app crashed, and the webhook was delayed or lost.
 *      Polling finds the captured payment and completes the order.
 *   2. The customer abandoned checkout. The payment stays "created" forever and is
 *      expired so the order can be cleanly failed.
 */
async function reconcilePayments(
    admin: ReturnType<typeof serviceClient>,
    requestId: string,
): Promise<Record<string, unknown>> {
    if (!env.razorpayConfigured) {
        return { skipped: "Razorpay is not configured." };
    }

    const flagged = await rpc<{ processed: number; payments: UnreconciledPayment[] }>(
        admin,
        "run_scheduled_jobs",
        { p_cadence: "HOURLY" },
    ).then(() => rpcFlagged(admin));

    let captured = 0;
    let failedOut = 0;
    let expired = 0;
    let unchanged = 0;

    for (const payment of flagged.payments.slice(0, 50)) {
        try {
            // Prefer the payment id; fall back to listing the gateway order's attempts.
            let gatewayPayment = payment.provider_payment_id
                ? await razorpay.fetchPayment(payment.provider_payment_id)
                : null;

            if (!gatewayPayment && payment.provider_order_id) {
                const attempts = await razorpay.fetchOrderPayments(payment.provider_order_id);
                gatewayPayment = attempts.items.find((item) =>
                    item.status === "captured" || item.status === "authorized"
                ) ?? attempts.items[0] ?? null;
            }

            if (!gatewayPayment) {
                // Nothing was ever attempted at the gateway; let the DB job expire it.
                expired++;
                continue;
            }

            if (gatewayPayment.status === "captured") {
                await rpc(admin, "svc_record_payment_capture", {
                    p_payment_id: payment.payment_id,
                    p_provider_payment_id: gatewayPayment.id,
                    p_amount_captured: fromPaise(gatewayPayment.amount),
                    p_method: mapPaymentMethod(gatewayPayment.method),
                    p_source: "POLL",
                    p_method_detail: extractMethodDetail(gatewayPayment),
                    p_gateway_fee: gatewayPayment.fee ? fromPaise(gatewayPayment.fee) : 0,
                    p_gateway_tax: gatewayPayment.tax ? fromPaise(gatewayPayment.tax) : 0,
                });

                captured++;

                logger.warn("reconciliation.recovered_payment", {
                    request_id: requestId,
                    payment_id: payment.payment_id,
                    order_number: payment.order_number,
                    note: "Payment captured at the gateway but not confirmed by webhook.",
                });
                continue;
            }

            if (gatewayPayment.status === "failed") {
                await rpc(admin, "svc_record_payment_failure", {
                    p_payment_id: payment.payment_id,
                    p_failure_code: gatewayPayment.error_code ?? "PAYMENT_FAILED",
                    p_failure_reason: gatewayPayment.error_description ?? "Failed at the gateway.",
                    p_source: "POLL",
                });
                failedOut++;
                continue;
            }

            unchanged++;
        } catch (error) {
            logger.error("reconciliation.payment_failed", {
                request_id: requestId,
                payment_id: payment.payment_id,
                error: String(error),
            });
        }
    }

    return {
        flagged: flagged.payments.length,
        captured,
        failed: failedOut,
        expired,
        unchanged,
    };
}

/** Reads the flagged-payment list produced by the DB job. */
async function rpcFlagged(
    admin: ReturnType<typeof serviceClient>,
): Promise<{ processed: number; payments: UnreconciledPayment[] }> {
    const { data, error } = await admin
        .from("job_runs")
        .select("result")
        .eq("job_name", "unreconciled_payments")
        .eq("status", "SUCCESS")
        .order("started_at", { ascending: false })
        .limit(1)
        .maybeSingle();

    if (error || !data?.result) {
        return { processed: 0, payments: [] };
    }

    const result = data.result as { processed?: number; payments?: UnreconciledPayment[] };
    return { processed: result.processed ?? 0, payments: result.payments ?? [] };
}
