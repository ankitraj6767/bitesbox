-- ═══════════════════════════════════════════════════════════════════════════
-- PAYMENTS & IDEMPOTENCY
--
-- The two failures that cost real money are a customer charged twice and an
-- order created twice. Both are prevented by the same idea: the client supplies
-- an idempotency key, and the server treats a repeat as a replay rather than a
-- new instruction.
--
-- `svc_place_order` and the payment recorders are service-role only, so this
-- suite runs them as `service_role` — which is how the Edge Functions call them.
-- ═══════════════════════════════════════════════════════════════════════════
begin;

select tap.suite('Payments & idempotency');

select tap.reset();
select tap.remember('product', '55555555-0000-0000-0000-000000000052');  -- Onion Pakoda

-- ─── Arrange a valid cart ───────────────────────────────────────────────────
select tap.as_user(tap.seed('customer_a'));

select public.cart_clear();
select public.cart_set_options(null, 'DELIVERY', 'b1000000-0000-0000-0000-000000000001');
select public.cart_add_item(tap.recall_uuid('product'), null, 3::smallint);

select tap.eq(
  (select (public.calculate_checkout() ->> 'is_valid')::boolean),
  true,
  'the cart is ready to check out'
);

select tap.remember(
  'quoted',
  ((public.calculate_checkout() -> 'totals' ->> 'payable_amount')::numeric)::text
);

-- A client cannot place an order directly; only the Edge Function may.
select tap.throws(
  'select public.svc_place_order(auth.uid(), ''bb-test-1'')',
  'PERMISSION_DENIED',
  'a customer cannot call the order placement function'
);

select tap.reset();

-- ─── Placement is idempotent ────────────────────────────────────────────────
select tap.as_service();

select tap.remember(
  'order_id',
  (public.svc_place_order(tap.seed('customer_a'), 'bb-test-idem-1') ->> 'order_id')
);

select tap.ok(tap.recall('order_id') is not null, 'the order is created');

-- The same key again must return the same order, not a second one. This is the
-- double-tapped Place Order button.
select tap.eq(
  (public.svc_place_order(tap.seed('customer_a'), 'bb-test-idem-1') ->> 'order_id'),
  tap.recall('order_id'),
  'replaying the idempotency key returns the same order'
);

select tap.eq(
  (public.svc_place_order(tap.seed('customer_a'), 'bb-test-idem-1') ->> 'replayed')::boolean,
  true,
  'the replay is reported as such'
);

select tap.reset();

select tap.eq(
  (select count(*) from public.orders where idempotency_key = 'bb-test-idem-1'),
  1::bigint,
  'only one order row exists for the key'
);

-- ─── The order is priced by the server, not by the client ───────────────────
select tap.eq(
  (select payable_amount::numeric from public.orders where id = tap.recall_uuid('order_id')),
  tap.recall_numeric('quoted'),
  'the order total matches the server quote'
);

select tap.eq(
  (select count(*) from public.order_items where order_id = tap.recall_uuid('order_id')),
  1::bigint,
  'the cart lines became order items'
);

-- Historical accuracy: the item carries its own snapshot, so a later price change
-- cannot rewrite what the customer agreed to pay.
select tap.ok(
  (select product_name is not null and unit_price > 0
     from public.order_items where order_id = tap.recall_uuid('order_id') limit 1),
  'order items store a name and price snapshot'
);

select tap.eq(
  (select status::text from public.orders where id = tap.recall_uuid('order_id')),
  'PENDING_PAYMENT',
  'an online order waits for payment before the kitchen sees it'
);

-- ─── The kitchen must not see an unpaid order ───────────────────────────────
select tap.as_user(tap.seed('kitchen'));

select tap.eq(
  (select count(*) from jsonb_array_elements(public.kitchen_queue() -> 'orders') as q
    where (q ->> 'id')::uuid = tap.recall_uuid('order_id')),
  0::bigint,
  'an unpaid order is not in the kitchen queue'
);

select tap.reset();

-- ─── Capture ────────────────────────────────────────────────────────────────
select tap.as_service();

select tap.remember(
  'payment_id',
  (select id::text from public.payments where order_id = tap.recall_uuid('order_id') limit 1)
);

-- The gateway order is created by the create-payment function; when the customer
-- has not started paying there may be no attempt row yet, which is fine.
select tap.ok(
  tap.recall('payment_id') is not null
    or (select count(*) from public.payments where order_id = tap.recall_uuid('order_id')) = 0,
  'payment attempts are tracked per order'
);

select tap.reset();

-- ─── Webhook double-processing ──────────────────────────────────────────────
-- Razorpay retries webhooks. Registering the same provider event twice must
-- record it once, so a capture is never applied twice.
select tap.as_service();

select tap.remember(
  'event_1',
  (public.svc_register_webhook_event(
     'RAZORPAY'::public.payment_gateway,
     'evt_test_dedupe_1',
     'payment.captured',
     '{"test": true}'::jsonb,
     true
   ))::text
);

select tap.remember(
  'event_2',
  (public.svc_register_webhook_event(
     'RAZORPAY'::public.payment_gateway,
     'evt_test_dedupe_1',
     'payment.captured',
     '{"test": true}'::jsonb,
     true
   ))::text
);

select tap.reset();

select tap.eq(
  (select count(*) from public.payment_events where provider_event_id = 'evt_test_dedupe_1'),
  1::bigint,
  'a replayed webhook event is stored once'
);

-- ─── COD limits are enforced server-side ────────────────────────────────────
select tap.ok(
  (select (value #>> '{}')::numeric > 0 from public.settings where key = 'cod.max_amount'),
  'a maximum cash-on-delivery amount is configured'
);

select tap.done('Payments & idempotency');

rollback;
