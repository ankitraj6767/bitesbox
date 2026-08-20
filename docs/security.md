# Security

## The premise

> The apps are interfaces. The backend is the authority.

Both clients ship with a publishable key and nothing else. Every number that
matters — price, discount, coupon, tax, delivery fee, wallet balance, loyalty
points, payment status, order status, permissions — is computed or verified inside
Postgres or an Edge Function. A patched APK gets you the same answers as the
official one.

## Layers

```
┌────────────────────────────────────────────────────────────────┐
│ 1  Auth            Supabase phone OTP / email. auth.uid() is   │
│                    the only identity the database trusts.      │
├────────────────────────────────────────────────────────────────┤
│ 2  RLS             85 tables, RLS enabled on all 85.           │
│                    143 policies in public, 15 in storage.      │
├────────────────────────────────────────────────────────────────┤
│ 3  Permissions     app.has_permission(code, branch) inside     │
│                    every privileged function body.             │
├────────────────────────────────────────────────────────────────┤
│ 4  State machine   app.transition_order is the only writer of  │
│                    orders.status.                              │
├────────────────────────────────────────────────────────────────┤
│ 5  Service role    svc_* functions gated on                    │
│                    app.is_service_role(); key never in a       │
│                    client bundle.                              │
├────────────────────────────────────────────────────────────────┤
│ 6  Rate limits     app.consume_rate_limit on every abusable    │
│                    action.                                     │
├────────────────────────────────────────────────────────────────┤
│ 7  Audit           append-only, actor + before/after + IP.      │
└────────────────────────────────────────────────────────────────┘
```

No layer is load-bearing alone. Getting past RLS still leaves the permission check
inside the function; getting past both still leaves the state machine refusing an
illegal edge.

## RLS

Every table in `public` has `row level security` enabled. Not one is left open on
the assumption that no client reads it — a table with no policy returns nothing,
which is the correct default.

Helper functions used by policies, all `stable` and reading only the caller's own
grants:

```
app.has_permission(code, branch)     app.has_any_permission(codes[], branch)
app.has_role(role, branch)           app.is_staff()
app.is_rider()                       app.is_assigned_rider(order, user)
app.can_access_branch(branch)        app.accessible_branch_ids()
app.primary_role()                   app.account_is_active()
app.owns_order(order)                app.is_service_role()
```

### A real bug this surfaced

`grant select on all tables in schema public to anon` was in place, and the catalog
policies read:

```sql
using (deleted_at is null and (is_active or app.has_permission('menu.view')))
```

But `app.has_permission` was granted to `authenticated` only. RLS expressions run
with the caller's privileges, and the planner may evaluate either side of an `OR`
first — so a guest selecting from `products` got
`permission denied for function has_permission` instead of the menu.

The `security definer` read functions (`menu_catalog`, `home_feed`) masked it,
which is why the app still worked. Any direct table read or Realtime subscription
by an anonymous client failed, and a web storefront would have hit it immediately.

Migration `20260819090000` grants those ten helpers to `anon`. Safe by
construction: with no JWT, `auth.uid()` is null and every one of them returns
false.

### Append-only tables

`app.make_append_only(table)` installs a trigger that raises on UPDATE and DELETE.
Applied to ten tables:

```
audit_logs                     order_status_history
branch_status_log              settings_history
delivery_partner_availability  delivery_location_events
delivery_earnings              wallet_transactions
loyalty_transactions           stock_movements
```

Not even an owner can rewrite history through the API. A ledger you can edit is
not a ledger.

### Writes routed through functions

Where a table grant would work but would not record who did it, the grant is
revoked and a function takes its place:

| Was | Now | Because |
| --- | --- | --- |
| `update reviews` | `moderate_review()` | Hiding a review is something an operator may be asked to justify |
| `update orders set status` | `app.transition_order()` | Only legal edges, always a history row |
| `insert delivery_partner_documents` | `submit_rider_document()` | Status progression and expiry validation |
| `update delivery_partners` (self) | `update_my_rider_profile()` | A rider was able to self-activate — see below |

`orders.status` additionally has a trigger guard: it only changes while the session
flag `bitesbox.transition_ok` is set, which only `app.transition_order` sets, and
only for its own statement.

## Privilege escalation found and closed

Two real escalations were found while auditing the deployed surface. Both are now
regression-tested.

### A rider could promote themselves

`delivery_partners_self_update` let a rider update their own row. Verified by
probe, a rider could set `onboarding_status = 'VERIFIED'`, zero their
`cash_in_hand`, set `rating_average = 5` and `total_deliveries = 9999`, and raise
`max_concurrent_orders`.

Column grants cannot fix this: staff and riders are both `authenticated`. A trigger
guard would break the `security definer` functions that legitimately write those
columns. So the policy is dropped, and `update_my_rider_profile()` accepts exactly
the fields a rider owns.

Suite `070` asserts the rider's direct UPDATE matches zero rows and that status,
cash owed, rating and order limit are unchanged.

### The rider role held branch-wide delivery permissions

`DELIVERY_PARTNER` carried `delivery.view`, `delivery.pickup` and
`delivery.complete`. Those are branch-scoped, so any rider could list the whole
roster, read every other rider's assignment — including customer name, phone and
address — and complete another rider's delivery.

The role now holds **zero** permissions. Authority comes from
`app.is_assigned_rider(order_id, user_id)`: being the partner on the assignment for
*that* order.

This required re-creating `app.transition_order`, because `complete_delivery` and
`fail_delivery` set the assignment terminal *before* transitioning the order — so
the rider was no longer recognised and authorisation had been silently falling
through to the `delivery.complete` permission. `app.is_assigned_rider` was widened
to include `COMPLETED` and `FAILED`; no `rider_allowed` edge starts from a terminal
status, so nothing else opens up.

Suite `040` runs the entire rider flow with no permissions and asserts a second
rider gets `PERMISSION_DENIED`.

### available_riders had no guard

`public.available_riders` was granted to `authenticated` but, unlike every other
privileged read, carried no permission check in its body — and it is
`security definer`. Any signed-in customer could call the RPC directly and get the
roster: names, phone numbers, duty state, live proximity. The Edge Function guarded
it; the RPC did not.

It now requires one of `delivery.assign`, `delivery.view` or `rider.view`.

## Verification codes

Pickup codes and delivery OTPs are stored only as `app.hash_code(code, salt)` with
a per-row salt. The plaintext exists on the kitchen ticket and in the customer's
app, never in a column. A database dump does not let you collect somebody's dinner.

Two independent limits: `max_attempts` on the code row, and a rate-limit bucket
keyed on the assignment. Both raise `TOO_MANY_ATTEMPTS`. Consumption is recorded
(`consumed_at`), so a code cannot be replayed.

## Rate limits

`app.consume_rate_limit(bucket, identifier, max_hits, window_seconds,
block_seconds)` is an atomic fixed-window counter. It inserts-or-increments in one
statement and returns false when the caller must be rejected, so two concurrent
requests cannot both pass a check-then-act race.

`block_seconds > 0` adds a lockout beyond the window, for the cases where the
pattern itself is the signal.

| Bucket | Keyed on | Limit | Lockout |
| --- | --- | --- | --- |
| `place_order` | user | 10 / 10 min | 15 min |
| `cancel_order` | user | 3 / day | — |
| `coupon_attempt` | user | 20 / 5 min | 10 min |
| `refund_request` | **customer account** | 10 / day | — |
| `support_ticket` | user | 5 / hour | — |
| `pickup_code` | assignment | 6 / 10 min | 5 min |
| `delivery_otp` | assignment | 6 / 15 min | 10 min |

`refund_request` is keyed on the customer rather than the agent on purpose: ten
requests a day against one account trips the limit no matter which agent is being
talked into raising them.

## Audit

`audit_logs` is append-only and records actor id, actor kind, actor role, actor
name, action, entity type/id/label, branch, `old_value`, `new_value`,
`changed_fields`, reason, IP, user agent and request id.

`changed_fields` is computed inside `app.audit` by diffing the two JSONB blobs, so
a reviewer sees which fields moved instead of two documents to compare by eye.

Indexed by entity, actor, action, branch and time — the five ways anyone actually
asks the question.

Actor metadata is resolved at write time, not join time. A staff member who leaves
and is deleted still leaves a log naming them.

`app.request_ip()` and `app.request_user_agent()` read the PostgREST request
headers, so the trail includes where the action came from.

Audited actions include every refund decision, every order override, every
cancellation, review moderation, rider approval and suspension, reassignment,
COD settlement, and campaign launch.

## Storage

Eight buckets, declared in SQL rather than only in `config.toml` — `supabase start`
reads `config.toml`, `supabase db push` does not, so on the hosted project the
buckets were simply absent and every upload the RLS policies were written for
would have failed with "Bucket not found".

| Bucket | Public | Limit | MIME |
| --- | --- | --- | --- |
| `menu-images` | yes | 8 MB | png, jpeg, webp, avif |
| `banners` | yes | 8 MB | png, jpeg, webp, avif |
| `brand-assets` | yes | 4 MB | png, jpeg, webp, svg, ico |
| `staff-photos` | no | 4 MB | png, jpeg, webp |
| `rider-documents` | no | 10 MB | png, jpeg, webp, pdf |
| `delivery-proofs` | no | 6 MB | png, jpeg, webp |
| `support-attachments` | no | 10 MB | png, jpeg, webp, pdf |
| `invoices` | no | 5 MB | pdf |

Private buckets are read through signed URLs with a short expiry. 15 storage
policies enforce access; the private reads are:

```sql
rider-documents      app.has_permission('rider.view')
                     or foldername[1] = auth.uid()

invoices             app.has_permission('finance.view')
                     or foldername[1] = auth.uid()

delivery-proofs      (app.is_staff() and app.has_permission('delivery.view'))
                     or owner_id = auth.uid()
```

The path-prefix convention is load-bearing: a private object lives under
`{user_id}/…`, so "your own folder" is expressible as a policy rather than a join.
The `is_staff()` conjunct on `delivery-proofs` is what stops a rider — who has no
permissions — from reading every proof photo at the branch; they can still read
the ones they uploaded.

MIME allow-lists and size limits are set on the bucket, so a rejected upload is
rejected by storage rather than by a check somebody has to remember to write.

## Secrets

`.env.example` is the contract. Nothing real is committed.

Split by trust:

```
client-safe   SUPABASE_PUBLISHABLE_KEY, NEXT_PUBLIC_*, RAZORPAY key id,
              per-platform restricted Maps keys
server-only   SUPABASE_SERVICE_ROLE_KEY, SUPABASE_DB_PASSWORD,
              SUPABASE_JWT_SECRET, RAZORPAY_KEY_SECRET,
              RAZORPAY_WEBHOOK_SECRET, FCM_PRIVATE_KEY,
              GOOGLE_MAPS_SERVER_KEY, MSG91_AUTH_KEY, TWILIO_AUTH_TOKEN,
              RESEND_API_KEY, SENTRY_AUTH_TOKEN
```

The service role key bypasses RLS entirely. It exists in Edge Function secrets and
in admin server actions. It is never in a Flutter build and never in a
`NEXT_PUBLIC_` variable.

`scripts/check-secrets.sh` runs in CI and fails the build on:

- `sb_secret_…` Supabase secret keys
- a `"role": "service_role"` claim outside `supabase/seeds/`, `supabase/tests/`
  and `docs/` (the harness legitimately sets that claim against a throwaway local
  database)
- `rzp_live_…` keys, or `RAZORPAY_KEY_SECRET` with a value assigned
- any `BEGIN … PRIVATE KEY` block
- a Google service-account JSON (`"type": "service_account"`)
- tracked files that must stay local: `*.jks`, `*.keystore`,
  `android/key.properties`, `env/prod.json`, `env/staging.json`,
  `ios/Flutter/Maps.xcconfig`, `google-services.json`,
  `GoogleService-Info.plist`, `supabase/functions/.env`

It is a targeted backstop, not a scanner. A generic high-entropy sweep over a repo
full of UUID seed data is all false positives, so it looks for the specific
credential shapes this project actually handles.

## Edge Function boundaries

| Function | `verify_jwt` | Notes |
| --- | --- | --- |
| `razorpay-webhook` | **false** | Razorpay cannot present a Supabase token. The HMAC over the raw body is the authentication. |
| `scheduled-jobs` | true | Additionally checks the `Authorization` header carries the service role key, so a signed-in user cannot trigger the job runner. |
| everything else | true | `requireCaller(req)` resolves `auth.uid()` |

`razorpay-webhook` is the only endpoint on the platform reachable without a
Supabase token, which is why its signature check runs before anything else touches
the body.

Functions that must enforce the caller's own permissions use `userClient(req)`, so
RLS and `app.require_permission` apply — `process-refund` and the campaign path in
`send-notification` both do this deliberately. The service client is used only for
work the caller is not allowed to authorise, such as reading an order to price it.

CORS is an allow-list, not `*`. Every response carries the request id, so a client
error report maps to a server log line.

## Realtime

Four tables were in the publication without `replica identity full`. Realtime needs
the old row to authorise an UPDATE against RLS, so those change events were being
dropped silently — including `delivery_partners` (rider duty state) and
`support_tickets` (the support inbox). Fixed in `20260819090000` for
`order_items`, `delivery_partners`, `branches` and `support_tickets`.

Realtime respects RLS, so a subscription leaks nothing a `select` would not.

## Data handling

Rider bank account numbers are stored masked (`bank_account_masked`); the full
value lives with payroll, outside this platform. Card data is never stored — only
`card_last4` and `card_network` as returned by the gateway. Phone numbers are
normalised through `app.normalize_phone` so one customer is one row.

`profiles.deleted_at` is a soft delete; orders reference `auth.users` with
`on delete restrict`, so financial history cannot be orphaned by an account
deletion.

## What is not covered

- Penetration testing has not been performed. The assertions here are what the SQL
  test suite proves against a real database with real API roles, not a third-party
  assessment.
- Rate limits are per-identifier in Postgres. They do not stop a distributed
  attack; that needs an edge WAF, which is a hosting concern.
- No compliance certification (PCI, SOC 2) is claimed. Card data never touches the
  platform — Razorpay's SDK handles it — which is what keeps the scope small, but
  scope is not certification.

## Tested

`supabase/tests/010_rbac_rls.test.sql` runs as each real API role and asserts
cross-tenant isolation, permission boundaries and the absence of the escalations
above. The other seven suites each assert the security properties of their own
area. See [testing.md](testing.md).
