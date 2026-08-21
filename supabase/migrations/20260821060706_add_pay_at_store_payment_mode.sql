-- Pickup orders are paid at the branch counter, not through Razorpay or COD.
-- Keep this as a first-class payment mode so the mobile checkout and the order
-- state machine use the same server-validated value.
alter type public.payment_mode add value if not exists 'PAY_AT_STORE';

-- Re-state order placement so pay-at-counter pickup orders enter the kitchen
-- immediately without being treated as COD or requiring Razorpay.
create or replace function app.place_order(
  p_user_id uuid,
  p_idempotency_key text,
  p_payment_mode public.payment_mode default 'ONLINE',
  p_cart_id uuid default null,
  p_branch_id uuid default null,
  p_tip_amount numeric default 0,
  p_loyalty_points int default 0,
  p_channel public.order_channel default 'MOBILE_APP',
  p_app_version text default null,
  p_device_platform public.device_platform default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cart public.carts;
  v_calc jsonb;
  v_totals jsonb;
  v_order public.orders;
  v_existing public.orders;
  v_address public.addresses;
  v_profile public.profiles;
  v_line jsonb;
  v_item_id uuid;
  v_mod jsonb;
  v_display int := 0;
  v_issues jsonb;
  v_first_issue jsonb;
  v_initial_status public.order_status;
  v_now timestamptz := now();
  v_prep int;
  v_delivery int;
begin
  if p_idempotency_key is null or length(btrim(p_idempotency_key)) < 8 then
    perform app.fail('IDEMPOTENCY_KEY_REQUIRED', 'A valid idempotency key is required.');
  end if;

  -- ── Idempotent replay ──
  select * into v_existing
  from public.orders
  where user_id = p_user_id and idempotency_key = p_idempotency_key;

  if found then
    return jsonb_build_object(
      'order_id', v_existing.id,
      'order_number', v_existing.order_number,
      'status', v_existing.status,
      'payment_mode', v_existing.payment_mode,
      'payable_amount', v_existing.payable_amount,
      'grand_total', v_existing.grand_total,
      'replayed', true
    );
  end if;

  if not app.account_is_active() and not app.is_service_role() then
    perform app.fail('ACCOUNT_BLOCKED', 'This account cannot place orders. Please contact support.');
  end if;

  -- Abuse guard: a burst of orders from one account is almost always a bug or fraud.
  if not app.consume_rate_limit('place_order', p_user_id::text, 10, 600, 900) then
    perform app.fail('RATE_LIMITED', 'Too many order attempts. Please wait a moment.');
  end if;

  select * into v_cart from public.carts
  where (p_cart_id is null or id = p_cart_id)
    and user_id = p_user_id
    and branch_id = coalesce(p_branch_id, app.default_branch_id())
    and is_active
  limit 1;

  if not found then
    perform app.fail('CART_EMPTY', 'Your cart is empty.');
  end if;

  -- Lock the cart so a second concurrent checkout cannot read the same lines.
  perform 1 from public.carts where id = v_cart.id for update;

  -- ── RECALCULATE. The client total is never used. ──
  v_calc := app.calculate_checkout(
    p_user_id, v_cart.id, p_payment_mode, p_tip_amount, p_loyalty_points, v_now
  );

  v_issues := coalesce(v_calc -> 'issues', '[]'::jsonb);

  if not coalesce((v_calc ->> 'is_valid')::boolean, false) then
    select i into v_first_issue
    from jsonb_array_elements(v_issues) i
    where i ->> 'severity' = 'BLOCKING'
    limit 1;

    perform app.fail(
      coalesce(v_first_issue ->> 'code', 'CHECKOUT_INVALID'),
      coalesce(v_first_issue ->> 'message', 'We could not place this order.'),
      jsonb_build_object('issues', v_issues)
    );
  end if;

  v_totals := v_calc -> 'totals';

  select * into v_profile from public.profiles where id = p_user_id;

  if v_cart.fulfilment_type = 'DELIVERY' then
    select * into v_address from public.addresses where id = v_cart.address_id;
  end if;

  -- ── Initial status by payment mode ──
  v_initial_status := case
    when (v_totals ->> 'payable_amount')::numeric <= 0 then 'PAYMENT_CONFIRMED'
    when p_payment_mode in ('COD', 'SPLIT_WALLET_COD', 'PAY_AT_STORE') then 'ORDER_PLACED'
    else 'PENDING_PAYMENT'
  end;

  v_prep := coalesce((v_calc #>> '{timing_estimate,prep_minutes}')::int, 20);
  v_delivery := coalesce((v_calc #>> '{timing_estimate,delivery_minutes}')::int, 0);

  insert into public.orders (
    order_number, branch_id, user_id, idempotency_key, channel, fulfilment_type,
    timing, scheduled_for, status,
    customer_name, customer_phone, customer_email,
    address_id, delivery_address_line1, delivery_address_line2, delivery_landmark,
    delivery_area, delivery_city, delivery_state, delivery_postal_code,
    delivery_latitude, delivery_longitude, delivery_instructions,
    delivery_contact_name, delivery_contact_phone,
    delivery_zone_id, delivery_zone_name, distance_km,
    currency_code, items_subtotal, items_discount,
    coupon_id, coupon_code, coupon_discount,
    promotion_id, promotion_discount, total_discount,
    taxable_amount, tax_amount, cgst_amount, sgst_amount, igst_amount, cess_amount,
    packaging_charge, delivery_fee, delivery_fee_waived, service_fee, tip_amount,
    round_off, wallet_applied, loyalty_points_redeemed, loyalty_discount,
    grand_total, payable_amount,
    payment_mode, payment_status, cod_status,
    prep_minutes_estimate, delivery_minutes_estimate, promised_at,
    customer_note, item_count, unit_count, is_first_order,
    app_version, device_platform, created_by
  )
  values (
    app.next_order_number(v_cart.branch_id), v_cart.branch_id, p_user_id,
    p_idempotency_key, p_channel, v_cart.fulfilment_type,
    v_cart.timing, v_cart.scheduled_for, v_initial_status,
    v_profile.full_name, v_profile.phone, v_profile.email,
    v_cart.address_id, v_address.address_line1, v_address.address_line2, v_address.landmark,
    v_address.area, v_address.city, v_address.state, v_address.postal_code,
    v_address.latitude, v_address.longitude,
    coalesce(v_cart.delivery_instructions, v_address.delivery_instructions),
    coalesce(v_address.contact_name, v_profile.full_name),
    coalesce(v_address.contact_phone, v_profile.phone),
    nullif(v_calc #>> '{delivery,zone_id}', '')::uuid,
    v_calc #>> '{delivery,zone_name}',
    nullif(v_calc #>> '{delivery,distance_km}', '')::numeric,
    coalesce(v_calc ->> 'currency_code', 'INR'),
    (v_totals ->> 'items_subtotal')::numeric,
    (v_totals ->> 'items_discount')::numeric,
    v_cart.coupon_id, v_cart.coupon_code, (v_totals ->> 'coupon_discount')::numeric,
    nullif(v_calc #>> '{promotion,promotion_id}', '')::uuid,
    (v_totals ->> 'promotion_discount')::numeric,
    (v_totals ->> 'total_discount')::numeric,
    (v_totals ->> 'taxable_amount')::numeric,
    (v_totals ->> 'tax_amount')::numeric,
    (v_totals ->> 'cgst_amount')::numeric,
    (v_totals ->> 'sgst_amount')::numeric,
    (v_totals ->> 'igst_amount')::numeric,
    (v_totals ->> 'cess_amount')::numeric,
    (v_totals ->> 'packaging_charge')::numeric,
    (v_totals ->> 'delivery_fee')::numeric,
    (v_totals ->> 'delivery_fee_waived')::numeric,
    (v_totals ->> 'service_fee')::numeric,
    (v_totals ->> 'tip_amount')::numeric,
    (v_totals ->> 'round_off')::numeric,
    (v_totals ->> 'wallet_applied')::numeric,
    (v_totals ->> 'loyalty_points_redeemed')::int,
    (v_totals ->> 'loyalty_discount')::numeric,
    (v_totals ->> 'grand_total')::numeric,
    (v_totals ->> 'payable_amount')::numeric,
    p_payment_mode,
    case when (v_totals ->> 'payable_amount')::numeric <= 0
         then 'CAPTURED'::public.payment_status
         else 'CREATED'::public.payment_status end,
    case when p_payment_mode in ('COD', 'SPLIT_WALLET_COD')
         then 'COD_PENDING'::public.cod_status else null end,
    v_prep, v_delivery,
    v_now + make_interval(mins => v_prep + v_delivery),
    v_cart.cooking_instructions,
    (v_calc ->> 'item_count')::int,
    (v_calc ->> 'unit_count')::int,
    coalesce(v_profile.completed_orders, 0) = 0,
    p_app_version, p_device_platform, p_user_id
  )
  returning * into v_order;

  -- ── Line snapshots ──
  for v_line in select * from jsonb_array_elements(v_calc -> 'lines') loop
    v_display := v_display + 1;

    insert into public.order_items (
      order_id, product_id, variant_id, category_id,
      product_name, product_slug, variant_name, variant_option_group, category_name,
      food_type, image_path, short_description,
      quantity, unit_price, modifiers_price, gross_amount,
      discount_amount, allocated_discount, net_amount, packaging_charge,
      tax_category_id, tax_rate, tax_inclusive, taxable_amount, tax_amount,
      cgst_amount, sgst_amount, igst_amount, cess_amount, hsn_sac_code,
      special_instructions, preparation_minutes, display_order
    )
    values (
      v_order.id,
      (v_line ->> 'product_id')::uuid,
      nullif(v_line ->> 'variant_id', '')::uuid,
      (v_line ->> 'category_id')::uuid,
      v_line ->> 'product_name',
      v_line ->> 'product_slug',
      v_line ->> 'variant_name',
      v_line ->> 'variant_option_group',
      v_line ->> 'category_name',
      (v_line ->> 'food_type')::public.food_type,
      v_line ->> 'image_path',
      v_line ->> 'short_description',
      (v_line ->> 'quantity')::smallint,
      (v_line ->> 'unit_price')::numeric,
      (v_line ->> 'modifiers_price')::numeric,
      (v_line ->> 'gross_amount')::numeric,
      0,
      (v_line ->> 'allocated_discount')::numeric,
      (v_line ->> 'net_amount')::numeric,
      (v_line ->> 'packaging_charge')::numeric,
      nullif(v_line ->> 'tax_category_id', '')::uuid,
      (v_line ->> 'tax_rate')::numeric,
      (v_line ->> 'tax_inclusive')::boolean,
      (v_line ->> 'taxable_amount')::numeric,
      (v_line ->> 'tax_amount')::numeric,
      case when (v_line ->> 'tax_rate')::numeric > 0
        then app.money_round((v_line ->> 'tax_amount')::numeric
             * (v_line ->> 'cgst_rate')::numeric / (v_line ->> 'tax_rate')::numeric)
        else 0 end,
      case when (v_line ->> 'tax_rate')::numeric > 0
        then app.money_round((v_line ->> 'tax_amount')::numeric
             * (v_line ->> 'sgst_rate')::numeric / (v_line ->> 'tax_rate')::numeric)
        else 0 end,
      case when (v_line ->> 'tax_rate')::numeric > 0
        then app.money_round((v_line ->> 'tax_amount')::numeric
             * (v_line ->> 'igst_rate')::numeric / (v_line ->> 'tax_rate')::numeric)
        else 0 end,
      app.money_round((v_line ->> 'taxable_amount')::numeric * (v_line ->> 'cess_rate')::numeric),
      v_line ->> 'hsn_sac_code',
      nullif(v_line ->> 'special_instructions', ''),
      (v_line ->> 'preparation_minutes')::int,
      v_display
    )
    returning id into v_item_id;

    for v_mod in select * from jsonb_array_elements(coalesce(v_line -> 'modifiers', '[]'::jsonb)) loop
      insert into public.order_item_modifiers (
        order_item_id, modifier_id, modifier_group_id, group_name, modifier_name,
        unit_price, quantity, total_price, food_type
      )
      values (
        v_item_id,
        (v_mod ->> 'modifier_id')::uuid,
        (v_mod ->> 'modifier_group_id')::uuid,
        v_mod ->> 'group_name',
        v_mod ->> 'modifier_name',
        (v_mod ->> 'unit_price')::numeric,
        (v_mod ->> 'quantity')::smallint,
        (v_mod ->> 'total_price')::numeric,
        (v_mod ->> 'food_type')::public.food_type
      );
    end loop;
  end loop;

  -- ── Coupon redemption (unique on order_id ⇒ never double counted) ──
  if v_order.coupon_id is not null and v_order.coupon_discount >= 0 then
    insert into public.coupon_redemptions (
      coupon_id, user_id, order_id, code, discount_amount, order_amount
    )
    values (
      v_order.coupon_id, p_user_id, v_order.id, v_order.coupon_code,
      v_order.coupon_discount, v_order.items_subtotal
    )
    on conflict (order_id) where order_id is not null do nothing;

    update public.coupons
    set total_used = total_used + 1, updated_at = now()
    where id = v_order.coupon_id;
  end if;

  -- ── Wallet debit ──
  if v_order.wallet_applied > 0 then
    perform app.post_wallet_entry(
      p_user_id, 'DEBIT', -v_order.wallet_applied,
      format('Paid towards order %s', v_order.order_number),
      v_order.id, null, 'wallet_debit:' || v_order.id::text
    );
  end if;

  -- ── Loyalty redemption ──
  if v_order.loyalty_points_redeemed > 0 then
    perform app.post_loyalty_entry(
      p_user_id, 'REDEEM', -v_order.loyalty_points_redeemed,
      format('Redeemed on order %s', v_order.order_number),
      v_order.id, v_order.loyalty_discount,
      'loyalty_redeem:' || v_order.id::text
    );
  end if;

  -- ── COD tracking row ──
  if p_payment_mode in ('COD', 'SPLIT_WALLET_COD') then
    insert into public.cod_collections (order_id, expected_amount)
    values (v_order.id, v_order.payable_amount)
    on conflict (order_id) do nothing;
  end if;

  -- ── Retire the cart ──
  update public.carts
  set is_active = false, converted_order_id = v_order.id, updated_at = now()
  where id = v_cart.id;

  -- ── Opening timeline entry ──
  insert into public.order_status_history (
    order_id, from_status, to_status, label, actor_id, actor_kind, metadata
  )
  values (
    v_order.id, null, v_initial_status,
    case v_initial_status
      when 'PENDING_PAYMENT' then 'Awaiting payment'
      when 'ORDER_PLACED' then 'Order placed'
      else 'Payment confirmed'
    end,
    p_user_id, 'USER',
    jsonb_build_object('channel', p_channel, 'payment_mode', p_payment_mode)
  );

  -- Fire the side effects for orders that skipped the payment step.
  if v_initial_status = 'ORDER_PLACED' then
    perform app.on_order_status_changed(v_order.id, null, 'ORDER_PLACED');
  elsif v_initial_status = 'PAYMENT_CONFIRMED' then
    perform app.on_order_status_changed(v_order.id, null, 'PAYMENT_CONFIRMED');
  end if;

  return jsonb_build_object(
    'order_id', v_order.id,
    'order_number', v_order.order_number,
    'status', v_order.status,
    'payment_mode', v_order.payment_mode,
    'payment_status', v_order.payment_status,
    'grand_total', v_order.grand_total,
    'payable_amount', v_order.payable_amount,
    'currency_code', v_order.currency_code,
    'requires_payment', v_order.status = 'PENDING_PAYMENT',
    'promised_at', v_order.promised_at,
    'replayed', false
  );
end;
$$;
