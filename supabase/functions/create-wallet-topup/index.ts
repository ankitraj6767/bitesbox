/**
 * POST /functions/v1/create-wallet-topup
 * Creates an idempotent Razorpay order for a customer wallet top-up.
 * The requested amount is validated here and is never accepted as proof of payment.
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import { requireCaller, serviceClient } from "../_shared/supabase.ts";
import { v } from "../_shared/validate.ts";
import { AppError, fromPostgrestError } from "../_shared/errors.ts";
import { razorpay, toPaise } from "../_shared/razorpay.ts";
import { env } from "../_shared/env.ts";
import { logger } from "../_shared/logger.ts";

const MIN_TOPUP = 100;
const MAX_TOPUP = 10_000;

serveFunction("create-wallet-topup", async ({ req, requestId, origin }) => {
    const caller = await requireCaller(req);
    const body = await readJson<Record<string, unknown>>(req);
    const amount = v.number(body, "amount", { min: MIN_TOPUP, max: MAX_TOPUP });
    const idempotencyKey = v.idempotencyKey(body, req);

    if (Math.abs(amount * 100 - Math.round(amount * 100)) > 1e-7) {
        throw new AppError(
            "INVALID_AMOUNT",
            "Enter an amount with no more than two decimal places.",
        );
    }

    const admin = serviceClient();
    const { data: walletEnabled, error: featureError } = await admin.rpc("feature_enabled", {
        p_key: "wallet",
        p_user_id: caller.userId,
    });
    if (featureError) throw fromPostgrestError(featureError);
    if (walletEnabled !== true) {
        throw new AppError("FEATURE_DISABLED", "Wallet top-ups are currently unavailable.");
    }

    const { data: wallet, error: walletError } = await admin
        .from("wallet_accounts")
        .select("is_frozen")
        .eq("user_id", caller.userId)
        .maybeSingle();
    if (walletError) throw fromPostgrestError(walletError);
    if (wallet?.is_frozen) {
        throw new AppError("WALLET_FROZEN", "Your wallet is on hold. Please contact support.");
    }

    // Ignore duplicate create calls with the same key, including a retry after a
    // dropped connection. A key can never be reused for a different amount.
    const { data: inserted, error: insertError } = await admin
        .from("wallet_topups")
        .upsert({
            user_id: caller.userId,
            amount,
            currency_code: "INR",
            status: "CREATED",
            idempotency_key: idempotencyKey,
        }, {
            onConflict: "user_id,idempotency_key",
            ignoreDuplicates: true,
        })
        .select(
            "id, user_id, amount, currency_code, status, idempotency_key, provider_order_id, expires_at",
        )
        .maybeSingle();
    if (insertError) throw fromPostgrestError(insertError);

    let topup = inserted;
    if (!topup) {
        const { data: existing, error: existingError } = await admin
            .from("wallet_topups")
            .select(
                "id, user_id, amount, currency_code, status, idempotency_key, provider_order_id, expires_at",
            )
            .eq("user_id", caller.userId)
            .eq("idempotency_key", idempotencyKey)
            .single();
        if (existingError) throw fromPostgrestError(existingError);
        topup = existing;
    }

    if (Number(topup.amount) !== amount) {
        throw new AppError(
            "IDEMPOTENCY_CONFLICT",
            "This top-up request was already used for a different amount.",
        );
    }
    if (topup.status === "CAPTURED") {
        throw new AppError(
            "PAYMENT_ALREADY_CAPTURED",
            "This wallet top-up has already been completed.",
        );
    }

    const reusable = topup.provider_order_id &&
        (!topup.expires_at || new Date(topup.expires_at) > new Date());
    if (topup.provider_order_id && !reusable) {
        throw new AppError(
            "PAYMENT_SESSION_EXPIRED",
            "This payment session expired. Start a new top-up.",
        );
    }

    // The key is tied to the persistent top-up id, so a retry after a lost
    // response asks Razorpay for the same order rather than creating a charge.
    const gatewayOrder = reusable
        ? await razorpay.fetchOrder(topup.provider_order_id!)
        : await razorpay.createOrder({
            amountRupees: amount,
            currency: topup.currency_code,
            receipt: `bbtopup-${topup.id}`,
            notes: {
                wallet_topup_id: topup.id,
                user_id: caller.userId,
                purpose: "BITESBOX_WALLET_TOPUP",
            },
            idempotencyKey: `bb-wallet-topup-${topup.id}`,
        });

    if (gatewayOrder.amount !== toPaise(amount) || gatewayOrder.currency !== "INR") {
        logger.error("wallet_topup.gateway_amount_mismatch", {
            request_id: requestId,
            topup_id: topup.id,
            expected_paise: toPaise(amount),
            gateway_paise: gatewayOrder.amount,
            gateway_currency: gatewayOrder.currency,
        });
        throw new AppError(
            "PAYMENT_GATEWAY_ERROR",
            "We could not start the payment safely. Please try again.",
        );
    }

    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
    const { error: updateError } = await admin
        .from("wallet_topups")
        .update({
            provider_order_id: gatewayOrder.id,
            status: "CREATED",
            expires_at: expiresAt,
        })
        .eq("id", topup.id);
    if (updateError) throw fromPostgrestError(updateError);

    logger.info("wallet_topup.gateway_order_created", {
        request_id: requestId,
        topup_id: topup.id,
        provider_order_id: gatewayOrder.id,
        amount,
        reused: Boolean(reusable),
    });

    return jsonResponse({
        topup: {
            id: topup.id,
            provider_order_id: gatewayOrder.id,
            amount: toPaise(amount),
            amount_rupees: amount,
            currency: "INR",
            reused: Boolean(reusable),
        },
        checkout: {
            key_id: env.razorpayKeyId,
            name: "Bites Box",
            description: `Add ₹${amount.toFixed(2)} to your wallet`,
            theme_color: "#C1121F",
            prefill: { name: "", contact: caller.phone ?? "", email: caller.email ?? "" },
        },
    }, { status: reusable ? 200 : 201, origin, requestId });
});
