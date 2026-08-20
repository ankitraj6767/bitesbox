/**
 * Supabase clients and caller identity.
 *
 * Two clients, deliberately distinct:
 *   · userClient    — carries the caller's JWT. RLS applies. Use for anything the
 *                     user is allowed to do themselves.
 *   · serviceClient — service role, bypasses RLS. Only for privileged operations
 *                     AFTER the function has verified the caller's permission in
 *                     the database.
 */

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2.49.4";
import { AppError, fromPostgrestError } from "./errors.ts";
import { env } from "./env.ts";

export type { SupabaseClient };

export function serviceClient(): SupabaseClient {
    return createClient(env.supabaseUrl, env.serviceRoleKey, {
        auth: { autoRefreshToken: false, persistSession: false },
        global: { headers: { "x-bitesbox-source": "edge-function" } },
    });
}

export function userClient(req: Request): SupabaseClient {
    const authorization = req.headers.get("Authorization") ?? "";

    return createClient(env.supabaseUrl, env.anonKey, {
        auth: { autoRefreshToken: false, persistSession: false },
        global: { headers: { Authorization: authorization, "x-bitesbox-source": "edge-function" } },
    });
}

export interface Caller {
    userId: string;
    email: string | null;
    phone: string | null;
    roles: string[];
    permissions: string[];
    primaryRole: string;
    branchIds: string[];
    accountStatus: string;
    accessToken: string;
}

/**
 * Verifies the bearer token and returns the caller with their claim-derived
 * roles. Claims are a convenience for branching in the function body; anything
 * that authorises a write is re-checked in Postgres.
 */
export async function requireCaller(req: Request): Promise<Caller> {
    const authorization = req.headers.get("Authorization");

    if (!authorization?.toLowerCase().startsWith("bearer ")) {
        throw new AppError("UNAUTHENTICATED", "Please sign in to continue.");
    }

    const accessToken = authorization.slice(7).trim();
    const admin = serviceClient();
    const { data, error } = await admin.auth.getUser(accessToken);

    if (error || !data?.user) {
        throw new AppError("INVALID_TOKEN", "Your session has expired. Please sign in again.");
    }

    const claims = decodeJwtClaims(accessToken);

    const caller: Caller = {
        userId: data.user.id,
        email: data.user.email ?? null,
        phone: data.user.phone ?? null,
        roles: asStringArray(claims["app_roles"]),
        permissions: asStringArray(claims["app_permissions"]),
        primaryRole: typeof claims["app_primary_role"] === "string"
            ? claims["app_primary_role"]
            : "CUSTOMER",
        branchIds: asStringArray(claims["app_branch_ids"]),
        accountStatus: typeof claims["app_account_status"] === "string"
            ? claims["app_account_status"]
            : "ACTIVE",
        accessToken,
    };

    if (caller.accountStatus === "BLOCKED" || caller.accountStatus === "DELETED") {
        throw new AppError(
            "ACCOUNT_BLOCKED",
            "This account cannot place orders. Please contact support.",
        );
    }

    return caller;
}

/** Requires the caller to hold a permission, verified against the database. */
export async function requirePermission(
    client: SupabaseClient,
    permission: string,
    branchId?: string | null,
): Promise<void> {
    const { data, error } = await client.rpc("has_permission", {
        p_permission: permission,
        p_branch_id: branchId ?? null,
    });

    if (error) throw fromPostgrestError(error);

    if (data !== true) {
        throw new AppError(
            "PERMISSION_DENIED",
            "You do not have permission to perform this action.",
            { permission },
        );
    }
}

/** Calls an RPC and unwraps the standard error contract. */
export async function rpc<T = unknown>(
    client: SupabaseClient,
    fn: string,
    args: Record<string, unknown> = {},
): Promise<T> {
    const { data, error } = await client.rpc(fn, args);
    if (error) throw fromPostgrestError(error);
    return data as T;
}

function decodeJwtClaims(token: string): Record<string, unknown> {
    try {
        const payload = token.split(".")[1];
        if (!payload) return {};
        const normalised = payload.replace(/-/g, "+").replace(/_/g, "/");
        const padded = normalised.padEnd(
            normalised.length + ((4 - (normalised.length % 4)) % 4),
            "=",
        );
        return JSON.parse(atob(padded)) as Record<string, unknown>;
    } catch {
        return {};
    }
}

function asStringArray(value: unknown): string[] {
    if (!Array.isArray(value)) return [];
    return value.filter((item): item is string => typeof item === "string");
}
