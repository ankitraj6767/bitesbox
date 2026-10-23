/**
 * POST /functions/v1/verify-wallet-topup
 * Verifies a Razorpay callback against Razorpay itself, then posts one credit to
 * the append-only wallet ledger. A client callback alone can never add balance.
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import { requireCaller, rpc, serviceClient } from "../_shared/supabase.ts";
import { v } from "../_shared/validate.ts";
import { AppError, fromPostgrestError } from "../_shared/errors.ts";
import { fromPaise, razorpay, toPaise, verifyPaymentSignature } from "../_shared/razorpay.ts";
import { logger, reportToSentry } from "../_shared/logger.ts";

serveFunction("verify-wallet-topup", async ({ req, requestId, origin }) => {
    const caller = await requireCaller(req);
    const body = await readJson<Record<string, unknown>>(req);
    const providerOrderId = v.string(body, "razorpay_order_id", { min: 6, max: 64 });
    const providerPaymentId = v.string(body, "razorpay_payment_id", { min: 6, max: 64 });
    const signature = v.string(body, "razorpay_signature", { min: 16, max: 256 });
    const admin = serviceClient();

    const { data: topup, error: topupError } = await admin
        .from("wallet_topups")
        .select("id, user_id, amount, currency_code, status, provider_order_id")
        .eq("provider_order_id", providerOrderId)
        .maybeSingle();
    if (topupError) throw fromPostgrestError(topupError);
    if (!topup || topup.user_id !== caller.userId) {
        throw new AppError(
            "PAYMENT_NOT_FOUND",
            "We could not find this wallet top-up on your account.",
        );
    }

    const signatureValid = await verifyPaymentSignature({
        razorpayOrderId: providerOrderId,
        razorpayPaymentId: providerPaymentId,
        signature,
    });
    if (!signatureValid) {
        logger.error("wallet_topup.signature_invalid", {
            request_id: requestId,
            topup_id: topup.id,
            provider_order_id: providerOrderId,
        });
        throw new AppError(
            "PAYMENT_FAILED",
            "We could not verify this payment. Please contact support if money was deducted.",
        );
    }

    const gatewayPayment = await razorpay.fetchPayment(providerPaymentId);
    if (gatewayPayment.order_id !== providerOrderId) {
        throw new AppError("PAYMENT_FAILED", "This payment does not belong to your wallet top-up.");
    }
    if (gatewayPayment.amount !== toPaise(Number(topup.amount))) {
        logger.error("wallet_topup.amount_mismatch", {
            request_id: requestId,
            topup_id: topup.id,
            expected_paise: toPaise(Number(topup.amount)),
            gateway_paise: gatewayPayment.amount,
        });
        await reportToSentry(new Error("wallet_topup.amount_mismatch"), {
            fn: "verify-wallet-topup",
            request_id: requestId,
            topup_id: topup.id,
            role_category: caller.primaryRole.toLowerCase(),
            error_code: "AMOUNT_MISMATCH",
        });
        throw new AppError(
            "PAYMENT_FAILED",
            "The paid amount does not match this wallet top-up. Please contact support.",
        );
    }
    if ((gatewayPayment.currency ?? "INR") !== topup.currency_code) {
        await reportToSentry(new Error("wallet_topup.currency_mismatch"), {
            fn: "verify-wallet-topup",
            request_id: requestId,
            topup_id: topup.id,
            role_category: caller.primaryRole.toLowerCase(),
            error_code: "CURRENCY_MISMATCH",
        });
        throw new AppError(
            "PAYMENT_FAILED",
            "The payment currency does not match this wallet top-up.",
        );
    }

    if (gatewayPayment.status === "failed") {
        const { error: statusError } = await admin.from("wallet_topups")
            .update({ status: "FAILED" })
            .eq("id", topup.id)
            .neq("status", "CAPTURED");
        if (statusError) throw fromPostgrestError(statusError);
        throw new AppError(
            "PAYMENT_FAILED",
            gatewayPayment.error_description ?? "Your payment did not go through.",
        );
    }

    if (gatewayPayment.status !== "captured") {
        const { error: statusError } = await admin.from("wallet_topups")
            .update({ status: gatewayPayment.status === "authorized" ? "AUTHORIZED" : "PENDING" })
            .eq("id", topup.id)
            .neq("status", "CAPTURED");
        if (statusError) throw fromPostgrestError(statusError);
        return jsonResponse({
            verified: false,
            status: "PENDING",
            message:
                "Your payment is still processing. Your wallet will update when it is confirmed.",
        }, { status: 202, origin, requestId });
    }

    const capture = await rpc<{
        transaction_id: string;
        balance: number;
        replayed: boolean;
        already_captured: boolean;
    }>(admin, "svc_record_wallet_topup_capture", {
        p_topup_id: topup.id,
        p_provider_payment_id: providerPaymentId,
        p_amount_captured: fromPaise(gatewayPayment.amount),
        p_source: "CALLBACK",
    });

    logger.info("wallet_topup.credited", {
        request_id: requestId,
        topup_id: topup.id,
        transaction_id: capture.transaction_id,
        already_captured: capture.already_captured,
    });

    return jsonResponse({
        verified: true,
        status: "CAPTURED",
        wallet_balance: capture.balance,
        already_credited: capture.already_captured,
    }, { origin, requestId });
});
