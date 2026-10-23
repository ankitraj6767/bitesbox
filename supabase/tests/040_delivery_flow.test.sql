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
select tap.eq(
  (select location_sharing_enabled from public.delivery_assignments
    where id = tap.recall_uuid('assignment_id')),
  false,
  'new assignments start with location sharing disabled'
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

select tap.throws(
  'select public.publish_rider_location(25.461, 85.523)',
  'LOCATION_CAPTURE_TIME_REQUIRED',
  'legacy location clients cannot publish without an OS capture timestamp'
);

select tap.no_throw(
  format('select public.set_delivery_location_sharing(%L, true)', tap.recall_uuid('assignment_id')),
  'the assigned rider explicitly enables delivery-scoped sharing'
);

select tap.throws(
  format(
    'insert into public.delivery_partner_locations (delivery_partner_id, order_id, assignment_id, latitude, longitude) values (%L, %L, %L, 25.461, 85.523)',
    tap.seed('dp_rahul'), tap.recall_uuid('order_id'), tap.recall_uuid('assignment_id')
  ),
  'PERMISSION_DENIED',
  'direct location inserts cannot bypass capture-time and consent checks'
);
select tap.throws(
  format(
    'update public.delivery_partner_locations set latitude = 25.462, recorded_at = now() where delivery_partner_id = %L',
    tap.seed('dp_rahul')
  ),
  'PERMISSION_DENIED',
  'direct location updates cannot bypass capture-time and consent checks'
);
select tap.throws(
  format(
    'insert into public.delivery_location_events (delivery_partner_id, order_id, assignment_id, latitude, longitude) values (%L, %L, %L, 25.461, 85.523)',
    tap.seed('dp_rahul'), tap.recall_uuid('order_id'), tap.recall_uuid('assignment_id')
  ),
  'PERMISSION_DENIED',
  'riders cannot inject unsampled location history'
);
select tap.throws(
  format(
    'insert into public.delivery_partner_availability (delivery_partner_id, duty_state, latitude, longitude) values (%L, ''AVAILABLE'', 25.461, 85.523)',
    tap.seed('dp_rahul')
  ),
  'PERMISSION_DENIED',
  'duty-state changes cannot write off-duty coordinates directly'
);

select tap.remember('location_fix_at', clock_timestamp()::text);

select tap.no_throw(
  format(
    'select public.publish_rider_location_v2(25.461, 85.523, %L::timestamptz)',
    tap.recall('location_fix_at')
  ),
  'the server accepts a fresh OS capture timestamp'
);

select tap.throws(
  format(
    'select public.publish_rider_location_v2(25.461, 85.523, %L::timestamptz)',
    tap.recall('location_fix_at')
  ),
  'LOCATION_FIX_OUT_OF_ORDER',
  'a duplicate or out-of-order fix is rejected'
);

select tap.throws(
  'select public.publish_rider_location_v2(25.461, 85.523, now() - interval ''3 minutes'')',
  'LOCATION_CAPTURE_TIME_INVALID',
  'a stale capture timestamp is rejected'
);

select tap.reset();
select tap.as_user(tap.seed('rider_amit'));
select tap.eq(
  (select public.publish_rider_location_v2(25.461, 85.523, clock_timestamp()) ->> 'should_keep_publishing'),
  'false',
  'a different rider cannot publish against the active assignment'
);
select tap.reset();

-- Reassignment revokes consent and detaches the old rider's current point.
select tap.as_service();
update public.delivery_assignments
set delivery_partner_id = tap.seed('dp_amit')
where id = tap.recall_uuid('assignment_id');
select tap.eq(
  (select location_sharing_enabled from public.delivery_assignments where id = tap.recall_uuid('assignment_id')),
  false,
  'reassignment clears location consent'
);
select tap.eq(
  (select assignment_id from public.delivery_partner_locations where delivery_partner_id = tap.seed('dp_rahul')),
  null::uuid,
  'reassignment removes the former rider current point'
);
update public.delivery_assignments
set delivery_partner_id = tap.seed('dp_rahul')
where id = tap.recall_uuid('assignment_id');
select tap.reset();

select tap.as_user(tap.seed('rider_rahul'));
select tap.no_throw(
  format('select public.set_delivery_location_sharing(%L, true)', tap.recall_uuid('assignment_id')),
  'the reassigned rider must explicitly enable sharing again'
);
select tap.no_throw(
  'select public.stop_my_delivery_location_sharing()',
  'sign-out can revoke active location consent'
);
select tap.eq(
  (select location_sharing_enabled from public.delivery_assignments where id = tap.recall_uuid('assignment_id')),
  false,
  'sign-out stops sharing on the server'
);
select tap.no_throw(
  format('select public.set_delivery_location_sharing(%L, true)', tap.recall_uuid('assignment_id')),
  'a rider can explicitly resume after signing back in'
);

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
select tap.eq(
  (select assignment_id from public.delivery_partner_locations
    where delivery_partner_id = tap.seed('dp_rahul')),
  null::uuid,
  'the customer-visible location no longer references a terminal assignment'
);
select tap.eq(
  (select location_sharing_enabled from public.delivery_assignments
    where id = tap.recall_uuid('assignment_id')),
  false,
  'completion revokes server-side location consent'
);
select tap.as_user(tap.seed('rider_rahul'));
select tap.eq(
  (select public.publish_rider_location_v2(25.461, 85.523, clock_timestamp()) ->> 'should_keep_publishing'),
  'false',
  'terminal assignments cannot resume location publishing'
);
select tap.reset();

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
