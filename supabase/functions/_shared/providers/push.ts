/**
 * Firebase Cloud Messaging (HTTP v1).
 *
 * Access tokens are minted from the service-account key with Web Crypto and
 * cached until shortly before expiry, so a burst of order notifications does not
 * trigger a token exchange per message.
 */

import { env } from "../env.ts";
import { logger } from "../logger.ts";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

let cachedToken: { value: string; expiresAt: number } | null = null;

export interface PushMessage {
    token: string;
    title?: string | null;
    body: string;
    imageUrl?: string | null;
    data?: Record<string, string>;
    /** Collapses replaceable updates (e.g. repeated status changes for one order). */
    collapseKey?: string;
    /** HIGH for order/delivery events, NORMAL for marketing. */
    priority?: "HIGH" | "NORMAL";
    androidChannelId?: string;
}

export interface PushResult {
    ok: boolean;
    messageId?: string;
    /** True when FCM says the token is dead and we should deactivate it. */
    tokenInvalid: boolean;
    error?: string;
}

async function accessToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);

    if (cachedToken && cachedToken.expiresAt > now + 60) {
        return cachedToken.value;
    }

    const header = { alg: "RS256", typ: "JWT" };
    const claims = {
        iss: env.fcmClientEmail,
        scope: FCM_SCOPE,
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
    };

    const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
    const key = await importPrivateKey(env.fcmPrivateKey);
    const signature = await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        key,
        new TextEncoder().encode(unsigned),
    );

    const assertion = `${unsigned}.${base64urlBytes(new Uint8Array(signature))}`;

    const response = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
            grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
            assertion,
        }),
    });

    if (!response.ok) {
        throw new Error(`FCM token exchange failed: ${response.status} ${await response.text()}`);
    }

    const payload = await response.json() as { access_token: string; expires_in: number };
    cachedToken = { value: payload.access_token, expiresAt: now + payload.expires_in };
    return payload.access_token;
}

export async function sendPush(message: PushMessage): Promise<PushResult> {
    if (!env.fcmConfigured) {
        // Development: log instead of failing so the whole pipeline stays testable.
        logger.info("push.console", {
            token: `${message.token.slice(0, 12)}…`,
            title: message.title,
            body: message.body,
        });
        return { ok: true, messageId: `console-${crypto.randomUUID()}`, tokenInvalid: false };
    }

    try {
        const token = await accessToken();

        const response = await fetch(
            `https://fcm.googleapis.com/v1/projects/${env.fcmProjectId}/messages:send`,
            {
                method: "POST",
                headers: {
                    Authorization: `Bearer ${token}`,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    message: {
                        token: message.token,
                        notification: {
                            ...(message.title ? { title: message.title } : {}),
                            body: message.body,
                            ...(message.imageUrl ? { image: message.imageUrl } : {}),
                        },
                        data: message.data ?? {},
                        android: {
                            priority: message.priority === "NORMAL" ? "NORMAL" : "HIGH",
                            ...(message.collapseKey ? { collapse_key: message.collapseKey } : {}),
                            notification: {
                                channel_id: message.androidChannelId ?? "bitesbox_orders",
                                sound: "default",
                                // Android groups by tag; reusing the collapse key replaces the
                                // previous status update instead of stacking five notifications.
                                ...(message.collapseKey ? { tag: message.collapseKey } : {}),
                            },
                        },
                        apns: {
                            headers: {
                                "apns-priority": message.priority === "NORMAL" ? "5" : "10",
                                ...(message.collapseKey
                                    ? { "apns-collapse-id": message.collapseKey }
                                    : {}),
                            },
                            payload: { aps: { sound: "default", "content-available": 1 } },
                        },
                    },
                }),
            },
        );

        const text = await response.text();

        if (response.ok) {
            const payload = JSON.parse(text) as { name?: string };
            return { ok: true, messageId: payload.name, tokenInvalid: false };
        }

        const errorPayload = safeJson(text) as {
            error?: { status?: string; message?: string; details?: Array<{ errorCode?: string }> };
        };
        const status = errorPayload.error?.status ?? "";
        const errorCode = errorPayload.error?.details?.[0]?.errorCode ?? "";

        const tokenInvalid = status === "NOT_FOUND" ||
            status === "INVALID_ARGUMENT" ||
            errorCode === "UNREGISTERED" ||
            errorCode === "INVALID_ARGUMENT";

        logger.warn("push.failed", {
            status: response.status,
            fcm_status: status,
            error_code: errorCode,
            token_invalid: tokenInvalid,
        });

        return {
            ok: false,
            tokenInvalid,
            error: errorPayload.error?.message ?? `FCM error ${response.status}`,
        };
    } catch (error) {
        logger.error("push.exception", { error: String(error) });
        return { ok: false, tokenInvalid: false, error: String(error) };
    }
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
    const body = pem
        .replace(/-----BEGIN PRIVATE KEY-----/, "")
        .replace(/-----END PRIVATE KEY-----/, "")
        .replace(/\s+/g, "");

    const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));

    return await crypto.subtle.importKey(
        "pkcs8",
        der,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"],
    );
}

function base64url(input: string): string {
    return base64urlBytes(new TextEncoder().encode(input));
}

function base64urlBytes(bytes: Uint8Array): string {
    let binary = "";
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function safeJson(text: string): unknown {
    try {
        return JSON.parse(text);
    } catch {
        return {};
    }
}
