-- SEED 90 · OPERATIONAL TEXTURE & CLEANUP

-- Run as the service role so the seed can drive the real business functions.
select set_config('request.jwt.claims', '{"role":"service_role"}', false);

-- ═══════════════════════════════════════════════════════════════════════════
-- SEQUENCE ALIGNMENT
--
-- The seed writes some rows with literal human-readable numbers rather than
-- through the function that allocates them. Any sequence behind such a column has
-- to be moved past the seeded values, or the first row a real user creates
-- collides on the unique index.
--
-- This bit the support inbox: seeded tickets ran to BB-T000003 while
-- `ticket_number_seq` was still at 1, so the first customer to ask for help hit
-- "duplicate key value violates unique constraint support_tickets_number_key".
--
-- Derived from the data rather than hard-coded, so adding seed rows cannot
-- reintroduce it.
-- ═══════════════════════════════════════════════════════════════════════════
select setval(
  'public.ticket_number_seq',
  greatest(
    coalesce(
      (
        select max(substring(ticket_number from 'T0*([0-9]+)$')::bigint)
        from public.support_tickets
        where ticket_number ~ 'T0*[0-9]+$'
      ),
      0
    ),
    1
  )
);

-- Orders already allocate through the sequence, so this only guards against a
-- future seed that writes an order number by hand.
select setval(
  'public.order_number_seq',
  greatest(
    (select last_value from public.order_number_seq),
    coalesce((select count(*) from public.orders), 0)
  )
);

-- ═══════════════════════════════════════════════════════════════════════════
-- OPERATIONAL TEXTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- One item out of stock, so the customer app and kitchen both show the state.
select public.set_product_availability(
  (select id from public.products where slug = 'mutton-curry'),
  'OUT_OF_STOCK', '11111111-1111-1111-1111-111111111111', null, 'Mutton finished for today'
);

select public.set_product_availability(
  (select id from public.products where slug = 'rice-kheer'),
  'TEMPORARILY_UNAVAILABLE', '11111111-1111-1111-1111-111111111111', 90, 'Next batch setting'
);

-- Search telemetry for trending queries and the zero-result report.
insert into public.search_queries (user_id, query, normalized, result_count, created_at)
select
  u.id,
  q.query,
  lower(q.query),
  q.count,
  now() - (random() * interval '5 days')
from (values
  ('biryani', 4), ('biriyani', 4), ('chicken biryani', 2), ('litti', 1), ('litti chokha', 1),
  ('champaran mutton', 1), ('roll', 3), ('paneer', 5), ('noodles', 2), ('butter chicken', 1),
  ('momos', 0), ('pizza', 0), ('dosa', 0), ('burger', 0)
) as q(query, count)
cross join (
  select id from public.profiles where id::text like '91000000%' limit 3
) u;

-- An open, unresolved ticket for the support inbox.
insert into public.support_tickets (
  ticket_number, user_id, order_id, branch_id, category, subject, description,
  status, priority, first_response_due_at
)
select
  'BB-T000002',
  '91000000-0000-0000-0000-000000000004',
  o.id,
  '11111111-1111-1111-1111-111111111111',
  'ORDER_DELAYED',
  'My order is taking very long',
  'It has been more than 40 minutes and my order is still not out for delivery. Please check.',
  'OPEN', 'URGENT', now() + interval '15 minutes'
from public.orders o
where o.user_id = '91000000-0000-0000-0000-000000000004'
  and o.status = 'READY_FOR_PICKUP'
limit 1;

insert into public.support_messages (ticket_id, author_kind, author_id, body)
select t.id, 'CUSTOMER', t.user_id, t.description
from public.support_tickets t where t.ticket_number = 'BB-T000002';

-- Marketing campaign ready to send.
insert into public.notification_campaigns (
  name, description, channels, segment, title, body, image_path, action_route,
  coupon_id, status, scheduled_for, created_by
) values
  ('Weekend Biryani Push',
   'Saturday morning push to all customers promoting BIRYANI20.',
   array['PUSH', 'IN_APP']::public.notification_channel[],
   'ALL_CUSTOMERS',
   'Weekend biryani, 20% off 🍛',
   'Handi dum biryani at 20% off all weekend. Use code BIRYANI20.',
   'banners/campaign-biryani.jpg',
   'bitesbox://menu/biryani',
   '88888888-0000-0000-0000-000000000002',
   'SCHEDULED',
   date_trunc('day', now()) + interval '1 day' + interval '11 hours',
   '90000000-0000-0000-0000-000000000006'),

  ('Win Back Inactive',
   'Targets customers with no order in 30+ days using COMEBACK150.',
   array['PUSH', 'SMS']::public.notification_channel[],
   'INACTIVE_CUSTOMERS',
   'We miss you — ₹150 off 💛',
   'It has been a while. Here is ₹150 off your next order above ₹499. Code: COMEBACK150.',
   null,
   'bitesbox://offers',
   '88888888-0000-0000-0000-000000000007',
   'DRAFT',
   null,
   '90000000-0000-0000-0000-000000000006');

-- Inventory groundwork (ingredient tracking stays off at launch).
insert into public.ingredients (name, sku, unit, category, average_cost_per_unit) values
  ('Basmati Rice (aged)', 'ING-RICE-01', 'KILOGRAM', 'Grains', 120),
  ('Chicken (curry cut)', 'ING-CHKN-01', 'KILOGRAM', 'Meat', 240),
  ('Goat Meat', 'ING-MTN-01', 'KILOGRAM', 'Meat', 720),
  ('Paneer', 'ING-PNR-01', 'KILOGRAM', 'Dairy', 380),
  ('Onion', 'ING-ONION-01', 'KILOGRAM', 'Vegetables', 32),
  ('Mustard Oil', 'ING-OIL-01', 'LITRE', 'Oils', 165),
  ('Sattu (roasted gram flour)', 'ING-SATTU-01', 'KILOGRAM', 'Flours', 90),
  ('Wheat Flour', 'ING-ATTA-01', 'KILOGRAM', 'Flours', 42),
  ('Yoghurt', 'ING-CURD-01', 'KILOGRAM', 'Dairy', 80),
  ('Saffron', 'ING-SAFF-01', 'GRAM', 'Spices', 480);

insert into public.inventory_items (branch_id, ingredient_id, quantity_on_hand, low_stock_threshold, reorder_quantity)
select
  '11111111-1111-1111-1111-111111111111',
  i.id,
  case i.unit when 'GRAM' then 250 when 'KILOGRAM' then 40 else 20 end,
  case i.unit when 'GRAM' then 50 when 'KILOGRAM' then 8 else 5 end,
  case i.unit when 'GRAM' then 200 when 'KILOGRAM' then 25 else 15 end
from public.ingredients i;

-- ═══════════════════════════════════════════════════════════════════════════
-- FINISH
-- ═══════════════════════════════════════════════════════════════════════════
drop function if exists app.seed_user(uuid, text, text, text);
drop function if exists app.seed_grant_role(uuid, public.app_role, uuid, boolean);
drop function if exists app.seed_cart_item(uuid, text, text, smallint, text[], text);
drop function if exists app.seed_cart(uuid, uuid, public.fulfilment_type, text);
drop function if exists app.seed_capture_payment(uuid, public.payment_method);

select set_config('request.jwt.claims', '', false);

do $$
declare
  v_orders int;
  v_products int;
  v_users int;
begin
  select count(*) into v_orders from public.orders;
  select count(*) into v_products from public.products;
  select count(*) into v_users from public.profiles;

  raise notice '';
  raise notice '═══════════════════════════════════════════════════════';
  raise notice ' Bites Box seed complete';
  raise notice '   Branch        : Bites Box Bakhtiyarpur (BKP-01)';
  raise notice '   Products      : %', v_products;
  raise notice '   Orders        : %', v_orders;
  raise notice '   Users         : %', v_users;
  raise notice '';
  raise notice ' Sign in (password: Password123!)';
  raise notice '   Owner         owner@bitesbox.in';
  raise notice '   Manager       manager@bitesbox.in';
  raise notice '   Operations    operations@bitesbox.in';
  raise notice '   Finance       finance@bitesbox.in';
  raise notice '   Support       support@bitesbox.in';
  raise notice '   Marketing     marketing@bitesbox.in';
  raise notice '';
  raise notice ' Mobile OTP logins (code shown per number)';
  raise notice '   Customer      +919900000001 → 100001';
  raise notice '   Rider         +919900000101 → 100101';
  raise notice '   Kitchen       +919900000201 → 100201';
  raise notice '   Manager       +919900000301 → 100301';
  raise notice '═══════════════════════════════════════════════════════';
end;
$$;
