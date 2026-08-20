/**
 * POST /functions/v1/complete-delivery
 *
 * The rider app's delivery lifecycle endpoint:
 *   ARRIVED_STORE · VERIFY_PICKUP · ARRIVED_CUSTOMER · COMPLETE · FAIL
 *
 * COMPLETE requires the customer's delivery OTP. Only a user holding
 * delivery.override can complete without it, and that path writes a
 * MANUAL_DELIVERY_OVERRIDE audit entry naming them. COD collection is reconciled
 * in the same transaction as completion, so cash can never go unrecorded.
 *
 * OTP attempts are rate limited per assignment, so a rider cannot brute-force a
 * 4-digit code.
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import { requireCaller, rpc, userClient } from "../_shared/supabase.ts";
import { v } from "../_shared/validate.ts";
import { logger } from "../_shared/logger.ts";

const STEPS = [
    "ARRIVED_STORE",
    "VERIFY_PICKUP",
    "ARRIVED_CUSTOMER",
    "COMPLETE",
    "FAIL",
] as const;

serveFunction("complete-delivery", async ({ req, requestId, origin }) => {
    const caller = await requireCaller(req);
    const body = await readJson<Record<string, unknown>>(req);

    const assignmentId = v.uuid(body, "assignment_id");
    const step = v.enumValue(body, "step", STEPS);
    const client = userClient(req);

    let result: unknown;

    switch (step) {
        case "ARRIVED_STORE":
            result = await rpc(client, "rider_arrived_at_store", { p_assignment_id: assignmentId });
            break;

        case "VERIFY_PICKUP":
            result = await rpc(client, "verify_pickup", {
                p_assignment_id: assignmentId,
                p_code: v.string(body, "code", { min: 3, max: 12 }),
            });
            break;

        case "ARRIVED_CUSTOMER":
            result = await rpc(client, "rider_arrived_at_customer", {
                p_assignment_id: assignmentId,
            });
            break;

        case "COMPLETE": {
            const managerOverride = v.boolean(body, "manager_override", false);

            result = await rpc(client, "complete_delivery", {
                p_assignment_id: assignmentId,
                // Required unless a permitted manager override is requested.
                p_otp: managerOverride ? null : v.string(body, "otp", { min: 3, max: 8 }),
                p_cash_collected: v.optionalNumber(body, "cash_collected", { min: 0, max: 100000 }),
                p_proof_photo_path: v.optionalString(body, "proof_photo_path", { max: 500 }),
                p_note: v.optionalString(body, "note", { max: 1000 }),
                p_manager_override: managerOverride,
            });

            if (managerOverride) {
                logger.warn("delivery.manager_override_used", {
                    request_id: requestId,
                    assignment_id: assignmentId,
                    actor: caller.userId,
                    role: caller.primaryRole,
                });
            }
            break;
        }

        case "FAIL":
            result = await rpc(client, "fail_delivery", {
                p_assignment_id: assignmentId,
                p_reason: v.string(body, "reason", { min: 3, max: 200 }),
                p_note: v.optionalString(body, "note", { max: 1000 }),
            });
            break;
    }

    logger.info("delivery.step", {
        request_id: requestId,
        step,
        assignment_id: assignmentId,
        actor: caller.userId,
    });

    return jsonResponse(result, { origin, requestId });
});
