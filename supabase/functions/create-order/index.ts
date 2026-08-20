/**
 * POST /functions/v1/create-order
 *
 * The only way an order comes into existence.
 *
 * Guarantees
 *   · The cart is re-priced server-side; the client's totals are ignored entirely.
 *   · Serviceability, availability, store state, coupon validity and COD limits
 *     are all re-checked at this instant, not when the cart was built.
 *   · Idempotent: the same key always returns the same order, so a double tap on
 *     "Place Order" or a retry after a dropped connection cannot duplicate it.
 *
 * Request
 *   { idempotency_key, payment_mode?, cart_id?, branch_id?, tip_amount?,
 *     loyalty_points?, app_version?, device_platform? }
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import { requireCaller, rpc, serviceClient } from "../_shared/supabase.ts";
import { DEVICE_PLATFORMS, PAYMENT_MODES, v } from "../_shared/validate.ts";
import { logger } from "../_shared/logger.ts";

interface PlaceOrderResult {
    order_id: string;
    order_number: string;
    status: string;
    payment_mode: string;
    payment_status: string;
    grand_total: number;
    payable_amount: number;
    currency_code: string;
    requires_payment: boolean;
    promised_at: string | null;
    replayed: boolean;
}

serveFunction("create-order", async ({ req, requestId, origin }) => {
    const caller = await requireCaller(req);
    const body = await readJson<Record<string, unknown>>(req);

    const idempotencyKey = v.idempotencyKey(body, req);
    const paymentMode = v.enumValue(body, "payment_mode", PAYMENT_MODES, "ONLINE");
    const cartId = v.optionalUuid(body, "cart_id");
    const branchId = v.optionalUuid(body, "branch_id");
    const tipAmount = v.optionalNumber(body, "tip_amount", { min: 0, max: 5000 }) ?? 0;
    const loyaltyPoints = v.optionalNumber(body, "loyalty_points", { min: 0, max: 100000 }) ?? 0;
    const appVersion = v.optionalString(body, "app_version", { max: 32 });

    const devicePlatform = body["device_platform"] === undefined || body["device_platform"] === null
        ? (req.headers.get("x-device-platform") as string | null)
        : v.enumValue(body, "device_platform", DEVICE_PLATFORMS);

    const admin = serviceClient();

    // app.place_order is SECURITY DEFINER and granted only to the service role, so
    // no client can reach it directly. It performs the authoritative recalculation.
    const result = await rpc<PlaceOrderResult>(admin, "svc_place_order", {
        p_user_id: caller.userId,
        p_idempotency_key: idempotencyKey,
        p_payment_mode: paymentMode,
        p_cart_id: cartId,
        p_branch_id: branchId,
        p_tip_amount: tipAmount,
        p_loyalty_points: Math.floor(loyaltyPoints),
        p_channel: "MOBILE_APP",
        p_app_version: appVersion,
        p_device_platform: DEVICE_PLATFORMS.includes(devicePlatform as never)
            ? devicePlatform
            : null,
    });

    logger.info("order.placed", {
        request_id: requestId,
        order_id: result.order_id,
        order_number: result.order_number,
        status: result.status,
        payment_mode: result.payment_mode,
        payable_amount: result.payable_amount,
        replayed: result.replayed,
    });

    return jsonResponse(
        {
            order: result,
            // Tells the app whether to open Razorpay next or go straight to tracking.
            next_action: result.requires_payment ? "CREATE_PAYMENT" : "TRACK_ORDER",
        },
        { status: result.replayed ? 200 : 201, origin, requestId },
    );
});
