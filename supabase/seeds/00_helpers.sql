-- ═══════════════════════════════════════════════════════════════════════════
-- SEED 00 · HELPERS
--
-- The Supabase CLI prepares every statement in a seed file as a single batch, so
-- a function cannot be created and called in the same file. Helpers therefore
-- live here, in the private `app` schema, and are dropped by 90_finish.sql.
--
-- These helpers exist so the seed exercises the REAL code paths — app.place_order,
-- app.transition_order, complete_delivery, request_refund — rather than writing
-- order rows by hand. A regression in the pricing engine or state machine makes
-- `supabase db reset` fail loudly instead of silently producing bad data.
-- ═══════════════════════════════════════════════════════════════════════════

-- Run as the service role so the seed can drive the real business functions.
select set_config('request.jwt.claims', '{"role":"service_role"}', false);

create or replace function app.seed_user(
  p_id uuid,
  p_phone text,
  p_email text,
  p_full_name text
)
returns uuid
language plpgsql
as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    phone, phone_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, last_sign_in_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  )
  values (
    '00000000-0000-0000-0000-000000000000',
    p_id,
    'authenticated',
    'authenticated',
    p_email,
    extensions.crypt('Password123!', extensions.gen_salt('bf')),
    now(),
    app.normalize_phone(p_phone),
    now(),
    jsonb_build_object('provider', 'phone', 'providers', array['phone', 'email']),
    jsonb_build_object('full_name', p_full_name, 'phone', app.normalize_phone(p_phone),
                       'signup_channel', 'seed'),
    now() - interval '90 days',
    now(),
    now() - interval '1 day',
    '', '', '', ''
  );

  insert into auth.identities (
    id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  values (
    gen_random_uuid(), p_id, p_id::text,
    jsonb_build_object('sub', p_id::text, 'email', p_email, 'email_verified', true,
                       'phone', app.normalize_phone(p_phone), 'phone_verified', true),
    'email', now(), now(), now()
  );

  return p_id;
end;
$$;

create or replace function app.seed_grant_role(
  p_user_id uuid,
  p_role public.app_role,
  p_branch_id uuid default '11111111-1111-1111-1111-111111111111',
  p_primary boolean default true
)
returns void
language plpgsql
as $$
declare
  v_role_id uuid;
begin
  select id into v_role_id from public.roles where code = p_role;

  -- The signup trigger already granted CUSTOMER as primary; demote it first.
  if p_primary then
    update public.user_roles set is_primary = false
    where user_id = p_user_id and is_primary;
  end if;

  insert into public.user_roles (user_id, role_id, branch_id, is_primary, assigned_by)
  values (
    p_user_id, v_role_id,
    case when p_role in ('OWNER', 'ADMIN') then null else p_branch_id end,
    p_primary, p_user_id
  )
  on conflict do nothing;
end;
$$;

create or replace function app.seed_cart_item(
  p_cart_id uuid,
  p_product_slug text,
  p_variant_name text default null,
  p_quantity smallint default 1,
  p_modifier_names text[] default '{}',
  p_instructions text default null
)
returns uuid
language plpgsql
as $$
declare
  v_product_id uuid;
  v_variant_id uuid;
  v_mods jsonb := '[]'::jsonb;
  v_name text;
  v_mod_id uuid;
  v_item_id uuid;
begin
  select id into v_product_id from public.products where slug = p_product_slug;

  if v_product_id is null then
    raise exception 'Seed error: product % not found', p_product_slug;
  end if;

  if p_variant_name is not null then
    select id into v_variant_id from public.product_variants
    where product_id = v_product_id and name = p_variant_name and deleted_at is null;
  else
    select id into v_variant_id from public.product_variants
    where product_id = v_product_id and is_default and deleted_at is null;
  end if;

  foreach v_name in array coalesce(p_modifier_names, '{}') loop
    select m.id into v_mod_id
    from public.modifiers m
    join public.product_modifier_groups pmg on pmg.modifier_group_id = m.modifier_group_id
    where pmg.product_id = v_product_id and m.name = v_name
    limit 1;

    if v_mod_id is null then
      raise exception 'Seed error: modifier % not valid for %', v_name, p_product_slug;
    end if;

    v_mods := v_mods || jsonb_build_array(jsonb_build_object('modifier_id', v_mod_id, 'quantity', 1));
  end loop;

  insert into public.cart_items (cart_id, product_id, variant_id, quantity, special_instructions, config_hash)
  values (
    p_cart_id, v_product_id, v_variant_id, p_quantity, p_instructions,
    app.cart_config_hash(v_product_id, v_variant_id, v_mods, p_instructions)
  )
  returning id into v_item_id;

  insert into public.cart_item_modifiers (cart_item_id, modifier_id, quantity)
  select v_item_id, (m ->> 'modifier_id')::uuid, (m ->> 'quantity')::smallint
  from jsonb_array_elements(v_mods) m;

  return v_item_id;
end;
$$;

create or replace function app.seed_cart(
  p_user_id uuid,
  p_address_id uuid default null,
  p_fulfilment public.fulfilment_type default 'DELIVERY',
  p_coupon_code text default null
)
returns uuid
language plpgsql
as $$
declare
  v_cart_id uuid;
  v_coupon_id uuid;
begin
  -- Retire any previous cart for this customer so each demo order is isolated.
  update public.carts set is_active = false
  where user_id = p_user_id and is_active and converted_order_id is null;

  if p_coupon_code is not null then
    select id into v_coupon_id from public.coupons where upper(code) = upper(p_coupon_code);
  end if;

  insert into public.carts (user_id, branch_id, fulfilment_type, address_id, coupon_id, coupon_code)
  values (
    p_user_id, '11111111-1111-1111-1111-111111111111', p_fulfilment,
    case when p_fulfilment = 'DELIVERY' then p_address_id else null end,
    v_coupon_id, upper(p_coupon_code)
  )
  returning id into v_cart_id;

  return v_cart_id;
end;
$$;

create or replace function app.seed_capture_payment(
  p_order_id uuid,
  p_method public.payment_method default 'UPI'
)
returns void
language plpgsql
as $$
declare
  v_order public.orders;
  v_payment_id uuid;
begin
  select * into v_order from public.orders where id = p_order_id;

  insert into public.payments (
    order_id, user_id, branch_id, gateway, mode, method, status,
    amount, idempotency_key, provider_order_id, provider_payment_id,
    provider_signature, attempt_number, expires_at
  )
  values (
    p_order_id, v_order.user_id, v_order.branch_id, 'RAZORPAY', 'ONLINE', p_method, 'CREATED',
    v_order.payable_amount,
    'seed_pay:' || p_order_id::text,
    'order_seed' || substr(replace(p_order_id::text, '-', ''), 1, 14),
    'pay_seed' || substr(replace(p_order_id::text, '-', ''), 1, 16),
    'seed-signature', 1, now() + interval '15 minutes'
  )
  returning id into v_payment_id;

  -- Callback first, then the webhook — exactly the real double-verification path.
  perform app.record_payment_capture(
    v_payment_id,
    'pay_seed' || substr(replace(p_order_id::text, '-', ''), 1, 16),
    v_order.payable_amount, p_method, 'CALLBACK',
    case p_method
      when 'UPI' then jsonb_build_object('vpa', 'customer@upi')
      when 'CARD' then jsonb_build_object('last4', '4242', 'network', 'Visa')
      else '{}'::jsonb
    end
  );

  perform app.record_payment_capture(
    v_payment_id,
    'pay_seed' || substr(replace(p_order_id::text, '-', ''), 1, 16),
    v_order.payable_amount, p_method, 'WEBHOOK', '{}'::jsonb,
    round(v_order.payable_amount * 0.02, 2), round(v_order.payable_amount * 0.0036, 2)
  );

  insert into public.payment_events (
    payment_id, order_id, gateway, provider_event_id, event_type, source,
    signature_verified, payload, processed, processed_at
  )
  values (
    v_payment_id, p_order_id, 'RAZORPAY',
    'evt_seed' || substr(replace(p_order_id::text, '-', ''), 1, 16),
    'payment.captured', 'WEBHOOK', true,
    jsonb_build_object('event', 'payment.captured', 'seeded', true), true, now()
  );
end;
$$;

-- Recovers the plaintext of a seeded verification code by brute-forcing the
-- 4-digit space against its stored salt. Only possible because the seed created
-- the code moments earlier; production never needs (or has) this ability.
create or replace function app.seed_recover_code(
  p_order_id uuid,
  p_purpose text
)
returns text
language plpgsql
as $$
declare
  v_salt text;
  v_hash text;
  v_code text;
begin
  select salt, code_hash into v_salt, v_hash
  from public.verification_codes
  where order_id = p_order_id and purpose = p_purpose and consumed_at is null
  order by created_at desc
  limit 1;

  if v_salt is null then
    raise exception 'Seed error: no active % code for order %', p_purpose, p_order_id;
  end if;

  select lpad(i::text, 4, '0') into v_code
  from generate_series(0, 9999) i
  where app.hash_code(lpad(i::text, 4, '0'), v_salt) = v_hash
  limit 1;

  if v_code is null then
    raise exception 'Seed error: could not recover % code for order %', p_purpose, p_order_id;
  end if;

  return v_code;
end;
$$;
