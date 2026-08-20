/**
 * POST /functions/v1/create-payment
 *
 * Creates the Razorpay order for an existing Bites Box order and returns only
 * what the checkout SDK needs.
 *
 * Guarantees
 *   · The amount comes from orders.payable_amount, never from the request.
 *   · One live gateway order per Bites Box order: a retry reuses the existing
 *     Razorpay order instead of creating a second one, so a customer can never be
 *     charged twice for one basket.
 *   · The key secret never leaves the server; only the public key id is returned.
 *
 * Request  { order_id }
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import { requireCaller, serviceClient } from "../_shared/supabase.ts";
import { v } from "../_shared/validate.ts";
import { AppError, fromPostgrestError } from "../_shared/errors.ts";
import { razorpay, toPaise } from "../_shared/razorpay.ts";
import { env } from "../_shared/env.ts";
import { logger } from "../_shared/logger.ts";

serveFunction("create-payment", async ({ req, requestId, origin }) => {
    const caller = await requireCaller(req);
    const body = await readJson<Record<string, unknown>>(req);
    const orderId = v.uuid(body, "order_id");

    const admin = serviceClient();

    const { data: order, error: orderError } = await admin
        .from("orders")
        // A single literal (not a concatenation) so supabase-js can infer row types.
        .select(
            `id, order_number, user_id, branch_id, status, payment_mode, payment_status,
             payable_amount, grand_total, currency_code, customer_name, customer_phone, customer_email`,
        )
        .eq("id", orderId)
        .maybeSingle();

    if (orderError) throw fromPostgrestError(orderError);

    if (!order || order.user_id !== caller.userId) {
        throw new AppError("ORDER_NOT_FOUND", "We could not find that order on your account.");
    }

    if (order.payment_status === "CAPTURED") {
        throw new AppError(
            "PAYMENT_ALREADY_CAPTURED",
            "This order has already been paid for.",
            { order_number: order.order_number },
        );
    }

    if (order.status !== "PENDING_PAYMENT" && order.status !== "PAYMENT_FAILED") {
        throw new AppError(
            "INVALID_ORDER_TRANSITION",
            "This order is not awaiting payment.",
            { status: order.status },
        );
    }

    const payable = Number(order.payable_amount);
    if (!(payable > 0)) {
        throw new AppError("INVALID_AMOUNT", "This order has nothing left to pay.");
    }

    // ── Reuse a live gateway order rather than minting another ──
    const { data: existing, error: existingError } = await admin
        .from("payments")
        .select("id, provider_order_id, status, amount, expires_at, attempt_number")
        .eq("order_id", orderId)
        .in("status", ["CREATED", "PENDING", "AUTHORIZED"])
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

    if (existingError) throw fromPostgrestError(existingError);

    const reusable = existing &&
        existing.provider_order_id &&
        Number(existing.amount) === payable &&
        (!existing.expires_at || new Date(existing.expires_at) > new Date());

    if (reusable) {
        logger.info("payment.reused_gateway_order", {
            request_id: requestId,
            order_id: orderId,
            payment_id: existing!.id,
        });

        return jsonResponse(
            buildCheckoutPayload({
                paymentId: existing!.id,
                providerOrderId: existing!.provider_order_id!,
                amountRupees: payable,
                currency: order.currency_code,
                order,
                caller,
                reused: true,
            }),
            { origin, requestId },
        );
    }

    // Retire any stale attempt so exactly one row is ever in flight.
    if (existing) {
        await admin
            .from("payments")
            .update({ status: "EXPIRED", updated_at: new Date().toISOString() })
            .eq("id", existing.id);
    }

    const attemptNumber = (existing?.attempt_number ?? 0) + 1;

    // Deterministic per (order, attempt) so a retried call reuses the gateway order.
    const idempotencyKey = `bb-pay-${orderId}-${attemptNumber}`;

    const gatewayOrder = await razorpay.createOrder({
        amountRupees: payable,
        currency: order.currency_code ?? "INR",
        receipt: order.order_number,
        notes: {
            order_id: order.id,
            order_number: order.order_number,
            branch_id: order.branch_id,
            user_id: caller.userId,
        },
        idempotencyKey,
    });

    // Defence in depth: the gateway must be charging exactly what we computed.
    if (gatewayOrder.amount !== toPaise(payable)) {
        logger.error("payment.amount_mismatch", {
            request_id: requestId,
            order_id: orderId,
            expected_paise: toPaise(payable),
            gateway_paise: gatewayOrder.amount,
        });
        throw new AppError(
            "PAYMENT_GATEWAY_ERROR",
            "We could not start the payment safely. Please try again.",
        );
    }

    const { data: payment, error: insertError } = await admin
        .from("payments")
        .insert({
            order_id: order.id,
            user_id: caller.userId,
            branch_id: order.branch_id,
            gateway: "RAZORPAY",
            mode: order.payment_mode,
            status: "CREATED",
            currency_code: order.currency_code ?? "INR",
            amount: payable,
            provider_order_id: gatewayOrder.id,
            idempotency_key: idempotencyKey,
            attempt_number: attemptNumber,
            // Razorpay checkout sessions are short-lived; the reconciliation job closes
            // anything still open after this.
            expires_at: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
            notes: { receipt: order.order_number },
        })
        .select("id")
        .single();

    if (insertError) throw fromPostgrestError(insertError);

    await admin.from("orders")
        .update({ payment_status: "PENDING", updated_at: new Date().toISOString() })
        .eq("id", order.id);

    logger.info("payment.gateway_order_created", {
        request_id: requestId,
        order_id: orderId,
        payment_id: payment.id,
        provider_order_id: gatewayOrder.id,
        amount: payable,
        attempt: attemptNumber,
    });

    return jsonResponse(
        buildCheckoutPayload({
            paymentId: payment.id,
            providerOrderId: gatewayOrder.id,
            amountRupees: payable,
            currency: order.currency_code ?? "INR",
            order,
            caller,
            reused: false,
        }),
        { status: 201, origin, requestId },
    );
});

function buildCheckoutPayload(input: {
    paymentId: string;
    providerOrderId: string;
    amountRupees: number;
    currency: string;
    order: {
        id: string;
        order_number: string;
        customer_name: string | null;
        customer_phone: string | null;
        customer_email: string | null;
    };
    caller: { email: string | null; phone: string | null };
    reused: boolean;
}) {
    return {
        payment: {
            payment_id: input.paymentId,
            order_id: input.order.id,
            provider: "RAZORPAY",
            provider_order_id: input.providerOrderId,
            // Paise, matching what the SDK expects.
            amount: toPaise(input.amountRupees),
            amount_rupees: input.amountRupees,
            currency: input.currency,
            reused: input.reused,
        },
        checkout: {
            // Publishable key id only. The secret stays server-side, always.
            key_id: env.razorpayKeyId,
            name: "Bites Box",
            description: `Order ${input.order.order_number}`,
            theme_color: "#C1121F",
            prefill: {
                name: input.order.customer_name ?? "",
                contact: input.order.customer_phone ?? input.caller.phone ?? "",
                email: input.order.customer_email ?? input.caller.email ?? "",
            },
            notes: { order_number: input.order.order_number },
        },
    };
}
