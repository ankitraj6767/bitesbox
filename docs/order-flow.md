# Order flow

## The state machine is data

51 rows in `order_status_transitions`. Every legal edge, with the rule that
authorises it:

```sql
from_status | to_status | required_permission | customer_allowed | rider_allowed | label
```

`app.transition_order` is the only writer of `orders.status`. It reads this table,
and an edge that is not present cannot be travelled — except by someone holding
`order.override`, which writes an `ORDER_STATUS_OVERRIDE` audit entry.

Direct writes are blocked at the table:

```sql
update public.orders set status = 'DELIVERED' where id = '…';
-- ERROR: permission denied
```

`orders.status` only changes while the session flag `bitesbox.transition_ok` is set,
which only `app.transition_order` sets, and only for its own statement.

## The states

```
                        PENDING_PAYMENT
                         │           │
             (webhook)   │           │  (failure / expiry)
                         ▼           ▼
                PAYMENT_CONFIRMED   PAYMENT_FAILED
                         │           │
                         ▼           └──► CUSTOMER_CANCELLED
                    ORDER_PLACED ◄────────────┐
                    │        │                │ rider declined
        accept ─────┘        └───── reject    │
                ▼                     ▼       │
         STORE_ACCEPTED         STORE_REJECTED│
                │                             │
                ▼                             │
            PREPARING                         │
                │                             │
                ▼                             │
        READY_FOR_PICKUP ─────────────────────┤
                │                             │
                ▼                             │
         RIDER_ASSIGNED                       │
                │                             │
                ▼                             │
      RIDER_ARRIVED_STORE                     │
                │  pickup code                │
                ▼                             │
            PICKED_UP ────────────────────────┘
                │
                ▼
        OUT_FOR_DELIVERY
                │
                ▼
     RIDER_ARRIVED_CUSTOMER
                │  customer OTP
                ▼
            DELIVERED ──► COMPLETED
```

Failure and money-back states: `PAYMENT_FAILED`, `STORE_REJECTED`,
`CUSTOMER_CANCELLED`, `ADMIN_CANCELLED`, `DELIVERY_FAILED`, `REFUND_PENDING`,
`PARTIALLY_REFUNDED`, `REFUNDED`.

A COD order skips straight to `ORDER_PLACED` — there is nothing to confirm.

## Authorisation, in order

```sql
if actor_kind in ('SYSTEM','WEBHOOK','SCHEDULER') or app.is_service_role() then
  authorised
elsif required_permission is null then
  -- a system-only edge attempted by a human
  authorised := app.has_permission('order.override', branch_id)
elsif customer_allowed and actor = order.user_id then
  authorised
elsif rider_allowed and app.is_assigned_rider(order_id, actor) then
  authorised
else
  authorised := app.has_permission(required_permission, branch_id)
end if
```

Two consequences worth knowing.

The null-permission branch is checked *before* `customer_allowed`, so an edge with
no permission is effectively system-only. `PAYMENT_FAILED → PENDING_PAYMENT` is
marked `customer_allowed` but has no permission, so a customer retrying payment goes
through the service role in `create-payment` rather than driving the edge directly.

`rider_allowed` is scoped to the rider assigned to *that* order, never to a
permission. A rider holds no permissions at all — see [rbac.md](rbac.md).

## Placement

Only `create-order` may place an order, and only through `svc_place_order`, which is
service-role gated.

```
POST /functions/v1/create-order
{ idempotency_key, payment_mode?, cart_id?, tip_amount?, loyalty_points? }
```

Inside one transaction:

1. Re-price the cart from scratch. The quote the app was showing is ignored.
2. Re-check serviceability, branch state, trading hours, item availability, the
   coupon, and the COD limits.
3. Snapshot every line into `order_items` and `order_item_modifiers`.
4. Set `PENDING_PAYMENT` for an online order, or `ORDER_PLACED` for COD.
5. Enqueue the notifications.

Being one transaction is the point: there is no window in which an order exists
without its items, or a status changed without the customer being told.

### Idempotency

`orders.idempotency_key` is unique. A repeated key returns the original order with
`replayed: true` rather than creating a second one.

This is the double-tapped Place Order button, and the retry after a timeout on a
train between Bakhtiyarpur and Patna. Suite `050_payments_and_idempotency` asserts
that three calls with the same key produce exactly one order row.

## Kitchen

| Action | Function | Permission | Effect |
| --- | --- | --- | --- |
| Accept | `accept_order(order_id, prep_minutes)` | `order.accept` | `STORE_ACCEPTED`, sets `promised_at` |
| Reject | `reject_order(order_id, reason, note)` | `order.reject` | `STORE_REJECTED`, refund raised automatically |
| Start | `start_preparing(order_id)` | `order.prepare` | `PREPARING` |
| Ready | `mark_order_ready(order_id)` | `order.ready` | `READY_FOR_PICKUP`, issues the pickup code |
| Cancel a line | `cancel_order_item(item_id, note)` | `order.override` | Re-prices, raises a partial refund |

Accepting is where the customer's promise time is set, which is why the prep
estimate is asked for rather than assumed.

Every one of these is idempotent. Accepting an already-accepted order returns
`changed: false` instead of failing — a kitchen tablet double-tap on a flaky
connection must not produce an error the staff have to reason about mid-service.

An unpaid order never appears in `kitchen_queue`. The kitchen cannot start cooking
something that has not been paid for.

## Cancellation

`cancellation_policies` is configuration, per status:

```
ORDER_PLACED      customer may cancel, full refund
STORE_ACCEPTED    customer may cancel, fee may apply
PREPARING         approval required
READY_FOR_PICKUP  restricted
PICKED_UP         blocked
```

`cancellation_options(order_id)` returns what would happen — whether cancellation is
allowed, the refund amount, any fee, whether approval is needed — so the app quotes
a number that will actually be honoured rather than estimating one.

`cancel_order(order_id, reason, note)` then applies it and raises the refund.

## Timeline

`order_status_history` records every transition: from, to, label, note, actor, actor
kind, actor role, whether it was an override, and metadata. Append-only.

That is what the customer's tracking screen renders, and what answers "who cancelled
this and when" three weeks later.

```
7:20 PM  Order placed
7:21 PM  Payment confirmed
7:23 PM  Restaurant accepted
7:24 PM  Preparing
7:37 PM  Ready
7:39 PM  Assigned to Rahul Kumar
7:43 PM  Picked up
7:44 PM  Out for delivery
8:01 PM  Delivered
```

## Side effects

`app.on_order_status_changed` runs after every transition and is the single place
where a status change fans out: customer notification, kitchen alert, rider
notification, pickup code and delivery OTP generation, COD reconciliation, review
request.

One place, so a new status cannot be added and quietly forget to tell anyone.

## Scheduled repair

Real-world failures need cleaning up without a human noticing:

| Job | Cadence | Does |
| --- | --- | --- |
| `job_expire_unpaid_orders` | minute | Cancels `PENDING_PAYMENT` past its window |
| `job_activate_scheduled_orders` | minute | Releases a scheduled order to the kitchen |
| `job_detect_delays` | minute | Flags `is_delayed`, alerts the customer |
| `job_expire_assignments` | minute | Expires an unanswered offer, returns the order to dispatch |
| `job_complete_delivered_orders` | hourly | `DELIVERED → COMPLETED` after the refund window |
| `job_flag_unreconciled_payments` | hourly | Surfaces a capture with no webhook |

Driven by `pg_cron`, with the `scheduled-jobs` Edge Function as a fallback.

## Errors

Stable codes, mirrored in `packages/shared-types/src/errors.ts` and
`apps/mobile/lib/core/errors/app_error.dart`:

```
INVALID_ORDER_TRANSITION   ORDER_NOT_FOUND        RESTAURANT_CLOSED
ORDERING_PAUSED            ITEM_UNAVAILABLE       CART_EMPTY
ADDRESS_NOT_SERVICEABLE    MIN_ORDER_NOT_MET      COUPON_EXPIRED
CANCELLATION_NOT_ALLOWED   PERMISSION_DENIED      QUANTITY_LIMIT_EXCEEDED
```

`app.fail(code, message, detail)` raises with the code in the exception `HINT`, the
customer-safe copy in the message, and structured detail as JSON. Both clients read
the hint, so screens branch on a stable code and never show a raw Postgres string.

## Tested

`supabase/tests/020_order_state_machine.test.sql` asserts, as real API roles:

- an order cannot start preparing before it is accepted
- accepting twice is a no-op, not an error
- a customer cannot accept their own order or mark it ready
- a delivered order cannot be cancelled
- a customer cannot cancel someone else's order
- a direct `update orders set status` is refused and the status is unchanged
- no edge leads from a terminal status back into the kitchen
- every customer cancellation edge requires `order.cancel`
