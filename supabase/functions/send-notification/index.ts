/**
 * POST /functions/v1/send-notification
 *
 * Drains the notification queue. Three modes:
 *
 *   { mode: "DRAIN", limit?, channels? }     — worker mode, called by the scheduler
 *   { mode: "ENQUEUE", user_id, event, ... } — enqueue an ad-hoc notification
 *                                              (requires notification.send)
 *   { campaign_id }                          — resolve a segment and send to it
 *                                              (requires campaign.manage)
 *
 * Design notes
 *   · Enqueue and delivery are separate. Enqueue is transactional with the order
 *     write, so a status change can never be committed without its notification
 *     being queued. Delivery happens here and may retry safely.
 *   · Rows are claimed with FOR UPDATE SKIP LOCKED, so several workers can run at
 *     once without sending anything twice.
 *   · A dead FCM token is deactivated rather than retried forever.
 *   · A campaign's audience is resolved in Postgres by `launch_campaign`, so the
 *     browser that pressed Send never receives a customer list. Marketing opt-outs
 *     and per-channel preferences are applied there too, which is why the response
 *     distinguishes how many were targeted from how many were actually queued.
 */

import { jsonResponse, readJson, serveFunction } from "../_shared/http.ts";
import {
    requireCaller,
    requirePermission,
    rpc,
    serviceClient,
    userClient,
} from "../_shared/supabase.ts";
import { NOTIFICATION_CHANNELS, v } from "../_shared/validate.ts";
import { sendPush } from "../_shared/providers/push.ts";
import { sendSms } from "../_shared/providers/sms.ts";
import { sendEmail } from "../_shared/providers/email.ts";
import { env } from "../_shared/env.ts";
import { AppError } from "../_shared/errors.ts";
import { logger } from "../_shared/logger.ts";

interface QueuedNotification {
    id: string;
    user_id: string | null;
    event: string;
    channel: "PUSH" | "SMS" | "EMAIL" | "IN_APP" | "WHATSAPP";
    title: string | null;
    body: string;
    action_route: string | null;
    image_path: string | null;
    data: Record<string, unknown>;
    order_id: string | null;
    destination: string | null;
    push_tokens: Array<{ id: string; token: string; platform: string }>;
    locale: string;
    attempts: number;
}

/** How many notifications a "Send now" flushes before handing back to the scheduler. */
const CAMPAIGN_FLUSH_LIMIT = 100;

serveFunction("send-notification", async ({ req, requestId, origin }) => {
    const body = await readJson<Record<string, unknown>>(req);
    const admin = serviceClient();

    // A campaign id is unambiguous, so it selects the mode on its own. The admin
    // dashboard posts only { campaign_id }.
    const campaignId = v.optionalUuid(body, "campaign_id");
    const mode = campaignId
        ? "CAMPAIGN"
        : v.enumValue(body, "mode", ["DRAIN", "ENQUEUE", "CAMPAIGN"] as const, "DRAIN");

    if (mode === "CAMPAIGN") {
        if (!campaignId) {
            throw new AppError("VALIDATION_FAILED", "campaign_id is required to send a campaign.");
        }

        const caller = await requireCaller(req);
        const asUser = userClient(req);

        // Checked here for a clear error, and again inside launch_campaign, which is
        // what actually protects the data and writes the audit entry naming the actor.
        await requirePermission(asUser, "campaign.manage");

        const result = await rpc<{
            campaign_id: string;
            status: string;
            targeted: number;
            queued: number;
            changed: boolean;
        }>(asUser, "launch_campaign", { p_campaign_id: campaignId });

        logger.info("campaign.launched", {
            request_id: requestId,
            campaign_id: campaignId,
            targeted: result.targeted,
            queued: result.queued,
            changed: result.changed,
            actor: caller.userId,
        });

        // Flush a first batch so pressing Send produces visible delivery rather than
        // waiting up to a minute for the scheduler. The rest drains normally.
        const flushed = result.queued > 0
            ? await drainQueue(admin, {
                limit: Math.min(result.queued, CAMPAIGN_FLUSH_LIMIT),
                channels: [],
                requestId,
            })
            : { processed: 0, sent: 0, failed: 0, skipped: 0 };

        return jsonResponse(
            {
                campaign_id: result.campaign_id,
                status: result.status,
                targeted: result.targeted,
                queued: result.queued,
                changed: result.changed,
                delivery: flushed,
            },
            { status: result.changed ? 202 : 200, origin, requestId },
        );
    }

    if (mode === "ENQUEUE") {
        const caller = await requireCaller(req);
        const asUser = userClient(req);

        // Only staff with notification.send may push an ad-hoc message.
        await requirePermission(asUser, "notification.send");

        const queued = await rpc<number>(admin, "svc_enqueue_notification", {
            p_user_id: v.uuid(body, "user_id"),
            p_event: v.string(body, "event", { min: 3, max: 64 }),
            p_vars: (body["vars"] as Record<string, unknown>) ?? {},
            p_channels: v.array(body, "channels", (item) => String(item), { max: 5 }).filter((c) =>
                NOTIFICATION_CHANNELS.includes(c as never)
            ),
            p_order_id: v.optionalUuid(body, "order_id"),
            p_dedupe_key: v.optionalString(body, "dedupe_key", { max: 200 }),
            p_scheduled_for: v.optionalString(body, "scheduled_for", { max: 40 }),
        });

        logger.info("notification.enqueued", {
            request_id: requestId,
            queued,
            actor: caller.userId,
        });

        return jsonResponse({ queued }, { status: 202, origin, requestId });
    }

    // ── DRAIN ──
    // Worker mode is service-role only; the scheduler calls it with the secret key.
    const authorization = req.headers.get("Authorization") ?? "";
    const isServiceCall = authorization.includes(env.serviceRoleKey);

    if (!isServiceCall) {
        const asUser = userClient(req);
        await requireCaller(req);
        await requirePermission(asUser, "notification.send");
    }

    const limit = v.optionalNumber(body, "limit", { min: 1, max: 200 }) ?? 50;
    const channels = v
        .array(body, "channels", (item) => String(item), { max: 5 })
        .filter((c) => NOTIFICATION_CHANNELS.includes(c as never));

    const result = await drainQueue(admin, {
        limit: Math.floor(limit),
        channels,
        requestId,
    });

    return jsonResponse(result, { origin, requestId });
});

interface DrainResult {
    processed: number;
    sent: number;
    failed: number;
    skipped: number;
}

/**
 * Claims a batch and delivers it.
 *
 * Shared by the scheduler and by a campaign send, so both take exactly the same
 * path: claim with SKIP LOCKED, deliver, settle. A delivery that throws is settled
 * as FAILED rather than left claimed, otherwise the row would be invisible to the
 * next worker and never retried.
 */
async function drainQueue(
    admin: ReturnType<typeof serviceClient>,
    options: { limit: number; channels: string[]; requestId: string },
): Promise<DrainResult> {
    const batch = await rpc<QueuedNotification[]>(admin, "svc_claim_notifications", {
        p_limit: options.limit,
        p_channels: options.channels.length > 0 ? options.channels : null,
    });

    if (batch.length === 0) {
        return { processed: 0, sent: 0, failed: 0, skipped: 0 };
    }

    let sent = 0;
    let failed = 0;
    let skipped = 0;

    for (const notification of batch) {
        try {
            const outcome = await deliver(admin, notification);

            if (outcome === "SENT") sent++;
            else if (outcome === "SKIPPED") skipped++;
            else failed++;
        } catch (error) {
            failed++;
            logger.error("notification.delivery_exception", {
                request_id: options.requestId,
                notification_id: notification.id,
                channel: notification.channel,
                error: String(error),
            });

            await rpc(admin, "svc_settle_notification", {
                p_id: notification.id,
                p_status: "FAILED",
                p_failure_reason: String(error).slice(0, 500),
            }).catch(() => {});
        }
    }

    logger.info("notification.drained", {
        request_id: options.requestId,
        processed: batch.length,
        sent,
        failed,
        skipped,
    });

    return { processed: batch.length, sent, failed, skipped };
}

async function deliver(
    admin: ReturnType<typeof serviceClient>,
    notification: QueuedNotification,
): Promise<"SENT" | "FAILED" | "SKIPPED"> {
    switch (notification.channel) {
        case "IN_APP": {
            // Nothing to transmit: the row itself is the in-app notification. Realtime
            // pushes it to any connected client.
            await rpc(admin, "svc_settle_notification", {
                p_id: notification.id,
                p_status: "DELIVERED",
                p_provider: "in_app",
            });
            return "SENT";
        }

        case "PUSH": {
            if (notification.push_tokens.length === 0) {
                await rpc(admin, "svc_settle_notification", {
                    p_id: notification.id,
                    p_status: "SUPPRESSED",
                    p_provider: "fcm",
                    p_failure_reason: "No active device token for this user.",
                });
                return "SKIPPED";
            }

            const data: Record<string, string> = {
                event: notification.event,
                ...(notification.order_id ? { order_id: notification.order_id } : {}),
                ...(notification.action_route ? { route: notification.action_route } : {}),
            };

            // Flatten the template variables so the app can deep link without a fetch.
            for (const [key, value] of Object.entries(notification.data ?? {})) {
                if (value !== null && value !== undefined && typeof value !== "object") {
                    data[key] = String(value);
                }
            }

            let anySucceeded = false;
            let lastError: string | undefined;

            for (const device of notification.push_tokens) {
                const result = await sendPush({
                    token: device.token,
                    title: notification.title,
                    body: notification.body,
                    data,
                    // One notification per order replaces the previous status update rather
                    // than stacking five entries in the tray.
                    collapseKey: notification.order_id ?? notification.event,
                    priority:
                        notification.event === "PROMOTION" || notification.event === "CAMPAIGN"
                            ? "NORMAL"
                            : "HIGH",
                    androidChannelId: pushChannelFor(notification.event),
                });

                if (result.ok) {
                    anySucceeded = true;
                } else {
                    lastError = result.error;
                    if (result.tokenInvalid) {
                        await rpc(admin, "svc_deactivate_device_token", { p_token_id: device.id });
                    }
                }
            }

            await rpc(admin, "svc_settle_notification", {
                p_id: notification.id,
                p_status: anySucceeded ? "SENT" : "FAILED",
                p_provider: "fcm",
                p_failure_reason: anySucceeded ? null : (lastError ?? "All device tokens failed."),
            });

            return anySucceeded ? "SENT" : "FAILED";
        }

        case "SMS": {
            if (!notification.destination) {
                await rpc(admin, "svc_settle_notification", {
                    p_id: notification.id,
                    p_status: "SUPPRESSED",
                    p_failure_reason: "No phone number on file.",
                });
                return "SKIPPED";
            }

            const result = await sendSms({
                to: notification.destination,
                body: notification.body,
                variables: stringifyVars(notification.data),
            });

            await rpc(admin, "svc_settle_notification", {
                p_id: notification.id,
                p_status: result.ok ? "SENT" : "FAILED",
                p_provider: result.provider,
                p_provider_message_id: result.messageId ?? null,
                p_failure_reason: result.ok
                    ? null
                    : (result.error ?? "SMS provider rejected the message."),
            });

            return result.ok ? "SENT" : "FAILED";
        }

        case "EMAIL": {
            if (!notification.destination) {
                await rpc(admin, "svc_settle_notification", {
                    p_id: notification.id,
                    p_status: "SUPPRESSED",
                    p_failure_reason: "No email address on file.",
                });
                return "SKIPPED";
            }

            const result = await sendEmail({
                to: notification.destination,
                subject: notification.title ?? "Bites Box",
                body: notification.body,
            });

            await rpc(admin, "svc_settle_notification", {
                p_id: notification.id,
                p_status: result.ok ? "SENT" : "FAILED",
                p_provider: result.provider,
                p_provider_message_id: result.messageId ?? null,
                p_failure_reason: result.ok ? null : result.error,
            });

            return result.ok ? "SENT" : "FAILED";
        }

        case "WHATSAPP": {
            // Reserved: WhatsApp Business API is a phase-2 channel. Suppress rather than
            // retry so the queue does not fill with impossible work.
            await rpc(admin, "svc_settle_notification", {
                p_id: notification.id,
                p_status: "SUPPRESSED",
                p_failure_reason: "WhatsApp channel is not enabled yet.",
            });
            return "SKIPPED";
        }
    }
}

/** Separate Android channels so customers can mute marketing but not order updates. */
function pushChannelFor(event: string): string {
    switch (event) {
        case "PROMOTION":
        case "CAMPAIGN":
            return "bitesbox_offers";
        case "NEW_ORDER_KITCHEN":
            return "bitesbox_kitchen";
        case "NEW_ASSIGNMENT_RIDER":
            return "bitesbox_delivery";
        default:
            return "bitesbox_orders";
    }
}

function stringifyVars(data: Record<string, unknown>): Record<string, string> {
    const out: Record<string, string> = {};
    for (const [key, value] of Object.entries(data ?? {})) {
        if (value !== null && value !== undefined && typeof value !== "object") {
            out[key] = String(value);
        }
    }
    return out;
}
