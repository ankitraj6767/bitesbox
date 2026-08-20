-- ═══════════════════════════════════════════════════════════════════════════
-- 0016 · PRICING ENGINE
--
-- The client sends intent only. Every rupee is computed here:
--   line prices → modifier pricing (with free selections) → item discounts →
--   automatic promotions → coupon → GST (inclusive) → packaging → delivery fee →
--   service fee → wallet → loyalty → round off → grand total
--
-- app.calculate_checkout() is the ONLY money authority. create-order calls it
-- again immediately before writing the order, so a stale client total can never
-- become an order.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Cart helpers ──────────────────────────────────────────────────────────
create or replace function app.cart_config_hash(
  p_product_id uuid,
  p_variant_id uuid,
  p_modifiers jsonb,
  p_instructions text
)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.encode(
    extensions.digest(
      p_product_id::text
      || '|' || coalesce(p_variant_id::text, '-')
      || '|' || coalesce((
           select string_agg(
             (m ->> 'modifier_id') || 'x' || coalesce(m ->> 'quantity', '1'),
             ',' order by (m ->> 'modifier_id')
           )
           from jsonb_array_elements(coalesce(p_modifiers, '[]'::jsonb)) m
         ), '-')
      || '|' || coalesce(btrim(lower(p_instructions)), '-'),
      'sha256'
    ),
    'hex'
  );
$$;

comment on function app.cart_config_hash is
  'Stable identity for a cart line so identical configurations merge instead of stacking.';

create or replace function app.get_or_create_cart(
  p_user_id uuid,
  p_branch_id uuid default null
)
returns public.carts
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_cart public.carts;
begin
  select * into v_cart
  from public.carts
  where user_id = p_user_id and branch_id = v_branch and is_active;

  if found then
    return v_cart;
  end if;

  insert into public.carts (user_id, branch_id)
  values (p_user_id, v_branch)
  on conflict (user_id, branch_id) where is_active do update set updated_at = now()
  returning * into v_cart;

  return v_cart;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- CART MUTATIONS
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.cart_add_item(
  p_product_id uuid,
  p_variant_id uuid default null,
  p_quantity smallint default 1,
  p_modifiers jsonb default '[]'::jsonb,
  p_special_instructions text default null,
  p_branch_id uuid default null,
  p_replace_quantity boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cart public.carts;
  v_product public.products;
  v_hash text;
  v_item public.cart_items;
  v_mod jsonb;
  v_group record;
  v_selected int;
  v_new_qty smallint;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to build your cart.');
  end if;

  if not app.account_is_active() then
    perform app.fail('ACCOUNT_BLOCKED', 'This account cannot place orders. Please contact support.');
  end if;

  if coalesce(p_quantity, 1) < 1 then
    perform app.fail('INVALID_QUANTITY', 'Quantity must be at least 1.');
  end if;

  v_cart := app.get_or_create_cart(v_uid, p_branch_id);

  select * into v_product from public.products
  where id = p_product_id and is_active and deleted_at is null;

  if not found then
    perform app.fail('ITEM_NOT_FOUND', 'This dish is no longer on the menu.');
  end if;

  if not app.product_orderable(p_product_id, v_cart.branch_id) then
    perform app.fail(
      'ITEM_UNAVAILABLE',
      format('%s is not available right now.', v_product.name),
      jsonb_build_object('product_id', p_product_id, 'product_name', v_product.name)
    );
  end if;

  -- A product with variants must be ordered as a specific variant.
  if p_variant_id is null and exists (
    select 1 from public.product_variants
    where product_id = p_product_id and is_active and deleted_at is null
  ) then
    perform app.fail('VARIANT_REQUIRED', format('Please choose an option for %s.', v_product.name));
  end if;

  if p_variant_id is not null then
    if not exists (
      select 1 from public.product_variants
      where id = p_variant_id and product_id = p_product_id and is_active and deleted_at is null
    ) then
      perform app.fail('VARIANT_NOT_FOUND', 'That option is no longer available.');
    end if;

    if not app.variant_orderable(p_variant_id) then
      perform app.fail('ITEM_UNAVAILABLE', 'That option is out of stock right now.');
    end if;
  end if;

  -- Validate every submitted modifier belongs to the product and is available.
  for v_mod in select * from jsonb_array_elements(coalesce(p_modifiers, '[]'::jsonb)) loop
    if not exists (
      select 1
      from public.modifiers m
      join public.product_modifier_groups pmg on pmg.modifier_group_id = m.modifier_group_id
      where m.id = (v_mod ->> 'modifier_id')::uuid
        and pmg.product_id = p_product_id
        and m.is_active and m.deleted_at is null
    ) then
      perform app.fail('MODIFIER_INVALID', 'One of the selected add-ons is not valid for this dish.');
    end if;

    if not app.modifier_orderable((v_mod ->> 'modifier_id')::uuid) then
      perform app.fail(
        'MODIFIER_UNAVAILABLE',
        coalesce(
          (select format('%s is out of stock.', name) from public.modifiers
           where id = (v_mod ->> 'modifier_id')::uuid),
          'An add-on is out of stock.'
        )
      );
    end if;
  end loop;

  -- Enforce min/max selections per modifier group.
  for v_group in
    select
      mg.id,
      mg.name,
      coalesce(pmg.is_required, mg.is_required) as is_required,
      coalesce(pmg.min_select, mg.min_select) as min_select,
      coalesce(pmg.max_select, mg.max_select) as max_select
    from public.product_modifier_groups pmg
    join public.modifier_groups mg on mg.id = pmg.modifier_group_id
    where pmg.product_id = p_product_id and mg.is_active and mg.deleted_at is null
  loop
    select count(*)
    into v_selected
    from jsonb_array_elements(coalesce(p_modifiers, '[]'::jsonb)) m
    join public.modifiers mo on mo.id = (m ->> 'modifier_id')::uuid
    where mo.modifier_group_id = v_group.id;

    if v_group.is_required and v_selected < greatest(v_group.min_select, 1) then
      perform app.fail(
        'MODIFIER_SELECTION_REQUIRED',
        format('Please choose %s.', v_group.name),
        jsonb_build_object('group', v_group.name, 'min_select', greatest(v_group.min_select, 1))
      );
    end if;

    if v_group.max_select is not null and v_selected > v_group.max_select then
      perform app.fail(
        'MODIFIER_SELECTION_EXCEEDED',
        format('You can pick at most %s from %s.', v_group.max_select, v_group.name),
        jsonb_build_object('group', v_group.name, 'max_select', v_group.max_select)
      );
    end if;
  end loop;

  v_hash := app.cart_config_hash(p_product_id, p_variant_id, p_modifiers, p_special_instructions);

  select * into v_item from public.cart_items
  where cart_id = v_cart.id and config_hash = v_hash;

  v_new_qty := case
    when not found then p_quantity
    when p_replace_quantity then p_quantity
    else v_item.quantity + p_quantity
  end;

  -- Per-order quantity ceiling protects the kitchen from abusive orders.
  if v_product.max_quantity_per_order is not null
     and v_new_qty > v_product.max_quantity_per_order then
    perform app.fail(
      'QUANTITY_LIMIT_EXCEEDED',
      format('You can order up to %s of %s.', v_product.max_quantity_per_order, v_product.name),
      jsonb_build_object('max_quantity', v_product.max_quantity_per_order)
    );
  end if;

  if v_new_qty < v_product.min_quantity_per_order then
    v_new_qty := v_product.min_quantity_per_order;
  end if;

  insert into public.cart_items as ci (
    cart_id, product_id, variant_id, quantity, special_instructions, config_hash
  )
  values (
    v_cart.id, p_product_id, p_variant_id, v_new_qty,
    nullif(btrim(coalesce(p_special_instructions, '')), ''), v_hash
  )
  on conflict (cart_id, config_hash) do update
    set quantity = v_new_qty, updated_at = now()
  returning * into v_item;

  -- Rewrite the modifier set so it always matches the hashed configuration.
  delete from public.cart_item_modifiers where cart_item_id = v_item.id;

  insert into public.cart_item_modifiers (cart_item_id, modifier_id, quantity)
  select
    v_item.id,
    (m ->> 'modifier_id')::uuid,
    greatest(coalesce((m ->> 'quantity')::smallint, 1), 1)
  from jsonb_array_elements(coalesce(p_modifiers, '[]'::jsonb)) m
  on conflict (cart_item_id, modifier_id) do update set quantity = excluded.quantity;

  update public.carts set updated_at = now() where id = v_cart.id;

  return app.calculate_checkout(v_uid, v_cart.id);
end;
$$;

create or replace function public.cart_update_item(
  p_cart_item_id uuid,
  p_quantity smallint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cart_id uuid;
  v_max smallint;
  v_name text;
begin
  select c.id, p.max_quantity_per_order, p.name
  into v_cart_id, v_max, v_name
  from public.cart_items ci
  join public.carts c on c.id = ci.cart_id
  join public.products p on p.id = ci.product_id
  where ci.id = p_cart_item_id and c.user_id = v_uid and c.is_active;

  if v_cart_id is null then
    perform app.fail('CART_ITEM_NOT_FOUND', 'That item is no longer in your cart.');
  end if;

  if p_quantity <= 0 then
    delete from public.cart_items where id = p_cart_item_id;
  else
    if v_max is not null and p_quantity > v_max then
      perform app.fail(
        'QUANTITY_LIMIT_EXCEEDED',
        format('You can order up to %s of %s.', v_max, v_name)
      );
    end if;

    update public.cart_items
    set quantity = p_quantity, updated_at = now()
    where id = p_cart_item_id;
  end if;

  update public.carts set updated_at = now() where id = v_cart_id;

  return app.calculate_checkout(v_uid, v_cart_id);
end;
$$;

create or replace function public.cart_remove_item(p_cart_item_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public.cart_update_item(p_cart_item_id, 0::smallint);
end;
$$;

create or replace function public.cart_clear(p_branch_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cart public.carts;
begin
  v_cart := app.get_or_create_cart(v_uid, p_branch_id);

  delete from public.cart_items where cart_id = v_cart.id;

  update public.carts
  set coupon_id = null, coupon_code = null, use_wallet = false, updated_at = now()
  where id = v_cart.id;

  return app.calculate_checkout(v_uid, v_cart.id);
end;
$$;

create or replace function public.cart_set_options(
  p_branch_id uuid default null,
  p_fulfilment_type public.fulfilment_type default null,
  p_address_id uuid default null,
  p_timing public.order_timing default null,
  p_scheduled_for timestamptz default null,
  p_delivery_instructions text default null,
  p_cooking_instructions text default null,
  p_use_wallet boolean default null,
  p_clear_coupon boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cart public.carts;
begin
  v_cart := app.get_or_create_cart(v_uid, p_branch_id);

  -- An address must belong to the caller.
  if p_address_id is not null and not exists (
    select 1 from public.addresses
    where id = p_address_id and user_id = v_uid and deleted_at is null
  ) then
    perform app.fail('ADDRESS_NOT_FOUND', 'That delivery address is not available.');
  end if;

  if p_timing = 'SCHEDULED' then
    if p_scheduled_for is null then
      perform app.fail('SCHEDULE_REQUIRED', 'Please pick a delivery time.');
    end if;

    if not public.feature_enabled('scheduled_orders') then
      perform app.fail('SCHEDULING_DISABLED', 'Scheduled ordering is currently unavailable.');
    end if;

    if p_scheduled_for < now() + interval '30 minutes' then
      perform app.fail('SCHEDULE_TOO_SOON', 'Please choose a slot at least 30 minutes from now.');
    end if;

    if p_scheduled_for > now() + interval '7 days' then
      perform app.fail('SCHEDULE_TOO_FAR', 'You can schedule up to 7 days ahead.');
    end if;
  end if;

  if p_fulfilment_type = 'PICKUP' and not public.feature_enabled('self_pickup') then
    perform app.fail('PICKUP_DISABLED', 'Self pickup is currently unavailable.');
  end if;

  update public.carts
  set fulfilment_type = coalesce(p_fulfilment_type, fulfilment_type),
      address_id = case
        when p_fulfilment_type = 'PICKUP' then null
        else coalesce(p_address_id, address_id)
      end,
      timing = coalesce(p_timing, timing),
      scheduled_for = case
        when coalesce(p_timing, timing) = 'NOW' then null
        else coalesce(p_scheduled_for, scheduled_for)
      end,
      delivery_instructions = coalesce(p_delivery_instructions, delivery_instructions),
      cooking_instructions = coalesce(p_cooking_instructions, cooking_instructions),
      use_wallet = coalesce(p_use_wallet, use_wallet),
      coupon_id = case when p_clear_coupon then null else coupon_id end,
      coupon_code = case when p_clear_coupon then null else coupon_code end,
      updated_at = now()
  where id = v_cart.id;

  return app.calculate_checkout(v_uid, v_cart.id);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- COUPON EVALUATION
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.evaluate_coupon(
  p_coupon_id uuid,
  p_user_id uuid,
  p_lines jsonb,
  p_items_subtotal numeric,
  p_fulfilment public.fulfilment_type,
  p_zone_id uuid,
  p_payment_mode public.payment_mode default null,
  p_branch_id uuid default null,
  p_at timestamptz default now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_coupon public.coupons;
  v_profile public.profiles;
  v_tz text := 'Asia/Kolkata';
  v_local timestamp;
  v_uses int;
  v_eligible_subtotal numeric := 0;
  v_discount numeric := 0;
  v_rule public.coupon_rules;
  v_rule_value numeric;
  v_free_delivery boolean := false;
  v_scoped boolean;
begin
  select * into v_coupon from public.coupons
  where id = p_coupon_id and deleted_at is null;

  if not found then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_INVALID',
      'message', 'This coupon code is not valid.');
  end if;

  if not v_coupon.is_active then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_INACTIVE',
      'message', 'This coupon is no longer active.');
  end if;

  if v_coupon.starts_at > p_at then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_NOT_STARTED',
      'message', 'This offer has not started yet.');
  end if;

  if v_coupon.ends_at is not null and v_coupon.ends_at <= p_at then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_EXPIRED',
      'message', 'This offer has expired.');
  end if;

  if v_coupon.branch_id is not null and p_branch_id is not null
     and v_coupon.branch_id <> p_branch_id then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_NOT_APPLICABLE',
      'message', 'This offer is not available at this outlet.');
  end if;

  -- Day / time restrictions
  select timezone into v_tz from public.branches where id = coalesce(p_branch_id, app.default_branch_id());
  v_local := p_at at time zone coalesce(v_tz, 'Asia/Kolkata');

  if not (extract(dow from v_local)::smallint = any (v_coupon.valid_days_of_week)) then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_NOT_VALID_TODAY',
      'message', 'This offer is not valid today.');
  end if;

  if v_coupon.valid_from_time is not null
     and not (v_local::time between v_coupon.valid_from_time and v_coupon.valid_to_time) then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_NOT_VALID_NOW',
      'message', format('This offer is valid between %s and %s.',
                        to_char(v_coupon.valid_from_time, 'HH12:MI AM'),
                        to_char(v_coupon.valid_to_time, 'HH12:MI AM')));
  end if;

  -- Global usage cap
  if v_coupon.max_total_uses is not null and v_coupon.total_used >= v_coupon.max_total_uses then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_EXHAUSTED',
      'message', 'This offer has been fully claimed.');
  end if;

  -- Per-customer cap
  select count(*) into v_uses
  from public.coupon_redemptions
  where coupon_id = v_coupon.id and user_id = p_user_id;

  if v_uses >= v_coupon.max_uses_per_customer then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_ALREADY_USED',
      'message', 'You have already used this offer.');
  end if;

  select * into v_profile from public.profiles where id = p_user_id;

  -- Audience targeting
  if v_coupon.audience = 'SPECIFIC_CUSTOMERS'
     and not exists (
       select 1 from public.coupon_customers
       where coupon_id = v_coupon.id and user_id = p_user_id
     ) then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_NOT_ELIGIBLE',
      'message', 'This offer is not available on your account.');
  end if;

  if (v_coupon.first_order_only or v_coupon.audience = 'FIRST_ORDER')
     and coalesce(v_profile.completed_orders, 0) > 0 then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_FIRST_ORDER_ONLY',
      'message', 'This offer is only for your first order.');
  end if;

  if v_coupon.new_customer_days is not null
     and v_profile.created_at < p_at - make_interval(days => v_coupon.new_customer_days) then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_NOT_ELIGIBLE',
      'message', 'This offer is for new customers only.');
  end if;

  if v_coupon.audience = 'HIGH_VALUE_CUSTOMERS'
     and coalesce(v_profile.lifetime_value, 0) < app.setting_numeric('segment.high_value_ltv', 5000) then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_NOT_ELIGIBLE',
      'message', 'This offer is not available on your account.');
  end if;

  if v_coupon.audience = 'INACTIVE_CUSTOMERS'
     and coalesce(v_profile.last_order_at, 'epoch'::timestamptz)
         > p_at - make_interval(days => app.setting_int('segment.inactive_days', 30)) then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_NOT_ELIGIBLE',
      'message', 'This offer is not available on your account.');
  end if;

  -- Fulfilment / payment / zone restrictions
  if cardinality(v_coupon.eligible_fulfilment) > 0
     and not (p_fulfilment = any (v_coupon.eligible_fulfilment)) then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_NOT_APPLICABLE',
      'message', case when p_fulfilment = 'PICKUP'
                      then 'This offer is valid on delivery orders only.'
                      else 'This offer is valid on pickup orders only.' end);
  end if;

  if cardinality(v_coupon.eligible_payment_modes) > 0
     and p_payment_mode is not null
     and not (p_payment_mode = any (v_coupon.eligible_payment_modes)) then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_PAYMENT_RESTRICTED',
      'message', 'This offer requires a different payment method.');
  end if;

  if cardinality(v_coupon.eligible_zone_ids) > 0
     and (p_zone_id is null or not (p_zone_id = any (v_coupon.eligible_zone_ids))) then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_NOT_APPLICABLE',
      'message', 'This offer is not available in your area.');
  end if;

  -- Minimum order value
  if p_items_subtotal < v_coupon.min_order_amount then
    return jsonb_build_object(
      'valid', false,
      'reason_code', 'COUPON_MIN_ORDER_NOT_MET',
      'message', format('Add items worth ₹%s more to use this offer.',
                        to_char(v_coupon.min_order_amount - p_items_subtotal, 'FM999999990.00')),
      'shortfall', v_coupon.min_order_amount - p_items_subtotal,
      'min_order_amount', v_coupon.min_order_amount
    );
  end if;

  -- Which portion of the basket the discount applies to
  v_scoped := cardinality(v_coupon.eligible_product_ids) > 0
              or cardinality(v_coupon.eligible_category_ids) > 0;

  select coalesce(sum((l ->> 'gross_amount')::numeric), 0)
  into v_eligible_subtotal
  from jsonb_array_elements(p_lines) l
  where (
      not v_scoped
      or (l ->> 'product_id')::uuid = any (v_coupon.eligible_product_ids)
      or (l ->> 'category_id')::uuid = any (v_coupon.eligible_category_ids)
    )
    and not ((l ->> 'product_id')::uuid = any (v_coupon.excluded_product_ids));

  if v_eligible_subtotal <= 0 and v_coupon.discount_kind <> 'FREE_DELIVERY' then
    return jsonb_build_object('valid', false, 'reason_code', 'COUPON_NO_ELIGIBLE_ITEMS',
      'message', 'Your cart has no items eligible for this offer.');
  end if;

  -- Extra composable rules
  for v_rule in select * from public.coupon_rules where coupon_id = v_coupon.id loop
    v_rule_value := nullif(v_rule.value #>> '{}', '')::numeric;

    if v_rule.rule_type = 'MIN_ITEM_COUNT' then
      if (select coalesce(sum((l ->> 'quantity')::int), 0) from jsonb_array_elements(p_lines) l) < v_rule_value then
        return jsonb_build_object('valid', false, 'reason_code', 'COUPON_RULE_NOT_MET',
          'message', format('Add at least %s items to use this offer.', v_rule_value::int));
      end if;
    elsif v_rule.rule_type = 'CUSTOMER_ORDER_COUNT' then
      if coalesce(v_profile.completed_orders, 0) < v_rule_value then
        return jsonb_build_object('valid', false, 'reason_code', 'COUPON_RULE_NOT_MET',
          'message', 'This offer is not available on your account.');
      end if;
    elsif v_rule.rule_type = 'MIN_LIFETIME_VALUE' then
      if coalesce(v_profile.lifetime_value, 0) < v_rule_value then
        return jsonb_build_object('valid', false, 'reason_code', 'COUPON_RULE_NOT_MET',
          'message', 'This offer is not available on your account.');
      end if;
    elsif v_rule.rule_type = 'REQUIRES_PRODUCT' then
      if not exists (
        select 1 from jsonb_array_elements(p_lines) l
        where (l ->> 'product_id') = (v_rule.value #>> '{}')
      ) then
        return jsonb_build_object('valid', false, 'reason_code', 'COUPON_RULE_NOT_MET',
          'message', 'Your cart is missing an item required for this offer.');
      end if;
    end if;
  end loop;

  -- Discount computation
  if v_coupon.discount_kind = 'PERCENTAGE' then
    v_discount := v_eligible_subtotal * v_coupon.discount_value / 100;
  elsif v_coupon.discount_kind = 'FLAT' then
    v_discount := v_coupon.discount_value;
  elsif v_coupon.discount_kind = 'FREE_DELIVERY' then
    v_free_delivery := true;
    v_discount := 0;
  elsif v_coupon.discount_kind in ('PRODUCT_DISCOUNT', 'CATEGORY_DISCOUNT') then
    -- discount_value is a percentage off the eligible portion
    v_discount := v_eligible_subtotal * v_coupon.discount_value / 100;
  elsif v_coupon.discount_kind = 'BUY_X_GET_Y' then
    v_discount := coalesce((
      select least(
        floor(sum((l ->> 'quantity')::int) / v_coupon.buy_quantity) * v_coupon.get_quantity,
        999
      ) * (
        select p.base_price from public.products p where p.id = v_coupon.get_product_id
      )
      from jsonb_array_elements(p_lines) l
      where not v_scoped
        or (l ->> 'product_id')::uuid = any (v_coupon.eligible_product_ids)
        or (l ->> 'category_id')::uuid = any (v_coupon.eligible_category_ids)
    ), 0);
  end if;

  if v_coupon.max_discount_amount is not null then
    v_discount := least(v_discount, v_coupon.max_discount_amount);
  end if;

  -- A coupon can never exceed the value it is discounting.
  v_discount := least(app.money_round(v_discount), v_eligible_subtotal);

  return jsonb_build_object(
    'valid', true,
    'coupon_id', v_coupon.id,
    'code', v_coupon.code,
    'title', v_coupon.title,
    'discount_kind', v_coupon.discount_kind,
    'discount_amount', v_discount,
    'free_delivery', v_free_delivery,
    'eligible_subtotal', v_eligible_subtotal,
    'scoped', v_scoped,
    'eligible_product_ids', to_jsonb(v_coupon.eligible_product_ids),
    'eligible_category_ids', to_jsonb(v_coupon.eligible_category_ids),
    'excluded_product_ids', to_jsonb(v_coupon.excluded_product_ids)
  );
end;
$$;

comment on function app.evaluate_coupon is
  'Full rule evaluation returning either a stable failure code or the exact discount.';

-- ─── Automatic promotion selection ─────────────────────────────────────────
create or replace function app.evaluate_promotions(
  p_lines jsonb,
  p_items_subtotal numeric,
  p_fulfilment public.fulfilment_type,
  p_branch_id uuid,
  p_at timestamptz default now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_promo public.promotions;
  v_best jsonb := jsonb_build_object('applied', false, 'discount_amount', 0, 'free_delivery', false);
  v_best_amount numeric := 0;
  v_eligible numeric;
  v_discount numeric;
  v_tz text;
  v_local timestamp;
  v_scoped boolean;
begin
  select timezone into v_tz from public.branches where id = p_branch_id;
  v_local := p_at at time zone coalesce(v_tz, 'Asia/Kolkata');

  for v_promo in
    select * from public.promotions
    where is_active
      and deleted_at is null
      and trigger = 'AUTOMATIC'
      and starts_at <= p_at
      and (ends_at is null or ends_at > p_at)
      and (branch_id is null or branch_id = p_branch_id)
    order by priority desc
  loop
    if not (extract(dow from v_local)::smallint = any (v_promo.valid_days_of_week)) then
      continue;
    end if;

    if v_promo.valid_from_time is not null
       and not (v_local::time between v_promo.valid_from_time and v_promo.valid_to_time) then
      continue;
    end if;

    if cardinality(v_promo.eligible_fulfilment) > 0
       and not (p_fulfilment = any (v_promo.eligible_fulfilment)) then
      continue;
    end if;

    if p_items_subtotal < v_promo.min_order_amount then
      continue;
    end if;

    v_scoped := cardinality(v_promo.eligible_product_ids) > 0
                or cardinality(v_promo.eligible_category_ids) > 0;

    select coalesce(sum((l ->> 'gross_amount')::numeric), 0)
    into v_eligible
    from jsonb_array_elements(p_lines) l
    where not v_scoped
      or (l ->> 'product_id')::uuid = any (v_promo.eligible_product_ids)
      or (l ->> 'category_id')::uuid = any (v_promo.eligible_category_ids);

    if v_eligible <= 0 and v_promo.discount_kind <> 'FREE_DELIVERY' then
      continue;
    end if;

    v_discount := case v_promo.discount_kind
      when 'PERCENTAGE' then v_eligible * v_promo.discount_value / 100
      when 'FLAT' then v_promo.discount_value
      when 'PRODUCT_DISCOUNT' then v_eligible * v_promo.discount_value / 100
      when 'CATEGORY_DISCOUNT' then v_eligible * v_promo.discount_value / 100
      else 0
    end;

    if v_promo.max_discount_amount is not null then
      v_discount := least(v_discount, v_promo.max_discount_amount);
    end if;

    v_discount := least(app.money_round(v_discount), v_eligible);

    -- Free delivery is valued at the current fee by the caller; here we mark it.
    if v_promo.discount_kind = 'FREE_DELIVERY' then
      if not (v_best ->> 'free_delivery')::boolean then
        v_best := jsonb_build_object(
          'applied', true,
          'promotion_id', v_promo.id,
          'name', v_promo.name,
          'headline', v_promo.headline,
          'badge_text', v_promo.badge_text,
          'discount_kind', v_promo.discount_kind,
          'discount_amount', 0,
          'free_delivery', true,
          'stacks_with_coupon', v_promo.stacks_with_coupon,
          'eligible_subtotal', v_eligible
        );
      end if;
      continue;
    end if;

    if v_discount > v_best_amount then
      v_best_amount := v_discount;
      v_best := jsonb_build_object(
        'applied', true,
        'promotion_id', v_promo.id,
        'name', v_promo.name,
        'headline', v_promo.headline,
        'badge_text', v_promo.badge_text,
        'discount_kind', v_promo.discount_kind,
        'discount_amount', v_discount,
        'free_delivery', coalesce((v_best ->> 'free_delivery')::boolean, false),
        'stacks_with_coupon', v_promo.stacks_with_coupon,
        'eligible_subtotal', v_eligible,
        'eligible_product_ids', to_jsonb(v_promo.eligible_product_ids),
        'eligible_category_ids', to_jsonb(v_promo.eligible_category_ids)
      );
    end if;
  end loop;

  return v_best;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- CALCULATE CHECKOUT — the money authority
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.calculate_checkout(
  p_user_id uuid,
  p_cart_id uuid,
  p_payment_mode public.payment_mode default null,
  p_tip_amount numeric default 0,
  p_loyalty_points int default 0,
  p_at timestamptz default now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_cart public.carts;
  v_branch public.branches;
  v_address public.addresses;
  v_lines jsonb := '[]'::jsonb;
  v_priced_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_issues jsonb := '[]'::jsonb;

  v_items_subtotal numeric := 0;
  v_items_discount numeric := 0;
  v_packaging numeric := 0;
  v_coupon jsonb;
  v_promo jsonb;
  v_coupon_discount numeric := 0;
  v_promo_discount numeric := 0;
  v_total_discount numeric := 0;
  v_discountable_base numeric := 0;

  v_tax_total numeric := 0;
  v_cgst numeric := 0;
  v_sgst numeric := 0;
  v_igst numeric := 0;
  v_cess numeric := 0;
  v_taxable numeric := 0;

  v_zone record;
  v_delivery_fee numeric := 0;
  v_delivery_waived numeric := 0;
  v_free_delivery boolean := false;
  v_service_fee numeric := 0;
  v_tip numeric := 0;

  v_wallet_balance numeric := 0;
  v_wallet_applied numeric := 0;
  v_loyalty_points int := 0;
  v_loyalty_discount numeric := 0;

  v_pre_round numeric := 0;
  v_round_off numeric := 0;
  v_grand_total numeric := 0;
  v_payable numeric := 0;

  v_branch_state jsonb;
  v_serviceability jsonb;
  v_prep_minutes int := 0;
  v_eta_minutes int := 0;
  v_max_prep int := 0;
  v_item_count int := 0;
  v_unit_count int := 0;
  v_payment_mode public.payment_mode;
  v_cod_limit numeric;
  v_min_order numeric := 0;
begin
  select * into v_cart from public.carts where id = p_cart_id and user_id = p_user_id;

  if not found then
    perform app.fail('CART_NOT_FOUND', 'Your cart could not be found.');
  end if;

  select * into v_branch from public.branches where id = v_cart.branch_id;
  v_branch_state := public.branch_ordering_state(v_branch.id);
  v_payment_mode := coalesce(p_payment_mode, 'ONLINE'::public.payment_mode);

  -- Pickup orders never resolve a delivery zone, but the code below still reads
  -- v_zone fields. `where false` assigns the record with NULLs without any work,
  -- which is what PL/pgSQL requires before a RECORD can be dereferenced.
  select * into v_zone
  from app.resolve_delivery_zone(0, 0, null) where false;

  -- ── Pass 1: line pricing (modifiers with free selections, availability) ──
  with mod_rows as (
    select
      cim.cart_item_id,
      m.id as modifier_id,
      m.name as modifier_name,
      m.price,
      m.food_type,
      cim.quantity,
      mg.id as group_id,
      mg.name as group_name,
      mg.free_selections,
      app.modifier_orderable(m.id, p_at) as is_available,
      row_number() over (
        partition by cim.cart_item_id, mg.id order by m.price asc, m.name
      ) as rn
    from public.cart_item_modifiers cim
    join public.modifiers m on m.id = cim.modifier_id
    join public.modifier_groups mg on mg.id = m.modifier_group_id
    join public.cart_items ci on ci.id = cim.cart_item_id
    where ci.cart_id = p_cart_id
  ),
  mod_priced as (
    select
      *,
      case when rn <= free_selections then 0::numeric else price::numeric end as effective_price
    from mod_rows
  ),
  mod_agg as (
    select
      cart_item_id,
      sum(effective_price * quantity) as modifiers_price,
      bool_and(is_available) as all_available,
      jsonb_agg(
        jsonb_build_object(
          'modifier_id', modifier_id,
          'modifier_group_id', group_id,
          'group_name', group_name,
          'modifier_name', modifier_name,
          'unit_price', effective_price,
          'list_price', price,
          'quantity', quantity,
          'total_price', effective_price * quantity,
          'food_type', food_type,
          'is_available', is_available,
          'is_free', effective_price = 0 and price > 0
        ) order by group_name, modifier_name
      ) as modifiers
    from mod_priced
    group by cart_item_id
  )
  select coalesce(jsonb_agg(line order by line ->> 'product_name'), '[]'::jsonb)
  into v_lines
  from (
    select jsonb_build_object(
      'cart_item_id', ci.id,
      'product_id', p.id,
      'variant_id', v.id,
      'category_id', p.category_id,
      'product_name', p.name,
      'product_slug', p.slug,
      'short_description', p.short_description,
      'variant_name', v.name,
      'variant_option_group', v.option_group,
      'category_name', c.name,
      'food_type', p.food_type,
      'image_path', coalesce(p.thumbnail_path, p.hero_image_path),
      'quantity', ci.quantity,
      'unit_price', coalesce(v.price, p.base_price),
      'compare_price', coalesce(v.compare_price, p.compare_price),
      'modifiers_price', coalesce(ma.modifiers_price, 0),
      'gross_amount', app.money_round(
        (coalesce(v.price, p.base_price) + coalesce(ma.modifiers_price, 0)) * ci.quantity
      ),
      'packaging_charge', app.money_round(
        (coalesce(nullif(v.packaging_charge, 0), p.packaging_charge)) * ci.quantity
      ),
      'tax_category_id', p.tax_category_id,
      'tax_rate', coalesce(tc.rate, 0),
      'tax_inclusive', coalesce(tc.is_inclusive, true),
      'cgst_rate', coalesce(tc.cgst_rate, 0),
      'sgst_rate', coalesce(tc.sgst_rate, 0),
      'igst_rate', coalesce(tc.igst_rate, 0),
      'cess_rate', coalesce(tc.cess_rate, 0),
      'hsn_sac_code', tc.hsn_sac_code,
      'special_instructions', ci.special_instructions,
      'preparation_minutes', coalesce(v.preparation_minutes, p.preparation_minutes),
      'modifiers', coalesce(ma.modifiers, '[]'::jsonb),
      'is_available', app.product_orderable(p.id, v_cart.branch_id, p_at)
                      and (v.id is null or app.variant_orderable(v.id, p_at))
                      and coalesce(ma.all_available, true),
      'display_order', p.display_order
    ) as line
    from public.cart_items ci
    join public.products p on p.id = ci.product_id
    join public.categories c on c.id = p.category_id
    left join public.product_variants v on v.id = ci.variant_id
    left join public.tax_categories tc on tc.id = p.tax_category_id
    left join mod_agg ma on ma.cart_item_id = ci.id
    where ci.cart_id = p_cart_id
  ) lines;

  -- Aggregate the basket and collect availability problems.
  select
    coalesce(sum((l ->> 'gross_amount')::numeric), 0),
    coalesce(sum((l ->> 'packaging_charge')::numeric), 0),
    count(*)::int,
    coalesce(sum((l ->> 'quantity')::int), 0),
    coalesce(max((l ->> 'preparation_minutes')::int), 0)
  into v_items_subtotal, v_packaging, v_item_count, v_unit_count, v_max_prep
  from jsonb_array_elements(v_lines) l;

  for v_line in select * from jsonb_array_elements(v_lines) loop
    if not (v_line ->> 'is_available')::boolean then
      v_issues := v_issues || jsonb_build_array(jsonb_build_object(
        'code', 'ITEM_UNAVAILABLE',
        'severity', 'BLOCKING',
        'cart_item_id', v_line ->> 'cart_item_id',
        'product_id', v_line ->> 'product_id',
        'message', format('%s is no longer available. Please remove it to continue.',
                          v_line ->> 'product_name')
      ));
    end if;
  end loop;

  -- ── Fulfilment, serviceability & delivery fee ──
  if v_cart.fulfilment_type = 'DELIVERY' then
    if v_cart.address_id is null then
      v_issues := v_issues || jsonb_build_array(jsonb_build_object(
        'code', 'ADDRESS_REQUIRED', 'severity', 'BLOCKING',
        'message', 'Choose a delivery address to continue.'
      ));
    else
      select * into v_address from public.addresses
      where id = v_cart.address_id and user_id = p_user_id and deleted_at is null;

      if not found then
        v_issues := v_issues || jsonb_build_array(jsonb_build_object(
          'code', 'ADDRESS_REQUIRED', 'severity', 'BLOCKING',
          'message', 'Choose a delivery address to continue.'
        ));
      else
        select * into v_zone
        from app.resolve_delivery_zone(v_address.latitude, v_address.longitude, v_cart.branch_id);

        if v_zone.zone_id is null or not v_zone.is_serviceable then
          v_issues := v_issues || jsonb_build_array(jsonb_build_object(
            'code', 'ADDRESS_NOT_SERVICEABLE', 'severity', 'BLOCKING',
            'message', 'We do not deliver to this address yet.'
          ));
        else
          v_min_order := v_zone.min_order_amount;
          v_delivery_fee := app.compute_delivery_fee(
            v_zone.zone_id, v_zone.distance_km, v_items_subtotal, p_at
          );
          v_eta_minutes := v_zone.base_eta_minutes + v_zone.extra_eta_minutes;

          if v_items_subtotal < v_zone.min_order_amount then
            v_issues := v_issues || jsonb_build_array(jsonb_build_object(
              'code', 'MIN_ORDER_NOT_MET', 'severity', 'BLOCKING',
              'shortfall', v_zone.min_order_amount - v_items_subtotal,
              'min_order_amount', v_zone.min_order_amount,
              'message', format('Minimum order for delivery is ₹%s. Add ₹%s more.',
                to_char(v_zone.min_order_amount, 'FM999999990.00'),
                to_char(v_zone.min_order_amount - v_items_subtotal, 'FM999999990.00'))
            ));
          end if;
        end if;
      end if;
    end if;
  else
    -- Pickup: no fee, no serviceability, shorter promise.
    v_delivery_fee := 0;
    v_eta_minutes := 0;

    if (v_branch_state ->> 'service_mode') = 'DELIVERY' then
      v_issues := v_issues || jsonb_build_array(jsonb_build_object(
        'code', 'PICKUP_UNAVAILABLE', 'severity', 'BLOCKING',
        'message', 'Self pickup is not available at this outlet.'
      ));
    end if;
  end if;

  -- ── Automatic promotions ──
  v_promo := app.evaluate_promotions(
    v_lines, v_items_subtotal, v_cart.fulfilment_type, v_cart.branch_id, p_at
  );
  v_promo_discount := coalesce((v_promo ->> 'discount_amount')::numeric, 0);

  if coalesce((v_promo ->> 'free_delivery')::boolean, false) then
    v_free_delivery := true;
  end if;

  -- ── Coupon ──
  if v_cart.coupon_id is not null then
    v_coupon := app.evaluate_coupon(
      v_cart.coupon_id, p_user_id, v_lines, v_items_subtotal,
      v_cart.fulfilment_type,
      case when v_zone.zone_id is not null then v_zone.zone_id else null end,
      v_payment_mode, v_cart.branch_id, p_at
    );

    if (v_coupon ->> 'valid')::boolean then
      v_coupon_discount := coalesce((v_coupon ->> 'discount_amount')::numeric, 0);

      if coalesce((v_coupon ->> 'free_delivery')::boolean, false) then
        v_free_delivery := true;
      end if;

      -- A non-stacking promotion yields to the coupon when the coupon is better.
      if v_promo_discount > 0
         and not coalesce((v_promo ->> 'stacks_with_coupon')::boolean, false) then
        if v_coupon_discount >= v_promo_discount then
          v_promo_discount := 0;
          v_promo := jsonb_build_object('applied', false, 'discount_amount', 0,
                                        'free_delivery', v_free_delivery,
                                        'suppressed_by_coupon', true);
        else
          v_coupon_discount := 0;
          v_coupon := v_coupon || jsonb_build_object(
            'valid', false,
            'reason_code', 'BETTER_OFFER_APPLIED',
            'message', format('%s gives you a bigger saving, so it was applied instead.',
                              coalesce(v_promo ->> 'headline', 'An active offer'))
          );
        end if;
      end if;
    else
      v_issues := v_issues || jsonb_build_array(jsonb_build_object(
        'code', v_coupon ->> 'reason_code',
        'severity', 'WARNING',
        'message', v_coupon ->> 'message'
      ));
    end if;
  end if;

  if v_free_delivery and v_delivery_fee > 0 then
    v_delivery_waived := v_delivery_fee;
    v_delivery_fee := 0;
  end if;

  v_total_discount := app.money_round(v_items_discount + v_coupon_discount + v_promo_discount);
  v_discountable_base := v_items_subtotal;

  -- ── Pass 2: allocate discounts proportionally and compute GST per line ──
  -- Proportional allocation keeps per-item tax and refunds exact.
  select coalesce(jsonb_agg(priced order by (priced ->> 'display_order')::int), '[]'::jsonb)
  into v_priced_lines
  from (
    select
      l
      || jsonb_build_object('allocated_discount', alloc.allocated)
      || jsonb_build_object('net_amount', app.money_round((l ->> 'gross_amount')::numeric - alloc.allocated))
      || jsonb_build_object(
           'taxable_amount',
           case
             when (l ->> 'tax_inclusive')::boolean and (l ->> 'tax_rate')::numeric > 0
             then app.money_round(
               ((l ->> 'gross_amount')::numeric - alloc.allocated) / (1 + (l ->> 'tax_rate')::numeric)
             )
             else app.money_round((l ->> 'gross_amount')::numeric - alloc.allocated)
           end
         )
      || jsonb_build_object(
           'tax_amount',
           case
             when (l ->> 'tax_rate')::numeric = 0 then 0
             when (l ->> 'tax_inclusive')::boolean
             then app.money_round(
               ((l ->> 'gross_amount')::numeric - alloc.allocated)
               - ((l ->> 'gross_amount')::numeric - alloc.allocated) / (1 + (l ->> 'tax_rate')::numeric)
             )
             else app.money_round(
               ((l ->> 'gross_amount')::numeric - alloc.allocated) * (l ->> 'tax_rate')::numeric
             )
           end
         ) as priced
    from (
      select
        l,
        -- Discounts are shared in proportion to each line's gross value.
        case
          when v_discountable_base <= 0 then 0
          else app.money_round(
            v_total_discount * (l ->> 'gross_amount')::numeric / v_discountable_base
          )
        end as allocated
      from jsonb_array_elements(v_lines) l
    ) alloc(l, allocated)
  ) t(priced);

  -- Split the composite tax into CGST/SGST/IGST/CESS components.
  select
    coalesce(sum((l ->> 'tax_amount')::numeric), 0),
    coalesce(sum((l ->> 'taxable_amount')::numeric), 0),
    coalesce(sum(
      case when (l ->> 'tax_rate')::numeric > 0
        then (l ->> 'tax_amount')::numeric * (l ->> 'cgst_rate')::numeric / (l ->> 'tax_rate')::numeric
        else 0 end
    ), 0),
    coalesce(sum(
      case when (l ->> 'tax_rate')::numeric > 0
        then (l ->> 'tax_amount')::numeric * (l ->> 'sgst_rate')::numeric / (l ->> 'tax_rate')::numeric
        else 0 end
    ), 0),
    coalesce(sum(
      case when (l ->> 'tax_rate')::numeric > 0
        then (l ->> 'tax_amount')::numeric * (l ->> 'igst_rate')::numeric / (l ->> 'tax_rate')::numeric
        else 0 end
    ), 0),
    coalesce(sum((l ->> 'taxable_amount')::numeric * (l ->> 'cess_rate')::numeric), 0)
  into v_tax_total, v_taxable, v_cgst, v_sgst, v_igst, v_cess
  from jsonb_array_elements(v_priced_lines) l;

  v_tax_total := app.money_round(v_tax_total);
  v_taxable := app.money_round(v_taxable);
  v_cgst := app.money_round(v_cgst);
  v_sgst := app.money_round(v_sgst);
  v_igst := app.money_round(v_igst);
  v_cess := app.money_round(v_cess);

  -- ── Fees ──
  v_service_fee := app.money_round(app.setting_numeric('ordering.service_fee', 0));
  v_tip := app.money_round(greatest(coalesce(p_tip_amount, 0), 0));

  -- ── Loyalty redemption ──
  if p_loyalty_points > 0 and public.feature_enabled('loyalty', p_user_id) then
    v_loyalty_points := least(
      p_loyalty_points,
      coalesce((select points_balance from public.loyalty_accounts where user_id = p_user_id), 0)
    );

    v_loyalty_discount := app.money_round(
      v_loyalty_points * app.setting_numeric('loyalty.redeem_value_per_point', 0.25)
    );

    -- Cap redemption at a configured share of the order.
    v_loyalty_discount := least(
      v_loyalty_discount,
      app.money_round(v_items_subtotal * app.setting_numeric('loyalty.max_redeem_percent', 20) / 100)
    );
  end if;

  -- ── Grand total ──
  v_pre_round := (v_items_subtotal - v_total_discount)
                 + v_packaging + v_delivery_fee + v_service_fee + v_tip
                 - v_loyalty_discount;

  -- Inclusive GST is already inside the item price, so it is not added again.
  if exists (
    select 1 from jsonb_array_elements(v_priced_lines) l
    where not (l ->> 'tax_inclusive')::boolean and (l ->> 'tax_amount')::numeric > 0
  ) then
    v_pre_round := v_pre_round + coalesce((
      select sum((l ->> 'tax_amount')::numeric)
      from jsonb_array_elements(v_priced_lines) l
      where not (l ->> 'tax_inclusive')::boolean
    ), 0);
  end if;

  v_pre_round := greatest(app.money_round(v_pre_round), 0);

  if app.setting_bool('ordering.round_off_enabled', true) then
    v_grand_total := round(v_pre_round);
    v_round_off := app.money_round(v_grand_total - v_pre_round);
  else
    v_grand_total := v_pre_round;
    v_round_off := 0;
  end if;

  -- ── Wallet ──
  if v_cart.use_wallet and public.feature_enabled('wallet', p_user_id) then
    select coalesce(balance, 0) into v_wallet_balance
    from public.wallet_accounts where user_id = p_user_id and not is_frozen;

    v_wallet_applied := least(coalesce(v_wallet_balance, 0), v_grand_total);
  end if;

  v_payable := app.money_round(v_grand_total - v_wallet_applied);

  -- ── COD eligibility ──
  if v_payment_mode in ('COD', 'SPLIT_WALLET_COD') then
    if not app.setting_bool('cod.enabled', true) or not public.feature_enabled('cod') then
      v_issues := v_issues || jsonb_build_array(jsonb_build_object(
        'code', 'COD_UNAVAILABLE', 'severity', 'BLOCKING',
        'message', 'Cash on delivery is currently unavailable.'
      ));
    elsif v_cart.fulfilment_type = 'PICKUP' then
      v_issues := v_issues || jsonb_build_array(jsonb_build_object(
        'code', 'COD_UNAVAILABLE', 'severity', 'BLOCKING',
        'message', 'Pay at store instead of cash on delivery for pickup orders.'
      ));
    else
      v_cod_limit := least(
        coalesce(v_zone.max_cod_amount, 999999),
        app.setting_numeric('cod.max_amount', 2000)
      );

      if v_payable > v_cod_limit then
        v_issues := v_issues || jsonb_build_array(jsonb_build_object(
          'code', 'COD_LIMIT_EXCEEDED', 'severity', 'BLOCKING',
          'limit', v_cod_limit,
          'message', format('Cash on delivery is available up to ₹%s. Please pay online.',
                            to_char(v_cod_limit, 'FM999999990'))
        ));
      end if;

      if v_zone.zone_id is not null and not v_zone.cod_enabled then
        v_issues := v_issues || jsonb_build_array(jsonb_build_object(
          'code', 'COD_UNAVAILABLE', 'severity', 'BLOCKING',
          'message', 'Cash on delivery is not available in your area.'
        ));
      end if;

      if v_payable < app.setting_numeric('cod.min_order_amount', 0) then
        v_issues := v_issues || jsonb_build_array(jsonb_build_object(
          'code', 'COD_MIN_ORDER_NOT_MET', 'severity', 'BLOCKING',
          'message', 'Order value is too low for cash on delivery.'
        ));
      end if;
    end if;
  end if;

  -- ── Store state ──
  if not (v_branch_state ->> 'accepting_orders')::boolean then
    v_issues := v_issues || jsonb_build_array(jsonb_build_object(
      'code', coalesce(v_branch_state ->> 'reason_code', 'RESTAURANT_CLOSED'),
      'severity', case when v_cart.timing = 'SCHEDULED' then 'WARNING' else 'BLOCKING' end,
      'message', case
        when (v_branch_state ->> 'reason_code') = 'MAINTENANCE_MODE'
          then 'Bites Box is briefly under maintenance. Please try again shortly.'
        when (v_branch_state ->> 'reason_code') = 'OUTSIDE_TRADING_HOURS'
          then 'Our kitchen is closed right now. You can schedule an order for later.'
        when (v_branch_state ->> 'reason_code') = 'TOO_BUSY'
          then 'Our kitchen is at full capacity. Please try again in a few minutes.'
        else coalesce(v_branch_state ->> 'status_note', 'We are not accepting orders right now.')
      end
    ));
  end if;

  if v_item_count = 0 then
    v_issues := v_issues || jsonb_build_array(jsonb_build_object(
      'code', 'CART_EMPTY', 'severity', 'BLOCKING',
      'message', 'Your cart is empty.'
    ));
  end if;

  -- ── Promise time ──
  v_prep_minutes := greatest(
    coalesce((v_branch_state ->> 'prep_minutes')::int, 20),
    v_max_prep
  );

  return jsonb_build_object(
    'cart_id', v_cart.id,
    'branch_id', v_cart.branch_id,
    'currency_code', v_branch.currency_code,
    'fulfilment_type', v_cart.fulfilment_type,
    'timing', v_cart.timing,
    'scheduled_for', v_cart.scheduled_for,
    'address_id', v_cart.address_id,
    'payment_mode', v_payment_mode,
    'lines', v_priced_lines,
    'item_count', v_item_count,
    'unit_count', v_unit_count,
    'totals', jsonb_build_object(
      'items_subtotal', v_items_subtotal,
      'items_discount', v_items_discount,
      'coupon_discount', v_coupon_discount,
      'promotion_discount', v_promo_discount,
      'total_discount', v_total_discount,
      'taxable_amount', v_taxable,
      'tax_amount', v_tax_total,
      'cgst_amount', v_cgst,
      'sgst_amount', v_sgst,
      'igst_amount', v_igst,
      'cess_amount', v_cess,
      'packaging_charge', v_packaging,
      'delivery_fee', v_delivery_fee,
      'delivery_fee_waived', v_delivery_waived,
      'service_fee', v_service_fee,
      'tip_amount', v_tip,
      'loyalty_points_redeemed', v_loyalty_points,
      'loyalty_discount', v_loyalty_discount,
      'round_off', v_round_off,
      'grand_total', v_grand_total,
      'wallet_applied', v_wallet_applied,
      'wallet_balance', coalesce(v_wallet_balance, 0),
      'payable_amount', v_payable,
      'total_savings', app.money_round(v_total_discount + v_delivery_waived + v_loyalty_discount)
    ),
    'coupon', v_coupon,
    'promotion', v_promo,
    'delivery', jsonb_build_object(
      'zone_id', v_zone.zone_id,
      'zone_name', v_zone.zone_name,
      'distance_km', v_zone.distance_km,
      'min_order_amount', v_min_order,
      'free_delivery_threshold', v_zone.free_delivery_threshold,
      'eta_minutes', v_eta_minutes
    ),
    'timing_estimate', jsonb_build_object(
      'prep_minutes', v_prep_minutes,
      'delivery_minutes', v_eta_minutes,
      'total_minutes', v_prep_minutes + v_eta_minutes,
      'promised_at', p_at + make_interval(mins => v_prep_minutes + v_eta_minutes)
    ),
    'branch', v_branch_state,
    'issues', v_issues,
    'is_valid', not exists (
      select 1 from jsonb_array_elements(v_issues) i where i ->> 'severity' = 'BLOCKING'
    ),
    'calculated_at', p_at
  );
end;
$$;

comment on function app.calculate_checkout is
  'THE money authority. Called by the cart, the checkout screen and again inside create-order.';

-- ─── Public wrappers ───────────────────────────────────────────────────────
create or replace function public.calculate_checkout(
  p_cart_id uuid default null,
  p_branch_id uuid default null,
  p_payment_mode public.payment_mode default null,
  p_tip_amount numeric default 0,
  p_loyalty_points int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cart_id uuid := p_cart_id;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to continue.');
  end if;

  if v_cart_id is null then
    select id into v_cart_id
    from public.carts
    where user_id = v_uid
      and branch_id = coalesce(p_branch_id, app.default_branch_id())
      and is_active;
  end if;

  if v_cart_id is null then
    -- No cart yet: return an empty-but-valid shape so the UI can render.
    return jsonb_build_object(
      'cart_id', null,
      'branch_id', coalesce(p_branch_id, app.default_branch_id()),
      'lines', '[]'::jsonb,
      'item_count', 0,
      'unit_count', 0,
      'totals', jsonb_build_object(
        'items_subtotal', 0, 'total_discount', 0, 'tax_amount', 0,
        'packaging_charge', 0, 'delivery_fee', 0, 'grand_total', 0, 'payable_amount', 0
      ),
      'issues', jsonb_build_array(jsonb_build_object(
        'code', 'CART_EMPTY', 'severity', 'BLOCKING', 'message', 'Your cart is empty.'
      )),
      'is_valid', false,
      'branch', public.branch_ordering_state(coalesce(p_branch_id, app.default_branch_id()))
    );
  end if;

  return app.calculate_checkout(v_uid, v_cart_id, p_payment_mode, p_tip_amount, p_loyalty_points);
end;
$$;

create or replace function public.apply_coupon(
  p_code text,
  p_cart_id uuid default null,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cart public.carts;
  v_coupon_id uuid;
  v_result jsonb;
  v_evaluation jsonb;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to use offers.');
  end if;

  -- Throttle code guessing.
  if not app.consume_rate_limit('coupon_attempt', v_uid::text, 20, 300, 600) then
    perform app.fail('RATE_LIMITED', 'Too many coupon attempts. Please try again in a few minutes.');
  end if;

  v_cart := app.get_or_create_cart(v_uid, p_branch_id);

  select id into v_coupon_id from public.coupons
  where upper(code) = upper(btrim(p_code)) and deleted_at is null;

  if v_coupon_id is null then
    perform app.fail('COUPON_INVALID', 'This coupon code is not valid.');
  end if;

  -- Dry-run against the current cart before persisting the selection.
  update public.carts
  set coupon_id = v_coupon_id, coupon_code = upper(btrim(p_code)), updated_at = now()
  where id = v_cart.id;

  v_result := app.calculate_checkout(v_uid, v_cart.id);
  v_evaluation := v_result -> 'coupon';

  if not coalesce((v_evaluation ->> 'valid')::boolean, false) then
    -- Roll the selection back so an invalid coupon never sticks to the cart.
    update public.carts
    set coupon_id = null, coupon_code = null, updated_at = now()
    where id = v_cart.id;

    perform app.fail(
      coalesce(v_evaluation ->> 'reason_code', 'COUPON_INVALID'),
      coalesce(v_evaluation ->> 'message', 'This coupon cannot be applied.'),
      v_evaluation
    );
  end if;

  return v_result;
end;
$$;

create or replace function public.remove_coupon(p_branch_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cart public.carts;
begin
  v_cart := app.get_or_create_cart(v_uid, p_branch_id);

  update public.carts
  set coupon_id = null, coupon_code = null, updated_at = now()
  where id = v_cart.id;

  return app.calculate_checkout(v_uid, v_cart.id);
end;
$$;

-- Coupons the customer can actually use with their current cart.
create or replace function public.available_coupons(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_cart public.carts;
  v_calc jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_subtotal numeric := 0;
  v_coupon record;
  v_eval jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to see your offers.');
  end if;

  select * into v_cart from public.carts
  where user_id = v_uid and branch_id = v_branch and is_active;

  if found then
    v_calc := app.calculate_checkout(v_uid, v_cart.id);
    v_lines := coalesce(v_calc -> 'lines', '[]'::jsonb);
    v_subtotal := coalesce((v_calc #>> '{totals,items_subtotal}')::numeric, 0);
  end if;

  for v_coupon in
    select * from public.coupons
    where is_active and is_visible and deleted_at is null
      and starts_at <= now()
      and (ends_at is null or ends_at > now())
      and (branch_id is null or branch_id = v_branch)
    order by created_at desc
  loop
    v_eval := app.evaluate_coupon(
      v_coupon.id, v_uid, v_lines, v_subtotal,
      coalesce(v_cart.fulfilment_type, 'DELIVERY'::public.fulfilment_type),
      null, null, v_branch
    );

    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'id', v_coupon.id,
      'code', v_coupon.code,
      'title', v_coupon.title,
      'description', v_coupon.description,
      'terms', v_coupon.terms,
      'discount_kind', v_coupon.discount_kind,
      'discount_value', v_coupon.discount_value,
      'min_order_amount', v_coupon.min_order_amount,
      'max_discount_amount', v_coupon.max_discount_amount,
      'banner_path', v_coupon.banner_path,
      'ends_at', v_coupon.ends_at,
      'is_applicable', (v_eval ->> 'valid')::boolean,
      'reason_code', v_eval ->> 'reason_code',
      'reason', v_eval ->> 'message',
      'estimated_discount', coalesce((v_eval ->> 'discount_amount')::numeric, 0)
    ));
  end loop;

  return v_out;
end;
$$;

comment on function public.available_coupons is
  'Coupon sheet data: every visible coupon annotated with applicability for this cart.';
