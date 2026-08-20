/**
 * POST /functions/v1/verify-payment
 *
 * Called with the Razorpay checkout callback. The callback alone is NEVER treated
 * as proof of payment:
 *
 *   1. the HMAC signature is verified against our key secret
 *   2. the payment is fetched from Razorpay and its status, amount, currency and
 *      order id are checked against our own record
 *   3. only then does app.record_payment_capture() advance the order
 *
 * A malicious client can therefore post any payload it likes and get nowhere.
 * The webhook independently performs the same capture, and both paths converge on
 * one idempotent function.
 *
 * Request { order_id, razorpay_order_id, razorpay_payment_id, razorpay_signature }
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import { requireCaller, rpc, serviceClient } from "../_shared/supabase.ts";
import { v } from "../_shared/validate.ts";
import { AppError, fromPostgrestError } from "../_shared/errors.ts";
import {
    extractMethodDetail,
    fromPaise,
    mapPaymentMethod,
    razorpay,
    toPaise,
    verifyPaymentSignature,
} from "../_shared/razorpay.ts";
import { logger } from "../_shared/logger.ts";

serveFunction("verify-payment", async ({ req, requestId, origin }) => {
    const caller = await requireCaller(req);
    const body = await readJson<Record<string, unknown>>(req);

    const providerOrderId = v.string(body, "razorpay_order_id", { min: 6, max: 64 });
    const providerPaymentId = v.string(body, "razorpay_payment_id", { min: 6, max: 64 });
    const signature = v.string(body, "razorpay_signature", { min: 16, max: 256 });

    const admin = serviceClient();

    // ── 1. Locate our own payment record by the gateway order id ──
    const { data: payment, error: paymentError } = await admin
        .from("payments")
        .select("id, order_id, user_id, amount, currency_code, status, provider_order_id")
        .eq("provider_order_id", providerOrderId)
        .maybeSingle();

    if (paymentError) throw fromPostgrestError(paymentError);

    if (!payment) {
        logger.warn("verify_payment.unknown_gateway_order", {
            request_id: requestId,
            provider_order_id: providerOrderId,
        });
        throw new AppError("PAYMENT_NOT_FOUND", "We could not find this payment.");
    }

    if (payment.user_id !== caller.userId) {
        // Someone is replaying another customer's callback.
        logger.warn("verify_payment.owner_mismatch", {
            request_id: requestId,
            payment_id: payment.id,
            caller: caller.userId,
        });
        throw new AppError("PERMISSION_DENIED", "This payment does not belong to your account.");
    }

    // ── 2. Verify the signature ──
    const signatureValid = await verifyPaymentSignature({
        razorpayOrderId: providerOrderId,
        razorpayPaymentId: providerPaymentId,
        signature,
    });

    // Record the attempt either way; a failed signature is a security event.
    await admin.from("payment_events").insert({
        payment_id: payment.id,
        order_id: payment.order_id,
        gateway: "RAZORPAY",
        event_type: signatureValid ? "callback.signature_verified" : "callback.signature_invalid",
        source: "CALLBACK",
        signature_verified: signatureValid,
        payload: {
            razorpay_order_id: providerOrderId,
            razorpay_payment_id: providerPaymentId,
            request_id: requestId,
        },
        processed: signatureValid,
        processed_at: signatureValid ? new Date().toISOString() : null,
    });

    if (!signatureValid) {
        logger.error("verify_payment.signature_invalid", {
            request_id: requestId,
            payment_id: payment.id,
            provider_order_id: providerOrderId,
        });
        throw new AppError(
            "PAYMENT_FAILED",
            "We could not verify this payment. If money was deducted it will be refunded automatically.",
            { reason: "SIGNATURE_INVALID" },
        );
    }

    // ── 3. Confirm with Razorpay directly ──
    const gatewayPayment = await razorpay.fetchPayment(providerPaymentId);

    if (gatewayPayment.order_id !== providerOrderId) {
        throw new AppError(
            "PAYMENT_FAILED",
            "This payment does not belong to the order being paid.",
            { reason: "ORDER_MISMATCH" },
        );
    }

    if (gatewayPayment.amount !== toPaise(Number(payment.amount))) {
        // Amount tampering, or a partial payment we must not treat as complete.
        logger.error("verify_payment.amount_mismatch", {
            request_id: requestId,
            payment_id: payment.id,
            expected_paise: toPaise(Number(payment.amount)),
            gateway_paise: gatewayPayment.amount,
        });
        throw new AppError(
            "PAYMENT_FAILED",
            "The paid amount does not match this order. Our team will review it.",
            { reason: "AMOUNT_MISMATCH" },
        );
    }

    if ((gatewayPayment.currency ?? "INR") !== (payment.currency_code ?? "INR")) {
        throw new AppError("PAYMENT_FAILED", "Currency mismatch on this payment.", {
            reason: "CURRENCY_MISMATCH",
        });
    }

    if (gatewayPayment.status === "failed") {
        await rpc(admin, "svc_record_payment_failure", {
            p_payment_id: payment.id,
            p_failure_code: gatewayPayment.error_code ?? "PAYMENT_FAILED",
            p_failure_reason: gatewayPayment.error_description ?? "Payment failed at the gateway.",
            p_source: "CALLBACK",
        });

        throw new AppError(
            "PAYMENT_FAILED",
            gatewayPayment.error_description ??
                "Your payment did not go through. Nothing has been charged.",
            { gateway_code: gatewayPayment.error_code },
        );
    }

    if (gatewayPayment.status !== "captured" && gatewayPayment.status !== "authorized") {
        throw new AppError(
            "PAYMENT_FAILED",
            "This payment is not complete yet. Please wait a moment and refresh.",
            { gateway_status: gatewayPayment.status },
        );
    }

    // ── 4. Idempotent capture ──
    const capture = await rpc<{
        payment_id: string;
        order_id: string;
        status: string;
        already_captured: boolean;
        amount_captured: number;
        fully_reconciled: boolean;
    }>(admin, "svc_record_payment_capture", {
        p_payment_id: payment.id,
        p_provider_payment_id: providerPaymentId,
        p_amount_captured: fromPaise(gatewayPayment.amount),
        p_method: mapPaymentMethod(gatewayPayment.method),
        p_source: "CALLBACK",
        p_method_detail: extractMethodDetail(gatewayPayment),
        p_gateway_fee: gatewayPayment.fee ? fromPaise(gatewayPayment.fee) : 0,
        p_gateway_tax: gatewayPayment.tax ? fromPaise(gatewayPayment.tax) : 0,
    });

    logger.info("verify_payment.captured", {
        request_id: requestId,
        payment_id: payment.id,
        order_id: payment.order_id,
        already_captured: capture.already_captured,
        fully_reconciled: capture.fully_reconciled,
    });

    const { data: order } = await admin
        .from("orders")
        .select("id, order_number, status, payment_status, grand_total, promised_at")
        .eq("id", payment.order_id)
        .single();

    return jsonResponse(
        {
            verified: true,
            payment: {
                payment_id: capture.payment_id,
                status: capture.status,
                amount_captured: capture.amount_captured,
                method: mapPaymentMethod(gatewayPayment.method),
                already_captured: capture.already_captured,
                // False until the webhook also arrives; the app does not need to wait.
                fully_reconciled: capture.fully_reconciled,
            },
            order,
            next_action: "TRACK_ORDER",
        },
        { origin, requestId },
    );
});
