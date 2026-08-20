/**
 * Standardised error contract shared by every Edge Function.
 *
 * Postgres business errors raise with HINT = stable error code and MESSAGE =
 * customer-friendly copy (see app.fail). This module translates those into an
 * HTTP response the clients can map to localised UI without string matching.
 */

export const ERROR_STATUS: Record<string, number> = {
    // 400 — the request itself is wrong
    VALIDATION_FAILED: 400,
    INVALID_JSON: 400,
    INVALID_AMOUNT: 400,
    INVALID_QUANTITY: 400,
    IDEMPOTENCY_KEY_REQUIRED: 400,
    MODIFIER_INVALID: 400,
    MODIFIER_SELECTION_REQUIRED: 400,
    MODIFIER_SELECTION_EXCEEDED: 400,
    VARIANT_REQUIRED: 400,
    SCHEDULE_REQUIRED: 400,
    SCHEDULE_TOO_SOON: 400,
    SCHEDULE_TOO_FAR: 400,
    REFUND_ITEMS_REQUIRED: 400,
    REFUND_AMOUNT_REQUIRED: 400,
    INVALID_REFUND_AMOUNT: 400,
    DELIVERY_OTP_REQUIRED: 400,
    UNKNOWN_CADENCE: 400,

    // 401 / 403 — identity and authorisation
    UNAUTHENTICATED: 401,
    INVALID_TOKEN: 401,
    PERMISSION_DENIED: 403,
    ACCOUNT_BLOCKED: 403,
    PRIVILEGE_ESCALATION_BLOCKED: 403,
    SELF_APPROVAL_NOT_ALLOWED: 403,
    OVERRIDE_NOT_PERMITTED: 403,
    NOT_A_DELIVERY_PARTNER: 403,
    RIDER_NOT_ACTIVE: 403,
    REFUND_EXCEEDS_ROLE_LIMIT: 403,
    WALLET_FROZEN: 403,

    // 404 — missing
    ORDER_NOT_FOUND: 404,
    ORDER_ITEM_NOT_FOUND: 404,
    ITEM_NOT_FOUND: 404,
    VARIANT_NOT_FOUND: 404,
    CART_NOT_FOUND: 404,
    CART_ITEM_NOT_FOUND: 404,
    ADDRESS_NOT_FOUND: 404,
    PAYMENT_NOT_FOUND: 404,
    REFUND_NOT_FOUND: 404,
    RIDER_NOT_FOUND: 404,
    ASSIGNMENT_NOT_FOUND: 404,
    TICKET_NOT_FOUND: 404,
    CUSTOMER_NOT_FOUND: 404,
    BRANCH_NOT_FOUND: 404,

    // 409 — state conflicts
    ORDER_ALREADY_CREATED: 409,
    INVALID_ORDER_TRANSITION: 409,
    ORDER_NOT_ASSIGNABLE: 409,
    ORDER_ALREADY_PICKED_UP: 409,
    ASSIGNMENT_EXPIRED: 409,
    DELIVERY_NOT_IN_PROGRESS: 409,
    REVIEW_ALREADY_SUBMITTED: 409,
    REVIEW_NOT_ALLOWED: 409,
    REFUND_NOT_ALLOWED: 409,
    REFUND_NOT_PENDING: 409,
    REFUND_AMOUNT_EXCEEDS_REFUNDABLE: 409,
    REFUND_QUANTITY_EXCEEDED: 409,
    CANCELLATION_NOT_ALLOWED: 409,
    LAST_ITEM_CANNOT_BE_CANCELLED: 409,
    ITEM_CANCEL_NOT_ALLOWED: 409,
    PICKUP_CODE_UNAVAILABLE: 409,
    DELIVERY_OTP_UNAVAILABLE: 409,
    RIDER_AT_CAPACITY: 409,
    RIDER_WRONG_BRANCH: 409,
    ACTIVE_DELIVERIES_PENDING: 409,
    NOT_A_DELIVERY_ORDER: 409,
    PAYMENT_ALREADY_CAPTURED: 409,

    // 422 — business rules the customer can act on
    CART_EMPTY: 422,
    ITEM_UNAVAILABLE: 422,
    MODIFIER_UNAVAILABLE: 422,
    QUANTITY_LIMIT_EXCEEDED: 422,
    ADDRESS_REQUIRED: 422,
    ADDRESS_NOT_SERVICEABLE: 422,
    OUTSIDE_MAX_DISTANCE: 422,
    MIN_ORDER_NOT_MET: 422,
    RESTAURANT_CLOSED: 422,
    OUTSIDE_TRADING_HOURS: 422,
    ORDERING_PAUSED: 422,
    MAINTENANCE_MODE: 422,
    BRANCH_INACTIVE: 422,
    TOO_BUSY: 422,
    COUPON_INVALID: 422,
    COUPON_INACTIVE: 422,
    COUPON_EXPIRED: 422,
    COUPON_NOT_STARTED: 422,
    COUPON_EXHAUSTED: 422,
    COUPON_ALREADY_USED: 422,
    COUPON_NOT_ELIGIBLE: 422,
    COUPON_NOT_APPLICABLE: 422,
    COUPON_MIN_ORDER_NOT_MET: 422,
    COUPON_FIRST_ORDER_ONLY: 422,
    COUPON_NO_ELIGIBLE_ITEMS: 422,
    COUPON_PAYMENT_RESTRICTED: 422,
    COUPON_NOT_VALID_TODAY: 422,
    COUPON_NOT_VALID_NOW: 422,
    COUPON_RULE_NOT_MET: 422,
    COD_UNAVAILABLE: 422,
    COD_LIMIT_EXCEEDED: 422,
    COD_MIN_ORDER_NOT_MET: 422,
    COD_AMOUNT_MISMATCH: 422,
    PICKUP_DISABLED: 422,
    PICKUP_UNAVAILABLE: 422,
    SCHEDULING_DISABLED: 422,
    INSUFFICIENT_WALLET_BALANCE: 422,
    INSUFFICIENT_LOYALTY_POINTS: 422,
    CHECKOUT_INVALID: 422,
    REORDER_UNAVAILABLE: 422,
    PICKUP_CODE_INVALID: 422,
    DELIVERY_OTP_INVALID: 422,
    CANCELLATION_LIMIT_REACHED: 422,
    NO_DELIVERY_PARTNER: 422,
    INVOICE_NOT_AVAILABLE: 422,
    CLOSURE_REASON_REQUIRED: 422,

    // 429 — throttling
    RATE_LIMITED: 429,
    TOO_MANY_ATTEMPTS: 429,

    // 5xx
    PAYMENT_FAILED: 502,
    PAYMENT_GATEWAY_ERROR: 502,
    REFUND_GATEWAY_ERROR: 502,
    NOTIFICATION_PROVIDER_ERROR: 502,
    CONFIGURATION_ERROR: 500,
    INTERNAL_ERROR: 500,
};

export class AppError extends Error {
    constructor(
        readonly code: string,
        message: string,
        readonly detail: Record<string, unknown> = {},
        readonly status: number = ERROR_STATUS[code] ?? 400,
    ) {
        super(message);
        this.name = "AppError";
    }
}

/** Shape returned to every client on failure. */
export interface ErrorBody {
    error: {
        code: string;
        message: string;
        detail?: Record<string, unknown>;
        request_id: string;
    };
}

/**
 * Converts a Postgres error raised by app.fail() into an AppError.
 * app.fail puts the stable code in HINT and the customer copy in MESSAGE.
 */
export function fromPostgrestError(error: {
    message?: string;
    hint?: string | null;
    details?: string | null;
    code?: string | null;
}): AppError {
    const code = error.hint?.trim() || mapSqlState(error.code) || "INTERNAL_ERROR";

    let detail: Record<string, unknown> = {};
    if (error.details) {
        try {
            const parsed = JSON.parse(error.details);
            if (parsed && typeof parsed === "object") detail = parsed;
        } catch {
            detail = { details: error.details };
        }
    }

    const message = error.message?.trim() ||
        "Something went wrong. Please try again.";

    return new AppError(code, message, detail);
}

/** Maps a handful of SQLSTATEs to friendly codes for unexpected DB failures. */
function mapSqlState(sqlState?: string | null): string | undefined {
    switch (sqlState) {
        case "23505":
        case "23P01":
            return "ORDER_ALREADY_CREATED";
        case "42501":
            return "PERMISSION_DENIED";
        case "23514":
            return "VALIDATION_FAILED";
        case "40001":
        case "40P01":
            return "INTERNAL_ERROR";
        default:
            return undefined;
    }
}

export function isAppError(error: unknown): error is AppError {
    return error instanceof AppError;
}
