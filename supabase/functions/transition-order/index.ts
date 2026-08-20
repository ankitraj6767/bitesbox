/**
 * POST /functions/v1/transition-order
 *
 * Single entry point for the staff-driven order actions:
 *   ACCEPT · REJECT · PREPARE · READY · CANCEL · CANCEL_ITEM
 *
 * Every action maps to a purpose-built RPC that validates the state-machine edge
 * and the caller's permission inside Postgres. Nothing here can force an illegal
 * transition, and an override still requires order.override and is audited.
 *
 * Request { order_id, action, ... }
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import { requireCaller, rpc, userClient } from "../_shared/supabase.ts";
import { v } from "../_shared/validate.ts";
import { logger } from "../_shared/logger.ts";

const ACTIONS = [
    "ACCEPT",
    "REJECT",
    "PREPARE",
    "READY",
    "CANCEL",
    "CANCEL_ITEM",
] as const;

const CANCELLATION_REASONS = [
    "CUSTOMER_CHANGED_MIND",
    "ORDERED_BY_MISTAKE",
    "DELIVERY_TOO_LONG",
    "ADDRESS_WRONG",
    "ITEM_UNAVAILABLE",
    "KITCHEN_OVERLOADED",
    "RESTAURANT_CLOSED",
    "NO_DELIVERY_PARTNER",
    "PAYMENT_ISSUE",
    "DUPLICATE_ORDER",
    "CUSTOMER_UNREACHABLE",
    "WEATHER",
    "FRAUD_SUSPECTED",
    "OTHER",
] as const;

serveFunction("transition-order", async ({ req, requestId, origin }) => {
    const caller = await requireCaller(req);
    const body = await readJson<Record<string, unknown>>(req);
    const action = v.enumValue(body, "action", ACTIONS);
    const client = userClient(req);

    let result: unknown;

    switch (action) {
        case "ACCEPT":
            result = await rpc(client, "accept_order", {
                p_order_id: v.uuid(body, "order_id"),
                // Lets the kitchen commit to a realistic prep time, which reshapes the ETA.
                p_prep_minutes: v.optionalNumber(body, "prep_minutes", { min: 1, max: 240 }),
            });
            break;

        case "REJECT":
            result = await rpc(client, "reject_order", {
                p_order_id: v.uuid(body, "order_id"),
                p_reason: v.enumValue(body, "reason", CANCELLATION_REASONS, "KITCHEN_OVERLOADED"),
                p_note: v.optionalString(body, "note", { max: 1000 }),
            });
            break;

        case "PREPARE":
            result = await rpc(client, "start_preparing", { p_order_id: v.uuid(body, "order_id") });
            break;

        case "READY":
            result = await rpc(client, "mark_order_ready", {
                p_order_id: v.uuid(body, "order_id"),
            });
            break;

        case "CANCEL":
            result = await rpc(client, "cancel_order", {
                p_order_id: v.uuid(body, "order_id"),
                p_reason: v.enumValue(body, "reason", CANCELLATION_REASONS, "OTHER"),
                p_note: v.optionalString(body, "note", { max: 1000 }),
            });
            break;

        case "CANCEL_ITEM":
            result = await rpc(client, "cancel_order_item", {
                p_order_item_id: v.uuid(body, "order_item_id"),
                p_note: v.optionalString(body, "note", { max: 1000 }),
            });
            break;
    }

    logger.info("order.transition", {
        request_id: requestId,
        action,
        actor: caller.userId,
        role: caller.primaryRole,
        order_id: body["order_id"] ?? null,
    });

    return jsonResponse(result, { origin, requestId });
});
