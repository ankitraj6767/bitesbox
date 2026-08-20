/**
 * Razorpay client.
 *
 * Rules encoded here:
 *   · Amounts cross the wire in paise (integers). Rupee↔paise conversion is
 *     centralised so no caller can accidentally send ₹566 as 566 paise.
 *   · Every write sends an idempotency key so a retried network call cannot
 *     create a second order, payment capture or refund.
 *   · Signatures are verified with a constant-time comparison.
 */

import { AppError } from "./errors.ts";
import { env } from "./env.ts";
import { logger } from "./logger.ts";

const API_BASE = "https://api.razorpay.com/v1";

export interface RazorpayOrder {
    id: string;
    entity: string;
    amount: number;
    amount_paid: number;
    amount_due: number;
    currency: string;
    receipt: string | null;
    status: "created" | "attempted" | "paid";
    attempts: number;
    notes: Record<string, string>;
    created_at: number;
}

export interface RazorpayPayment {
    id: string;
    entity: string;
    amount: number;
    currency: string;
    status: "created" | "authorized" | "captured" | "refunded" | "failed";
    order_id: string | null;
    method: string | null;
    amount_refunded: number;
    captured: boolean;
    description: string | null;
    card_id: string | null;
    bank: string | null;
    wallet: string | null;
    vpa: string | null;
    email: string | null;
    contact: string | null;
    fee: number | null;
    tax: number | null;
    error_code: string | null;
    error_description: string | null;
    error_reason: string | null;
    acquirer_data?: Record<string, unknown>;
    card?: { last4?: string; network?: string; type?: string };
    notes: Record<string, string>;
    created_at: number;
}

export interface RazorpayRefund {
    id: string;
    entity: string;
    amount: number;
    currency: string;
    payment_id: string;
    status: "pending" | "processed" | "failed";
    speed_processed: string | null;
    speed_requested: string | null;
    notes: Record<string, string>;
    created_at: number;
}

export function toPaise(rupees: number | string): number {
    const value = typeof rupees === "string" ? Number(rupees) : rupees;
    if (!Number.isFinite(value) || value < 0) {
        throw new AppError("INVALID_AMOUNT", "The payment amount is not valid.");
    }
    // Round only after scaling so 566.20 becomes 56620, never 56619.
    return Math.round(value * 100);
}

export function fromPaise(paise: number): number {
    return Math.round(paise) / 100;
}

function authHeader(): string {
    return `Basic ${btoa(`${env.razorpayKeyId}:${env.razorpayKeySecret}`)}`;
}

async function call<T>(
    path: string,
    init: { method?: "GET" | "POST"; body?: unknown; idempotencyKey?: string } = {},
): Promise<T> {
    if (!env.razorpayConfigured) {
        throw new AppError(
            "CONFIGURATION_ERROR",
            "Online payments are not configured. Please choose cash on delivery.",
            { missing: "RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET" },
        );
    }

    const headers: Record<string, string> = {
        Authorization: authHeader(),
        "Content-Type": "application/json",
    };

    // Razorpay honours this header on create endpoints, making retries safe.
    if (init.idempotencyKey) {
        headers["X-Razorpay-Idempotency-Key"] = init.idempotencyKey;
    }

    const response = await fetch(`${API_BASE}${path}`, {
        method: init.method ?? "GET",
        headers,
        body: init.body ? JSON.stringify(init.body) : undefined,
    });

    const text = await response.text();
    let payload: unknown = {};
    try {
        payload = text ? JSON.parse(text) : {};
    } catch {
        payload = { raw: text };
    }

    if (!response.ok) {
        const detail =
            (payload as { error?: { code?: string; description?: string; reason?: string } })
                .error ?? {};

        logger.error("razorpay.request_failed", {
            path,
            status: response.status,
            gateway_code: detail.code,
            gateway_reason: detail.reason,
        });

        throw new AppError(
            response.status >= 500 ? "PAYMENT_GATEWAY_ERROR" : "PAYMENT_FAILED",
            detail.description ??
                "We could not reach the payment gateway. Please try again in a moment.",
            {
                gateway_code: detail.code,
                gateway_reason: detail.reason,
                http_status: response.status,
            },
            response.status >= 500 ? 502 : 402,
        );
    }

    return payload as T;
}

export const razorpay = {
    /** Creates a Razorpay order for the exact amount the backend computed. */
    createOrder(params: {
        amountRupees: number;
        currency?: string;
        receipt: string;
        notes?: Record<string, string>;
        idempotencyKey: string;
    }): Promise<RazorpayOrder> {
        return call<RazorpayOrder>("/orders", {
            method: "POST",
            idempotencyKey: params.idempotencyKey,
            body: {
                amount: toPaise(params.amountRupees),
                currency: params.currency ?? "INR",
                receipt: params.receipt.slice(0, 40),
                notes: params.notes ?? {},
                // We capture automatically; a separate capture step adds a failure mode
                // with no operational benefit for a restaurant.
                payment_capture: 1,
            },
        });
    },

    fetchOrder(orderId: string): Promise<RazorpayOrder> {
        return call<RazorpayOrder>(`/orders/${orderId}`);
    },

    fetchPayment(paymentId: string): Promise<RazorpayPayment> {
        return call<RazorpayPayment>(`/payments/${paymentId}`);
    },

    fetchOrderPayments(orderId: string): Promise<{ items: RazorpayPayment[] }> {
        return call<{ items: RazorpayPayment[] }>(`/orders/${orderId}/payments`);
    },

    createRefund(params: {
        paymentId: string;
        amountRupees?: number;
        speed?: "normal" | "optimum";
        notes?: Record<string, string>;
        idempotencyKey: string;
    }): Promise<RazorpayRefund> {
        return call<RazorpayRefund>(`/payments/${params.paymentId}/refund`, {
            method: "POST",
            idempotencyKey: params.idempotencyKey,
            body: {
                // Omitting amount refunds the whole payment.
                ...(params.amountRupees !== undefined
                    ? { amount: toPaise(params.amountRupees) }
                    : {}),
                speed: params.speed ?? "normal",
                notes: params.notes ?? {},
            },
        });
    },

    fetchRefund(paymentId: string, refundId: string): Promise<RazorpayRefund> {
        return call<RazorpayRefund>(`/payments/${paymentId}/refunds/${refundId}`);
    },
};

/**
 * Verifies the checkout callback signature:
 *   HMAC_SHA256(razorpay_order_id + "|" + razorpay_payment_id, key_secret)
 */
export async function verifyPaymentSignature(params: {
    razorpayOrderId: string;
    razorpayPaymentId: string;
    signature: string;
}): Promise<boolean> {
    const expected = await hmacSha256Hex(
        `${params.razorpayOrderId}|${params.razorpayPaymentId}`,
        env.razorpayKeySecret,
    );
    return timingSafeEqual(expected, params.signature);
}

/** Verifies a webhook body against the X-Razorpay-Signature header. */
export async function verifyWebhookSignature(
    rawBody: string,
    signature: string | null,
): Promise<boolean> {
    if (!signature) return false;
    const expected = await hmacSha256Hex(rawBody, env.razorpayWebhookSecret);
    return timingSafeEqual(expected, signature);
}

async function hmacSha256Hex(message: string, secret: string): Promise<string> {
    const key = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"],
    );

    const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));

    return Array.from(new Uint8Array(signature))
        .map((byte) => byte.toString(16).padStart(2, "0"))
        .join("");
}

/** Constant-time comparison so a signature cannot be discovered by timing. */
function timingSafeEqual(a: string, b: string): boolean {
    if (a.length !== b.length) return false;
    let mismatch = 0;
    for (let i = 0; i < a.length; i++) {
        mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
    }
    return mismatch === 0;
}

/** Maps a Razorpay method string onto our payment_method enum. */
export function mapPaymentMethod(method: string | null | undefined): string | null {
    switch ((method ?? "").toLowerCase()) {
        case "upi":
            return "UPI";
        case "card":
            return "CARD";
        case "netbanking":
            return "NETBANKING";
        case "wallet":
            return "WALLET_PROVIDER";
        case "emi":
            return "EMI";
        case "paylater":
            return "PAYLATER";
        default:
            return null;
    }
}

/** Extracts the instrument details worth storing for support and reconciliation. */
export function extractMethodDetail(payment: RazorpayPayment): Record<string, unknown> {
    return {
        ...(payment.vpa ? { vpa: payment.vpa } : {}),
        ...(payment.card?.last4 ? { last4: payment.card.last4 } : {}),
        ...(payment.card?.network ? { network: payment.card.network } : {}),
        ...(payment.card?.type ? { card_type: payment.card.type } : {}),
        ...(payment.bank ? { bank: payment.bank } : {}),
        ...(payment.wallet ? { wallet: payment.wallet } : {}),
        ...(payment.acquirer_data ? { acquirer_data: payment.acquirer_data } : {}),
    };
}
