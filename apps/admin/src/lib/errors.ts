import { ERROR_CODES, ERROR_FALLBACK_MESSAGES } from '@bitesbox/shared-types';

/**
 * Normalises anything thrown by supabase-js into a stable `{ code, message }`.
 *
 * Postgres business errors arrive as PostgrestError where our machine-readable
 * code sits in `hint` (set by `app.fail`) and the operator-safe copy in
 * `message`. Everything else gets a generic code so the UI never shows a raw
 * database string.
 */
export interface NormalisedError {
    code: string;
    message: string;
    details?: unknown;
}

export function normaliseError(error: unknown): NormalisedError {
    if (!error) {
        return { code: ERROR_CODES.UNKNOWN, message: fallback(ERROR_CODES.UNKNOWN) };
    }

    if (typeof error === 'object' && error !== null) {
        const candidate = error as {
            code?: string;
            hint?: string;
            message?: string;
            details?: unknown;
            error?: { code?: string; message?: string; details?: unknown };
            status?: number;
        };

        // Edge Function envelope: { error: { code, message } }
        if (candidate.error?.code) {
            return {
                code: candidate.error.code,
                message: candidate.error.message ?? fallback(candidate.error.code),
                details: candidate.error.details,
            };
        }

        // Postgres via PostgREST: our code is in `hint`.
        if (candidate.hint && /^[A-Z][A-Z0-9_]+$/.test(candidate.hint)) {
            return {
                code: candidate.hint,
                message: candidate.message ?? fallback(candidate.hint),
                details: candidate.details,
            };
        }

        // Row-level security rejections surface as 42501.
        if (candidate.code === '42501') {
            return {
                code: ERROR_CODES.PERMISSION_DENIED,
                message: 'You do not have permission to do that.',
            };
        }

        if (candidate.code === 'PGRST301' || candidate.status === 401) {
            return { code: ERROR_CODES.UNAUTHENTICATED, message: 'Your session expired. Please sign in again.' };
        }

        if (candidate.message?.toLowerCase().includes('failed to fetch')) {
            return { code: ERROR_CODES.NETWORK_ERROR, message: fallback(ERROR_CODES.NETWORK_ERROR) };
        }

        if (candidate.message) {
            return {
                code: candidate.code ?? ERROR_CODES.UNKNOWN,
                message: candidate.message,
                details: candidate.details,
            };
        }
    }

    if (error instanceof Error) {
        return { code: ERROR_CODES.UNKNOWN, message: error.message };
    }

    return { code: ERROR_CODES.UNKNOWN, message: fallback(ERROR_CODES.UNKNOWN) };
}

function fallback(code: string): string {
    return ERROR_FALLBACK_MESSAGES[code] ?? 'Something went wrong. Please try again.';
}

/** Convenience for toast handlers. */
export function errorMessage(error: unknown): string {
    return normaliseError(error).message;
}
