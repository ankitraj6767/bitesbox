/**
 * POST /functions/v1/admin-operation
 *
 * Privileged back-office operations that need more than a table write:
 *
 *   BLOCK_CUSTOMER / UNBLOCK_CUSTOMER  — customer.block
 *   ISSUE_WALLET_CREDIT                — customer.credit
 *   APPROVE_RIDER / SUSPEND_RIDER      — rider.approve / rider.suspend
 *   SET_BRANCH_STATUS                  — branch.manage
 *   SETTLE_COD                         — payment.reconcile
 *   GRANT_ROLE / REVOKE_ROLE           — role.assign
 *   CREATE_STAFF                       — staff.create + role.assign
 *   RESET_STAFF_PASSWORD               — staff.update
 *
 * Each branch re-checks the specific permission in the database with the caller's
 * own JWT, then performs the write with the service client where a table-level
 * policy alone is not enough. Every operation writes an audit entry, either
 * through a trigger or explicitly.
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import {
    requireCaller,
    requirePermission,
    rpc,
    serviceClient,
    userClient,
} from "../_shared/supabase.ts";
import { v } from "../_shared/validate.ts";
import { AppError, fromPostgrestError } from "../_shared/errors.ts";
import { logger } from "../_shared/logger.ts";

const OPERATIONS = [
    "BLOCK_CUSTOMER",
    "UNBLOCK_CUSTOMER",
    "ISSUE_WALLET_CREDIT",
    "APPROVE_RIDER",
    "SUSPEND_RIDER",
    "SET_BRANCH_STATUS",
    "SETTLE_COD",
    "GRANT_ROLE",
    "REVOKE_ROLE",
    "CREATE_STAFF",
    "RESET_STAFF_PASSWORD",
] as const;

const BRANCH_STATUSES = ["OPEN", "CLOSED", "PAUSED", "BUSY"] as const;
const CLOSURE_REASONS = [
    "SCHEDULED_CLOSED",
    "TOO_BUSY",
    "TECHNICAL_ISSUE",
    "KITCHEN_ISSUE",
    "WEATHER",
    "HOLIDAY",
    "OTHER",
] as const;
const ASSIGNABLE_ROLES = [
    "CUSTOMER",
    "DELIVERY_PARTNER",
    "KITCHEN_STAFF",
    "SUPPORT",
    "MARKETING",
    "FINANCE",
    "OPERATIONS",
    "MANAGER",
    "ADMIN",
] as const;
const STAFF_ROLES = [
    "KITCHEN_STAFF",
    "MANAGER",
    "OPERATIONS",
    "FINANCE",
    "SUPPORT",
    "MARKETING",
    "ADMIN",
] as const;

serveFunction("admin-operation", async ({ req, requestId, origin }) => {
    const caller = await requireCaller(req);
    const body = await readJson<Record<string, unknown>>(req);
    const operation = v.enumValue(body, "operation", OPERATIONS);

    const asUser = userClient(req);
    const admin = serviceClient();
    const now = new Date().toISOString();

    let result: Record<string, unknown>;

    switch (operation) {
        case "BLOCK_CUSTOMER": {
            await requirePermission(asUser, "customer.block");

            const userId = v.uuid(body, "user_id");
            const reason = v.string(body, "reason", { min: 3, max: 500 });

            if (userId === caller.userId) {
                throw new AppError("VALIDATION_FAILED", "You cannot block your own account.");
            }

            const { error } = await admin
                .from("profiles")
                .update({
                    status: "BLOCKED",
                    blocked_reason: reason,
                    blocked_at: now,
                    blocked_by: caller.userId,
                    updated_at: now,
                })
                .eq("id", userId);

            if (error) throw fromPostgrestError(error);

            // Audited by the audit_profile_status trigger.
            result = { user_id: userId, status: "BLOCKED" };
            break;
        }

        case "UNBLOCK_CUSTOMER": {
            await requirePermission(asUser, "customer.block");

            const userId = v.uuid(body, "user_id");

            const { error } = await admin
                .from("profiles")
                .update({
                    status: "ACTIVE",
                    blocked_reason: null,
                    blocked_at: null,
                    blocked_by: null,
                    updated_at: now,
                })
                .eq("id", userId);

            if (error) throw fromPostgrestError(error);

            result = { user_id: userId, status: "ACTIVE" };
            break;
        }

        case "ISSUE_WALLET_CREDIT": {
            await requirePermission(asUser, "customer.credit");

            const userId = v.uuid(body, "user_id");
            const amount = v.number(body, "amount", { min: 1, max: 25000 });
            const note = v.string(body, "note", { min: 3, max: 500 });

            // Idempotency stops a double-click from crediting twice.
            const idempotencyKey = v.idempotencyKey(body, req);

            const ledger = await rpc<
                { transaction_id: string; balance: number; replayed: boolean }
            >(
                admin,
                "svc_post_wallet_entry",
                {
                    p_user_id: userId,
                    p_kind: "ADJUSTMENT",
                    p_amount: amount,
                    p_description: note,
                    p_idempotency_key: idempotencyKey,
                },
            );

            await rpc(admin, "svc_audit", {
                p_action: "WALLET_ADJUSTMENT",
                p_entity_type: "wallet",
                p_entity_id: userId,
                p_new_value: { amount, note, transaction_id: ledger.transaction_id },
                p_reason: note,
                p_actor_id: caller.userId,
            });

            result = { user_id: userId, ...ledger };
            break;
        }

        case "APPROVE_RIDER": {
            await requirePermission(asUser, "rider.approve");

            const riderId = v.uuid(body, "delivery_partner_id");

            // Documents must be reviewed before a rider can carry orders.
            const { data: pending, error: docError } = await admin
                .from("delivery_partner_documents")
                .select("document_type, status")
                .eq("delivery_partner_id", riderId)
                .neq("status", "APPROVED");

            if (docError) throw fromPostgrestError(docError);

            if ((pending ?? []).length > 0) {
                throw new AppError(
                    "VALIDATION_FAILED",
                    "Approve every document before activating this delivery partner.",
                    { pending_documents: pending?.map((d) => d.document_type) },
                );
            }

            const { error } = await admin
                .from("delivery_partners")
                .update({
                    onboarding_status: "ACTIVE",
                    approved_by: caller.userId,
                    approved_at: now,
                    rejection_reason: null,
                    suspended_reason: null,
                    updated_at: now,
                })
                .eq("id", riderId);

            if (error) throw fromPostgrestError(error);

            result = { delivery_partner_id: riderId, onboarding_status: "ACTIVE" };
            break;
        }

        case "SUSPEND_RIDER": {
            await requirePermission(asUser, "rider.suspend");

            const riderId = v.uuid(body, "delivery_partner_id");
            const reason = v.string(body, "reason", { min: 3, max: 500 });
            const until = v.optionalString(body, "suspended_until", { max: 40 });

            // A rider mid-delivery must finish before being taken offline.
            const { data: active, error: activeError } = await admin
                .from("delivery_assignments")
                .select("id")
                .eq("delivery_partner_id", riderId)
                .in("status", ["ACCEPTED", "AT_STORE", "PICKED_UP", "AT_CUSTOMER"]);

            if (activeError) throw fromPostgrestError(activeError);

            if ((active ?? []).length > 0) {
                throw new AppError(
                    "ACTIVE_DELIVERIES_PENDING",
                    "This delivery partner has active deliveries. Reassign them first.",
                    { active_deliveries: active?.length },
                );
            }

            const { error } = await admin
                .from("delivery_partners")
                .update({
                    onboarding_status: "SUSPENDED",
                    suspended_reason: reason,
                    suspended_until: until,
                    duty_state: "OFFLINE",
                    updated_at: now,
                })
                .eq("id", riderId);

            if (error) throw fromPostgrestError(error);

            result = { delivery_partner_id: riderId, onboarding_status: "SUSPENDED" };
            break;
        }

        case "SET_BRANCH_STATUS": {
            // Permission is enforced inside set_branch_status().
            result = await rpc(asUser, "set_branch_status", {
                p_status: v.enumValue(body, "status", BRANCH_STATUSES),
                p_reason: body["reason"] ? v.enumValue(body, "reason", CLOSURE_REASONS) : null,
                p_note: v.optionalString(body, "note", { max: 500 }),
                p_branch_id: v.optionalUuid(body, "branch_id"),
                p_resume_after_minutes: v.optionalNumber(body, "resume_after_minutes", {
                    min: 5,
                    max: 1440,
                }),
            });
            break;
        }

        case "SETTLE_COD": {
            result = await rpc(asUser, "settle_cod", {
                p_delivery_partner_id: v.uuid(body, "delivery_partner_id"),
                p_order_ids: v.array(body, "order_ids", (item) => String(item), { max: 200 }),
                p_note: v.optionalString(body, "note", { max: 500 }),
            });
            break;
        }

        case "GRANT_ROLE":
        case "REVOKE_ROLE": {
            await requirePermission(asUser, "role.assign");

            const userId = v.uuid(body, "user_id");
            const roleCode = v.enumValue(body, "role", ASSIGNABLE_ROLES);
            const branchId = v.optionalUuid(body, "branch_id");

            // The privilege-escalation guard in the database has the final word; using
            // the user client keeps auth.uid() populated so it can evaluate rank.
            result = await rpc(asUser, "manage_user_role", {
                p_user_id: userId,
                p_role: roleCode,
                p_branch_id: branchId,
                p_grant: operation === "GRANT_ROLE",
                p_make_primary: v.boolean(body, "make_primary", false),
            });
            break;
        }

        case "CREATE_STAFF": {
            // Provisioning needs both capabilities: creating the employee record
            // and granting the role that makes the account usable in the app.
            await requirePermission(asUser, "staff.create");
            await requirePermission(asUser, "role.assign");

            const email = v.string(body, "email", { min: 5, max: 254 }).toLowerCase();
            if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
                throw new AppError("VALIDATION_FAILED", "Enter a valid work email address.");
            }
            const password = v.string(body, "temporary_password", { min: 8, max: 72 });
            const fullName = v.string(body, "full_name", { min: 2, max: 120 });
            const phone = v.optionalString(body, "phone", { max: 30 });
            const roleCode = v.enumValue(body, "role", STAFF_ROLES);
            const branchId = v.optionalUuid(body, "branch_id") ?? caller.branchIds[0] ??
                await defaultBranchId(admin);
            const employeeCode = v.optionalString(body, "employee_code", { max: 40 });
            const designation = v.optionalString(body, "designation", { max: 120 });
            const department = v.optionalString(body, "department", { max: 120 });
            const shiftStart = v.optionalString(body, "shift_start", { max: 12 });
            const shiftEnd = v.optionalString(body, "shift_end", { max: 12 });

            await requirePermission(asUser, "staff.create", branchId);

            const { data: created, error: createError } = await admin.auth.admin.createUser({
                email,
                password,
                email_confirm: true,
                user_metadata: {
                    full_name: fullName,
                    ...(phone ? { phone } : {}),
                    signup_channel: "admin_invite",
                },
            });

            if (createError || !created.user) {
                throw new AppError(
                    "VALIDATION_FAILED",
                    createError?.message ?? "The staff account could not be created.",
                );
            }

            const userId = created.user.id;
            try {
                const { data: staffMember, error: staffError } = await admin
                    .from("staff_members")
                    .insert({
                        user_id: userId,
                        branch_id: branchId,
                        employee_code: employeeCode,
                        designation,
                        department,
                        shift_start: shiftStart,
                        shift_end: shiftEnd,
                        created_by: caller.userId,
                    })
                    .select("id")
                    .single();

                if (staffError || !staffMember) {
                    throw fromPostgrestError(
                        staffError ?? { message: "The staff record could not be created." },
                    );
                }

                await rpc(asUser, "manage_user_role", {
                    p_user_id: userId,
                    p_role: roleCode,
                    p_branch_id: branchId,
                    p_grant: true,
                    p_make_primary: true,
                });

                await rpc(admin, "svc_audit", {
                    p_action: "CREATE",
                    p_entity_type: "staff_member",
                    p_entity_id: staffMember.id,
                    p_new_value: {
                        user_id: userId,
                        email,
                        role: roleCode,
                        branch_id: branchId,
                        employee_code: employeeCode,
                    },
                    p_entity_label: fullName,
                    p_branch_id: branchId,
                    p_actor_id: caller.userId,
                });

                result = {
                    user_id: userId,
                    staff_member_id: staffMember.id,
                    email,
                    full_name: fullName,
                    role: roleCode,
                    branch_id: branchId,
                    temporary_password: password,
                };
            } catch (error) {
                // Do not leave an Auth account that cannot sign in to the app.
                await admin.auth.admin.deleteUser(userId);
                throw error;
            }
            break;
        }

        case "RESET_STAFF_PASSWORD": {
            await requirePermission(asUser, "staff.update");

            const userId = v.uuid(body, "user_id");
            const password = v.string(body, "temporary_password", { min: 8, max: 72 });

            if (userId === caller.userId) {
                throw new AppError(
                    "VALIDATION_FAILED",
                    "Use the account recovery flow to change your own password.",
                );
            }

            const { data: staffMember, error: staffError } = await admin
                .from("staff_members")
                .select("id, branch_id, profiles!staff_members_user_profile_fkey(full_name, email)")
                .eq("user_id", userId)
                .is("deleted_at", null)
                .maybeSingle();

            if (staffError) throw fromPostgrestError(staffError);
            if (!staffMember) {
                throw new AppError("VALIDATION_FAILED", "That account has no active staff record.");
            }

            const { error: updateError } = await admin.auth.admin.updateUserById(userId, {
                password,
            });
            if (updateError) throw new AppError("VALIDATION_FAILED", updateError.message);

            const profile = staffMember.profiles?.[0];

            await rpc(admin, "svc_audit", {
                p_action: "UPDATE",
                p_entity_type: "staff_member",
                p_entity_id: staffMember.id,
                p_new_value: { user_id: userId, password_reset: true },
                p_reason: "Staff password reset by an authorised manager.",
                p_entity_label: profile?.full_name ?? profile?.email ?? userId,
                p_branch_id: staffMember.branch_id,
                p_actor_id: caller.userId,
            });

            result = {
                user_id: userId,
                email: profile?.email,
                temporary_password: password,
            };
            break;
        }
    }

    logger.info("admin.operation", {
        request_id: requestId,
        operation,
        actor: caller.userId,
        role: caller.primaryRole,
    });

    return jsonResponse({ operation, result }, { origin, requestId });
});

async function defaultBranchId(admin: ReturnType<typeof serviceClient>): Promise<string> {
    const { data, error } = await admin
        .from("branches")
        .select("id")
        .eq("is_default", true)
        .is("deleted_at", null)
        .maybeSingle();

    if (error) throw fromPostgrestError(error);
    if (!data?.id) {
        throw new AppError("VALIDATION_FAILED", "No active default branch is configured.");
    }
    return data.id;
}
