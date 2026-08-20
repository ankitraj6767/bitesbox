/**
 * POST /functions/v1/calculate-checkout
 *
 * Re-prices the caller's cart. Returns the full bill breakdown plus an `issues`
 * array of blocking and warning conditions (unavailable item, address not
 * serviceable, minimum order not met, store closed, coupon no longer valid…).
 *
 * The checkout screen renders straight from this response. `is_valid` is the only
 * thing that decides whether Place Order is enabled — and create-order calls the
 * same function again before writing anything, so a stale client cannot slip a
 * wrong total through.
 *
 * Request { cart_id?, branch_id?, payment_mode?, tip_amount?, loyalty_points? }
 */

import { serveRpcProxy } from "../_shared/proxy.ts";
import { PAYMENT_MODES, v } from "../_shared/validate.ts";

serveRpcProxy("calculate-checkout", {
    rpcName: "calculate_checkout",
    mapArgs: (body) => ({
        p_cart_id: v.optionalUuid(body, "cart_id"),
        p_branch_id: v.optionalUuid(body, "branch_id"),
        p_payment_mode: v.enumValue(body, "payment_mode", PAYMENT_MODES, "ONLINE"),
        p_tip_amount: v.optionalNumber(body, "tip_amount", { min: 0, max: 5000 }) ?? 0,
        p_loyalty_points: Math.floor(
            v.optionalNumber(body, "loyalty_points", { min: 0, max: 100000 }) ?? 0,
        ),
    }),
    logFields: (body) => ({ payment_mode: body["payment_mode"] ?? "ONLINE" }),
});
