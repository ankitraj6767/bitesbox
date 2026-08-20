/**
 * SMS provider abstraction.
 *
 * Providers are swapped by the OTP_PROVIDER secret alone — no code change and no
 * redeploy of dependent functions. Adding a new Indian provider means adding one
 * case here and nothing else.
 */

import { env } from "../env.ts";
import { logger } from "../logger.ts";

export interface SmsMessage {
    to: string;
    body: string;
    /** DLT-registered template id, mandatory for transactional SMS in India. */
    templateId?: string | null;
    /** Variables for providers that render server-side templates. */
    variables?: Record<string, string>;
}

export interface SmsResult {
    ok: boolean;
    provider: string;
    messageId?: string;
    error?: string;
}

export interface SmsProvider {
    readonly name: string;
    send(message: SmsMessage): Promise<SmsResult>;
}

/** Development provider: logs the message so flows stay testable offline. */
const consoleProvider: SmsProvider = {
    name: "console",
    send(message) {
        logger.info("sms.console", { to: maskPhone(message.to), body: message.body });
        return Promise.resolve({
            ok: true,
            provider: "console",
            messageId: `console-${crypto.randomUUID()}`,
        });
    },
};

const msg91Provider: SmsProvider = {
    name: "msg91",
    async send(message) {
        if (!env.msg91AuthKey) {
            return { ok: false, provider: "msg91", error: "MSG91_AUTH_KEY is not set" };
        }

        try {
            // MSG91 Flow API: the message body lives in the DLT-approved template and
            // we only supply variables.
            const response = await fetch("https://control.msg91.com/api/v5/flow/", {
                method: "POST",
                headers: {
                    authkey: env.msg91AuthKey,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    template_id: message.templateId ?? env.otpTemplateId,
                    sender: env.otpSenderId,
                    short_url: 0,
                    recipients: [{
                        mobiles: message.to.replace(/^\+/, ""),
                        ...(message.variables ?? { body: message.body }),
                    }],
                }),
            });

            const text = await response.text();

            if (!response.ok) {
                logger.warn("sms.msg91_failed", { status: response.status });
                return { ok: false, provider: "msg91", error: text.slice(0, 300) };
            }

            const payload = safeJson(text) as { request_id?: string; type?: string };
            return { ok: true, provider: "msg91", messageId: payload.request_id };
        } catch (error) {
            return { ok: false, provider: "msg91", error: String(error) };
        }
    },
};

const twilioProvider: SmsProvider = {
    name: "twilio",
    async send(message) {
        if (!env.twilioAccountSid || !env.twilioAuthToken) {
            return { ok: false, provider: "twilio", error: "Twilio credentials are not set" };
        }

        try {
            const response = await fetch(
                `https://api.twilio.com/2010-04-01/Accounts/${env.twilioAccountSid}/Messages.json`,
                {
                    method: "POST",
                    headers: {
                        Authorization: `Basic ${
                            btoa(`${env.twilioAccountSid}:${env.twilioAuthToken}`)
                        }`,
                        "Content-Type": "application/x-www-form-urlencoded",
                    },
                    body: new URLSearchParams({
                        To: message.to,
                        From: env.twilioFromNumber,
                        Body: message.body,
                    }),
                },
            );

            const payload = await response.json() as { sid?: string; message?: string };

            if (!response.ok) {
                logger.warn("sms.twilio_failed", { status: response.status });
                return { ok: false, provider: "twilio", error: payload.message };
            }

            return { ok: true, provider: "twilio", messageId: payload.sid };
        } catch (error) {
            return { ok: false, provider: "twilio", error: String(error) };
        }
    },
};

/**
 * Firebase Phone Auth handles OTP delivery inside the client SDK, so there is no
 * server-side send. Operational SMS (delivery OTP, order updates) must therefore
 * use a real SMS provider even when login uses Firebase.
 */
const firebaseProvider: SmsProvider = {
    name: "firebase",
    send(message) {
        logger.warn("sms.firebase_noop", {
            to: maskPhone(message.to),
            reason:
                "Firebase Phone Auth sends login OTPs client-side; configure MSG91 or Twilio for operational SMS.",
        });
        return Promise.resolve({
            ok: false,
            provider: "firebase",
            error: "Not supported server-side",
        });
    },
};

const PROVIDERS: Record<string, SmsProvider> = {
    console: consoleProvider,
    msg91: msg91Provider,
    twilio: twilioProvider,
    firebase: firebaseProvider,
};

export function smsProvider(): SmsProvider {
    const provider = PROVIDERS[env.otpProvider];

    if (!provider) {
        logger.warn("sms.unknown_provider", { configured: env.otpProvider });
        return consoleProvider;
    }

    // Never silently fall back to console logging in production: an operator would
    // believe SMS is working while customers receive nothing.
    if (provider.name === "console" && env.isProduction) {
        logger.error("sms.console_in_production", {
            hint: "Set OTP_PROVIDER to msg91 or twilio before going live.",
        });
    }

    return provider;
}

export function sendSms(message: SmsMessage): Promise<SmsResult> {
    return smsProvider().send(message);
}

function maskPhone(phone: string): string {
    return phone.length > 4 ? `${"*".repeat(phone.length - 4)}${phone.slice(-4)}` : "****";
}

function safeJson(text: string): unknown {
    try {
        return JSON.parse(text);
    } catch {
        return {};
    }
}
