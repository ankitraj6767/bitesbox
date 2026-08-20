/**
 * POST /functions/v1/apply-coupon
 *
 * Validates a coupon code against the caller's live cart and, if it holds up,
 * attaches it and returns the recalculated bill.
 *
 * All rules live in app.evaluate_coupon: window, day/time restrictions, audience,
 * first-order-only, per-customer and global usage caps, eligible products and
 * categories, payment-mode and zone restrictions, minimum order value, and any
 * composed coupon_rules. An invalid coupon is rolled off the cart rather than left
 * attached, and code guessing is rate limited per user.
 *
 * Request { code, cart_id?, branch_id? }
 */

import { serveRpcProxy } from "../_shared/proxy.ts";
import { v } from "../_shared/validate.ts";

serveRpcProxy("apply-coupon", {
    rpcName: "apply_coupon",
    mapArgs: (body) => ({
        p_code: v.string(body, "code", { min: 3, max: 32 }).toUpperCase(),
        p_cart_id: v.optionalUuid(body, "cart_id"),
        p_branch_id: v.optionalUuid(body, "branch_id"),
    }),
    logFields: (body) => ({ code: String(body["code"] ?? "").toUpperCase() }),
});
