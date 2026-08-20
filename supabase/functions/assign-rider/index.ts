/**
 * POST /functions/v1/assign-rider
 *
 * Dispatch. Two modes:
 *   { order_id, delivery_partner_id }  — manual assignment (launch behaviour)
 *   { order_id, mode: "AUTO" }         — pick the best candidate automatically
 *
 * Automatic mode reuses exactly the same scoring as the manual rider list
 * (public.available_riders), which ranks by current workload, distance to the
 * restaurant, rating and duty state. That means the dispatcher and the algorithm
 * always agree on who the best rider is — turning auto-assign on later changes no
 * business logic, only who presses the button.
 *
 * Reassignment, capacity limits, branch scoping and the RIDER_ASSIGNED transition
 * are all enforced inside public.assign_rider.
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import { requireCaller, requirePermission, rpc, userClient } from "../_shared/supabase.ts";
import { v } from "../_shared/validate.ts";
import { AppError } from "../_shared/errors.ts";
import { logger } from "../_shared/logger.ts";

interface RiderCandidate {
    delivery_partner_id: string;
    full_name: string;
    duty_state: string;
    active_load: number;
    max_concurrent_orders: number;
    distance_to_store_km: number | null;
    score: number;
}

serveFunction("assign-rider", async ({ req, requestId, origin }) => {
    const caller = await requireCaller(req);
    const body = await readJson<Record<string, unknown>>(req);

    const orderId = v.uuid(body, "order_id");
    const mode = v.enumValue(body, "mode", ["MANUAL", "AUTO"] as const, "MANUAL");
    const client = userClient(req);

    await requirePermission(client, "delivery.assign");

    let riderId = v.optionalUuid(body, "delivery_partner_id");

    if (mode === "AUTO" || !riderId) {
        const { data: order, error } = await client
            .from("orders")
            .select("id, branch_id, status, fulfilment_type")
            .eq("id", orderId)
            .maybeSingle();

        if (error) throw new AppError("ORDER_NOT_FOUND", "Order not found.");
        if (!order) throw new AppError("ORDER_NOT_FOUND", "Order not found.");

        const candidates = await rpc<RiderCandidate[]>(client, "available_riders", {
            p_branch_id: order.branch_id,
            p_order_id: orderId,
        });

        const best = candidates
            .filter((c) => c.active_load < c.max_concurrent_orders)
            .sort((a, b) => a.score - b.score)[0];

        if (!best) {
            throw new AppError(
                "NO_DELIVERY_PARTNER",
                "No delivery partner is available right now. Try again shortly or assign manually.",
                { candidates_considered: candidates.length },
            );
        }

        riderId = best.delivery_partner_id;

        logger.info("dispatch.auto_selected", {
            request_id: requestId,
            order_id: orderId,
            delivery_partner_id: riderId,
            score: best.score,
            active_load: best.active_load,
            distance_km: best.distance_to_store_km,
        });
    }

    const result = await rpc(client, "assign_rider", {
        p_order_id: orderId,
        p_delivery_partner_id: riderId,
        p_mode: mode,
        p_offer_ttl_seconds: v.optionalNumber(body, "offer_ttl_seconds", { min: 30, max: 600 }),
    });

    logger.info("dispatch.assigned", {
        request_id: requestId,
        order_id: orderId,
        delivery_partner_id: riderId,
        mode,
        actor: caller.userId,
    });

    return jsonResponse(result, { status: 201, origin, requestId });
});
