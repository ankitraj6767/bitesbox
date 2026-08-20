import { describe, expect, it } from 'vitest';
import { errorMessage, normaliseError } from './errors';

/**
 * The contract this file defends: an operator never sees a raw database string, and
 * a stable machine code always comes back so the UI can branch on it.
 *
 * `app.fail` puts the business code in the PostgREST `hint`, which is the detail
 * most easily lost when this normaliser is refactored.
 */
describe('normaliseError', () => {
    it('reads the business code out of the Postgres hint', () => {
        const result = normaliseError({
            message: 'Only ₹566.00 can still be refunded on this order.',
            hint: 'REFUND_AMOUNT_EXCEEDS_REFUNDABLE',
            code: 'P0001',
        });

        expect(result.code).toBe('REFUND_AMOUNT_EXCEEDS_REFUNDABLE');
        expect(result.message).toContain('566');
    });

    it('ignores a hint that is prose rather than a code', () => {
        const result = normaliseError({
            message: 'column "foo" does not exist',
            hint: 'Perhaps you meant to reference the column "bar".',
        });

        expect(result.code).not.toBe('Perhaps you meant to reference the column "bar".');
    });

    it('unwraps the Edge Function error envelope', () => {
        const result = normaliseError({
            error: { code: 'NO_DELIVERY_PARTNER', message: 'No rider is available right now.' },
        });

        expect(result.code).toBe('NO_DELIVERY_PARTNER');
        expect(result.message).toBe('No rider is available right now.');
    });

    // 42501 is how both a privilege rejection and an RLS rejection arrive, and
    // "new row violates row-level security policy" is not an operator-facing message.
    it('translates a row-level security rejection', () => {
        const result = normaliseError({
            code: '42501',
            message: 'new row violates row-level security policy for table "orders"',
        });

        expect(result.code).toBe('PERMISSION_DENIED');
        expect(result.message).toBe('You do not have permission to do that.');
    });

    it('treats an expired session as something the user can act on', () => {
        expect(normaliseError({ code: 'PGRST301', message: 'JWT expired' }).code).toBe(
            'UNAUTHENTICATED',
        );
        expect(normaliseError({ status: 401, message: 'Unauthorized' }).code).toBe(
            'UNAUTHENTICATED',
        );
    });

    it('recognises a dropped connection', () => {
        const result = normaliseError({ message: 'TypeError: Failed to fetch' });
        expect(result.code).toBe('NETWORK_ERROR');
    });

    it('always produces a message, whatever it was handed', () => {
        for (const thrown of [null, undefined, {}, 'a string', 42, new Error('boom')]) {
            const result = normaliseError(thrown);
            expect(result.message).toBeTruthy();
            expect(result.code).toBeTruthy();
        }
    });

    it('carries structured detail through', () => {
        const result = normaliseError({
            message: 'Collect ₹632.00 from the customer.',
            hint: 'COD_AMOUNT_MISMATCH',
            details: { expected: 632, collected: 500 },
        });

        expect(result.details).toEqual({ expected: 632, collected: 500 });
    });
});

describe('errorMessage', () => {
    it('is the message a toast should show', () => {
        expect(errorMessage({ hint: 'COUPON_EXPIRED', message: 'That offer has ended.' })).toBe(
            'That offer has ended.',
        );
    });

    it('never returns an empty string', () => {
        expect(errorMessage(undefined).length).toBeGreaterThan(0);
    });
});
