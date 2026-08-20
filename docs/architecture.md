# Architecture

## The one rule

> The apps are interfaces. The database is the authority.

Every number that matters — price, discount, tax, delivery fee, wallet balance,
payout, refund amount — is computed in Postgres. Every state change goes through a
function that checks whether the caller may make it. A tampered client gains
nothing, because it was never trusted with anything.

This is not a stylistic preference. A restaurant platform handles money and food in
the physical world: an order the kitchen cooked but the customer did not pay for, or
a delivery marked complete that never arrived, costs real money and cannot be undone
by a bug fix. So the invariants live in one place, close to the data, where they
cannot be bypassed by a second client written later.

## Topology

```
┌───────────────────────────────────────────────────────────┐
│                   UNIFIED FLUTTER APP                     │
│                                                           │
│   Customer shell      Rider shell       Kitchen shell     │
│   /home /menu         /rider            /kitchen          │
│   /cart /orders       /rider/earnings   /kitchen/         │
│   /account            /rider/profile      availability    │
└──────────┬────────────────────────────────────────────────┘
           │  Postgres RPC (RLS enforced) + Realtime
           │  Edge Functions for anything privileged
           ▼
┌───────────────────────────────────────────────────────────┐
│                  SUPABASE / POSTGRESQL                    │
│                                                           │
│   public.*     the API surface: tables + RPC functions    │
│   app.*        private helpers, triggers, guards          │
│   analytics.*  reporting helpers                          │
│                                                           │
│   85 tables · 57 enums · 158 RLS policies · 95 client RPCs │
└──────────┬────────────────────────────────────────────────┘
           │  PostgREST + service role (server-side only)
           ▼
┌───────────────────────────────────────────────────────────┐
│              NEXT.JS 15 ADMIN DASHBOARD                   │
│   Owner · Admin · Manager · Operations ·                  │
│   Finance · Support · Marketing                           │
│   One application, RBAC decides what each operator sees   │
└───────────────────────────────────────────────────────────┘
```

## Where logic lives, and why

There are three places a rule can live. The choice is not arbitrary.

### Postgres functions — the default

Anything that must be true regardless of which client is calling. Pricing, the
order state machine, coupon evaluation, refund limits, delivery verification, RBAC.

These are `SECURITY DEFINER` with `SET search_path = ''`, so they run as the table
owner and cannot be redirected by a hostile search path. They are the only writer
for every financial table: `orders`, `payments`, `refunds`, `wallet_transactions`,
`delivery_earnings` are all read-only to clients.

Being inside the transaction is the point. `svc_place_order` prices the cart,
writes the order, snapshots the items and enqueues the notifications atomically.
There is no window in which an order exists without its items, or a status changed
without the customer being told.

### Edge Functions — only when Postgres cannot

A function goes in Deno only when it needs to talk to the outside world or hold a
secret that must never reach a client:

| Function | Why it cannot be a Postgres function |
| --- | --- |
| `create-payment` | Calls the Razorpay API with the secret key |
| `verify-payment` | HMAC verification, then a Razorpay fetch to cross-check |
| `razorpay-webhook` | Receives an unauthenticated HTTP request and verifies a signature |
| `process-refund` | Calls the Razorpay refund API |
| `send-notification` | Calls FCM, the SMS provider and the email provider |
| `scheduled-jobs` | Entry point for the cron/worker cadence |
| `create-order` | Holds the service role needed to call `svc_place_order` |

The rest — `apply-coupon`, `calculate-checkout`, `transition-order`,
`assign-rider`, `complete-delivery`, `admin-operation` — are thin façades over RPCs
that exist mainly to give the mobile app one HTTP shape and one place to log. The
authorisation still happens in the database, using the caller's own JWT.

### The clients — presentation and nothing else

The Flutter app and the admin dashboard decide what to show, never what is true.
When a rider taps "Complete delivery" the app sends an OTP and renders whatever the
database says happened. It does not decide that the delivery is complete.

Concretely: `cart_items` has no price column at all. There is nothing for a client
to tamper with, because the cart stores only what was chosen — product, variant,
quantity, modifiers — and every amount is resolved from the catalogue at pricing
time.

## Realtime is a signal, not a payload

Eleven tables are published: `orders`, `order_status_history`, `order_items`,
`product_availability`, `delivery_assignments`, `delivery_partner_locations`,
`delivery_partners`, `branches`, `notifications`, `support_messages`,
`support_tickets`.

Every subscriber treats an event as "something changed, ask again" and re-reads
through the RPC. Nothing is rendered from the broadcast payload directly.

That costs an extra round trip and buys two things. RLS remains the only thing
deciding what a client can see — a broadcast cannot leak a row a query would have
refused. And state can never be half-applied from an out-of-order event.

Tables published for UPDATE carry `REPLICA IDENTITY FULL`, because Realtime needs
the old row to authorise the change against RLS. Without it the events are silently
dropped.

## Three shells, one codebase

`AppSession`, from `public.my_session()`, decides which shell loads:

```
isRider              → /rider      (delivery partner)
prefersKitchenShell  → /kitchen     (kitchen staff and managers)
otherwise            → /home        (customer)
```

The router enforces this by redirect: a rider cannot navigate to `/cart`, and
kitchen staff are held to `/kitchen*`, `/order/*` and `/profile`.

That redirect is convenience, not security. A rider who patched the binary to load
the customer shell would see an empty cart and be refused at every write, because
the database checks the same session independently. Suite `010_rbac_rls` asserts
exactly that, as the real API roles rather than as the table owner.

Role membership comes from the grant list, not from `primary_role`: a rider whose
primary role was left as `CUSTOMER` still reaches the rider shell, because
otherwise they would be shown a cart they cannot use.

## Data flow: one order, end to end

```
Customer                Database                    Kitchen / Rider
   │                       │                              │
   ├─ cart_add_item ──────►│ prices from the catalogue     │
   ├─ apply_coupon ───────►│ validates rules server-side   │
   ├─ calculate_checkout ─►│ returns the bill + issues[]   │
   │                       │                              │
   ├─ create-order ───────►│ svc_place_order               │
   │   (idempotency key)   │  · re-prices from scratch     │
   │                       │  · snapshots every item       │
   │                       │  · PENDING_PAYMENT            │
   │                       │                              │
   ├─ create-payment ─────►│ Razorpay order created        │
   ├─ pays in the SDK      │                              │
   ├─ verify-payment ─────►│ HMAC + gateway cross-check    │
   │                       │ → PAYMENT_CONFIRMED           │
   │  webhook (authority) ►│ reconciles either way         │
   │                       │ → ORDER_PLACED ──────────────►│ appears in the queue
   │                       │                              │
   │                       │◄──────── accept_order ────────┤
   │◄── realtime ──────────┤ → STORE_ACCEPTED              │
   │                       │◄──────── mark_order_ready ────┤
   │                       │                              │
   │                       │◄──── assign_rider (ops) ──────┤
   │                       │◄──── verify_pickup ───────────┤ pickup code
   │◄── live map ──────────┤ publish_rider_location        │
   │                       │◄──── complete_delivery ───────┤ customer OTP
   │◄── DELIVERED ─────────┤                              │
```

The customer's payment callback is never treated as authoritative on its own. The
webhook reconciles independently, so an app that is killed mid-payment still ends up
with a confirmed order. See [payment-flow.md](payment-flow.md).

## Multi-branch, from day one

The launch is one outlet in Bakhtiyarpur. Every table that could ever be
branch-specific already carries `branch_id`: orders, products' availability, zones,
hours, riders, assignments, coupons, campaigns, settings.

Permissions are branch-scoped too. `app.has_permission(code, branch_id)` treats a
grant with `branch_id IS NULL` as organisation-wide and a scoped grant as applying
to that branch only. A manager at a second outlet is a `user_roles` row, not a code
change.

What is deliberately absent is multi-branch *UI*. The customer app talks to
`app.default_branch_id()`, and the dashboard shows one outlet. Adding a branch
selector later is additive; retrofitting `branch_id` into a live orders table is
not. That asymmetry is the whole argument for carrying the column early.

## Deliberate omissions

Building these now would cost more than it returns:

- **No marketplace.** No vendor onboarding, no commission engine, no restaurant
  discovery. One brand.
- **No ingredient inventory.** `ingredients`, `recipes`, `stock_movements` and
  `purchase_entries` exist with RLS and grants but no functions, gated behind the
  `inventory.ingredient_tracking` flag. Menu-level availability is what a kitchen
  actually maintains during service.
- **No automatic dispatch.** `available_riders` already computes the score
  (`load × 100 + distance × 10 + (5 − rating) × 5 + duty penalty`) and
  `assign-rider` can consume it in `AUTO` mode. With three riders at one outlet, a
  human picking from a ranked list is better than a robot.
- **No customer website.** Products and categories carry `slug`, `meta_title` and
  `meta_description` so one can be added without touching the schema.

## Choices worth knowing about

**Hand-written JSON parsing in Flutter, no `freezed` or `json_serializable`.**
The payloads come from purpose-built Postgres functions whose shape we control, and
avoiding `build_runner` keeps `flutter analyze` and CI free of a codegen step. The
cost is that a renamed key is caught by a test rather than by the compiler, which is
why `test/features/delivery_models_test.dart` pins the JSON contract explicitly.

**A straight line on the tracking map, not a driving route.**
Drawing the real route would mean a Directions API call per GPS fix, refreshed every
few seconds, for a visual the rider does not navigate by. Turn-by-turn hands off to
the phone's own maps app, which does traffic and lane guidance far better. The
customer sees a dashed line and a live marker, which is what the ETA is for.

**No position interpolation.** The rider marker steps every few seconds rather than
gliding. A smoothly animated marker that is actually a guess is worse than one that
is true, because the customer walks to the door based on it.

**Push is optional.** Firebase is configured entirely through `--dart-define`, so
no `google-services.json` is committed and a build without keys still works: order
updates arrive over Realtime and land in the in-app inbox. Push only adds the
ability to wake a closed app.

## Reading order

| Document | For |
| --- | --- |
| [database.md](database.md) | Schema, conventions, what each domain owns |
| [rbac.md](rbac.md) | Roles, permissions, the four enforcement layers |
| [order-flow.md](order-flow.md) | The state machine and who may travel each edge |
| [payment-flow.md](payment-flow.md) | Razorpay, idempotency, reconciliation |
| [delivery-flow.md](delivery-flow.md) | Dispatch, verification, live location |
| [security.md](security.md) | RLS, secrets, abuse controls, audit |
| [testing.md](testing.md) | The suites and the critical matrix |
| [deployment.md](deployment.md) | Environments, CI/CD, release |
