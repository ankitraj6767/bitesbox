/**
 * Email provider abstraction, mirroring the SMS one so both can be swapped by
 * configuration alone.
 */

import { env } from "../env.ts";
import { logger } from "../logger.ts";

export interface EmailMessage {
    to: string;
    subject: string;
    /** Plain-text body. HTML is generated from it when the provider needs HTML. */
    body: string;
    html?: string | null;
    replyTo?: string | null;
}

export interface EmailResult {
    ok: boolean;
    provider: string;
    messageId?: string;
    error?: string;
}

export interface EmailProvider {
    readonly name: string;
    send(message: EmailMessage): Promise<EmailResult>;
}

const consoleProvider: EmailProvider = {
    name: "console",
    send(message) {
        logger.info("email.console", { to: message.to, subject: message.subject });
        return Promise.resolve({
            ok: true,
            provider: "console",
            messageId: `console-${crypto.randomUUID()}`,
        });
    },
};

const resendProvider: EmailProvider = {
    name: "resend",
    async send(message) {
        if (!env.resendApiKey) {
            return { ok: false, provider: "resend", error: "RESEND_API_KEY is not set" };
        }

        try {
            const response = await fetch("https://api.resend.com/emails", {
                method: "POST",
                headers: {
                    Authorization: `Bearer ${env.resendApiKey}`,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    from: env.emailFrom,
                    to: [message.to],
                    subject: message.subject,
                    text: message.body,
                    html: message.html ?? toHtml(message.body),
                    ...(message.replyTo ? { reply_to: message.replyTo } : {}),
                }),
            });

            const payload = await response.json() as { id?: string; message?: string };

            if (!response.ok) {
                logger.warn("email.resend_failed", { status: response.status });
                return { ok: false, provider: "resend", error: payload.message };
            }

            return { ok: true, provider: "resend", messageId: payload.id };
        } catch (error) {
            return { ok: false, provider: "resend", error: String(error) };
        }
    },
};

const PROVIDERS: Record<string, EmailProvider> = {
    console: consoleProvider,
    resend: resendProvider,
};

export function emailProvider(): EmailProvider {
    const provider = PROVIDERS[env.emailProvider];

    if (!provider) {
        logger.warn("email.unknown_provider", { configured: env.emailProvider });
        return consoleProvider;
    }

    return provider;
}

export function sendEmail(message: EmailMessage): Promise<EmailResult> {
    return emailProvider().send(message);
}

/** Wraps plain text in a minimal, brand-consistent HTML shell. */
function toHtml(body: string): string {
    const escaped = body
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/\n/g, "<br>");

    return `<!doctype html>
<html><body style="margin:0;padding:24px;background:#FFFBF6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#1A1614;">
  <div style="max-width:560px;margin:0 auto;background:#FFFFFF;border-radius:16px;padding:32px;">
    <div style="font-size:20px;font-weight:700;color:#C1121F;margin-bottom:20px;">Bites Box</div>
    <div style="font-size:15px;line-height:1.6;">${escaped}</div>
    <hr style="border:none;border-top:1px solid #F0EAE4;margin:28px 0 16px;">
    <div style="font-size:12px;color:#6B625C;">
      Bites Box, Station Road, Bakhtiyarpur, Patna, Bihar 803212<br>
      Need help? Reply to this email or call +91 94311 00100.
    </div>
  </div>
</body></html>`;
}
