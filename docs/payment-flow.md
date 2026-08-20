# Payment flow

## The rule

> A payment is confirmed when Razorpay tells the server so over a signed channel.
> Never when the app says it succeeded.

The Flutter checkout callback is a hint that something probably happened. It is
verified before it is believed, and it is not the only path — the webhook confirms
independently. Both converge on one idempotent function.

## Money in

```
                 ┌──────────────────────────────────────────┐
                 │  create-order → orders.payable_amount    │
                 └────────────────────┬─────────────────────┘
                                      ▼
                          POST /create-payment
                  amount read from the order row, never the request
                                      │
                          Razorpay order created
                          payments row: CREATED
                                      │
                            key_id returned (never the secret)
                                      ▼
                          Razorpay checkout in the app
                          │                        │
              callback returns              Razorpay POSTs
                          ▼                        ▼
              POST /verify-payment        POST /razorpay-webhook
              1. HMAC over               1. HMAC over the raw body
                 order|payment           2. x-razorpay-event-id
              2. fetchPayment()             deduplicated
                 status/amount/
                 currency/order id
                          │                        │
                          └───────────┬────────────┘
                                      ▼
                    app.record_payment_capture()  — idempotent
                                      │
                       payments.status = CAPTURED
                       orders  → PAYMENT_CONFIRMED → ORDER_PLACED
```

### create-payment

Reads `orders.payable_amount` and refuses if the order is not in
`PENDING_PAYMENT` or `PAYMENT_FAILED`, or if `payment_status` is already
`CAPTURED` (`PAYMENT_ALREADY_CAPTURED`).

One live gateway order per Bites Box order. An existing `CREATED`/`PENDING`/
`AUTHORIZED` row with the same amount and an unexpired window is reused; otherwise
the stale row is marked `EXPIRED` and `attempt_number` increments. The Razorpay
idempotency key is `bb-pay-{order_id}-{attempt}`, deterministic, so a retried HTTP
call reuses the gateway order rather than minting a second one. A customer cannot
be charged twice for one basket.

After creating the gateway order it asserts `gatewayOrder.amount === toPaise(payable)`
and refuses with `PAYMENT_GATEWAY_ERROR` on a mismatch. That check should never
fire; it exists so that if it ever does, nobody gets charged the wrong number.

The response carries `key_id` — the publishable key id. `RAZORPAY_KEY_SECRET`
never leaves the server.

### verify-payment

Four gates, in order:

1. Locate our `payments` row by `provider_order_id`. Unknown ⇒ `PAYMENT_NOT_FOUND`.
2. `payments.user_id` must equal the caller. Someone replaying another customer's
   callback gets `PERMISSION_DENIED` and a logged `verify_payment.owner_mismatch`.
3. HMAC over `{razorpay_order_id}|{razorpay_payment_id}`. Valid or not, a
   `payment_events` row is written — `callback.signature_verified` or
   `callback.signature_invalid`. An invalid signature is a security event, not a
   typo, so it is stored.
4. `razorpay.fetchPayment()` and compare against our own record: order id, amount
   in paise, currency. Mismatches raise `PAYMENT_FAILED` with
   `reason: ORDER_MISMATCH | AMOUNT_MISMATCH | CURRENCY_MISMATCH`.

Only then `svc_record_payment_capture`. A `failed` gateway status routes to
`svc_record_payment_failure` instead.

The response includes `fully_reconciled`, which is false until the webhook also
arrives. The app does not wait for it — the order is already moving.

### razorpay-webhook

`verify_jwt = false`, because Razorpay cannot present a Supabase token. The HMAC
over the raw body *is* the authentication. The body is read with `req.text()` and
never reserialised, since re-encoding JSON changes the bytes and breaks the digest.

Exactly-once comes from `payment_events (gateway, provider_event_id)` being unique.
`svc_register_webhook_event` returns `{ duplicate, already_processed }`; a repeat
delivery returns 200 immediately without repeating a side effect.

Status codes are deliberate:

| Situation | Response | Why |
| --- | --- | --- |
| Bad or missing signature | **401** | Not a Razorpay delivery. Nothing to retry. |
| Valid signature, handler threw | **200** | Retrying a broken handler forever helps nobody. |
| Valid signature, handled | **200** | Normal. |

A failed handler writes the error onto the event row via
`svc_settle_webhook_event(processed => false)` and reports to Sentry.
`job_flag_unreconciled_payments` and the live-ops alert are what surface it — not
an infinite Razorpay retry loop.

Events handled:

```
payment.captured / order.paid   → svc_record_payment_capture
payment.authorized              → payments.status = AUTHORIZED
payment.failed                  → svc_record_payment_failure
refund.created / speed_changed  → svc_mark_refund_processing
refund.processed                → svc_complete_refund
refund.failed                   → svc_fail_refund
anything else                   → stored, outcome "ignored"
```

Unknown types are still persisted. When Razorpay adds an event, or when someone is
reconstructing an incident at 11pm, the payload is already there.

An underpayment (`captured < payments.amount`) returns `amount_mismatch` and does
**not** capture. A short payment is an incident, not a sale.

## payments

One row per attempt. `amount` is what we intend to collect; `amount_captured` is
what the gateway confirmed. Constraints hold the invariants:

```sql
payments_captured_bounds  check (amount_captured <= amount)
payments_refund_bounds    check (amount_refunded <= amount_captured)
payments_failure_shape    check (status <> 'FAILED' or failure_code is not null)
```

A row cannot be `FAILED` without saying why. Support always has a reason to read
out.

Unique indexes: `idempotency_key`, and partial uniques on `provider_order_id` and
`provider_payment_id`. One Razorpay payment cannot be recorded twice under any
race.

`verified_by_callback` and `verified_by_webhook` are tracked separately.
`reconciled_at` is set when both agree. Captured with only the callback is a real,
usable payment — but it is not reconciled, and the hourly job knows the difference.

Method detail (`vpa`, `card_last4`, `card_network`, `bank_name`,
`wallet_provider`) is extracted from the gateway response, because "which UPI ID
did I pay from" is a real support question.

## COD

There is nothing to confirm, so a COD order goes straight to `ORDER_PLACED`, and
`svc_place_order` inserts `cod_collections` with `expected_amount = payable_amount`
in the same transaction.

```
COD_PENDING ──rider collects──► COD_COLLECTED ──handover──► settled_at
```

`complete_delivery` will not close a COD delivery for less than the payable
amount — short cash raises `COD_AMOUNT_MISMATCH` naming the figure to collect. On
success it sets `COD_COLLECTED`, stamps `discrepancy_amount` (signed, so over and
short are both recorded rather than one being quietly dropped), and marks the order
`payment_status = CAPTURED`.

`settle_cod(delivery_partner_id, order_ids[], note)` records the handover to the
branch till, requires `payment.reconcile`, and draws down
`delivery_partners.cash_in_hand`. `cod_collections_unsettled_idx` covers
`COD_COLLECTED and settled_at is null` — the "cash still in a rider's pocket"
query.

COD eligibility is re-checked at placement against `cod.max_amount`, not trusted
from the app.

## Money out

`refunds` is a workflow, not a flag:

```
REQUESTED / APPROVAL_PENDING ──► APPROVED ──► PROCESSING ──► COMPLETED
                             └─► REJECTED                └─► FAILED
```

### Amount

`app.refundable_amount(order_id)` is the single source of truth — grand total less
already refunded less refunds in flight. Every path checks against it:

```
REFUND_AMOUNT_EXCEEDS_REFUNDABLE   requested more than remains
REFUND_AMOUNT_REQUIRED             PARTIAL_REFUND without an amount
REFUND_ITEMS_REQUIRED              ITEM_REFUND without items
REFUND_QUANTITY_EXCEEDED           more units than were bought and not yet refunded
REFUND_NOT_ALLOWED                 no captured payment, or already fully refunded
```

`ITEM_REFUND` prices each line from `order_items.net_amount / quantity`, so the
refund reflects the discount actually applied to that item rather than menu price.

### Who may refund how much

`refund_policies`, one row per role, is configuration:

| Role | Auto-approve up to | Max request | Second approval above |
| --- | --- | --- | --- |
| SUPPORT | ₹300 | ₹2,000 | ₹1,000 |
| OPERATIONS | ₹500 | ₹3,000 | ₹1,500 |
| MANAGER | ₹2,000 | ₹10,000 | ₹5,000 |
| FINANCE | ₹10,000 | unlimited | ₹25,000 |
| ADMIN | ₹25,000 | unlimited | — |
| OWNER | effectively unlimited | unlimited | — |

Holding `refund.approve` auto-approves regardless. Otherwise the amount is checked
against `auto_approve_limit`, and `max_request_amount` is a hard ceiling —
exceeding it raises `REFUND_EXCEEDS_ROLE_LIMIT` telling the agent to escalate.

Note SUPPORT holds `refund.create` and *not* `refund.approve`. A support agent can
always start a refund and can settle a small one; a large one goes to a human with
more authority.

### Destination

`ORIGINAL_PAYMENT_METHOD` is silently downgraded to `WALLET_CREDIT` when the order
was COD or `SPLIT_WALLET_COD`, or when no captured payment row exists. Cash cannot
be pushed back down a gateway, so store credit is the honest answer instead of a
refund that never lands.

`WALLET_CREDIT` settles inside `app.complete_refund` via `app.post_wallet_entry`
with idempotency key `refund_wallet:{refund_id}` — no gateway call, immediate.

### Abuse guard

```sql
app.consume_rate_limit('refund_request', order.user_id, 10, 86400)
```

Keyed on the **customer**, not the agent, so ten requests a day against one
account trips `RATE_LIMITED` regardless of which agent is being talked into it.

### The gateway call

`process-refund` decides nothing. Permission, amount, policy routing and
four-eyes all happen inside `request_refund` / `approve_refund` against the
caller's own JWT — the function uses `userClient(req)` for the decision step
precisely so RLS and `app.require_permission` apply. It reads
`requires_gateway_call` from the result and, if true, calls Razorpay and records
what it said.

Refund completion is asynchronous. `refund.processed` from the webhook is what
sets `COMPLETED`. `refund.failed` sets `FAILED` with
`REFUND_FAILED_AT_GATEWAY` for finance to review.

`app.sync_order_refund_state` is a trigger, so `orders.refunded_amount`,
`orders.status` (`PARTIALLY_REFUNDED` / `REFUNDED`) and `payments.amount_refunded`
follow the refund rows automatically. Nothing has to remember to update them.

## Reconciliation

| Job | Cadence | Does |
| --- | --- | --- |
| `job_expire_unpaid_orders` | minute | Cancels `PENDING_PAYMENT` past its window |
| `job_flag_unreconciled_payments` | hourly | Surfaces a capture with no matching webhook |

`payments_reconcile_idx` covers `status in (CREATED, PENDING, AUTHORIZED)` so the
sweep is an index scan rather than a table scan on a growing table.

## Tested

`supabase/tests/050_payments_and_idempotency.test.sql` asserts, as real API roles:

- a customer calling `svc_place_order` directly is refused with `PERMISSION_DENIED`
- placing three times with one idempotency key yields one order row, and the
  repeats report `replayed: true`
- the stored `payable_amount` equals the server quote the app was shown
- `order_items` carry their own name and price snapshot
- an online order sits at `PENDING_PAYMENT` and is absent from `kitchen_queue`
- registering the same `provider_event_id` twice stores one `payment_events` row
- `cod.max_amount` is configured

`060_refunds.test.sql` asserts:

- a customer cannot refund themselves, but `request_order_help` and
  `refund_eligibility` both work for them
- kitchen staff cannot issue refunds
- an unpaid order raises `REFUND_NOT_ALLOWED`
- 999999 raises `REFUND_AMOUNT_EXCEEDS_REFUNDABLE`; `-50` and `0` raise
  `REFUND_AMOUNT_REQUIRED`
- a replayed refund key returns the same refund, and one row exists for it
- SUPPORT can request but not approve; FINANCE can approve
- approval alone writes no wallet entry; `svc_complete_refund` writes exactly one,
  and settling twice still writes one
- the ledger entry records the balance it produced
- after ₹100 of ₹566 is returned, ₹566 again is refused and ₹466 is allowed
- `update refunds set amount = 1` is refused even for FINANCE
- the decision appears in `audit_logs` as `REFUND_REQUEST` / `REFUND_APPROVE`
