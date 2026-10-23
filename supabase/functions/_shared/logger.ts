/**
 * Structured JSON logging.
 *
 * Every line is a single JSON object so log drains (Logflare, Sentry, CloudWatch)
 * can index fields without regex. Values that could contain personal data or
 * secrets are redacted centrally rather than at each call site.
 */

import { env } from "./env.ts";

type Level = "debug" | "info" | "warn" | "error";

const LEVEL_ORDER: Record<Level, number> = { debug: 10, info: 20, warn: 30, error: 40 };

const REDACT_KEYS = new Set([
    "password",
    "token",
    "access_token",
    "refresh_token",
    "authorization",
    "apikey",
    "api_key",
    "secret",
    "key_secret",
    "signature",
    "otp",
    "otp_code",
    "verification_code",
    "delivery_otp",
    "pickup_code",
    "card",
    "card_number",
    "cvv",
    "private_key",
    "email",
    "phone",
    "full_phone",
    "address",
    "street_address",
    "customer_address",
    "document_path",
    "document_url",
    "image",
    "image_url",
    "raw_body",
    "request_body",
    "response_body",
]);

const REDACT_KEY_PATTERN =
    /(authorization|token|secret|password|signature|otp|phone|email|address|document|image|base64|raw.?body|contact)/i;

function sanitizeText(value: string): string {
    return value
        .replace(/\bBearer\s+[A-Za-z0-9._~+/-]+=*/gi, "Bearer [redacted]")
        .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, "[email]")
        .replace(/(?:\+?\d[\d\s().-]{7,}\d)/g, "[phone]")
        .replace(/data:image\/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=]+/g, "[image redacted]")
        .replace(/https?:\/\/[^\s?]+\?[^\s)]+/gi, "[url with query redacted]")
        .replace(/[A-Za-z0-9_-]{80,}/g, "[long value redacted]")
        .slice(0, 2000);
}

function redact(value: unknown, depth = 0): unknown {
    if (depth > 6) return "[truncated]";
    if (value === null || value === undefined) return value;

    if (Array.isArray(value)) {
        return value.slice(0, 50).map((item) => redact(item, depth + 1));
    }

    if (typeof value === "object") {
        const out: Record<string, unknown> = {};
        for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
            out[key] = REDACT_KEYS.has(key.toLowerCase()) || REDACT_KEY_PATTERN.test(key)
                ? "[redacted]"
                : redact(item, depth + 1);
        }
        return out;
    }

    if (typeof value === "string") {
        return sanitizeText(value);
    }

    return value;
}

export function sanitizeTelemetry(value: unknown): unknown {
    return redact(value);
}

function emit(level: Level, message: string, context: Record<string, unknown> = {}): void {
    const threshold = LEVEL_ORDER[env.logLevel as Level] ?? LEVEL_ORDER.info;
    if (LEVEL_ORDER[level] < threshold) return;

    const line = JSON.stringify({
        level,
        message,
        ts: new Date().toISOString(),
        env: env.appEnv,
        ...(redact(context) as Record<string, unknown>),
    });

    if (level === "error") console.error(line);
    else if (level === "warn") console.warn(line);
    else console.log(line);
}

export const logger = {
    debug: (message: string, context?: Record<string, unknown>) => emit("debug", message, context),
    info: (message: string, context?: Record<string, unknown>) => emit("info", message, context),
    warn: (message: string, context?: Record<string, unknown>) => emit("warn", message, context),
    error: (message: string, context?: Record<string, unknown>) => emit("error", message, context),
};

/**
 * Best-effort Sentry report over the Store API. Failure to report is never
 * allowed to affect the request that triggered it.
 */
export async function reportToSentry(
    error: unknown,
    context: Record<string, unknown> = {},
): Promise<void> {
    const dsn = env.sentryDsn;
    if (!dsn) return;

    try {
        const match = dsn.match(/^https:\/\/([^@]+)@([^/]+)\/(.+)$/);
        if (!match) return;

        const [, publicKey, host, projectId] = match;
        const endpoint = `https://${host}/api/${projectId}/store/`;

        await fetch(endpoint, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "X-Sentry-Auth": [
                    "Sentry sentry_version=7",
                    `sentry_key=${publicKey}`,
                    "sentry_client=bitesbox-edge/1.0",
                ].join(", "),
            },
            body: JSON.stringify({
                event_id: crypto.randomUUID().replace(/-/g, ""),
                timestamp: new Date().toISOString(),
                platform: "javascript",
                level: "error",
                environment: env.appEnv,
                server_name: "supabase-edge",
                exception: {
                    values: [{
                        type: error instanceof Error ? error.name : "Error",
                        value: sanitizeText(error instanceof Error ? error.message : String(error)),
                        stacktrace: error instanceof Error && error.stack
                            ? {
                                frames: [{
                                    filename: "edge",
                                    function: sanitizeText(
                                        error.stack.split("\n")[1]?.trim() ?? "edge",
                                    ),
                                }],
                            }
                            : undefined,
                    }],
                },
                release: optionalRelease(),
                tags: {
                    function: String(context.fn ?? "edge"),
                    role_category: String(context.role_category ?? "system"),
                },
                extra: sanitizeTelemetry(context),
            }),
            signal: AbortSignal.timeout(1500),
        });
    } catch {
        // Never let telemetry break a food order.
    }
}

function optionalRelease(): string | undefined {
    const value = Deno.env.get("SENTRY_RELEASE")?.trim();
    return value ? sanitizeText(value) : undefined;
}
