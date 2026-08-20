-- ═══════════════════════════════════════════════════════════════════════════
-- DELIVERY FLOW
--
-- Walks one order from dispatch to delivered as the real actors, and checks the
-- guard rails that protect the two things a rider can get wrong expensively:
-- leaving with the wrong parcel, and marking food delivered that never arrived.
--
-- This suite is also the regression test for migration 0031, which removed
-- `delivery.view` / `delivery.pickup` / `delivery.complete` from the
-- DELIVERY_PARTNER role. The whole rider flow must still work without them,
-- because a rider's authority comes from being the assigned partner.
-- ═══════════════════════════════════════════════════════════════════════════
begin;

select tap.suite('Delivery flow');

-- ─── Fixture: a ready order and known verification codes ────────────────────
select tap.reset();

select tap.remember('order_id', tap.seed_order(5)::text);   -- READY_FOR_PICKUP

-- Fail loudly here rather than three statements later with a not-null violation
-- on a column nobody was thinking about.
select tap.ok(tap.recall('order_id') is not null, 'the fixture order resolved');

-- Codes are stored only as a salted hash, so a test cannot read the real one.
-- Planting a known code is the same operation that puts one on a kitchen ticket.
insert into public.verification_codes (purpose, subject, code_hash, salt, order_id, expires_at)
values (
  'PICKUP_CODE',
  tap.recall('order_id'),
  app.hash_code('424242', 'test-salt'),
  'test-salt',
  tap.recall_uuid('order_id'),
  now() + interval '1 hour'
);

-- The delivery OTP is deliberately *not* planted here. `verify_pickup` issues it
-- at the moment of pickup, which is the behaviour worth preserving: the customer
-- cannot be given a code for food that has not left the kitchen. The suite
-- rewrites that generated code to a known value once it exists.

select tap.eq(
  (select status::text from public.orders where id = tap.recall_uuid('order_id')),
  'READY_FOR_PICKUP',
  'the order starts ready for pickup'
);

-- ─── Dispatch ───────────────────────────────────────────────────────────────
select tap.as_user(tap.seed('operations'));

select tap.throws(
  format('select public.assign_rider(%L, %L)',
         tap.recall_uuid('order_id'), tap.seed('dp_suraj')),
  'RIDER_NOT_ACTIVE',
  'a partner still in onboarding cannot be dispatched'
);

select tap.no_throw(
  format('select public.assign_rider(%L, %L)',
         tap.recall_uuid('order_id'), tap.seed('dp_rahul')),
  'operations can dispatch an active rider'
);

select tap.reset();

select tap.eq(
  (select status::text from public.orders where id = tap.recall_uuid('order_id')),
  'RIDER_ASSIGNED',
  'the order moves to rider assigned'
);

select tap.remember('assignment_id', da.id::text)
from public.delivery_assignments da
where da.order_id = tap.recall_uuid('order_id')
  and da.status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER');

select tap.eq(
  (select status::text from public.delivery_assignments
    where id = tap.recall_uuid('assignment_id')),
  'ACCEPTED',
  'manual dispatch is authoritative, so the assignment starts accepted'
);

-- Migration 0029 added the payout trigger; the total must be the sum of its parts
-- rather than whatever the caller happened to pass in.
select tap.ok(
  (select total_payout = app.money_round(base_payout + distance_payout + surge_payout)
   from public.delivery_assignments
   where id = tap.recall_uuid('assignment_id')),
  'total payout equals base + distance + surge'
);

-- ─── The assigned rider drives their own delivery, holding no permissions ────
select tap.eq(
  (select count(*) from public.permissions p
    join public.role_permissions rp on rp.permission_id = p.id
    join public.roles r on r.id = rp.role_id
    where r.code = 'DELIVERY_PARTNER'),
  0::bigint,
  'the rider role holds no permissions at all'
);

select tap.as_user(tap.seed('rider_rahul'));

select tap.no_throw(
  format('select public.rider_arrived_at_store(%L)', tap.recall_uuid('assignment_id')),
  'the rider can report arriving at the outlet'
);

select tap.throws(
  format('select public.verify_pickup(%L, %L)', tap.recall_uuid('assignment_id'), '111111'),
  'PICKUP_CODE_INVALID',
  'a wrong pickup code is refused'
);

select tap.no_throw(
  format('select public.verify_pickup(%L, %L)', tap.recall_uuid('assignment_id'), '424242'),
  'the correct pickup code releases the order'
);

select tap.reset();

select tap.eq(
  (select status::text from public.orders where id = tap.recall_uuid('order_id')),
  'OUT_FOR_DELIVERY',
  'pickup moves the order straight to out for delivery'
);

-- Scoped to the code this suite planted; the seed carries its own.
select tap.eq(
  (select consumed_at is not null from public.verification_codes
    where purpose = 'PICKUP_CODE'
      and order_id = tap.recall_uuid('order_id')
      and salt = 'test-salt'),
  true,
  'the pickup code is consumed and cannot be replayed'
);

-- Pickup issues the customer's delivery OTP. Only its hash is stored, so the
-- suite substitutes a known value — the equivalent of the customer reading it.
select tap.eq(
  (select count(*) from public.verification_codes
    where purpose = 'DELIVERY_OTP'
      and order_id = tap.recall_uuid('order_id')
      and consumed_at is null
      and expires_at > now()),
  1::bigint,
  'pickup issues exactly one live delivery OTP'
);

update public.verification_codes
set code_hash = app.hash_code('4821', 'otp-salt'), salt = 'otp-salt'
where purpose = 'DELIVERY_OTP'
  and order_id = tap.recall_uuid('order_id')
  and consumed_at is null
  and expires_at > now();

-- ─── A rider cannot go offline holding somebody's dinner ────────────────────
select tap.as_user(tap.seed('rider_rahul'));

select tap.throws(
  'select public.set_duty_state(''OFFLINE'')',
  'ACTIVE_DELIVERIES_PENDING',
  'a rider cannot go offline mid-delivery'
);

select tap.no_throw(
  format('select public.rider_arrived_at_customer(%L)', tap.recall_uuid('assignment_id')),
  'the rider can report arriving at the customer'
);

-- ─── Delivery requires the customer's OTP ───────────────────────────────────
select tap.throws(
  format('select public.complete_delivery(%L)', tap.recall_uuid('assignment_id')),
  'DELIVERY_OTP_REQUIRED',
  'delivery cannot be completed without an OTP'
);

select tap.throws(
  format('select public.complete_delivery(%L, %L)', tap.recall_uuid('assignment_id'), '0000'),
  'DELIVERY_OTP_INVALID',
  'a wrong OTP is refused'
);

select tap.throws(
  format('select public.complete_delivery(%L, null, null, null, null, true)',
         tap.recall_uuid('assignment_id')),
  'OVERRIDE_NOT_PERMITTED',
  'a rider cannot grant themselves a manager override'
);

select tap.reset();

-- ─── One rider must not be able to finish another's delivery ────────────────
-- This is exactly what removing `delivery.complete` from the role protects.
select tap.as_user(tap.seed('rider_amit'));

select tap.throws(
  format('select public.complete_delivery(%L, %L)', tap.recall_uuid('assignment_id'), '4821'),
  'PERMISSION_DENIED',
  'another rider cannot complete this delivery'
);

select tap.reset();

-- ─── The real thing ─────────────────────────────────────────────────────────
select tap.as_user(tap.seed('rider_rahul'));

select tap.no_throw(
  format('select public.complete_delivery(%L, %L)', tap.recall_uuid('assignment_id'), '4821'),
  'the correct OTP completes the delivery'
);

select tap.reset();

select tap.eq(
  (select status::text from public.orders where id = tap.recall_uuid('order_id')),
  'DELIVERED',
  'the order is delivered'
);

select tap.eq(
  (select delivery_verification_method from public.orders
    where id = tap.recall_uuid('order_id')),
  'CUSTOMER_OTP',
  'the verification method is recorded'
);

select tap.eq(
  (select count(*) from public.delivery_earnings
    where assignment_id = tap.recall_uuid('assignment_id')
      and entry_type = 'DELIVERY_PAYOUT'),
  1::bigint,
  'exactly one payout is posted for the trip'
);

-- Completing twice must not pay twice.
select tap.as_user(tap.seed('rider_rahul'));

select tap.no_throw(
  format('select public.complete_delivery(%L, %L)', tap.recall_uuid('assignment_id'), '4821'),
  'completing an already-completed delivery is a no-op'
);

select tap.reset();

select tap.eq(
  (select count(*) from public.delivery_earnings
    where assignment_id = tap.recall_uuid('assignment_id')),
  1::bigint,
  'a repeated completion does not post a second payout'
);

select tap.eq(
  (select order_id from public.delivery_partner_locations
    where delivery_partner_id = tap.seed('dp_rahul')),
  null::uuid,
  'live tracking is detached once the delivery ends'
);

-- ─── Location publishing is scoped to riders ────────────────────────────────
select tap.as_user(tap.seed('customer_a'));

select tap.throws(
  'select public.publish_rider_location(25.46, 85.52)',
  'NOT_A_DELIVERY_PARTNER',
  'a customer cannot publish a rider position'
);

select tap.reset();

select tap.done('Delivery flow');

rollback;
