/**
 * HTTP plumbing: CORS, JSON responses, request ids and the handler wrapper that
 * turns thrown errors into the standard error contract.
 */

import { AppError, ErrorBody, fromPostgrestError, isAppError } from "./errors.ts";
import { env } from "./env.ts";
import { logger } from "./logger.ts";

const DEFAULT_ALLOWED_HEADERS = [
    "authorization",
    "x-client-info",
    "apikey",
    "content-type",
    "x-idempotency-key",
    "x-app-version",
    "x-device-platform",
    "x-request-id",
].join(", ");

export function corsHeaders(origin: string | null): Record<string, string> {
    const allowlist = env.allowedOrigins;

    // With no explicit allowlist (development) reflect the caller. In production an
    // allowlist should always be configured.
    const allowOrigin = allowlist.length === 0
        ? (origin ?? "*")
        : (origin && allowlist.includes(origin) ? origin : allowlist[0]);

    return {
        "Access-Control-Allow-Origin": allowOrigin,
        "Access-Control-Allow-Headers": DEFAULT_ALLOWED_HEADERS,
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
        "Access-Control-Max-Age": "86400",
        "Vary": "Origin",
    };
}

export function jsonResponse(
    body: unknown,
    init: {
        status?: number;
        origin?: string | null;
        requestId?: string;
        headers?: Record<string, string>;
    } = {},
): Response {
    return new Response(JSON.stringify(body), {
        status: init.status ?? 200,
        headers: {
            "Content-Type": "application/json; charset=utf-8",
            "Cache-Control": "no-store",
            "X-Request-Id": init.requestId ?? "",
            ...corsHeaders(init.origin ?? null),
            ...(init.headers ?? {}),
        },
    });
}

export function newRequestId(req: Request): string {
    return req.headers.get("x-request-id") ?? crypto.randomUUID();
}

export async function readJson<T>(req: Request): Promise<T> {
    if (req.method === "GET") return {} as T;

    const raw = await req.text();
    if (!raw || raw.trim().length === 0) return {} as T;

    try {
        return JSON.parse(raw) as T;
    } catch {
        throw new AppError("INVALID_JSON", "The request body is not valid JSON.");
    }
}

export interface HandlerContext {
    req: Request;
    requestId: string;
    origin: string | null;
    functionName: string;
}

/**
 * Wraps a function handler with CORS preflight, structured logging, timing and
 * uniform error translation. Business errors surface their stable code; anything
 * unexpected becomes INTERNAL_ERROR and is logged in full server-side only.
 */
export function serveFunction(
    functionName: string,
    handler: (ctx: HandlerContext) => Promise<Response>,
    options: { methods?: string[] } = {},
): void {
    const allowedMethods = options.methods ?? ["POST"];

    Deno.serve(async (req) => {
        const origin = req.headers.get("origin");
        const requestId = newRequestId(req);
        const started = performance.now();

        if (req.method === "OPTIONS") {
            return new Response("ok", { headers: corsHeaders(origin) });
        }

        if (!allowedMethods.includes(req.method)) {
            return jsonResponse(
                errorBody("VALIDATION_FAILED", `${req.method} is not supported.`, {}, requestId),
                { status: 405, origin, requestId },
            );
        }

        try {
            const response = await handler({ req, requestId, origin, functionName });

            logger.info("request.completed", {
                fn: functionName,
                request_id: requestId,
                status: response.status,
                duration_ms: Math.round(performance.now() - started),
            });

            return response;
        } catch (error) {
            const appError = toAppError(error);

            const logPayload = {
                fn: functionName,
                request_id: requestId,
                code: appError.code,
                status: appError.status,
                duration_ms: Math.round(performance.now() - started),
                message: appError.message,
            };

            if (appError.status >= 500) {
                logger.error("request.failed", { ...logPayload, stack: stackOf(error) });
            } else {
                logger.warn("request.rejected", logPayload);
            }

            return jsonResponse(
                errorBody(appError.code, appError.message, appError.detail, requestId),
                { status: appError.status, origin, requestId },
            );
        }
    });
}

export function errorBody(
    code: string,
    message: string,
    detail: Record<string, unknown>,
    requestId: string,
): ErrorBody {
    return {
        error: {
            code,
            message,
            ...(Object.keys(detail).length > 0 ? { detail } : {}),
            request_id: requestId,
        },
    };
}

function toAppError(error: unknown): AppError {
    if (isAppError(error)) return error;

    // PostgREST / supabase-js error shape
    if (error && typeof error === "object" && "message" in error) {
        const candidate = error as {
            message?: string;
            hint?: string;
            details?: string;
            code?: string;
        };
        if (candidate.hint || candidate.code) {
            return fromPostgrestError(candidate);
        }
    }

    return new AppError(
        "INTERNAL_ERROR",
        "Something went wrong on our side. Please try again.",
        {},
        500,
    );
}

function stackOf(error: unknown): string | undefined {
    return error instanceof Error ? error.stack : undefined;
}
