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
    "code",
    "delivery_otp",
    "pickup_code",
    "card",
    "card_number",
    "cvv",
    "private_key",
]);

function redact(value: unknown, depth = 0): unknown {
    if (depth > 6) return "[truncated]";
    if (value === null || value === undefined) return value;

    if (Array.isArray(value)) {
        return value.slice(0, 50).map((item) => redact(item, depth + 1));
    }

    if (typeof value === "object") {
        const out: Record<string, unknown> = {};
        for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
            out[key] = REDACT_KEYS.has(key.toLowerCase()) ? "[redacted]" : redact(item, depth + 1);
        }
        return out;
    }

    if (typeof value === "string" && value.length > 2000) {
        return `${value.slice(0, 2000)}…[truncated]`;
    }

    return value;
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
                        value: error instanceof Error ? error.message : String(error),
                        stacktrace: error instanceof Error && error.stack
                            ? {
                                frames: [{
                                    filename: "edge",
                                    function: error.stack.split("\n")[1]?.trim(),
                                }],
                            }
                            : undefined,
                    }],
                },
                extra: redact(context),
            }),
        });
    } catch {
        // Never let telemetry break a food order.
    }
}
