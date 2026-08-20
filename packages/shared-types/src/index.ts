/**
 * @bitesbox/shared-types
 *
 * Single source of truth for cross-surface contracts:
 *   · database.types.ts — generated from the live schema (`npm run db:types`)
 *   · domain.ts         — hand-written shapes for the JSONB the RPCs return
 *   · errors.ts         — stable business error codes
 *   · permissions.ts    — permission, feature-flag and bucket constants
 *
 * The Dart mirror of these contracts lives in
 * apps/mobile/lib/core/contracts/ and is kept in step by hand; the error codes
 * and permission strings are the parts that must never drift.
 */
export type { Database, Json } from './database.types';
export type { Tables, TablesInsert, TablesUpdate, Enums } from './database.types';
export { Constants } from './database.types';

export * from './domain';
export * from './errors';
export * from './permissions';

/** Currency formatting used consistently across the admin dashboard. */
export function formatInr(amount: number | null | undefined, options?: { decimals?: boolean }): string {
    const value = amount ?? 0;
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        minimumFractionDigits: options?.decimals ? 2 : 0,
        maximumFractionDigits: options?.decimals ? 2 : 0,
    }).format(value);
}

/** Razorpay works in paise; our schema stores rupees as numeric(12,2). */
export function toPaise(rupees: number): number {
    return Math.round(rupees * 100);
}

export function fromPaise(paise: number): number {
    return Math.round(paise) / 100;
}

/** Human-friendly elapsed label for kitchen and operations timers. */
export function formatElapsed(seconds: number): string {
    const total = Math.max(0, Math.floor(seconds));
    const mins = Math.floor(total / 60);
    const secs = total % 60;
    if (mins < 60) return `${mins}:${secs.toString().padStart(2, '0')}`;
    const hours = Math.floor(mins / 60);
    return `${hours}h ${mins % 60}m`;
}
