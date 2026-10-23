-- GROUP ORDERS
-- A participant contributes through their own cart; only the host can merge
-- the group into the host's server-priced checkout cart.
begin;

select tap.suite('Group orders');
select tap.remember('group_branch', '11111111-1111-1111-1111-111111111111');
select tap.remember('group_product', '55555555-0000-0000-0000-000000000052');

-- The public tables are not a client API; the narrow RPCs are.
select tap.as_user(tap.seed('customer_a'));
select public.cart_clear(tap.recall_uuid('group_branch'));
select tap.remember(
  'group_create_result',
  public.group_order_create(tap.recall_uuid('group_branch'))::text
);
select tap.remember(
  'group_id',
  (tap.recall('group_create_result')::jsonb ->> 'group_order_id')
);
select tap.remember(
  'group_code',
  (tap.recall('group_create_result')::jsonb ->> 'invite_code')
);
select tap.eq(
  length(tap.recall('group_code')),
  32,
  'the host receives a high entropy invite code'
);
select tap.throws(
  'select * from public.group_orders',
  'PERMISSION_DENIED',
  'customers cannot read invite or membership tables directly'
);

select tap.reset();

select tap.as_user(tap.seed('customer_b'));
select public.cart_clear(tap.recall_uuid('group_branch'));
select tap.remember(
  'joined_group_id',
  (public.group_order_join(tap.recall('group_code')) ->> 'group_order_id')
);
select tap.eq(
  tap.recall('joined_group_id'),
  tap.recall('group_id'),
  'a participant joins with the host code'
);

select public.cart_add_item(tap.recall_uuid('group_product'), null, 1::smallint);
select tap.throws(
  format('select public.group_order_merge(%L)', tap.recall('group_id')),
  'PERMISSION_DENIED',
  'a participant cannot merge the group into checkout'
);
select tap.reset();

select tap.as_user(tap.seed('customer_c'));
select tap.throws(
  format('select public.group_order_detail(%L)', tap.recall('group_id')),
  'GROUP_NOT_FOUND',
  'a non-member cannot inspect the group or its cart contents'
);
select tap.reset();

select tap.as_user(tap.seed('customer_a'));
select tap.eq(
  jsonb_array_length(public.group_order_detail(tap.recall_uuid('group_id')) -> 'members'),
  2,
  'the host sees both participants'
);
select tap.eq(
  (public.group_order_merge(tap.recall_uuid('group_id')) ->> 'imported_lines')::int,
  1,
  'the host merges the participant cart through server validation'
);
select tap.eq(
  (public.calculate_checkout() ->> 'item_count')::int,
  1,
  'the host cart contains the participant contribution before checkout'
);
select tap.eq(
  public.group_order_current(),
  null::jsonb,
  'the active group closes once it is merged'
);
select tap.reset();

select tap.as_user(tap.seed('customer_b'));
select tap.eq(
  (public.calculate_checkout() ->> 'item_count')::int,
  0,
  'merged items are removed from the participant cart to prevent duplicate checkout'
);
select tap.reset();

select tap.done('Group orders');

rollback;
