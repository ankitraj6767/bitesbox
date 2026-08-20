# Database

85 tables, 57 enums, 158 RLS policies, 95 client-callable functions, across 32
version-controlled migrations. Nothing is created by hand in the dashboard.

## Schemas

| Schema | Contents | Reachable by a client |
| --- | --- | --- |
| `public` | Tables and the RPC surface | Yes, per grant + RLS |
| `app` | Helpers, triggers, guards, private business logic | No — `USAGE` is granted to `service_role` only |
| `analytics` | Reporting helpers | Read-only via `public.report_*` |
| `storage` | Supabase Storage, with our policies | Through the Storage API |

The `app` schema is the reason the surface is auditable. A client cannot call
`app.transition_order` directly; it can only reach it through `accept_order`,
`cancel_order` and the rest, each of which decides whether the caller may.

## Conventions

**UUID primary keys** everywhere, `gen_random_uuid()`. The exceptions are
deliberate: `delivery_partner_locations` is keyed by `delivery_partner_id` because
there is exactly one live position per rider, and `delivery_location_events` uses
`bigserial` because it is an append-only trail.

**Money is `numeric`, never float.** Domains carry the intent:

```sql
app.money         numeric(12,2)  check (value >= 0)
app.money_signed  numeric(12,2)  -- ledger entries, which may be negative
app.rate          numeric        check (0..1)
app.percent       numeric        check (0..100)
```

`app.money_round(numeric)` is the single rounding rule. A discount computed two
different ways in two different functions is how a bill stops adding up.

**Domains for anything with a shape**: `app.phone` (E.164), `app.email`,
`app.slug`, `app.latitude`, `app.longitude`. The constraint lives with the type, so
every column using it is checked without repeating the rule.

**Timestamps**: `created_at` and `updated_at` on every mutable table, maintained by
`app.attach_updated_at(regclass)` rather than by application code.

**Soft deletion** via `deleted_at` on catalogue and identity tables, where history
matters and a hard delete would orphan an order snapshot. Operational rows
(`cart_items`, `notifications`) are deleted outright.

**Append-only ledgers.** `app.make_append_only(regclass)` attaches a trigger that
refuses UPDATE and DELETE. Applied to `wallet_transactions`, `loyalty_transactions`,
`delivery_earnings`, `delivery_partner_availability`, `delivery_location_events`,
`stock_movements`. A balance is always derived from entries, never stored as a
mutable number that can drift.

**Partial unique indexes** carry business rules the type system cannot:

```sql
-- One live assignment per order. Rejected and expired rows remain as history.
create unique index delivery_assignments_active_order_key
  on public.delivery_assignments (order_id)
  where status in ('OFFERED','ACCEPTED','AT_STORE','PICKED_UP','AT_CUSTOMER');

-- One payout per trip per type, which is what makes completion idempotent.
create unique index delivery_earnings_assignment_key
  on public.delivery_earnings (assignment_id, entry_type)
  where assignment_id is not null;
```

## Domains, in migration order

| Migration | Owns |
| --- | --- |
| `0001 foundation` | Domains, `app.*` utilities: slugify, phone normalisation, haversine, money rounding, `app.fail`, rate limiting primitives |
| `0002 enums` | All 57 enums. Statuses are enums, not text, so an impossible value cannot be written |
| `0003 organisation` | `branches`, `branch_hours`, `branch_holidays`, `delivery_zones`, `tax_categories`, `settings`, `feature_flags` |
| `0004 identity_rbac` | `profiles`, `roles`, `permissions`, `role_permissions`, `user_roles`, `staff_members`, the signup trigger |
| `0005 catalog` | `categories`, `subcategories`, `products`, variants, modifier groups, availability, schedules, collections |
| `0006 addresses_cart` | `addresses`, `carts`, `cart_items`, serviceability |
| `0007 promotions` | `coupons`, `coupon_rules`, `promotions` |
| `0008 orders` | `orders`, `order_items`, `order_status_history`, `order_status_transitions`, `cancellation_policies` |
| `0009 payments_refunds` | `payments`, `payment_events`, `cod_collections`, `refunds`, `refund_policies` |
| `0010 delivery` | Rider tables, assignments, live location, earnings, payout config |
| `0011 notifications` | Templates, `notifications`, `device_tokens`, campaigns, `verification_codes`, `rate_limits` |
| `0012 support_reviews` | Tickets, messages, `reviews` |
| `0013 cms` | Home sections, banners, documents, FAQs |
| `0014 ledgers` | Wallet, loyalty, and the phase-2 inventory tables |
| `0015 audit` | `audit_logs` |
| `0016 pricing_engine` | Cart mutation and `calculate_checkout` |
| `0017 order_state_machine` | `app.transition_order` and the kitchen operations |
| `0018 delivery_operations` | The rider lifecycle RPCs |
| `0019 refund_operations` | Refund request, approval, eligibility |
| `0020 read_surfaces` | Menu, order, kitchen and customer read functions |
| `0021 rls` | Every policy |
| `0022 grants_realtime` | The grant surface and the Realtime publication |
| `0023 analytics` | Dashboard and report functions |
| `0024 scheduled_jobs` | `job_runs`, the jobs, the cadence orchestrator, `pg_cron` |
| `0025 service_api` | `svc_*` functions, service-role only |
| `0026 admin_operations` | Back-office read surfaces and role management |
| `0027 profile_relations` | Deferred foreign keys to `profiles` |
| `0028a notification_events` | Three enum values, alone in a migration (see below) |
| `0028 security_and_storage_hardening` | `available_riders` guard, `anon` helper grants, storage buckets, replica identity, `moderate_review` |
| `0029 rider_lifecycle` | Onboarding state machine, partner codes, earnings adjustments, peak payout |
| `0030 campaign_delivery` | Audience resolution, campaign send, scheduled campaigns |
| `0031 rider_privilege_scope` | Narrows rider privileges; `app.is_assigned_rider` |

`0028a` exists on its own because PostgreSQL refuses to *use* a new enum value in the
same transaction that adds it, and `0029` inserts notification templates for those
events.

## The order snapshot

`order_items` copies what was bought at the moment it was bought:

```sql
product_name, variant_name, product_image_path, food_type,
unit_price, modifiers_price, gross_amount, tax_rate, tax_amount,
packaging_charge, hsn_sac_code, tax_category_id
```

A six-month-old invoice must show the price the customer paid and the name the dish
had, not today's. Renaming a dish or raising its price must not rewrite history —
and a GST invoice that changes retroactively is a compliance problem, not a cosmetic
one.

`order_item_modifiers` snapshots the same way, so "Extra cheese +₹30" stays ₹30.

## The state machine as data

`order_status_transitions` holds 51 rows — every legal edge, with its authorisation
rule:

```sql
from_status | to_status | required_permission | customer_allowed | rider_allowed
```

`app.transition_order` reads this table. An edge that is not in it cannot be
travelled except by someone holding `order.override`, and that writes an
`ORDER_STATUS_OVERRIDE` audit entry.

Direct writes are blocked. `orders.status` can only change while
`bitesbox.transition_ok` is set, which only `app.transition_order` does:

```sql
-- Even a manager with table privileges gets nowhere:
update public.orders set status = 'DELIVERED' where id = '…';
-- ERROR: permission denied
```

See [order-flow.md](order-flow.md).

## Live location, deliberately two tables

```
delivery_partner_locations   one row per rider, updated in place
delivery_location_events     throttled breadcrumbs, append-only
```

A rider publishing every few seconds for an hour would write hundreds of rows per
trip. The mutable row is what the customer subscribes to, so tracking reads one row
by primary key. The trail is sampled at
`app.setting_int('delivery.location_sample_seconds', 20)` for disputes and distance
auditing, and pruned by `app.job_prune_location_history()`.

## Configuration, not constants

`settings` is a typed key-value table (`value jsonb`, `value_type`, `group`,
`label`, `is_public`, `is_secret`, `branch_id`) with history via
`settings_history`. Read through `app.setting_*` helpers.

Nothing operational is hard-coded. Delivery fees live in `delivery_zones`. Prep
time is per product and per branch. COD limits, rider document requirements, offer
TTLs, the nearby-notification radius, campaign thresholds — all settings.

`feature_flags` gates behaviour: COD, scheduled orders, self pickup, wallet,
loyalty, reviews, coupons, tracking, maintenance mode. Turning off COD is an
operator action, not a release.

## Indexes

Every foreign key is indexed. Beyond that, indexes follow the queries that actually
run during service:

```sql
-- The kitchen queue: active orders for one branch, oldest first
create index orders_active_idx on public.orders (branch_id, status, placed_at)
  where status not in (…terminal…);

-- Dispatch: available riders at one branch
create index delivery_partners_available_idx
  on public.delivery_partners (branch_id, duty_state)
  where onboarding_status = 'ACTIVE' and deleted_at is null;

-- Menu: a category's products in display order
create index products_category_idx on public.products (category_id, display_order)
  where is_active and deleted_at is null;
```

Partial indexes because the interesting rows are a small fraction of the table: an
outlet accumulates thousands of completed orders and has a handful of live ones.

## Working with the schema

```bash
npm run db:start      # start the local stack (needs Docker)
npm run db:reset      # every migration from empty, then the seed
npm run db:lint       # plpgsql_check across every function
npm run db:test       # the SQL suite
npm run db:types      # regenerate both database.types.ts files
npm run db:psql -- -c "select 1"

npm run db:diff -- add_something   # capture a change as a new migration
```

Never edit an applied migration. `db:reset` must always reproduce the current
schema from empty, which is what CI asserts.

## Seed data

`supabase/seeds/*.sql` runs in order after a reset and produces a realistic outlet:
one branch in Bakhtiyarpur, 12 categories, 38 products with variants and modifiers,
three delivery zones, 8 coupons, 3 promotions, 18 users across every role, and 10
orders covering delivered, out-for-delivery, preparing, ready-with-no-rider,
self-pickup, rejected-and-refunded, customer-cancelled, item-refunded and
pending-payment.

The states are chosen so every screen has something real to render — the operations
board has a delayed order and an unassigned one, the kitchen has an item out of
stock, and the refunds queue is not empty.

Sign-in details are printed at the end of a reset.

One thing worth knowing when adding seed rows: any sequence behind a
human-readable number must be advanced past the literal values. Seeded tickets ran
to `BB-T000003` while `ticket_number_seq` was still at 1, so the first customer to
ask for help collided on the unique index. `90_finish.sql` now derives the setval
from the data.
