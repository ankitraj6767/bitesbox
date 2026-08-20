/**
 * POST /functions/v1/process-refund
 *
 * The audited refund pipeline:
 *   permission check → amount validation → approval routing (all in Postgres)
 *   → Razorpay refund (here) → webhook confirmation → completion → notification.
 *
 * The function never decides who may refund or how much. public.request_refund /
 * approve_refund enforce that against refund_policies, the refundable balance and
 * the four-eyes rule. This function's only job is talking to the gateway and
 * recording what it said.
 *
 * Request
 *   Create:  { order_id, kind, reason, amount?, destination?, reason_note?,
 *              items?, idempotency_key, support_ticket_id? }
 *   Approve: { refund_id, action: "APPROVE" | "REJECT", note? }
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import { requireCaller, rpc, serviceClient, userClient } from "../_shared/supabase.ts";
import { REFUND_DESTINATIONS, REFUND_KINDS, REFUND_REASONS, v } from "../_shared/validate.ts";
import { AppError } from "../_shared/errors.ts";
import { razorpay } from "../_shared/razorpay.ts";
import { logger, reportToSentry } from "../_shared/logger.ts";

interface RefundDecision {
    refund_id: string;
    order_id?: string;
    status: string;
    amount: number;
    destination?: string;
    auto_approved?: boolean;
    requires_gateway_call: boolean;
    payment_id?: string | null;
    provider_payment_id?: string | null;
    replayed?: boolean;
    changed?: boolean;
}

serveFunction("process-refund", async ({ req, requestId, origin }) => {
    const caller = await requireCaller(req);
    const body = await readJson<Record<string, unknown>>(req);

    // Permission checks run inside the RPCs against the caller's own JWT, so the
    // user client (not the service client) is used for the decision step.
    const asUser = userClient(req);
    const admin = serviceClient();

    const action = v.enumValue(body, "action", ["CREATE", "APPROVE", "REJECT"] as const, "CREATE");

    let decision: RefundDecision;

    if (action === "CREATE") {
        decision = await rpc<RefundDecision>(asUser, "request_refund", {
            p_order_id: v.uuid(body, "order_id"),
            p_kind: v.enumValue(body, "kind", REFUND_KINDS),
            p_reason: v.enumValue(body, "reason", REFUND_REASONS),
            p_amount: v.optionalNumber(body, "amount", { min: 0.01, max: 1_000_000 }),
            p_destination: v.enumValue(
                body,
                "destination",
                REFUND_DESTINATIONS,
                "ORIGINAL_PAYMENT_METHOD",
            ),
            p_reason_note: v.optionalString(body, "reason_note", { max: 2000 }),
            p_items: v.array(body, "items", (item, index) => {
                const row = item as Record<string, unknown>;
                if (typeof row?.["order_item_id"] !== "string") {
                    throw new AppError(
                        "VALIDATION_FAILED",
                        `items[${index}].order_item_id must be a UUID.`,
                        { field: `items[${index}].order_item_id` },
                    );
                }
                return {
                    order_item_id: row["order_item_id"],
                    quantity: Number(row["quantity"] ?? 0) || null,
                };
            }, { max: 100 }),
            p_idempotency_key: v.idempotencyKey(body, req),
            p_support_ticket_id: v.optionalUuid(body, "support_ticket_id"),
        });

        if (decision.replayed) {
            logger.info("refund.replayed", {
                request_id: requestId,
                refund_id: decision.refund_id,
            });
            return jsonResponse({ refund: decision, replayed: true }, { origin, requestId });
        }
    } else if (action === "APPROVE") {
        decision = await rpc<RefundDecision>(asUser, "approve_refund", {
            p_refund_id: v.uuid(body, "refund_id"),
            p_note: v.optionalString(body, "note", { max: 2000 }),
        });
    } else {
        const rejected = await rpc<{ refund_id: string; status: string }>(asUser, "reject_refund", {
            p_refund_id: v.uuid(body, "refund_id"),
            p_note: v.string(body, "note", { min: 3, max: 2000 }),
        });

        logger.info("refund.rejected", { request_id: requestId, refund_id: rejected.refund_id });
        return jsonResponse({ refund: rejected }, { origin, requestId });
    }

    // ── Wallet credit and pending approvals need no gateway call ──
    if (!decision.requires_gateway_call) {
        if (decision.destination === "WALLET_CREDIT" && decision.status === "APPROVED") {
            // Store credit is settled immediately; there is nothing to wait for.
            const completed = await rpc<{ status: string; amount_processed: number }>(
                admin,
                "svc_complete_refund",
                { p_refund_id: decision.refund_id },
            );

            logger.info("refund.wallet_credited", {
                request_id: requestId,
                refund_id: decision.refund_id,
                amount: completed.amount_processed,
            });

            return jsonResponse(
                {
                    refund: {
                        ...decision,
                        status: completed.status,
                        amount_processed: completed.amount_processed,
                    },
                    gateway: null,
                    message: "Refund credited to the customer's Bites Box wallet.",
                },
                { origin, requestId },
            );
        }

        return jsonResponse(
            {
                refund: decision,
                gateway: null,
                message: decision.status === "APPROVAL_PENDING"
                    ? "Refund raised and waiting for approval."
                    : "Refund recorded.",
            },
            { origin, requestId },
        );
    }

    // ── Gateway refund ──
    if (!decision.provider_payment_id) {
        throw new AppError(
            "REFUND_NOT_ALLOWED",
            "This order has no gateway payment to refund. Use wallet credit instead.",
            { refund_id: decision.refund_id },
        );
    }

    try {
        const gatewayRefund = await razorpay.createRefund({
            paymentId: decision.provider_payment_id,
            amountRupees: Number(decision.amount),
            speed: "normal",
            notes: {
                refund_id: decision.refund_id,
                order_id: decision.order_id ?? "",
                requested_by: caller.userId,
            },
            // Deterministic per refund row, so a retried call never double-refunds.
            idempotencyKey: `bb-refund-${decision.refund_id}`,
        });

        await rpc(admin, "svc_mark_refund_processing", {
            p_refund_id: decision.refund_id,
            p_provider_refund_id: gatewayRefund.id,
            p_provider_status: gatewayRefund.status,
        });

        // Razorpay may settle instantly for some instruments; otherwise the
        // refund.processed webhook completes it.
        if (gatewayRefund.status === "processed") {
            await rpc(admin, "svc_complete_refund", {
                p_refund_id: decision.refund_id,
                p_amount_processed: Number(decision.amount),
                p_provider_refund_id: gatewayRefund.id,
                p_provider_status: "processed",
            });
        }

        logger.info("refund.gateway_accepted", {
            request_id: requestId,
            refund_id: decision.refund_id,
            provider_refund_id: gatewayRefund.id,
            gateway_status: gatewayRefund.status,
            amount: decision.amount,
        });

        return jsonResponse(
            {
                refund: {
                    ...decision,
                    status: gatewayRefund.status === "processed" ? "COMPLETED" : "PROCESSING",
                    provider_refund_id: gatewayRefund.id,
                },
                gateway: {
                    provider: "RAZORPAY",
                    refund_id: gatewayRefund.id,
                    status: gatewayRefund.status,
                },
                message: gatewayRefund.status === "processed"
                    ? "Refund processed. It reaches the customer in 3–5 working days."
                    : "Refund submitted to the gateway. We will confirm when it settles.",
            },
            { origin, requestId },
        );
    } catch (error) {
        // Mark it failed so finance sees it rather than a silently stuck refund.
        await rpc(admin, "svc_fail_refund", {
            p_refund_id: decision.refund_id,
            p_failure_code: error instanceof AppError ? error.code : "REFUND_GATEWAY_ERROR",
            p_failure_reason: error instanceof Error
                ? error.message
                : "Unknown gateway error while refunding.",
        }).catch(() => {});

        logger.error("refund.gateway_failed", {
            request_id: requestId,
            refund_id: decision.refund_id,
            error: String(error),
        });

        await reportToSentry(error, { fn: "process-refund", refundId: decision.refund_id });

        throw error instanceof AppError ? error : new AppError(
            "REFUND_GATEWAY_ERROR",
            "The refund could not be sent to the payment gateway. It has been flagged for finance.",
            { refund_id: decision.refund_id },
            502,
        );
    }
});
