-- ═══════════════════════════════════════════════════════════════════════════
-- PRICING, COUPONS & SERVICEABILITY
--
-- The rule this suite defends: the client never decides money. A cart is priced
-- by `calculate_checkout`, coupons are validated by `apply_coupon`, and the
-- delivery fee comes from the zone the address actually falls in.
-- ═══════════════════════════════════════════════════════════════════════════
begin;

select tap.suite('Pricing, coupons & serviceability');

select tap.reset();
-- Chosen because both are orderable at any hour: no variants, no required
-- modifier group, and no day-part schedule.
select tap.remember('product', '55555555-0000-0000-0000-000000000052');  -- Onion Pakoda, 89
select tap.remember('cheap',   '55555555-0000-0000-0000-000000000072');  -- Laccha Paratha, 55

-- Two purpose-made coupons with no restrictions beyond a minimum.
--
-- The seeded coupons are realistic marketing: category-scoped, weekend-only,
-- evening-only, first-order-only. That makes them excellent for the negative
-- assertions below and useless for testing the happy path, because the suite
-- would start failing at 7pm or on a Saturday. So the positive cases use coupons
-- this suite owns, and the seeded ones are used for exactly the restriction each
-- was built to express.
insert into public.coupons (
  code, title, discount_kind, discount_value, min_order_amount,
  audience, is_active, starts_at, ends_at
)
values
  ('TESTFLAT50', 'Test flat 50 off', 'FLAT', 50, 199,
   'ALL', true, now() - interval '1 day', now() + interval '1 day'),
  ('TESTFREEDEL', 'Test free delivery', 'FREE_DELIVERY', 0, 199,
   'ALL', true, now() - interval '1 day', now() + interval '1 day');

-- ─── Scheduled availability ─────────────────────────────────────────────────
-- Asserted against fixed timestamps rather than now(), so the result does not
-- depend on what time the suite happens to run.
select tap.eq(
  (select app.product_in_schedule(
     (select product_id from public.product_schedules where day_part = 'BREAKFAST' limit 1),
     null,
     '2026-08-19 13:00:00+05:30'::timestamptz
   )),
  false,
  'a breakfast dish is not orderable at 1pm'
);

select tap.eq(
  (select app.product_in_schedule(
     (select product_id from public.product_schedules where day_part = 'BREAKFAST' limit 1),
     null,
     '2026-08-19 08:00:00+05:30'::timestamptz
   )),
  true,
  'a breakfast dish is orderable at 8am'
);

-- ─── Serviceability is decided by distance from the outlet ──────────────────
select tap.as_anon();

select tap.eq(
  (select (public.check_serviceability(25.4632, 85.5252) ->> 'serviceable')::boolean),
  true,
  'an address in Bakhtiyarpur town is serviceable'
);

select tap.eq(
  (select (public.check_serviceability(25.6100, 85.1400) ->> 'serviceable')::boolean),
  false,
  'an address in Patna city is out of range'
);

select tap.eq(
  (select public.check_serviceability(25.6100, 85.1400) ->> 'reason_code'),
  'ADDRESS_NOT_SERVICEABLE',
  'the refusal carries a machine-readable reason'
);

-- The zone, not the app, sets the fee — and a nearer zone must not cost more.
select tap.ok(
  (select (public.check_serviceability(25.4632, 85.5252) ->> 'delivery_fee')::numeric
       <= (public.check_serviceability(25.5108, 85.5720) ->> 'delivery_fee')::numeric),
  'a closer address never costs more to deliver to'
);

select tap.eq(
  (select public.check_serviceability(25.4632, 85.5252) ->> 'zone_name'),
  'Zone A — Bakhtiyarpur Town',
  'the nearest address resolves to the innermost zone'
);

select tap.reset();

-- ─── A cart is priced server-side ───────────────────────────────────────────
select tap.as_user(tap.seed('customer_a'));

select tap.no_throw(
  format('select public.cart_clear()'),
  'a customer can clear their cart'
);

-- A delivery address is what makes a zone, and therefore a fee, resolvable.
select tap.no_throw(
  'select public.cart_set_options(
     null, ''DELIVERY'', ''b1000000-0000-0000-0000-000000000001''
   )',
  'a customer can choose their delivery address'
);

select tap.no_throw(
  format('select public.cart_add_item(%L, null, 2::smallint)', tap.recall('product')),
  'a customer can add an item'
);

select tap.eq(
  (select public.calculate_checkout() -> 'delivery' ->> 'zone_name'),
  'Zone A — Bakhtiyarpur Town',
  'the quote resolves the address to a zone'
);

select tap.remember(
  'subtotal',
  ((public.calculate_checkout() -> 'totals' ->> 'items_subtotal')::numeric)::text
);

select tap.eq(
  tap.recall_numeric('subtotal'),
  178.00::numeric,
  'the subtotal is 2 x 89 as priced by the server'
);

-- Tax, packaging and delivery are added by the server, so the payable amount is
-- always at least the subtotal.
select tap.ok(
  (select (public.calculate_checkout() -> 'totals' ->> 'grand_total')::numeric
       >= tap.recall_numeric('subtotal')),
  'the grand total is never less than the subtotal'
);

-- ─── Coupons are validated in the database ──────────────────────────────────
select tap.throws(
  'select public.apply_coupon(''NOPE-DOES-NOT-EXIST'')',
  'COUPON_INVALID',
  'an unknown code is rejected'
);

select tap.throws(
  'select public.apply_coupon(''EXPIRED50'')',
  'COUPON_EXPIRED',
  'an expired code is rejected'
);

-- BIRYANI20 needs a 249 minimum; the cart is at 218.
select tap.throws(
  'select public.apply_coupon(''BIRYANI20'')',
  'COUPON_MIN_ORDER_NOT_MET',
  'a code below its minimum order is rejected'
);

select tap.no_throw(
  format('select public.cart_add_item(%L, null, 2::smallint)', tap.recall('cheap')),
  'the customer adds more to clear the minimum'
);

-- BIRYANI20 is scoped to the biryani category, and this cart holds starters and
-- breads. Meeting the minimum is not the same as being eligible.
select tap.throws(
  'select public.apply_coupon(''BIRYANI20'')',
  'COUPON_NO_ELIGIBLE_ITEMS',
  'a category-scoped code is refused when nothing in the cart qualifies'
);

-- ─── A flat discount ────────────────────────────────────────────────────────
select tap.no_throw(
  'select public.apply_coupon(''TESTFLAT50'')',
  'an unrestricted code applies once its minimum is met'
);

select tap.eq(
  (select (public.calculate_checkout() -> 'totals' ->> 'coupon_discount')::numeric),
  50::numeric,
  'the flat discount is exactly the configured amount'
);

-- A discount must never exceed what is being bought.
select tap.ok(
  (select (public.calculate_checkout() -> 'totals' ->> 'total_discount')::numeric
       <= (public.calculate_checkout() -> 'totals' ->> 'items_subtotal')::numeric),
  'a discount never exceeds the subtotal'
);

select tap.no_throw(
  'select public.remove_coupon()',
  'a coupon can be removed'
);

select tap.eq(
  (select (public.calculate_checkout() -> 'totals' ->> 'total_discount')::numeric),
  0::numeric,
  'removing the coupon removes the discount'
);

-- ─── Free delivery ──────────────────────────────────────────────────────────
-- The cart sits between the 199 minimum and the zone's 349 free-delivery
-- threshold, so the waiver is actually visible rather than already implied.
select tap.ok(
  (select (public.calculate_checkout() -> 'totals' ->> 'delivery_fee')::numeric > 0),
  'delivery is charged before the coupon'
);

select tap.no_throw(
  'select public.apply_coupon(''TESTFREEDEL'')',
  'a free-delivery code applies'
);

select tap.eq(
  (select (public.calculate_checkout() -> 'totals' ->> 'delivery_fee')::numeric),
  0::numeric,
  'the delivery fee is waived'
);

select tap.ok(
  (select (public.calculate_checkout() -> 'totals' ->> 'delivery_fee_waived')::numeric > 0),
  'the waived amount is itemised rather than silently dropped'
);

select tap.no_throw('select public.remove_coupon()', 'the waiver can be removed');

select tap.ok(
  (select (public.calculate_checkout() -> 'totals' ->> 'delivery_fee')::numeric > 0),
  'removing the coupon restores the delivery fee'
);

-- ─── Time and day restrictions exist and are configured ─────────────────────
-- Asserted as configuration rather than by applying the codes, so the suite does
-- not pass or fail depending on the hour or the weekday it runs.
select tap.ok(
  (select array_length(valid_days_of_week, 1) > 0
     from public.coupons where code = 'WEEKEND100'),
  'a weekend code carries a day-of-week restriction'
);

select tap.ok(
  (select valid_from_time is not null and valid_to_time is not null
     from public.coupons where code = 'FREEDEL'),
  'an evening code carries a time-of-day window'
);

-- This customer has ordered before, so a first-order code must not work.
select tap.throws(
  'select public.apply_coupon(''BITES75'')',
  'COUPON_FIRST_ORDER_ONLY',
  'a first-order code is refused for a returning customer'
);

-- PICKUP10 is restricted to self-pickup, and this is a delivery cart.
select tap.throws(
  'select public.apply_coupon(''PICKUP10'')',
  'COUPON_NOT_APPLICABLE',
  'a pickup-only code is refused on a delivery order'
);

-- ─── The cart cannot carry a price at all ───────────────────────────────────
-- Stronger than validating a price the client sent: `cart_items` stores only what
-- was chosen — product, variant, quantity, modifiers — and every amount is
-- resolved from the catalogue at pricing time. There is nothing to tamper with.
select tap.eq(
  (select count(*) from information_schema.columns
    where table_schema = 'public'
      and table_name = 'cart_items'
      and column_name ~ 'price|amount|total|discount|fee'),
  0::bigint,
  'the cart stores no money, only choices'
);

select tap.eq(
  (select count(*) from information_schema.columns
    where table_schema = 'public'
      and table_name = 'cart_item_modifiers'
      and column_name ~ 'price|amount'),
  0::bigint,
  'modifier selections store no money either'
);

-- Quantity is the one thing a customer owns, and it is bounded by the product.
select tap.throws(
  format('select public.cart_add_item(%L, null, 500::smallint)', tap.recall('cheap')),
  'QUANTITY_LIMIT_EXCEEDED',
  'a customer cannot order an unbounded quantity'
);

select tap.reset();

-- ─── An unavailable item cannot be added ────────────────────────────────────
select tap.as_user(tap.seed('kitchen'));

select tap.no_throw(
  format('select public.set_product_availability(%L, ''OUT_OF_STOCK'')', tap.recall('product')),
  'kitchen staff can take an item off the menu'
);

select tap.reset();

select tap.as_user(tap.seed('customer_a'));

select tap.throws(
  format('select public.cart_add_item(%L, null, 1::smallint)', tap.recall('product')),
  'ITEM_UNAVAILABLE',
  'an out-of-stock item cannot be added to a cart'
);

-- An item that goes out of stock while it sits in a cart must block checkout
-- rather than silently disappear from the bill.
select tap.ok(
  (select (public.calculate_checkout() ->> 'is_valid')::boolean is not true),
  'checkout is invalid while the cart holds an unavailable item'
);

select tap.ok(
  (select jsonb_array_length(public.calculate_checkout() -> 'issues') > 0),
  'the quote explains what is wrong'
);

select tap.reset();

select tap.done('Pricing, coupons & serviceability');

rollback;
