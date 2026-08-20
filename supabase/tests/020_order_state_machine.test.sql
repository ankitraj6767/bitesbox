-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER STATE MACHINE
--
-- The state machine is data (`order_status_transitions`), not code, so what is
-- tested here is that the data is enforced: an edge that does not exist cannot be
-- travelled, and an actor without the right relationship to the order cannot
-- travel one that does.
-- ═══════════════════════════════════════════════════════════════════════════
begin;

select tap.suite('Order state machine');

select tap.reset();

select tap.remember('placed',    tap.seed_order(3)::text);   -- ORDER_PLACED, COD
select tap.remember('preparing', tap.seed_order(4)::text);   -- PREPARING
select tap.remember('delivered', tap.seed_order(1)::text);   -- DELIVERED
select tap.remember('unpaid',    tap.seed_order(10)::text);  -- PENDING_PAYMENT

-- ─── The graph is complete and consistent ───────────────────────────────────
select tap.ok(
  (select count(*) from public.order_status_transitions) > 30,
  'the transition table is populated'
);

-- Every edge a customer may travel to cancel is gated by order.cancel, so the
-- cancellation policy is the single place that decides whether they can.
select tap.eq(
  (select count(*) from public.order_status_transitions
    where customer_allowed
      and to_status::text like '%CANCELLED%'
      and coalesce(required_permission, '') <> 'order.cancel'),
  0::bigint,
  'every customer cancellation edge requires order.cancel'
);

-- An edge with no permission is system-only: app.transition_order checks that
-- branch before it checks customer_allowed, so these need order.override.
select tap.ok(
  (select count(*) from public.order_status_transitions
    where required_permission is null) > 0,
  'the graph has system-only edges'
);

-- A terminal order must not be able to re-enter the live flow.
select tap.eq(
  (select count(*) from public.order_status_transitions
    where from_status in ('DELIVERED', 'COMPLETED', 'REFUNDED')
      and to_status in ('PREPARING', 'READY_FOR_PICKUP', 'OUT_FOR_DELIVERY')),
  0::bigint,
  'a finished order cannot go back into the kitchen'
);

-- ─── Kitchen acceptance ─────────────────────────────────────────────────────
select tap.as_user(tap.seed('kitchen'));

select tap.throws(
  format('select public.start_preparing(%L)', tap.recall_uuid('placed')),
  'INVALID_ORDER_TRANSITION',
  'an order cannot start preparing before it is accepted'
);

select tap.no_throw(
  format('select public.accept_order(%L, 25)', tap.recall_uuid('placed')),
  'kitchen staff can accept a placed order'
);

select tap.reset();

select tap.eq(
  (select status::text from public.orders where id = tap.recall_uuid('placed')),
  'STORE_ACCEPTED',
  'the order is accepted'
);

select tap.eq(
  (select count(*) from public.order_status_history
    where order_id = tap.recall_uuid('placed') and to_status = 'STORE_ACCEPTED'),
  1::bigint,
  'the acceptance is recorded in the timeline'
);

-- Accepting twice is a no-op, not an error: a kitchen tablet double-tap on a
-- flaky connection must not produce a failure the staff have to reason about.
select tap.as_user(tap.seed('kitchen'));

select tap.no_throw(
  format('select public.accept_order(%L, 25)', tap.recall_uuid('placed')),
  'accepting an already-accepted order is idempotent'
);

select tap.no_throw(
  format('select public.start_preparing(%L)', tap.recall_uuid('placed')),
  'kitchen staff can start preparing'
);

select tap.no_throw(
  format('select public.mark_order_ready(%L)', tap.recall_uuid('placed')),
  'kitchen staff can mark it ready'
);

select tap.reset();

select tap.eq(
  (select status::text from public.orders where id = tap.recall_uuid('placed')),
  'READY_FOR_PICKUP',
  'the order reaches ready for pickup'
);

select tap.eq(
  (select ready_at is not null from public.orders where id = tap.recall_uuid('placed')),
  true,
  'the ready timestamp is stamped'
);

-- ─── A customer cannot drive the kitchen ────────────────────────────────────
select tap.as_user(tap.seed('customer_c'));

select tap.throws(
  format('select public.accept_order(%L, 20)', tap.recall_uuid('unpaid')),
  'PERMISSION_DENIED',
  'a customer cannot accept their own order'
);

select tap.throws(
  format('select public.mark_order_ready(%L)', tap.recall_uuid('preparing')),
  'PERMISSION_DENIED',
  'a customer cannot mark their food ready'
);

select tap.reset();

-- ─── Cancellation follows the configured policy ─────────────────────────────
select tap.as_user(tap.seed('customer_c'));

select tap.no_throw(
  format('select public.cancellation_options(%L)', tap.recall_uuid('placed')),
  'a customer can ask whether they may cancel'
);

select tap.throws(
  format('select public.cancel_order(%L)', tap.recall_uuid('delivered')),
  'PERMISSION_DENIED',
  'a customer cannot cancel an order that is not theirs'
);

select tap.reset();

select tap.as_user(tap.seed('customer_a'));

select tap.throws(
  format('select public.cancel_order(%L)', tap.recall_uuid('delivered')),
  'CANCELLATION_NOT_ALLOWED',
  'a delivered order cannot be cancelled'
);

select tap.reset();

-- ─── Nobody edits status directly ───────────────────────────────────────────
-- `bitesbox.transition_ok` is lifted only inside app.transition_order, so even a
-- staff member with table privileges cannot move an order by hand.
select tap.as_user(tap.seed('manager'));

select tap.throws(
  format('update public.orders set status = ''DELIVERED'' where id = %L',
         tap.recall_uuid('placed')),
  'PERMISSION_DENIED',
  'status cannot be changed with a direct update'
);

select tap.reset();

select tap.eq(
  (select status::text from public.orders where id = tap.recall_uuid('placed')),
  'READY_FOR_PICKUP',
  'the order status is unchanged after the attempt'
);

select tap.done('Order state machine');

rollback;
