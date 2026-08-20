/**
 * POST /functions/v1/razorpay-webhook
 *
 * The authoritative payment source of truth. Runs with verify_jwt = false because
 * Razorpay cannot present a Supabase token; authentication is the HMAC signature
 * over the raw request body instead.
 *
 * Exactly-once processing
 *   Razorpay retries a webhook until it receives a 2xx. Every delivery carries
 *   `x-razorpay-event-id`, which we insert into payment_events under a unique
 *   index. A duplicate delivery therefore finds an existing row and returns 200
 *   without repeating any side effect.
 *
 * Always returns 200 once the signature is valid, even if our own processing
 * fails — otherwise Razorpay retries forever. Failures are recorded on the event
 * row and surfaced through the unreconciled-payments alert instead.
 */

import { corsHeaders, jsonResponse, newRequestId } from "../_shared/http.ts";
import { rpc, serviceClient } from "../_shared/supabase.ts";
import {
    extractMethodDetail,
    fromPaise,
    mapPaymentMethod,
    type RazorpayPayment,
    verifyWebhookSignature,
} from "../_shared/razorpay.ts";
import { logger, reportToSentry } from "../_shared/logger.ts";

interface WebhookBody {
    event?: string;
    created_at?: number;
    payload?: {
        payment?: { entity?: RazorpayPayment };
        order?: { entity?: { id?: string; status?: string; amount?: number } };
        refund?: {
            entity?: {
                id?: string;
                payment_id?: string;
                amount?: number;
                status?: string;
                speed_processed?: string;
            };
        };
    };
}

Deno.serve(async (req) => {
    const origin = req.headers.get("origin");
    const requestId = newRequestId(req);

    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders(origin) });
    }

    if (req.method !== "POST") {
        return jsonResponse({ error: "method_not_allowed" }, { status: 405, origin, requestId });
    }

    // The raw body must be read verbatim: any reserialisation breaks the HMAC.
    const rawBody = await req.text();
    const signature = req.headers.get("x-razorpay-signature");
    const providerEventId = req.headers.get("x-razorpay-event-id");

    const signatureValid = await verifyWebhookSignature(rawBody, signature);

    if (!signatureValid) {
        // 401 (not 200): an unsigned request is not a Razorpay delivery worth retrying.
        logger.error("webhook.signature_invalid", {
            request_id: requestId,
            provider_event_id: providerEventId,
            has_signature: Boolean(signature),
        });
        return jsonResponse(
            { error: { code: "INVALID_SIGNATURE", message: "Signature verification failed." } },
            { status: 401, origin, requestId },
        );
    }

    let body: WebhookBody;
    try {
        body = JSON.parse(rawBody) as WebhookBody;
    } catch {
        logger.error("webhook.invalid_json", { request_id: requestId });
        return jsonResponse({ received: true, ignored: "invalid_json" }, { origin, requestId });
    }

    const eventType = body.event ?? "unknown";
    const admin = serviceClient();

    const paymentEntity = body.payload?.payment?.entity;
    const refundEntity = body.payload?.refund?.entity;
    const orderEntity = body.payload?.order?.entity;

    // ── Resolve our own records so the event row is linked correctly ──
    const ourPayment = await rpc<
        | {
            id: string;
            order_id: string;
            status: string;
            amount: number;
            currency_code: string;
            verified_by_callback: boolean;
            verified_by_webhook: boolean;
        }
        | null
    >(admin, "svc_find_payment", {
        p_provider_order_id: paymentEntity?.order_id ?? orderEntity?.id ?? null,
        p_provider_payment_id: paymentEntity?.id ?? refundEntity?.payment_id ?? null,
    }).catch(() => null);

    // ── Register the event: this is the exactly-once gate ──
    const registration = await rpc<{
        event_id: string;
        already_processed: boolean;
        duplicate: boolean;
    }>(admin, "svc_register_webhook_event", {
        p_gateway: "RAZORPAY",
        p_provider_event_id: providerEventId,
        p_event_type: eventType,
        p_payload: body as unknown as Record<string, unknown>,
        p_signature_verified: true,
        p_payment_id: ourPayment?.id ?? null,
        p_order_id: ourPayment?.order_id ?? null,
    });

    if (registration.duplicate && registration.already_processed) {
        logger.info("webhook.duplicate_ignored", {
            request_id: requestId,
            event_type: eventType,
            provider_event_id: providerEventId,
        });
        return jsonResponse(
            { received: true, duplicate: true, event_id: registration.event_id },
            { origin, requestId },
        );
    }

    try {
        const outcome = await handleEvent({
            admin,
            eventType,
            paymentEntity,
            refundEntity,
            ourPayment,
            requestId,
        });

        await rpc(admin, "svc_settle_webhook_event", {
            p_event_id: registration.event_id,
            p_processed: true,
            p_error: null,
        });

        logger.info("webhook.processed", {
            request_id: requestId,
            event_type: eventType,
            provider_event_id: providerEventId,
            outcome,
        });

        return jsonResponse(
            { received: true, event_type: eventType, outcome, event_id: registration.event_id },
            { origin, requestId },
        );
    } catch (error) {
        // Record and acknowledge. Retrying a broken handler forever helps nobody; the
        // reconciliation job and the live-ops alert pick this up instead.
        await rpc(admin, "svc_settle_webhook_event", {
            p_event_id: registration.event_id,
            p_processed: false,
            p_error: String(error).slice(0, 1000),
        }).catch(() => {});

        logger.error("webhook.processing_failed", {
            request_id: requestId,
            event_type: eventType,
            provider_event_id: providerEventId,
            error: String(error),
        });

        await reportToSentry(error, { fn: "razorpay-webhook", event_type: eventType, requestId });

        return jsonResponse(
            { received: true, processed: false, event_id: registration.event_id },
            { origin, requestId },
        );
    }
});

async function handleEvent(input: {
    admin: ReturnType<typeof serviceClient>;
    eventType: string;
    paymentEntity?: RazorpayPayment;
    refundEntity?: {
        id?: string;
        payment_id?: string;
        amount?: number;
        status?: string;
        speed_processed?: string;
    };
    ourPayment: { id: string; order_id: string; amount: number; status: string } | null;
    requestId: string;
}): Promise<string> {
    const { admin, eventType, paymentEntity, refundEntity, ourPayment } = input;

    switch (eventType) {
        // ── Money in ──
        case "payment.captured":
        case "order.paid": {
            if (!ourPayment || !paymentEntity) return "payment_not_found";

            // Never capture more than we asked for; a mismatch is an incident, not a sale.
            const capturedRupees = fromPaise(paymentEntity.amount);
            if (capturedRupees < Number(ourPayment.amount)) {
                logger.error("webhook.underpayment", {
                    payment_id: ourPayment.id,
                    expected: ourPayment.amount,
                    captured: capturedRupees,
                });
                return "amount_mismatch";
            }

            const result = await rpc<{ already_captured: boolean; fully_reconciled: boolean }>(
                admin,
                "svc_record_payment_capture",
                {
                    p_payment_id: ourPayment.id,
                    p_provider_payment_id: paymentEntity.id,
                    p_amount_captured: capturedRupees,
                    p_method: mapPaymentMethod(paymentEntity.method),
                    p_source: "WEBHOOK",
                    p_method_detail: extractMethodDetail(paymentEntity),
                    p_gateway_fee: paymentEntity.fee ? fromPaise(paymentEntity.fee) : 0,
                    p_gateway_tax: paymentEntity.tax ? fromPaise(paymentEntity.tax) : 0,
                },
            );

            return result.already_captured ? "already_captured" : "captured";
        }

        case "payment.authorized": {
            if (!ourPayment) return "payment_not_found";

            await admin
                .from("payments")
                .update({
                    status: "AUTHORIZED",
                    authorized_at: new Date().toISOString(),
                    provider_payment_id: paymentEntity?.id ?? null,
                    updated_at: new Date().toISOString(),
                })
                .eq("id", ourPayment.id)
                .in("status", ["CREATED", "PENDING"]);

            return "authorized";
        }

        case "payment.failed": {
            if (!ourPayment) return "payment_not_found";

            await rpc(admin, "svc_record_payment_failure", {
                p_payment_id: ourPayment.id,
                p_failure_code: paymentEntity?.error_code ?? "PAYMENT_FAILED",
                p_failure_reason: paymentEntity?.error_description ??
                    "Payment failed at the gateway.",
                p_source: "WEBHOOK",
            });

            return "failed";
        }

        // ── Money out ──
        case "refund.created":
        case "refund.speed_changed": {
            if (!refundEntity?.id) return "refund_missing";

            const ourRefund = await rpc<{ id: string; status: string } | null>(
                admin,
                "svc_find_refund",
                { p_provider_refund_id: refundEntity.id },
            );

            if (!ourRefund) return "refund_not_found";

            await rpc(admin, "svc_mark_refund_processing", {
                p_refund_id: ourRefund.id,
                p_provider_refund_id: refundEntity.id,
                p_provider_status: refundEntity.status ?? "pending",
            });

            return "refund_processing";
        }

        case "refund.processed": {
            if (!refundEntity?.id) return "refund_missing";

            const ourRefund = await rpc<{ id: string; status: string } | null>(
                admin,
                "svc_find_refund",
                { p_provider_refund_id: refundEntity.id },
            );

            if (!ourRefund) return "refund_not_found";

            await rpc(admin, "svc_complete_refund", {
                p_refund_id: ourRefund.id,
                p_amount_processed: refundEntity.amount ? fromPaise(refundEntity.amount) : null,
                p_provider_refund_id: refundEntity.id,
                p_provider_status: "processed",
            });

            return "refund_completed";
        }

        case "refund.failed": {
            if (!refundEntity?.id) return "refund_missing";

            const ourRefund = await rpc<{ id: string } | null>(admin, "svc_find_refund", {
                p_provider_refund_id: refundEntity.id,
            });

            if (!ourRefund) return "refund_not_found";

            await rpc(admin, "svc_fail_refund", {
                p_refund_id: ourRefund.id,
                p_failure_code: "REFUND_FAILED_AT_GATEWAY",
                p_failure_reason: "Razorpay reported the refund as failed. Finance must review it.",
            });

            return "refund_failed";
        }

        default:
            // Unhandled event types are still stored, which is useful when Razorpay adds
            // new ones or when investigating an incident.
            return "ignored";
    }
}
