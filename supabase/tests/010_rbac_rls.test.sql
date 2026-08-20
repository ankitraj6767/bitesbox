-- ═══════════════════════════════════════════════════════════════════════════
-- RBAC & ROW LEVEL SECURITY
--
-- The single most important property of this schema: a client can hold whatever
-- opinion it likes about who it is, and the database decides what it sees.
--
-- Every assertion here runs as a real API role (`anon` / `authenticated`) with a
-- JWT claim, not as the migration owner — testing RLS as a superuser proves
-- nothing, because the owner bypasses it.
-- ═══════════════════════════════════════════════════════════════════════════
begin;

select tap.suite('RBAC & RLS');

-- ─── Guests ─────────────────────────────────────────────────────────────────
select tap.as_anon();

select tap.ok(
  tap.visible_count('select 1 from public.products where is_active') > 0,
  'a guest can browse the menu'
);

select tap.eq(
  tap.visible_count('select 1 from public.orders'),
  0::bigint,
  'a guest sees no orders'
);

select tap.eq(
  tap.visible_count('select 1 from public.profiles'),
  0::bigint,
  'a guest sees no customer profiles'
);

select tap.throws(
  'select public.my_orders()',
  'PERMISSION_DENIED',
  'my_orders is not callable by a guest'
);

select tap.reset();

-- ─── Customers see only their own rows ──────────────────────────────────────
select tap.as_user(tap.seed('customer_a'));

select tap.ok(
  tap.visible_count('select 1 from public.orders') > 0,
  'a customer sees their own orders'
);

select tap.eq(
  (select count(*) from public.orders o
    where o.user_id <> tap.seed('customer_a')),
  0::bigint,
  'a customer sees no one else''s orders'
);

select tap.eq(
  (select count(*) from public.addresses a
    where a.user_id <> tap.seed('customer_a')),
  0::bigint,
  'a customer sees no one else''s addresses'
);

select tap.eq(
  (select count(*) from public.profiles p
    where p.id <> tap.seed('customer_a')),
  0::bigint,
  'a customer sees only their own profile'
);

select tap.eq(
  tap.visible_count('select 1 from public.audit_logs'),
  0::bigint,
  'a customer cannot read the audit log'
);

select tap.eq(
  tap.visible_count('select 1 from public.verification_codes'),
  0::bigint,
  'nobody reads OTP hashes — not even their own'
);

-- Financial tables are read-only to clients; all writes go through functions.
select tap.throws(
  'update public.orders set grand_total = 1 where user_id = auth.uid()',
  'PERMISSION_DENIED',
  'a customer cannot rewrite their order total'
);

select tap.throws(
  'insert into public.payments (order_id, branch_id, user_id, amount, mode, status)
   select o.id, o.branch_id, o.user_id, 1, ''ONLINE'', ''CAPTURED''
   from public.orders o where o.user_id = auth.uid() limit 1',
  'PERMISSION_DENIED',
  'a customer cannot invent a payment'
);

-- The gap that mattered: available_riders was SECURITY DEFINER, granted to
-- authenticated, and had no permission check. Any customer could list the roster.
select tap.throws(
  'select * from public.available_riders()',
  'PERMISSION_DENIED',
  'a customer cannot list delivery partners'
);

select tap.throws(
  'select public.live_operations()',
  'PERMISSION_DENIED',
  'a customer cannot open the operations board'
);

select tap.throws(
  'select public.kitchen_queue()',
  'PERMISSION_DENIED',
  'a customer cannot read the kitchen queue'
);

select tap.throws(
  'select public.dashboard_overview()',
  'PERMISSION_DENIED',
  'a customer cannot read revenue figures'
);

select tap.reset();

-- ─── One customer cannot reach another ──────────────────────────────────────
select tap.as_user(tap.seed('customer_b'));

select tap.throws(
  format(
    'select public.order_detail(%L)',
    (select o.id from public.orders o
      where o.user_id = tap.seed('customer_a') limit 1)
  ),
  'ORDER_NOT_FOUND',
  'a customer cannot open another customer''s order'
);

select tap.reset();

-- ─── Riders see the delivery they are carrying, and nothing more ────────────
select tap.as_user(tap.seed('rider_rahul'));

select tap.no_throw(
  'select public.my_deliveries()',
  'a rider can read their own assignment list'
);

select tap.eq(
  (select count(*) from public.delivery_assignments da
    where da.delivery_partner_id <> (
      select dp.id from public.delivery_partners dp
      where dp.user_id = tap.seed('rider_rahul')
    )),
  0::bigint,
  'a rider sees no one else''s assignments'
);

select tap.throws(
  'select public.kitchen_availability()',
  'PERMISSION_DENIED',
  'a rider cannot change what is on the menu'
);

select tap.throws(
  'select public.admin_customers()',
  'PERMISSION_DENIED',
  'a rider cannot browse the customer list'
);

select tap.reset();

-- ─── Kitchen staff ──────────────────────────────────────────────────────────
select tap.as_user(tap.seed('kitchen'));

select tap.no_throw(
  'select public.kitchen_queue()',
  'kitchen staff can read the queue'
);

select tap.no_throw(
  'select public.kitchen_availability()',
  'kitchen staff can read availability'
);

select tap.throws(
  'select public.report_sales()',
  'PERMISSION_DENIED',
  'kitchen staff cannot export the sales register'
);

select tap.throws(
  'select public.admin_refund_queue()',
  'PERMISSION_DENIED',
  'kitchen staff cannot approve refunds'
);

select tap.reset();

-- ─── Support ────────────────────────────────────────────────────────────────
select tap.as_user(tap.seed('support'));

select tap.no_throw(
  'select public.admin_support_inbox()',
  'support can open the ticket inbox'
);

select tap.throws(
  'select public.manage_user_role(auth.uid(), ''OWNER'', true)',
  'PERMISSION_DENIED',
  'support cannot grant itself ownership'
);

select tap.reset();

-- ─── Owner ──────────────────────────────────────────────────────────────────
select tap.as_user(tap.seed('owner'));

select tap.no_throw('select public.dashboard_overview()', 'the owner sees the dashboard');
select tap.no_throw('select * from public.available_riders()', 'the owner can list riders');
select tap.no_throw('select public.audit_trail()', 'the owner can read the audit trail');

-- ─── Role management, and the rank guard ────────────────────────────────────
--
-- Migration 0035 made `manage_user_role` SECURITY DEFINER, because as an
-- invoker-rights function it could not name the `app` schema and therefore threw
-- on every call — role management was entirely broken.
--
-- The worry with that change is the escalation guard. It survives, because the
-- guard is `app.tg_guard_role_assignment`, a SECURITY DEFINER *trigger* that fires
-- on the write and reads `auth.uid()`. These assertions prove that rather than
-- assuming it.
select tap.no_throw(
  format('select public.manage_user_role(%L, ''SUPPORT'', true)', tap.seed('customer_e')),
  'an owner can grant a role below their own'
);

select tap.throws(
  format('select public.manage_user_role(%L, ''OWNER'', true)', tap.seed('customer_e')),
  'PRIVILEGE_ESCALATION_BLOCKED',
  'not even an owner can mint another owner'
);

select tap.throws(
  'select public.manage_user_role(auth.uid(), ''SUPPORT'', true)',
  'VALIDATION_FAILED',
  'nobody edits their own roles'
);

select tap.reset();

-- A manager holds no role.assign at all, so they are stopped one step earlier.
select tap.as_user(tap.seed('manager'));

select tap.throws(
  format('select public.manage_user_role(%L, ''ADMIN'', true)', tap.seed('customer_e')),
  'PERMISSION_DENIED',
  'a manager cannot assign roles'
);

select tap.reset();

select tap.as_user(tap.seed('customer_a'));

select tap.throws(
  format('select public.manage_user_role(%L, ''SUPPORT'', true)', tap.seed('customer_e')),
  'PERMISSION_DENIED',
  'a customer cannot assign roles'
);

-- The client-facing permission check must report on the caller, not on the owner
-- the definer function runs as.
select tap.eq(
  (select public.has_permission('order.accept')),
  false,
  'has_permission answers about the caller, not the function owner'
);

select tap.reset();

select tap.as_user(tap.seed('kitchen'));

select tap.eq(
  (select public.has_permission('order.accept')),
  true,
  'kitchen staff do hold order.accept'
);

select tap.eq(
  (select public.has_permission('role.assign')),
  false,
  'and do not hold role.assign'
);

select tap.reset();

select tap.as_user(tap.seed('owner'));

select tap.ok(
  tap.visible_count('select 1 from public.orders') >= 10,
  'the owner sees every order'
);

select tap.reset();

-- ─── The service role key must never reach a client ─────────────────────────
select tap.as_user(tap.seed('customer_a'));

select tap.throws(
  'select public.svc_place_order(auth.uid(), ''test-key'')',
  'PERMISSION_DENIED',
  'a client cannot call a service-only function'
);

select tap.throws(
  'select public.run_scheduled_jobs()',
  'PERMISSION_DENIED',
  'a client cannot drive the job scheduler'
);

select tap.reset();

select tap.done('RBAC & RLS');

rollback;
