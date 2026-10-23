import { reportToSentry, sanitizeTelemetry } from "./logger.ts";
import { newRequestId } from "./http.ts";

Deno.test("telemetry redacts credentials and customer data in values and keys", () => {
    const cleaned = sanitizeTelemetry({
        message: "failed for ankit@example.test, call +91 98765 43210, Bearer abc.def.ghi",
        phone: "+919876543210",
        upload_image: "data:image/png;base64,AAAA1111",
        request_id: "req-12345678",
        status: 502,
    }) as Record<string, unknown>;

    if (cleaned.phone !== "[redacted]") throw new Error("phone field was not redacted");
    if (cleaned.upload_image !== "[redacted]") throw new Error("image field was not redacted");
    if (cleaned.request_id !== "req-12345678") throw new Error("correlation id was lost");
    const message = String(cleaned.message);
    if (
        message.includes("ankit@example.test") || message.includes("98765") ||
        message.includes("abc.def")
    ) {
        throw new Error("text PII or credential was not redacted");
    }
    if (cleaned.status !== 502) throw new Error("useful diagnostic status was lost");
});

Deno.test("request ids propagate only when they match the safe correlation format", () => {
    const accepted = new Request("https://edge.example", {
        headers: { "x-request-id": "req-12345678" },
    });
    const rejected = new Request("https://edge.example", {
        headers: { "x-request-id": "+91 98765 43210" },
    });
    if (newRequestId(accepted) !== "req-12345678") {
        throw new Error("valid request id did not propagate");
    }
    if (!/^[0-9a-f-]{36}$/i.test(newRequestId(rejected))) {
        throw new Error("unsafe request id was accepted");
    }
});

Deno.test("Sentry reporting failure never escapes to the business request", async () => {
    const originalDsn = Deno.env.get("SENTRY_DSN");
    const originalFetch = globalThis.fetch;
    Deno.env.set("SENTRY_DSN", "https://public@sentry.example/1");
    globalThis.fetch = (() => Promise.reject(new Error("telemetry offline"))) as typeof fetch;
    try {
        await reportToSentry(new Error("request failed for caller@example.test"), {
            fn: "create-order",
            request_id: "req-12345678",
        });
    } finally {
        globalThis.fetch = originalFetch;
        if (originalDsn === undefined) Deno.env.delete("SENTRY_DSN");
        else Deno.env.set("SENTRY_DSN", originalDsn);
    }
});
