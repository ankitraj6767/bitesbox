/**
 * Minimal, dependency-free request validation.
 *
 * Edge Functions must not trust any field from a client. These helpers coerce and
 * bound-check every value, throwing the standard VALIDATION_FAILED error with the
 * offending field name so the mobile app can highlight it.
 */

import { AppError } from "./errors.ts";

type Raw = Record<string, unknown>;

function fail(field: string, expectation: string, value?: unknown): never {
    throw new AppError(
        "VALIDATION_FAILED",
        `The field "${field}" ${expectation}.`,
        { field, expectation, received: typeof value },
    );
}

export const v = {
    string(body: Raw, field: string, opts: { min?: number; max?: number } = {}): string {
        const value = body[field];
        if (typeof value !== "string") fail(field, "must be a string", value);
        const trimmed = (value as string).trim();
        if (opts.min !== undefined && trimmed.length < opts.min) {
            fail(field, `must be at least ${opts.min} characters`);
        }
        if (opts.max !== undefined && trimmed.length > opts.max) {
            fail(field, `must be at most ${opts.max} characters`);
        }
        return trimmed;
    },

    optionalString(body: Raw, field: string, opts: { max?: number } = {}): string | null {
        const value = body[field];
        if (value === undefined || value === null || value === "") return null;
        if (typeof value !== "string") fail(field, "must be a string", value);
        const trimmed = (value as string).trim();
        if (opts.max !== undefined && trimmed.length > opts.max) {
            fail(field, `must be at most ${opts.max} characters`);
        }
        return trimmed || null;
    },

    uuid(body: Raw, field: string): string {
        const value = this.string(body, field, { min: 36, max: 36 });
        if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) {
            fail(field, "must be a valid UUID");
        }
        return value.toLowerCase();
    },

    optionalUuid(body: Raw, field: string): string | null {
        const value = body[field];
        if (value === undefined || value === null || value === "") return null;
        return this.uuid(body, field);
    },

    number(body: Raw, field: string, opts: { min?: number; max?: number } = {}): number {
        const raw = body[field];
        const value = typeof raw === "string" ? Number(raw) : raw;
        if (typeof value !== "number" || !Number.isFinite(value)) {
            fail(field, "must be a number", raw);
        }
        if (opts.min !== undefined && (value as number) < opts.min) {
            fail(field, `must be at least ${opts.min}`);
        }
        if (opts.max !== undefined && (value as number) > opts.max) {
            fail(field, `must be at most ${opts.max}`);
        }
        return value as number;
    },

    optionalNumber(
        body: Raw,
        field: string,
        opts: { min?: number; max?: number } = {},
    ): number | null {
        const raw = body[field];
        if (raw === undefined || raw === null || raw === "") return null;
        return this.number(body, field, opts);
    },

    integer(body: Raw, field: string, opts: { min?: number; max?: number } = {}): number {
        const value = this.number(body, field, opts);
        if (!Number.isInteger(value)) fail(field, "must be a whole number");
        return value;
    },

    boolean(body: Raw, field: string, fallback?: boolean): boolean {
        const value = body[field];
        if (value === undefined || value === null) {
            if (fallback !== undefined) return fallback;
            fail(field, "is required");
        }
        if (typeof value === "boolean") return value;
        if (value === "true") return true;
        if (value === "false") return false;
        return fail(field, "must be a boolean", value);
    },

    enumValue<T extends string>(body: Raw, field: string, allowed: readonly T[], fallback?: T): T {
        const value = body[field];
        if (value === undefined || value === null || value === "") {
            if (fallback !== undefined) return fallback;
            fail(field, "is required");
        }
        if (typeof value !== "string" || !allowed.includes(value as T)) {
            fail(field, `must be one of: ${allowed.join(", ")}`, value);
        }
        return value as T;
    },

    array<T>(
        body: Raw,
        field: string,
        mapper: (item: unknown, index: number) => T,
        opts: { max?: number } = {},
    ): T[] {
        const value = body[field];
        if (value === undefined || value === null) return [];
        if (!Array.isArray(value)) fail(field, "must be an array", value);
        if (opts.max !== undefined && value.length > opts.max) {
            fail(field, `must contain at most ${opts.max} items`);
        }
        return value.map(mapper);
    },

    /**
     * Idempotency keys guard every money-moving call. We require enough entropy
     * that two independent checkouts cannot collide.
     */
    idempotencyKey(body: Raw, req?: Request): string {
        const fromHeader = req?.headers.get("x-idempotency-key")?.trim();
        const raw = (body["idempotency_key"] as string | undefined)?.trim() || fromHeader;

        if (!raw || raw.length < 12) {
            throw new AppError(
                "IDEMPOTENCY_KEY_REQUIRED",
                "A unique idempotency key of at least 12 characters is required.",
                { field: "idempotency_key" },
            );
        }
        if (raw.length > 128) {
            fail("idempotency_key", "must be at most 128 characters");
        }
        if (!/^[A-Za-z0-9:_-]+$/.test(raw)) {
            fail("idempotency_key", "may contain only letters, digits, ':', '_' and '-'");
        }
        return raw;
    },

    latitude(body: Raw, field = "latitude"): number {
        return this.number(body, field, { min: -90, max: 90 });
    },

    longitude(body: Raw, field = "longitude"): number {
        return this.number(body, field, { min: -180, max: 180 });
    },
};

export const PAYMENT_MODES = [
    "ONLINE",
    "COD",
    "PAY_AT_STORE",
    "WALLET",
    "SPLIT_WALLET_ONLINE",
    "SPLIT_WALLET_COD",
] as const;

export const FULFILMENT_TYPES = ["DELIVERY", "PICKUP"] as const;

export const REFUND_KINDS = ["FULL_REFUND", "PARTIAL_REFUND", "ITEM_REFUND"] as const;

export const REFUND_DESTINATIONS = [
    "ORIGINAL_PAYMENT_METHOD",
    "WALLET_CREDIT",
    "BANK_TRANSFER",
    "CASH",
] as const;

export const REFUND_REASONS = [
    "RESTAURANT_CANCELLED",
    "ITEM_UNAVAILABLE",
    "PAYMENT_ISSUE",
    "WRONG_ITEM",
    "MISSING_ITEM",
    "QUALITY_ISSUE",
    "DELIVERY_FAILURE",
    "LATE_DELIVERY",
    "CUSTOMER_CANCELLATION",
    "DUPLICATE_PAYMENT",
    "MANUAL_ADJUSTMENT",
    "GOODWILL",
] as const;

export const DEVICE_PLATFORMS = ["ANDROID", "IOS", "WEB"] as const;

export const NOTIFICATION_CHANNELS = ["PUSH", "SMS", "EMAIL", "IN_APP", "WHATSAPP"] as const;
