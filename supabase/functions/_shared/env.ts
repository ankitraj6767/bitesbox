/**
 * Environment access for Edge Functions.
 *
 * Secrets are read once at module load and validated on first use so a
 * misconfigured deployment fails fast with a clear message instead of throwing
 * an opaque error deep inside a payment call.
 */

export type AppEnv = "development" | "staging" | "production";

function read(name: string): string | undefined {
    const value = Deno.env.get(name);
    return value && value.trim().length > 0 ? value.trim() : undefined;
}

/** Reads a required secret, throwing a descriptive error when absent. */
export function required(name: string): string {
    const value = read(name);
    if (!value) {
        throw new Error(
            `Missing required environment variable ${name}. ` +
                `Set it with: supabase secrets set ${name}=...`,
        );
    }
    return value;
}

export function optional(name: string, fallback = ""): string {
    return read(name) ?? fallback;
}

export function flag(name: string, fallback = false): boolean {
    const value = read(name);
    if (value === undefined) return fallback;
    return ["1", "true", "yes", "on"].includes(value.toLowerCase());
}

export const env = {
    get appEnv(): AppEnv {
        const value = optional("APP_ENV", "development").toLowerCase();
        return (["development", "staging", "production"].includes(value)
            ? value
            : "development") as AppEnv;
    },

    get isProduction(): boolean {
        return this.appEnv === "production";
    },

    // ── Supabase ──
    get supabaseUrl(): string {
        return required("SUPABASE_URL");
    },
    get serviceRoleKey(): string {
        // Provided automatically by the Edge Runtime.
        return required("SUPABASE_SERVICE_ROLE_KEY");
    },
    get anonKey(): string {
        return required("SUPABASE_ANON_KEY");
    },

    // ── Razorpay ──
    get razorpayKeyId(): string {
        return required("RAZORPAY_KEY_ID");
    },
    get razorpayKeySecret(): string {
        return required("RAZORPAY_KEY_SECRET");
    },
    get razorpayWebhookSecret(): string {
        return required("RAZORPAY_WEBHOOK_SECRET");
    },
    get razorpayConfigured(): boolean {
        return Boolean(read("RAZORPAY_KEY_ID") && read("RAZORPAY_KEY_SECRET"));
    },

    // ── Notification providers ──
    get otpProvider(): string {
        return optional("OTP_PROVIDER", "console").toLowerCase();
    },
    get emailProvider(): string {
        return optional("EMAIL_PROVIDER", "console").toLowerCase();
    },
    get fcmProjectId(): string {
        return optional("FCM_PROJECT_ID");
    },
    get fcmClientEmail(): string {
        return optional("FCM_CLIENT_EMAIL");
    },
    get fcmPrivateKey(): string {
        // Secrets are stored with literal \n; restore real newlines for the PEM parser.
        return optional("FCM_PRIVATE_KEY").replace(/\\n/g, "\n");
    },
    get fcmConfigured(): boolean {
        return Boolean(this.fcmProjectId && this.fcmClientEmail && this.fcmPrivateKey);
    },

    get msg91AuthKey(): string {
        return optional("MSG91_AUTH_KEY");
    },
    get otpSenderId(): string {
        return optional("OTP_SENDER_ID", "BITESB");
    },
    get otpTemplateId(): string {
        return optional("OTP_TEMPLATE_ID");
    },
    get twilioAccountSid(): string {
        return optional("TWILIO_ACCOUNT_SID");
    },
    get twilioAuthToken(): string {
        return optional("TWILIO_AUTH_TOKEN");
    },
    get twilioFromNumber(): string {
        return optional("TWILIO_FROM_NUMBER");
    },

    get resendApiKey(): string {
        return optional("RESEND_API_KEY");
    },
    get emailFrom(): string {
        return optional("EMAIL_FROM", "Bites Box <orders@bitesbox.in>");
    },

    // ── Observability ──
    get sentryDsn(): string {
        return optional("SENTRY_DSN");
    },
    get logLevel(): string {
        return optional("LOG_LEVEL", "info").toLowerCase();
    },

    // ── Misc ──
    get allowedOrigins(): string[] {
        const raw = optional("ALLOWED_ORIGINS");
        return raw ? raw.split(",").map((o) => o.trim()).filter(Boolean) : [];
    },
    get googleMapsServerKey(): string {
        return optional("GOOGLE_MAPS_SERVER_KEY");
    },
};
