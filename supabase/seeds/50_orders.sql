-- SEED 50 · DEMO ORDERS

-- Run as the service role so the seed can drive the real business functions.
select set_config('request.jwt.claims', '{"role":"service_role"}', false);

-- ═══════════════════════════════════════════════════════════════════════════
-- DEMO ORDERS
--
-- Built by driving the real functions: cart → app.place_order → payment capture
-- → kitchen → dispatch → OTP delivery → review. If any of that logic regresses,
-- `supabase db reset` fails here rather than in production.
-- ═══════════════════════════════════════════════════════════════════════════

-- Adds a line to a cart the same way cart_add_item does, but without needing an
-- authenticated session.
-- Simulates a verified Razorpay capture for an online order.
-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER 1 — Delivered, paid by UPI, reviewed. The full happy path.
-- ═══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cart uuid;
  v_result jsonb;
  v_order_id uuid;
  v_assignment jsonb;
  v_assignment_id uuid;
begin
  v_cart := app.seed_cart(
    '91000000-0000-0000-0000-000000000001',
    'b1000000-0000-0000-0000-000000000001',
    'DELIVERY', 'BIRYANI20'
  );

  perform app.seed_cart_item(v_cart, 'chicken-dum-biryani', 'Full (Serves 2)', 1::smallint,
    array['Bihari hot', 'Boondi raita'], 'Extra spicy please');
  perform app.seed_cart_item(v_cart, 'butter-naan', null, 2::smallint);
  perform app.seed_cart_item(v_cart, 'coca-cola', '600 ml', 1::smallint);

  v_result := app.place_order(
    '91000000-0000-0000-0000-000000000001',
    'seed-order-0001-idempotency-key',
    'ONLINE', v_cart
  );
  v_order_id := (v_result ->> 'order_id')::uuid;

  perform app.seed_capture_payment(v_order_id, 'UPI');

  perform app.transition_order(v_order_id, 'STORE_ACCEPTED', 'Accepted by kitchen', 'USER',
    '90000000-0000-0000-0000-000000000201');
  perform app.transition_order(v_order_id, 'PREPARING', null, 'USER',
    '90000000-0000-0000-0000-000000000201');
  perform app.transition_order(v_order_id, 'READY_FOR_PICKUP', null, 'USER',
    '90000000-0000-0000-0000-000000000201');

  v_assignment := public.assign_rider(v_order_id, 'a1000000-0000-0000-0000-000000000001', 'MANUAL');
  v_assignment_id := (v_assignment ->> 'assignment_id')::uuid;

  perform public.rider_arrived_at_store(v_assignment_id);

  perform public.verify_pickup(v_assignment_id, app.seed_recover_code(v_order_id, 'PICKUP_CODE'));

  perform app.transition_order(v_order_id, 'RIDER_ARRIVED_CUSTOMER', null, 'USER',
    '90000000-0000-0000-0000-000000000101');

  perform public.complete_delivery(
    v_assignment_id, app.seed_recover_code(v_order_id, 'DELIVERY_OTP'),
    null, 'delivery-proofs/seed-order-1.jpg', 'Handed over at the gate'
  );

  -- Backdate so the order looks like it happened yesterday evening.
  update public.orders
  set created_at = now() - interval '1 day' - interval '3 hours',
      placed_at = now() - interval '1 day' - interval '3 hours',
      accepted_at = now() - interval '1 day' - interval '2 hours 58 minutes',
      preparing_at = now() - interval '1 day' - interval '2 hours 56 minutes',
      ready_at = now() - interval '1 day' - interval '2 hours 34 minutes',
      assigned_at = now() - interval '1 day' - interval '2 hours 32 minutes',
      picked_up_at = now() - interval '1 day' - interval '2 hours 28 minutes',
      delivered_at = now() - interval '1 day' - interval '2 hours 12 minutes'
  where id = v_order_id;

  insert into public.reviews (
    order_id, user_id, branch_id, delivery_partner_id,
    food_rating, delivery_rating, overall_rating, comment, tags
  )
  values (
    v_order_id, '91000000-0000-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000001',
    5, 5, 5,
    'Best biryani in Bakhtiyarpur, hands down. Came piping hot and the raita was fresh. Rahul was very polite.',
    array['tasty', 'hot', 'well-packed', 'polite-rider']
  );

  insert into public.review_items (review_id, order_item_id, product_id, rating, comment)
  select r.id, oi.id, oi.product_id, 5, 'Perfectly cooked, meat was tender.'
  from public.reviews r
  join public.order_items oi on oi.order_id = r.order_id
  where r.order_id = v_order_id and oi.product_slug = 'chicken-dum-biryani';

  raise notice 'Seed order 1 (delivered + reviewed): %', v_result ->> 'order_number';
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER 2 — Out for delivery right now, live tracking data.
-- ═══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cart uuid;
  v_result jsonb;
  v_order_id uuid;
  v_assignment jsonb;
  v_assignment_id uuid;
begin
  v_cart := app.seed_cart(
    '91000000-0000-0000-0000-000000000002',
    'b1000000-0000-0000-0000-000000000002',
    'DELIVERY'
  );

  perform app.seed_cart_item(v_cart, 'champaran-handi-mutton', 'Half (Serves 2)', 1::smallint,
    array['Bihari hot', 'Extra gravy']);
  perform app.seed_cart_item(v_cart, 'tandoori-roti', null, 4::smallint);
  perform app.seed_cart_item(v_cart, 'sweet-lassi', 'Regular (300 ml)', 2::smallint);

  v_result := app.place_order(
    '91000000-0000-0000-0000-000000000002',
    'seed-order-0002-idempotency-key',
    'ONLINE', v_cart
  );
  v_order_id := (v_result ->> 'order_id')::uuid;

  perform app.seed_capture_payment(v_order_id, 'CARD');

  perform app.transition_order(v_order_id, 'STORE_ACCEPTED', null, 'USER', '90000000-0000-0000-0000-000000000202');
  perform app.transition_order(v_order_id, 'PREPARING', null, 'USER', '90000000-0000-0000-0000-000000000202');
  perform app.transition_order(v_order_id, 'READY_FOR_PICKUP', null, 'USER', '90000000-0000-0000-0000-000000000202');

  v_assignment := public.assign_rider(v_order_id, 'a1000000-0000-0000-0000-000000000002', 'MANUAL');
  v_assignment_id := (v_assignment ->> 'assignment_id')::uuid;

  perform public.rider_arrived_at_store(v_assignment_id);

  perform public.verify_pickup(v_assignment_id, app.seed_recover_code(v_order_id, 'PICKUP_CODE'));

  -- Rider is en route: a live position plus a short breadcrumb trail.
  update public.delivery_partner_locations
  set order_id = v_order_id,
      assignment_id = v_assignment_id,
      latitude = 25.4702000,
      longitude = 85.5276000,
      speed_kmph = 24,
      heading_degrees = 42,
      distance_to_destination_km = app.haversine_km(25.4702, 85.5276, 25.4761, 85.5299),
      eta_minutes = 4,
      is_moving = true,
      recorded_at = now() - interval '15 seconds',
      updated_at = now()
  where delivery_partner_id = 'a1000000-0000-0000-0000-000000000002';

  insert into public.delivery_location_events (
    delivery_partner_id, order_id, assignment_id, latitude, longitude, speed_kmph, recorded_at
  ) values
    ('a1000000-0000-0000-0000-000000000002', v_order_id, v_assignment_id, 25.4611, 85.5236, 0,  now() - interval '4 minutes'),
    ('a1000000-0000-0000-0000-000000000002', v_order_id, v_assignment_id, 25.4640, 85.5248, 18, now() - interval '3 minutes'),
    ('a1000000-0000-0000-0000-000000000002', v_order_id, v_assignment_id, 25.4668, 85.5259, 26, now() - interval '2 minutes'),
    ('a1000000-0000-0000-0000-000000000002', v_order_id, v_assignment_id, 25.4702, 85.5276, 24, now() - interval '15 seconds');

  raise notice 'Seed order 2 (out for delivery): %', v_result ->> 'order_number';
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER 3 — Sitting in the kitchen queue, waiting to be accepted (COD).
-- ═══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cart uuid;
  v_result jsonb;
begin
  v_cart := app.seed_cart(
    '91000000-0000-0000-0000-000000000003',
    'b1000000-0000-0000-0000-000000000003',
    'DELIVERY'
  );

  perform app.seed_cart_item(v_cart, 'chicken-tikka-roll', null, 2::smallint,
    array['Medium', 'Extra cheese'], 'No onion in one roll');
  perform app.seed_cart_item(v_cart, 'chicken-hakka-noodles', 'Regular', 1::smallint, array['Medium']);
  perform app.seed_cart_item(v_cart, 'coca-cola', '250 ml', 2::smallint);

  v_result := app.place_order(
    '91000000-0000-0000-0000-000000000003',
    'seed-order-0003-idempotency-key',
    'COD', v_cart
  );

  raise notice 'Seed order 3 (new, awaiting kitchen acceptance, COD): %', v_result ->> 'order_number';
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER 4 — Being prepared right now.
-- ═══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cart uuid;
  v_result jsonb;
  v_order_id uuid;
begin
  v_cart := app.seed_cart(
    '91000000-0000-0000-0000-000000000001',
    'b1000000-0000-0000-0000-000000000001',
    'DELIVERY'
  );

  perform app.seed_cart_item(v_cart, 'litti-chokha', '6 pieces', 1::smallint, array['Bihari hot']);
  perform app.seed_cart_item(v_cart, 'paneer-butter-masala', 'Half (Serves 2)', 1::smallint,
    array['Mild', 'Butter gravy']);
  perform app.seed_cart_item(v_cart, 'gulab-jamun', null, 1::smallint);

  v_result := app.place_order(
    '91000000-0000-0000-0000-000000000001',
    'seed-order-0004-idempotency-key',
    'ONLINE', v_cart
  );
  v_order_id := (v_result ->> 'order_id')::uuid;

  perform app.seed_capture_payment(v_order_id, 'UPI');
  perform app.transition_order(v_order_id, 'STORE_ACCEPTED', null, 'USER', '90000000-0000-0000-0000-000000000201');
  perform app.transition_order(v_order_id, 'PREPARING', null, 'USER', '90000000-0000-0000-0000-000000000201');

  raise notice 'Seed order 4 (preparing): %', v_result ->> 'order_number';
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER 5 — Ready for pickup, no rider assigned yet (raises a live-ops alert).
-- ═══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cart uuid;
  v_result jsonb;
  v_order_id uuid;
begin
  v_cart := app.seed_cart(
    '91000000-0000-0000-0000-000000000004',
    'b1000000-0000-0000-0000-000000000004',
    'DELIVERY'
  );

  perform app.seed_cart_item(v_cart, 'mutton-dum-biryani', 'Full (Serves 2)', 1::smallint,
    array['Medium', 'Boondi raita', 'Mirchi ka salan']);
  perform app.seed_cart_item(v_cart, 'chicken-seekh-kebab', null, 1::smallint, array['Bihari hot']);

  v_result := app.place_order(
    '91000000-0000-0000-0000-000000000004',
    'seed-order-0005-idempotency-key',
    'ONLINE', v_cart
  );
  v_order_id := (v_result ->> 'order_id')::uuid;

  perform app.seed_capture_payment(v_order_id, 'NETBANKING');
  perform app.transition_order(v_order_id, 'STORE_ACCEPTED', null, 'USER', '90000000-0000-0000-0000-000000000301');
  perform app.transition_order(v_order_id, 'PREPARING', null, 'USER', '90000000-0000-0000-0000-000000000301');
  perform app.transition_order(v_order_id, 'READY_FOR_PICKUP', null, 'USER', '90000000-0000-0000-0000-000000000301');

  -- Push the ready timestamp back so the "no rider available" alert fires.
  update public.orders
  set ready_at = now() - interval '9 minutes',
      promised_at = now() - interval '4 minutes'
  where id = v_order_id;

  raise notice 'Seed order 5 (ready, no rider — alert): %', v_result ->> 'order_number';
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER 6 — Self pickup, delivered last week.
-- ═══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cart uuid;
  v_result jsonb;
  v_order_id uuid;
begin
  v_cart := app.seed_cart('91000000-0000-0000-0000-000000000002', null, 'PICKUP', 'PICKUP10');

  perform app.seed_cart_item(v_cart, 'veg-thali-box', null, 2::smallint,
    array['Butter naan (2)']);

  v_result := app.place_order(
    '91000000-0000-0000-0000-000000000002',
    'seed-order-0006-idempotency-key',
    'ONLINE', v_cart
  );
  v_order_id := (v_result ->> 'order_id')::uuid;

  perform app.seed_capture_payment(v_order_id, 'UPI');
  perform app.transition_order(v_order_id, 'STORE_ACCEPTED', null, 'USER', '90000000-0000-0000-0000-000000000201');
  perform app.transition_order(v_order_id, 'PREPARING', null, 'USER', '90000000-0000-0000-0000-000000000201');
  perform app.transition_order(v_order_id, 'READY_FOR_PICKUP', null, 'USER', '90000000-0000-0000-0000-000000000201');
  perform app.transition_order(v_order_id, 'DELIVERED', 'Collected at the counter', 'USER',
    '90000000-0000-0000-0000-000000000201');
  perform app.transition_order(v_order_id, 'COMPLETED', null, 'SCHEDULER');

  update public.orders
  set created_at = now() - interval '6 days',
      placed_at = now() - interval '6 days',
      delivered_at = now() - interval '6 days' + interval '28 minutes',
      completed_at = now() - interval '6 days' + interval '6 hours'
  where id = v_order_id;

  raise notice 'Seed order 6 (self pickup, completed): %', v_result ->> 'order_number';
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER 7 — Store rejected + full refund, with a support ticket. Exercises the
-- refund workflow end to end.
-- ═══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cart uuid;
  v_result jsonb;
  v_order_id uuid;
  v_refund jsonb;
  v_ticket_id uuid;
begin
  v_cart := app.seed_cart(
    '91000000-0000-0000-0000-000000000003',
    'b1000000-0000-0000-0000-000000000003',
    'DELIVERY'
  );

  perform app.seed_cart_item(v_cart, 'mutton-curry', 'Full (Serves 4)', 1::smallint, array['Medium']);
  perform app.seed_cart_item(v_cart, 'laccha-paratha', null, 4::smallint);

  v_result := app.place_order(
    '91000000-0000-0000-0000-000000000003',
    'seed-order-0007-idempotency-key',
    'ONLINE', v_cart
  );
  v_order_id := (v_result ->> 'order_id')::uuid;

  perform app.seed_capture_payment(v_order_id, 'UPI');

  perform app.transition_order(
    v_order_id, 'STORE_REJECTED', 'Mutton sold out for the evening', 'USER',
    '90000000-0000-0000-0000-000000000301',
    jsonb_build_object('reason', 'ITEM_UNAVAILABLE'), false, 'STORE', 'ITEM_UNAVAILABLE'
  );

  v_refund := public.request_refund(
    v_order_id, 'FULL_REFUND', 'RESTAURANT_CANCELLED', null,
    'ORIGINAL_PAYMENT_METHOD', 'Mutton unavailable — full refund raised automatically',
    '[]'::jsonb, 'seed-refund-0007'
  );

  perform app.complete_refund(
    (v_refund ->> 'refund_id')::uuid, null,
    'rfnd_seed0007', 'processed'
  );

  insert into public.support_tickets (
    ticket_number, user_id, order_id, branch_id, category, subject, description,
    status, priority, assigned_to, first_response_due_at, first_response_at,
    resolved_at, resolved_by, resolution_note
  )
  values (
    'BB-T000001', '91000000-0000-0000-0000-000000000003', v_order_id,
    '11111111-1111-1111-1111-111111111111', 'CANCELLATION',
    'Order rejected — where is my refund?',
    'My order was rejected by the restaurant. I want to know when I get my money back.',
    'RESOLVED', 'HIGH', '90000000-0000-0000-0000-000000000005',
    now() - interval '5 days', now() - interval '5 days' + interval '11 minutes',
    now() - interval '5 days' + interval '25 minutes', '90000000-0000-0000-0000-000000000005',
    'Full refund processed to the original payment method. Customer informed.'
  )
  returning id into v_ticket_id;

  insert into public.support_messages (ticket_id, author_kind, author_id, body, is_internal, created_at) values
    (v_ticket_id, 'CUSTOMER', '91000000-0000-0000-0000-000000000003',
     'My order was rejected by the restaurant. I want to know when I get my money back.',
     false, now() - interval '5 days'),
    (v_ticket_id, 'AGENT', '90000000-0000-0000-0000-000000000005',
     'Hello Vivaan, apologies for this. The mutton ran out for the evening. Your full refund of the order value has already been raised and will reach your account in 3–5 working days.',
     false, now() - interval '5 days' + interval '11 minutes'),
    (v_ticket_id, 'AGENT', '90000000-0000-0000-0000-000000000005',
     'Refund confirmed in the gateway dashboard. Closing the ticket.',
     true, now() - interval '5 days' + interval '24 minutes'),
    (v_ticket_id, 'CUSTOMER', '91000000-0000-0000-0000-000000000003',
     'Thank you, received. Please keep mutton stocked next time!',
     false, now() - interval '5 days' + interval '40 minutes');

  update public.support_tickets set refund_id = (v_refund ->> 'refund_id')::uuid where id = v_ticket_id;

  update public.orders
  set created_at = now() - interval '5 days',
      placed_at = now() - interval '5 days'
  where id = v_order_id;

  raise notice 'Seed order 7 (rejected + refunded): %', v_result ->> 'order_number';
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER 8 — Customer cancelled inside the grace period.
-- ═══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cart uuid;
  v_result jsonb;
  v_order_id uuid;
begin
  v_cart := app.seed_cart(
    '91000000-0000-0000-0000-000000000004',
    'b1000000-0000-0000-0000-000000000004',
    'DELIVERY'
  );

  perform app.seed_cart_item(v_cart, 'veg-fried-rice', 'Regular', 1::smallint, array['Mild']);
  perform app.seed_cart_item(v_cart, 'veg-manchurian', 'Gravy', 1::smallint, array['Medium']);
  perform app.seed_cart_item(v_cart, 'onion-pakoda', null, 1::smallint);

  v_result := app.place_order(
    '91000000-0000-0000-0000-000000000004',
    'seed-order-0008-idempotency-key',
    'ONLINE', v_cart
  );
  v_order_id := (v_result ->> 'order_id')::uuid;

  perform app.seed_capture_payment(v_order_id, 'UPI');

  perform app.transition_order(
    v_order_id, 'CUSTOMER_CANCELLED', 'Ordered by mistake', 'USER',
    '91000000-0000-0000-0000-000000000004',
    jsonb_build_object('reason', 'ORDERED_BY_MISTAKE'), false, 'CUSTOMER', 'ORDERED_BY_MISTAKE'
  );

  update public.orders
  set created_at = now() - interval '3 days',
      placed_at = now() - interval '3 days'
  where id = v_order_id;

  raise notice 'Seed order 8 (customer cancelled): %', v_result ->> 'order_number';
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER 9 — Delivered with a partial item refund (missing item complaint).
-- ═══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cart uuid;
  v_result jsonb;
  v_order_id uuid;
  v_assignment jsonb;
  v_assignment_id uuid;
  v_item_id uuid;
  v_refund jsonb;
  v_ticket_id uuid;
begin
  v_cart := app.seed_cart(
    '91000000-0000-0000-0000-000000000002',
    'b1000000-0000-0000-0000-000000000005',
    'DELIVERY'
  );

  perform app.seed_cart_item(v_cart, 'butter-chicken', 'Half (Serves 2)', 1::smallint,
    array['Mild', 'Butter naan']);
  perform app.seed_cart_item(v_cart, 'dal-tadka', 'Half (Serves 2)', 1::smallint, array['Mild']);
  perform app.seed_cart_item(v_cart, 'gulab-jamun', null, 2::smallint);

  v_result := app.place_order(
    '91000000-0000-0000-0000-000000000002',
    'seed-order-0009-idempotency-key',
    'ONLINE', v_cart
  );
  v_order_id := (v_result ->> 'order_id')::uuid;

  perform app.seed_capture_payment(v_order_id, 'UPI');
  perform app.transition_order(v_order_id, 'STORE_ACCEPTED', null, 'USER', '90000000-0000-0000-0000-000000000201');
  perform app.transition_order(v_order_id, 'PREPARING', null, 'USER', '90000000-0000-0000-0000-000000000201');
  perform app.transition_order(v_order_id, 'READY_FOR_PICKUP', null, 'USER', '90000000-0000-0000-0000-000000000201');

  v_assignment := public.assign_rider(v_order_id, 'a1000000-0000-0000-0000-000000000003', 'MANUAL');
  v_assignment_id := (v_assignment ->> 'assignment_id')::uuid;

  perform public.rider_arrived_at_store(v_assignment_id);
  perform public.verify_pickup(v_assignment_id, app.seed_recover_code(v_order_id, 'PICKUP_CODE'));

  -- Manager override path: the customer's phone was unreachable for the OTP.
  perform public.complete_delivery(
    v_assignment_id, null, null, null,
    'Customer phone unreachable — completed with manager approval', true
  );

  -- Customer reports the dessert was missing. Inserted directly because
  -- create_support_ticket() derives the author from auth.uid(), which the seed
  -- session does not have.
  insert into public.support_tickets (
    ticket_number, user_id, order_id, branch_id, category, subject, description,
    status, priority, assigned_to, first_response_due_at, first_response_at
  )
  values (
    'BB-T000003', '91000000-0000-0000-0000-000000000002', v_order_id,
    '11111111-1111-1111-1111-111111111111', 'MISSING_ITEM',
    'Gulab jamun missing from my order',
    'The gulab jamun I ordered was not in the bag. Everything else arrived fine.',
    'IN_PROGRESS', 'HIGH', '90000000-0000-0000-0000-000000000005',
    now() - interval '2 days' + interval '45 minutes',
    now() - interval '2 days' + interval '52 minutes'
  )
  returning id into v_ticket_id;

  insert into public.support_messages (ticket_id, author_kind, author_id, body, created_at)
  values (
    v_ticket_id, 'CUSTOMER', '91000000-0000-0000-0000-000000000002',
    'The gulab jamun I ordered was not in the bag. Everything else arrived fine.',
    now() - interval '2 days' + interval '45 minutes'
  );

  select id into v_item_id from public.order_items
  where order_id = v_order_id and product_slug = 'gulab-jamun';

  v_refund := public.request_refund(
    v_order_id, 'ITEM_REFUND', 'MISSING_ITEM', null, 'WALLET_CREDIT',
    'Gulab jamun missing — refunded to wallet as store credit',
    jsonb_build_array(jsonb_build_object('order_item_id', v_item_id, 'quantity', 2)),
    'seed-refund-0009', v_ticket_id
  );

  perform app.complete_refund((v_refund ->> 'refund_id')::uuid);

  update public.support_tickets
  set status = 'RESOLVED', resolved_at = now(), resolved_by = '90000000-0000-0000-0000-000000000005',
      resolution_note = 'Missing dessert refunded to wallet immediately.',
      refund_id = (v_refund ->> 'refund_id')::uuid,
      assigned_to = '90000000-0000-0000-0000-000000000005',
      satisfaction_rating = 4
  where id = v_ticket_id;

  insert into public.support_messages (ticket_id, author_kind, author_id, body, is_internal)
  values (
    v_ticket_id, 'AGENT', '90000000-0000-0000-0000-000000000005',
    'Sorry about that, Diya. We have credited the full value of the gulab jamun to your Bites Box wallet — it is available immediately.',
    false
  );

  insert into public.reviews (
    order_id, user_id, branch_id, delivery_partner_id,
    food_rating, delivery_rating, overall_rating, comment, tags
  )
  values (
    v_order_id, '91000000-0000-0000-0000-000000000002',
    '11111111-1111-1111-1111-111111111111', 'a1000000-0000-0000-0000-000000000003',
    4, 3, 4,
    'Butter chicken was excellent. Dessert was missing but support sorted it out within minutes.',
    array['tasty', 'missing-item', 'good-support']
  );

  update public.orders
  set created_at = now() - interval '2 days',
      placed_at = now() - interval '2 days',
      delivered_at = now() - interval '2 days' + interval '34 minutes'
  where id = v_order_id;

  raise notice 'Seed order 9 (delivered, item refund to wallet): %', v_result ->> 'order_number';
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER 10 — Awaiting payment (unpaid). Exercises the expiry job and the
-- "resume payment" path in the app.
-- ═══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cart uuid;
  v_result jsonb;
begin
  v_cart := app.seed_cart(
    '91000000-0000-0000-0000-000000000001',
    'b1000000-0000-0000-0000-000000000001',
    'DELIVERY'
  );

  perform app.seed_cart_item(v_cart, 'solo-biryani-combo', null, 1::smallint,
    array['Coca-Cola 250ml']);

  v_result := app.place_order(
    '91000000-0000-0000-0000-000000000001',
    'seed-order-0010-idempotency-key',
    'ONLINE', v_cart
  );

  raise notice 'Seed order 10 (pending payment): %', v_result ->> 'order_number';
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- LIVE CART — Kabir has items waiting, at a non-serviceable address. Lets the
-- app demonstrate the ADDRESS_NOT_SERVICEABLE experience immediately.
-- ═══════════════════════════════════════════════════════════════════════════
do $$
declare
  v_cart uuid;
begin
  v_cart := app.seed_cart(
    '91000000-0000-0000-0000-000000000005',
    'b1000000-0000-0000-0000-000000000006',
    'DELIVERY'
  );

  perform app.seed_cart_item(v_cart, 'chicken-dum-biryani', 'Half (Serves 1)', 1::smallint,
    array['Medium']);
  perform app.seed_cart_item(v_cart, 'butter-naan', null, 2::smallint);
end;
$$;
