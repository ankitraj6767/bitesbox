import { AppError } from "./errors.ts";
import {
    matchesGatewayAmountAndCurrency,
    razorpay,
    toPaise,
    verifyPaymentSignature,
    verifyWebhookSignature,
} from "./razorpay.ts";

function hex(bytes: Uint8Array): string {
    return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function sign(message: string, secret: string): Promise<string> {
    const key = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"],
    );
    return hex(
        new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message))),
    );
}

Deno.test("Razorpay contracts: signatures, exact money, retries and failures", async (t) => {
    const envNames = ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET", "RAZORPAY_WEBHOOK_SECRET"];
    const original = new Map(envNames.map((name) => [name, Deno.env.get(name)]));
    const originalFetch = globalThis.fetch;
    Deno.env.set("RAZORPAY_KEY_ID", "rzp_test_local");
    Deno.env.set("RAZORPAY_KEY_SECRET", "local-only-secret");
    Deno.env.set("RAZORPAY_WEBHOOK_SECRET", "local-webhook-secret");

    try {
        await t.step("valid and invalid checkout and webhook signatures", async () => {
            const paymentSignature = await sign("order_local|pay_local", "local-only-secret");
            const webhookBody = '{"event":"payment.captured","id":"evt_local"}';
            const webhookSignature = await sign(webhookBody, "local-webhook-secret");

            if (
                !await verifyPaymentSignature({
                    razorpayOrderId: "order_local",
                    razorpayPaymentId: "pay_local",
                    signature: paymentSignature,
                })
            ) throw new Error("valid checkout signature was rejected");
            if (
                await verifyPaymentSignature({
                    razorpayOrderId: "order_other",
                    razorpayPaymentId: "pay_local",
                    signature: paymentSignature,
                })
            ) throw new Error("signature for a different order was accepted");
            if (!await verifyWebhookSignature(webhookBody, webhookSignature)) {
                throw new Error("valid webhook signature was rejected");
            }
            if (await verifyWebhookSignature(`${webhookBody} `, webhookSignature)) {
                throw new Error("signature over a modified webhook body was accepted");
            }
            if (await verifyWebhookSignature(webhookBody, null)) {
                throw new Error("unsigned webhook was accepted");
            }
        });

        await t.step("amount and currency must match exactly", () => {
            if (toPaise(566.2) !== 56620) throw new Error("rupees were not converted to paise");
            if (
                !matchesGatewayAmountAndCurrency({
                    expectedRupees: 566.2,
                    capturedPaise: 56620,
                    expectedCurrency: "INR",
                    capturedCurrency: "INR",
                })
            ) throw new Error("matching payment was rejected");
            for (const capturedPaise of [56619, 56621]) {
                if (
                    matchesGatewayAmountAndCurrency({
                        expectedRupees: 566.2,
                        capturedPaise,
                        expectedCurrency: "INR",
                        capturedCurrency: "INR",
                    })
                ) throw new Error("amount mismatch was accepted");
            }
            if (
                matchesGatewayAmountAndCurrency({
                    expectedRupees: 566.2,
                    capturedPaise: 56620,
                    expectedCurrency: "INR",
                    capturedCurrency: "USD",
                })
            ) throw new Error("currency mismatch was accepted");
        });

        await t.step("payment writes are not retried without provider idempotency", async () => {
            let attempts = 0;
            const observed: Request[] = [];
            globalThis.fetch = (input, init) => {
                attempts++;
                observed.push(new Request(input, init));
                return Promise.resolve(new Response("temporary", { status: 503 }));
            };

            try {
                await razorpay.createOrder({
                    amountRupees: 566.2,
                    currency: "INR",
                    receipt: "bb_local",
                });
                throw new Error("failed payment write unexpectedly succeeded");
            } catch (error) {
                if (!(error instanceof AppError) || error.code !== "PAYMENT_GATEWAY_ERROR") {
                    throw error;
                }
            }
            if (attempts !== 1 || observed.length !== 1) {
                throw new Error(`expected one write attempt; got ${attempts}`);
            }
            const request = observed[0]!;
            if (request.headers.has("X-Razorpay-Idempotency-Key")) {
                throw new Error("an undocumented idempotency header was sent");
            }
            const body = await request.json();
            if (body.amount !== 56620 || body.currency !== "INR") {
                throw new Error("provider request used an incorrect amount or currency");
            }
        });

        await t.step("safe reads retry within a bound", async () => {
            let attempts = 0;
            globalThis.fetch = () => {
                attempts++;
                if (attempts === 1) {
                    return Promise.resolve(new Response("temporary", { status: 503 }));
                }
                return Promise.resolve(Response.json({
                    id: "pay_local",
                    entity: "payment",
                    amount: 10000,
                    currency: "INR",
                    status: "captured",
                    order_id: "order_local",
                    amount_refunded: 0,
                    captured: true,
                    method: "upi",
                    card_id: null,
                    bank: null,
                    wallet: null,
                    vpa: null,
                    email: null,
                    contact: null,
                    fee: null,
                    tax: null,
                    error_code: null,
                    error_description: null,
                    error_reason: null,
                    notes: {},
                    created_at: 1,
                }));
            };
            const payment = await razorpay.fetchPayment("pay_local");
            if (attempts !== 2 || payment.id !== "pay_local") {
                throw new Error(`expected one bounded GET retry; got ${attempts} attempts`);
            }
        });

        await t.step("network failures do not replay a potentially accepted write", async () => {
            let attempts = 0;
            globalThis.fetch = () => {
                attempts++;
                return Promise.reject(new DOMException("timeout", "AbortError"));
            };
            try {
                await razorpay.createRefund({
                    paymentId: "pay_local",
                    amountRupees: 100,
                });
                throw new Error("a failed provider refund unexpectedly succeeded");
            } catch (error) {
                if (!(error instanceof AppError) || error.code !== "PAYMENT_GATEWAY_ERROR") {
                    throw error;
                }
            }
            if (attempts !== 1) {
                throw new Error(
                    `expected one potentially accepted refund attempt; got ${attempts}`,
                );
            }
        });
    } finally {
        globalThis.fetch = originalFetch;
        for (const name of envNames) {
            const value = original.get(name);
            if (value === undefined) Deno.env.delete(name);
            else Deno.env.set(name, value);
        }
    }
});
