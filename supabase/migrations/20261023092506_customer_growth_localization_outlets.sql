-- Customer growth, localization, outlet selection and saved products.
-- Forward-only migration. Rollback is intentionally a new compensating migration:
-- customer attribution and wallet ledger entries must never be deleted in place.

alter table public.profiles
  add column preferred_branch_id uuid references public.branches (id) on delete set null;

-- Existing consent is preserved; only future account defaults change.
alter table public.profiles alter column marketing_opt_in set default false;

-- Older accounts may predate referral-code assignment. Backfill with a longer
-- CSPRNG code and retry unique collisions without changing codes already shared.
do $$
declare
  v_profile record;
  v_code text;
begin
  for v_profile in select id from public.profiles where referral_code is null loop
    loop
      v_code := 'BB' || app.random_alnum_code(10);
      begin
        update public.profiles set referral_code = v_code
        where id = v_profile.id and referral_code is null;
        exit;
      exception when unique_violation then
        -- Generate another code if this improbable unique collision occurs.
        null;
      end;
    end loop;
  end loop;
end;
$$;

alter table public.categories
  add column name_hi text,
  add column short_description_hi text,
  add column description_hi text;

alter table public.subcategories
  add column name_hi text,
  add column description_hi text;

alter table public.products
  add column name_hi text,
  add column short_description_hi text,
  add column description_hi text;

alter table public.product_variants
  add column name_hi text,
  add column option_group_hi text;

alter table public.modifier_groups
  add column name_hi text,
  add column description_hi text;

alter table public.modifiers
  add column name_hi text,
  add column description_hi text;

alter table public.cms_sections
  add column title_hi text,
  add column subtitle_hi text,
  add column action_label_hi text,
  add column rich_text_hi text;

alter table public.cms_banners
  add column title_hi text,
  add column subtitle_hi text,
  add column badge_text_hi text,
  add column alt_text_hi text;

alter table public.coupons
  add column title_hi text,
  add column description_hi text;

-- Explicitly editable bilingual fields. English remains canonical and is the
-- fallback when a Hindi value has not been reviewed and entered by staff.
comment on column public.products.name_hi is 'Human-reviewed Hindi product name; English name remains the fallback.';
comment on column public.products.description_hi is 'Human-reviewed Hindi product description; never machine-generated.';

-- Only a deliberately configured owner/admin program may issue rewards. The
-- feature flag remains an independent rollout gate and starts disabled.
insert into public.permissions (code, resource, action, label, description, is_sensitive)
values ('referral.manage', 'referral', 'manage', 'Manage referrals',
        'Configure the referral program and view attribution and reward activity.', true)
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'referral.manage'
where r.code in ('OWNER', 'ADMIN')
on conflict do nothing;

create table public.referral_program_settings (
  id boolean primary key default true check (id),
  enabled boolean not null default false,
  referrer_reward app.money,
  referred_reward app.money,
  minimum_order_amount app.money,
  max_rewards_per_referrer int,
  reward_expiry_days int,
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint referral_rewards_nonnegative check (
    (referrer_reward is null or referrer_reward >= 0)
    and (referred_reward is null or referred_reward >= 0)
    and (minimum_order_amount is null or minimum_order_amount >= 0)
  ),
  constraint referral_cap_bounds check (max_rewards_per_referrer is null or max_rewards_per_referrer between 1 and 1000),
  constraint referral_expiry_bounds check (reward_expiry_days is null or reward_expiry_days between 1 and 3650),
  constraint enabled_referral_terms check (
    not enabled or (
      referrer_reward > 0 and referred_reward > 0 and minimum_order_amount > 0
    )
  )
);

insert into public.referral_program_settings (id) values (true) on conflict do nothing;
alter table public.referral_program_settings enable row level security;
create policy referral_settings_admin_read on public.referral_program_settings
  for select to authenticated using (app.has_permission('referral.manage'));
revoke all on public.referral_program_settings from anon, authenticated;
grant select on public.referral_program_settings to authenticated;

create table public.referrals (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null references public.profiles (id) on delete restrict,
  referred_user_id uuid not null unique references public.profiles (id) on delete restrict,
  referral_code text not null,
  status text not null default 'ATTRIBUTED'
    check (status in ('ATTRIBUTED', 'QUALIFIED', 'REWARDED', 'REVERSED')),
  qualifying_order_id uuid references public.orders (id) on delete set null,
  branch_id uuid references public.branches (id) on delete set null,
  referrer_reward app.money not null default 0,
  referred_reward app.money not null default 0,
  referrer_recovered app.money not null default 0,
  referred_recovered app.money not null default 0,
  reversal_shortfall app.money not null default 0,
  attributed_at timestamptz not null default now(),
  qualified_at timestamptz,
  rewarded_at timestamptz,
  reversed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint referrals_not_self check (inviter_id <> referred_user_id)
);

create index referrals_inviter_recent_idx on public.referrals (inviter_id, created_at desc);
create index referrals_qualification_idx on public.referrals (status, qualified_at desc);
alter table public.referrals enable row level security;
create policy referrals_party_read on public.referrals
  for select to authenticated
  using (inviter_id = auth.uid() or referred_user_id = auth.uid()
         or app.has_permission('referral.manage'));
revoke all on public.referrals from anon, authenticated;
grant select on public.referrals to authenticated;

create table public.referral_events (
  id uuid primary key default gen_random_uuid(),
  referral_id uuid not null references public.referrals (id) on delete restrict,
  event_key text not null unique,
  event_type text not null check (event_type in ('ATTRIBUTED', 'QUALIFIED', 'REWARDED', 'REVERSED')),
  actor_id uuid references auth.users (id) on delete set null,
  beneficiary_id uuid references auth.users (id) on delete set null,
  order_id uuid references public.orders (id) on delete set null,
  amount app.money_signed,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index referral_events_referral_idx on public.referral_events (referral_id, created_at);
alter table public.referral_events enable row level security;
create policy referral_events_party_read on public.referral_events
  for select to authenticated using (
    beneficiary_id = auth.uid()
    or exists (select 1 from public.referrals r where r.id = referral_id and r.inviter_id = auth.uid())
    or app.has_permission('referral.manage')
  );
revoke all on public.referral_events from anon, authenticated;
grant select on public.referral_events to authenticated;

create table public.customer_favorites (
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);
create index customer_favorites_product_idx on public.customer_favorites (product_id);
alter table public.customer_favorites enable row level security;
create policy customer_favorites_owner_all on public.customer_favorites
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke all on public.customer_favorites from anon, authenticated;
grant select, insert, delete on public.customer_favorites to authenticated;

-- First-party storefront analytics deliberately omit user IDs, contact details,
-- search text, addresses, payment identifiers and browser fingerprints.
create table analytics.storefront_events (
  event_id uuid primary key,
  event_name text not null check (event_name in (
    'MENU_VIEW', 'SEARCH', 'PRODUCT_VIEW', 'SERVICEABILITY_SUCCESS',
    'SERVICEABILITY_FAILURE', 'CHECKOUT_START', 'CHECKOUT_COMPLETED'
  )),
  branch_id uuid references public.branches (id) on delete set null,
  product_id uuid references public.products (id) on delete set null,
  created_at timestamptz not null default now()
);
create index storefront_events_branch_time_idx on analytics.storefront_events (branch_id, created_at desc);

create or replace function public.record_storefront_event(
  p_event_id uuid,
  p_event_name text,
  p_branch_id uuid default null,
  p_product_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_event_id is null or p_event_name is null or p_event_name not in (
    'MENU_VIEW', 'SEARCH', 'PRODUCT_VIEW', 'SERVICEABILITY_SUCCESS',
    'SERVICEABILITY_FAILURE', 'CHECKOUT_START', 'CHECKOUT_COMPLETED'
  ) then
    perform app.fail('INVALID_ANALYTICS_EVENT', 'This storefront event is not supported.');
  end if;
  if p_branch_id is not null and not exists (
    select 1 from public.branches where id = p_branch_id and is_active and deleted_at is null
  ) then
    perform app.fail('BRANCH_UNAVAILABLE', 'This outlet is not available.');
  end if;
  if p_product_id is not null and not exists (
    select 1 from public.products where id = p_product_id and is_active and deleted_at is null
  ) then
    p_product_id := null;
  end if;
  if auth.uid() is not null then
    if not app.consume_rate_limit('storefront_event', auth.uid()::text, 120, 60, 120) then return false; end if;
  elsif not app.consume_rate_limit('storefront_event_anon', coalesce(p_branch_id::text, 'public'), 1000, 60, 60) then
    return false;
  end if;
  insert into analytics.storefront_events (event_id, event_name, branch_id, product_id)
  values (p_event_id, p_event_name, p_branch_id, p_product_id)
  on conflict (event_id) do nothing;
  return true;
end;
$$;

create or replace function public.storefront_event_metrics(
  p_branch_id uuid default null,
  p_from timestamptz default now() - interval '30 days',
  p_to timestamptz default now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not app.has_permission('analytics.view', p_branch_id) then
    perform app.fail('PERMISSION_DENIED', 'You cannot view storefront analytics for this outlet.');
  end if;
  return coalesce((
    select jsonb_object_agg(event_name, event_count)
    from (
      select event_name, count(*) as event_count
      from analytics.storefront_events
      where created_at >= p_from and created_at < p_to
        and (p_branch_id is null or branch_id = p_branch_id)
        and (p_branch_id is not null or app.has_permission('analytics.view', branch_id))
      group by event_name
    ) metrics
  ), '{}'::jsonb);
end;
$$;

create or replace function public.my_session()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
  v_roles jsonb;
  v_permissions text[];
  v_primary public.app_role;
  v_branches jsonb;
begin
  if v_uid is null then return jsonb_build_object('authenticated', false); end if;
  select * into v_profile from public.profiles where id = v_uid;
  select jsonb_agg(jsonb_build_object(
    'role', r.code, 'label', r.label, 'branch_id', ur.branch_id,
    'is_primary', ur.is_primary, 'surfaces', r.surfaces
  ) order by ur.is_primary desc, r.rank desc) into v_roles
  from public.user_roles ur join public.roles r on r.id = ur.role_id
  where ur.user_id = v_uid and ur.is_active and (ur.expires_at is null or ur.expires_at > now());
  select coalesce(array_agg(distinct p.code), '{}') into v_permissions
  from public.user_roles ur join public.role_permissions rp on rp.role_id = ur.role_id
  join public.permissions p on p.id = rp.permission_id
  where ur.user_id = v_uid and ur.is_active and (ur.expires_at is null or ur.expires_at > now());
  v_primary := app.primary_role();
  select jsonb_agg(jsonb_build_object('id', b.id, 'code', b.code, 'name', b.name, 'status', b.status)
                   order by b.display_order)
    into v_branches from public.branches b
    where b.deleted_at is null and b.is_active and app.can_access_branch(b.id);
  return jsonb_build_object(
    'authenticated', true, 'user_id', v_uid,
    'profile', case when v_profile.id is null then null else jsonb_build_object(
      'id', v_profile.id, 'phone', v_profile.phone, 'email', v_profile.email,
      'full_name', v_profile.full_name, 'avatar_url', v_profile.avatar_url,
      'status', v_profile.status, 'preferred_language', v_profile.preferred_language,
      'preferred_branch_id', v_profile.preferred_branch_id,
      'onboarding_completed', v_profile.onboarding_completed, 'total_orders', v_profile.total_orders,
      'marketing_opt_in', v_profile.marketing_opt_in, 'push_enabled', v_profile.push_enabled,
      'sms_enabled', v_profile.sms_enabled, 'email_enabled', v_profile.email_enabled,
      'whatsapp_enabled', v_profile.whatsapp_enabled
    ) end,
    'primary_role', v_primary, 'roles', coalesce(v_roles, '[]'::jsonb),
    'permissions', to_jsonb(coalesce(v_permissions, '{}')),
    'branches', coalesce(v_branches, '[]'::jsonb),
    'account_active', coalesce(v_profile.status = 'ACTIVE', false)
  );
end;
$$;

create or replace function public.set_preferred_branch(p_branch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then perform app.fail('UNAUTHENTICATED', 'Sign in to select an outlet.'); end if;
  if p_branch_id is not null and not exists (
    select 1 from public.branches b where b.id = p_branch_id and b.is_active and b.deleted_at is null
  ) then
    perform app.fail('BRANCH_UNAVAILABLE', 'This outlet is no longer available.');
  end if;
  update public.profiles set preferred_branch_id = p_branch_id, updated_at = now()
  where id = auth.uid();
  return jsonb_build_object('branch_id', p_branch_id);
end;
$$;

create or replace function public.public_outlets()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', b.id, 'name', b.name, 'slug', b.slug, 'city', b.city,
      'state', b.state, 'postal_code', b.postal_code,
      'service_mode', b.service_mode, 'display_order', b.display_order,
      'ordering', public.branch_ordering_state(b.id)
    ) order by b.display_order, b.name
  ), '[]'::jsonb)
  from public.branches b
  where b.is_active and b.deleted_at is null;
$$;

create or replace function public.public_storefront_offers(
  p_branch_id uuid default null,
  p_locale text default 'en'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  if not exists (
    select 1 from public.branches b where b.id = v_branch and b.is_active and b.deleted_at is null
  ) then
    perform app.fail('BRANCH_UNAVAILABLE', 'This outlet is not available.');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id,
      'code', c.code,
      'title', case when p_locale = 'hi' then coalesce(c.title_hi, c.title) else c.title end,
      'description', case when p_locale = 'hi' then coalesce(c.description_hi, c.description) else c.description end,
      'terms', c.terms,
      'discount_kind', c.discount_kind,
      'discount_value', c.discount_value,
      'min_order_amount', c.min_order_amount,
      'max_discount_amount', c.max_discount_amount,
      'ends_at', c.ends_at
    ) order by c.created_at desc)
    from public.coupons c
    where c.is_active and c.is_visible and c.deleted_at is null
      and c.starts_at <= now() and (c.ends_at is null or c.ends_at > now())
      and (c.branch_id is null or c.branch_id = v_branch)
  ), '[]'::jsonb);
end;
$$;

create or replace function public.serviceable_outlets(p_latitude numeric, p_longitude numeric)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.id, 'name', b.name, 'slug', b.slug, 'city', b.city,
    'serviceability', public.check_serviceability(p_latitude,p_longitude,b.id,0)
  ) order by b.display_order, b.name), '[]'::jsonb)
  from public.branches b
  where b.is_active and b.deleted_at is null;
$$;

create or replace function public.localized_menu_catalog(
  p_branch_id uuid default null,
  p_category_id uuid default null,
  p_locale text default 'en'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb := public.menu_catalog(p_branch_id, p_category_id);
  v_item jsonb;
  v_sub jsonb;
  v_name text;
  v_short text;
  v_description text;
  v_variant jsonb;
  v_option_group text;
begin
  if p_locale <> 'hi' then return v_result; end if;

  for v_item in select value from jsonb_array_elements(coalesce(v_result -> 'categories', '[]'::jsonb)) loop
    select c.name_hi, c.short_description_hi, c.description_hi into v_name, v_short, v_description
    from public.categories c where c.id = (v_item ->> 'id')::uuid;
    if v_name is not null then v_item := jsonb_set(v_item, '{name}', to_jsonb(v_name), true); end if;
    if v_short is not null then v_item := jsonb_set(v_item, '{short_description}', to_jsonb(v_short), true); end if;
    if v_description is not null then v_item := jsonb_set(v_item, '{description}', to_jsonb(v_description), true); end if;
    if jsonb_typeof(v_item -> 'subcategories') = 'array' then
      for v_sub in select value from jsonb_array_elements(v_item -> 'subcategories') loop
        select sc.name_hi, sc.description_hi into v_name, v_description from public.subcategories sc where sc.id = (v_sub ->> 'id')::uuid;
        if v_name is not null then v_sub := jsonb_set(v_sub, '{name}', to_jsonb(v_name), true); end if;
        if v_description is not null then v_sub := jsonb_set(v_sub, '{description}', to_jsonb(v_description), true); end if;
        v_item := jsonb_set(v_item, '{subcategories}', (
          select jsonb_agg(case when item ->> 'id' = v_sub ->> 'id' then v_sub else item end)
          from jsonb_array_elements(v_item -> 'subcategories') as elements(item)
        ), true);
      end loop;
    end if;
    v_result := jsonb_set(v_result, '{categories}', (
      select jsonb_agg(case when item ->> 'id' = v_item ->> 'id' then v_item else item end)
      from jsonb_array_elements(v_result -> 'categories') as elements(item)
    ), true);
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(v_result -> 'products', '[]'::jsonb)) loop
    select p.name_hi, p.short_description_hi, p.description_hi into v_name, v_short, v_description
    from public.products p where p.id = (v_item ->> 'id')::uuid;
    if v_name is not null then v_item := jsonb_set(v_item, '{name}', to_jsonb(v_name), true); end if;
    if v_short is not null then v_item := jsonb_set(v_item, '{short_description}', to_jsonb(v_short), true); end if;
    if v_description is not null then v_item := jsonb_set(v_item, '{description}', to_jsonb(v_description), true); end if;
    for v_variant in select value from jsonb_array_elements(coalesce(v_item -> 'variants', '[]'::jsonb)) loop
      select pv.name_hi, pv.option_group_hi into v_name, v_option_group
      from public.product_variants pv where pv.id = (v_variant ->> 'id')::uuid;
      if v_name is not null then v_variant := jsonb_set(v_variant, '{name}', to_jsonb(v_name), true); end if;
      if v_option_group is not null then v_variant := jsonb_set(v_variant, '{option_group}', to_jsonb(v_option_group), true); end if;
      v_item := jsonb_set(v_item, '{variants}', (
        select jsonb_agg(case when item ->> 'id' = v_variant ->> 'id' then v_variant else item end)
        from jsonb_array_elements(v_item -> 'variants') as elements(item)
      ), true);
    end loop;
    v_result := jsonb_set(v_result, '{products}', (
      select jsonb_agg(case when item ->> 'id' = v_item ->> 'id' then v_item else item end)
      from jsonb_array_elements(v_result -> 'products') as elements(item)
    ), true);
  end loop;
  return v_result;
end;
$$;

create or replace function public.localized_product_detail(
  p_product_id uuid default null,
  p_slug text default null,
  p_branch_id uuid default null,
  p_locale text default 'en'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb := public.product_detail(p_product_id, p_slug, p_branch_id);
  v_product public.products;
  v_category public.categories;
  v_variant jsonb;
  v_group jsonb;
  v_modifier jsonb;
  v_name text;
  v_description text;
  v_option_group text;
begin
  if p_locale <> 'hi' then return v_result; end if;
  select * into v_product from public.products where id = (v_result ->> 'id')::uuid;
  select * into v_category from public.categories where id = v_product.category_id;
  if v_product.name_hi is not null then v_result := jsonb_set(v_result, '{name}', to_jsonb(v_product.name_hi), true); end if;
  if v_product.short_description_hi is not null then v_result := jsonb_set(v_result, '{short_description}', to_jsonb(v_product.short_description_hi), true); end if;
  if v_product.description_hi is not null then v_result := jsonb_set(v_result, '{description}', to_jsonb(v_product.description_hi), true); end if;
  if v_category.name_hi is not null then v_result := jsonb_set(v_result, '{category_name}', to_jsonb(v_category.name_hi), true); end if;
  for v_variant in select value from jsonb_array_elements(coalesce(v_result -> 'variants', '[]'::jsonb)) loop
    select pv.name_hi, pv.option_group_hi into v_name, v_option_group
    from public.product_variants pv where pv.id = (v_variant ->> 'id')::uuid;
    if v_name is not null then v_variant := jsonb_set(v_variant, '{name}', to_jsonb(v_name), true); end if;
    if v_option_group is not null then v_variant := jsonb_set(v_variant, '{option_group}', to_jsonb(v_option_group), true); end if;
    v_result := jsonb_set(v_result, '{variants}', (
      select jsonb_agg(case when item ->> 'id' = v_variant ->> 'id' then v_variant else item end)
      from jsonb_array_elements(v_result -> 'variants') as elements(item)
    ), true);
  end loop;
  for v_group in select value from jsonb_array_elements(coalesce(v_result -> 'modifier_groups', '[]'::jsonb)) loop
    select mg.name_hi, mg.description_hi into v_name, v_description
    from public.modifier_groups mg where mg.id = (v_group ->> 'id')::uuid;
    if v_name is not null then v_group := jsonb_set(v_group, '{name}', to_jsonb(v_name), true); end if;
    if v_description is not null then v_group := jsonb_set(v_group, '{description}', to_jsonb(v_description), true); end if;
    for v_modifier in select value from jsonb_array_elements(coalesce(v_group -> 'modifiers', '[]'::jsonb)) loop
      select m.name_hi, m.description_hi into v_name, v_description
      from public.modifiers m where m.id = (v_modifier ->> 'id')::uuid;
      if v_name is not null then v_modifier := jsonb_set(v_modifier, '{name}', to_jsonb(v_name), true); end if;
      if v_description is not null then v_modifier := jsonb_set(v_modifier, '{description}', to_jsonb(v_description), true); end if;
      v_group := jsonb_set(v_group, '{modifiers}', (
        select jsonb_agg(case when item ->> 'id' = v_modifier ->> 'id' then v_modifier else item end)
        from jsonb_array_elements(v_group -> 'modifiers') as elements(item)
      ), true);
    end loop;
    v_result := jsonb_set(v_result, '{modifier_groups}', (
      select jsonb_agg(case when item ->> 'id' = v_group ->> 'id' then v_group else item end)
      from jsonb_array_elements(v_result -> 'modifier_groups') as elements(item)
    ), true);
  end loop;
  return v_result;
end;
$$;

create or replace function public.localized_search_menu(
  p_query text,
  p_branch_id uuid default null,
  p_limit int default 30,
  p_locale text default 'en'
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_result jsonb := public.search_menu(p_query,p_branch_id,p_limit);
  v_item jsonb;
  v_name text;
  v_short text;
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_products jsonb;
  v_hindi_products jsonb;
  v_categories jsonb;
  v_hindi_categories jsonb;
begin
  if p_locale <> 'hi' then return v_result; end if;
  -- Search the original English index as well as human-entered Hindi names.
  -- Never machine-translate names, allergens, or promotional claims.
  v_products := coalesce(v_result -> 'products', '[]'::jsonb);
  v_categories := coalesce(v_result -> 'categories', '[]'::jsonb);
  v_hindi_products := coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'name', coalesce(p.name_hi, p.name), 'slug', p.slug,
      'short_description', coalesce(p.short_description_hi, p.short_description),
      'thumbnail_path', p.thumbnail_path, 'category_id', p.category_id,
      'category_name', coalesce(c.name_hi, c.name), 'food_type', p.food_type,
      'base_price', p.base_price, 'compare_price', p.compare_price,
      'rating_average', p.rating_average, 'rating_count', p.rating_count,
      'is_best_seller', p.is_best_seller, 'is_available', app.product_orderable(p.id, v_branch),
      'min_price', coalesce((select min(pv.price) from public.product_variants pv
        where pv.product_id = p.id and pv.is_active and pv.deleted_at is null), p.base_price),
      'has_variants', exists (select 1 from public.product_variants pv
        where pv.product_id = p.id and pv.is_active and pv.deleted_at is null),
      'rank', case when lower(p.name_hi) like lower(btrim(p_query)) || '%' then 5 else 2 end
    ) order by p.display_order, p.name)
    from public.products p
    join public.categories c on c.id = p.category_id
    where p_locale = 'hi' and length(btrim(coalesce(p_query, ''))) >= 2
      and p.name_hi is not null
      and lower(p.name_hi) like '%' || lower(btrim(p_query)) || '%'
      and p.is_active and p.deleted_at is null and c.is_active and c.deleted_at is null
      and (p.branch_id is null or p.branch_id = v_branch)
      and not exists (select 1 from jsonb_array_elements(v_products) existing
        where existing ->> 'id' = p.id::text)
  ), '[]'::jsonb);
  v_hindi_categories := coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'name', coalesce(c.name_hi, c.name), 'slug', c.slug,
      'thumbnail_path', c.thumbnail_path
    ) order by c.display_order)
    from public.categories c
    where c.is_active and c.deleted_at is null
      and (c.branch_id is null or c.branch_id = v_branch)
      and c.name_hi is not null
      and lower(c.name_hi) like '%' || lower(btrim(coalesce(p_query, ''))) || '%'
      and not exists (select 1 from jsonb_array_elements(v_categories) existing
        where existing ->> 'id' = c.id::text)
  ), '[]'::jsonb);
  for v_item in select value from jsonb_array_elements(coalesce(v_result -> 'products','[]'::jsonb)) loop
    select p.name_hi,p.short_description_hi into v_name,v_short from public.products p where p.id=(v_item->>'id')::uuid;
    if v_name is not null then v_item:=jsonb_set(v_item,'{name}',to_jsonb(v_name),true); end if;
    if v_short is not null then v_item:=jsonb_set(v_item,'{short_description}',to_jsonb(v_short),true); end if;
    v_result:=jsonb_set(v_result,'{products}',(
      select jsonb_agg(case when item->>'id'=v_item->>'id' then v_item else item end)
      from jsonb_array_elements(v_result->'products') as elements(item)
    ),true);
  end loop;
  for v_item in select value from jsonb_array_elements(coalesce(v_result -> 'categories','[]'::jsonb)) loop
    select c.name_hi into v_name from public.categories c where c.id=(v_item->>'id')::uuid;
    if v_name is not null then v_item:=jsonb_set(v_item,'{name}',to_jsonb(v_name),true); end if;
    v_result:=jsonb_set(v_result,'{categories}',(
      select jsonb_agg(case when item->>'id'=v_item->>'id' then v_item else item end)
      from jsonb_array_elements(v_result->'categories') as elements(item)
    ),true);
  end loop;
  v_products := coalesce(v_result -> 'products', '[]'::jsonb) || coalesce(v_hindi_products, '[]'::jsonb);
  v_categories := coalesce(v_result -> 'categories', '[]'::jsonb) || coalesce(v_hindi_categories, '[]'::jsonb);
  v_products := (
    select coalesce(jsonb_agg(item order by (item ->> 'rank')::numeric desc, item ->> 'name'), '[]'::jsonb)
    from (select value as item from jsonb_array_elements(v_products)
          order by (value ->> 'rank')::numeric desc, value ->> 'name'
          limit least(coalesce(p_limit, 30), 60)) ranked
  );
  v_result := jsonb_set(v_result, '{products}', v_products, true);
  v_result := jsonb_set(v_result, '{categories}', v_categories, true);
  v_result := jsonb_set(v_result, '{count}', to_jsonb(jsonb_array_length(v_products)), true);
  return v_result;
end;
$$;

create or replace function public.localized_home_feed(p_branch_id uuid default null, p_locale text default 'en')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb := public.home_feed(p_branch_id);
  v_section jsonb;
  v_item jsonb;
  v_title text;
  v_subtitle text;
  v_action text;
  v_rich text;
begin
  if p_locale <> 'hi' then return v_result; end if;
  for v_section in select value from jsonb_array_elements(coalesce(v_result->'sections','[]'::jsonb)) loop
    select s.title_hi,s.subtitle_hi,s.action_label_hi,s.rich_text_hi
      into v_title,v_subtitle,v_action,v_rich
    from public.cms_sections s where s.id=(v_section->>'id')::uuid;
    if v_title is not null then v_section:=jsonb_set(v_section,'{title}',to_jsonb(v_title),true); end if;
    if v_subtitle is not null then v_section:=jsonb_set(v_section,'{subtitle}',to_jsonb(v_subtitle),true); end if;
    if v_action is not null then v_section:=jsonb_set(v_section,'{action_label}',to_jsonb(v_action),true); end if;
    if v_rich is not null then v_section:=jsonb_set(v_section,'{rich_text}',to_jsonb(v_rich),true); end if;
    for v_item in select value from jsonb_array_elements(coalesce(v_section->'products','[]'::jsonb)) loop
      select p.name_hi,p.short_description_hi into v_title,v_subtitle from public.products p where p.id=(v_item->>'id')::uuid;
      if v_title is not null then v_item:=jsonb_set(v_item,'{name}',to_jsonb(v_title),true); end if;
      if v_subtitle is not null then v_item:=jsonb_set(v_item,'{short_description}',to_jsonb(v_subtitle),true); end if;
      v_section:=jsonb_set(v_section,'{products}',(
        select jsonb_agg(case when item->>'id'=v_item->>'id' then v_item else item end)
        from jsonb_array_elements(v_section->'products') as elements(item)
      ),true);
    end loop;
    for v_item in select value from jsonb_array_elements(coalesce(v_section->'categories','[]'::jsonb)) loop
      select c.name_hi into v_title from public.categories c where c.id=(v_item->>'id')::uuid;
      if v_title is not null then v_item:=jsonb_set(v_item,'{name}',to_jsonb(v_title),true); end if;
      v_section:=jsonb_set(v_section,'{categories}',(
        select jsonb_agg(case when item->>'id'=v_item->>'id' then v_item else item end)
        from jsonb_array_elements(v_section->'categories') as elements(item)
      ),true);
    end loop;
    for v_item in select value from jsonb_array_elements(coalesce(v_section->'banners','[]'::jsonb)) loop
      select b.title_hi,b.subtitle_hi,b.badge_text_hi,b.alt_text_hi into v_title,v_subtitle,v_action,v_rich
      from public.cms_banners b where b.id=(v_item->>'id')::uuid;
      if v_title is not null then v_item:=jsonb_set(v_item,'{title}',to_jsonb(v_title),true); end if;
      if v_subtitle is not null then v_item:=jsonb_set(v_item,'{subtitle}',to_jsonb(v_subtitle),true); end if;
      if v_action is not null then v_item:=jsonb_set(v_item,'{badge_text}',to_jsonb(v_action),true); end if;
      if v_rich is not null then v_item:=jsonb_set(v_item,'{alt_text}',to_jsonb(v_rich),true); end if;
      v_section:=jsonb_set(v_section,'{banners}',(
        select jsonb_agg(case when item->>'id'=v_item->>'id' then v_item else item end)
        from jsonb_array_elements(v_section->'banners') as elements(item)
      ),true);
    end loop;
    for v_item in select value from jsonb_array_elements(coalesce(v_section->'coupons','[]'::jsonb)) loop
      select c.title_hi,c.description_hi into v_title,v_subtitle from public.coupons c where c.id=(v_item->>'id')::uuid;
      if v_title is not null then v_item:=jsonb_set(v_item,'{title}',to_jsonb(v_title),true); end if;
      if v_subtitle is not null then v_item:=jsonb_set(v_item,'{description}',to_jsonb(v_subtitle),true); end if;
      v_section:=jsonb_set(v_section,'{coupons}',(
        select jsonb_agg(case when item->>'id'=v_item->>'id' then v_item else item end)
        from jsonb_array_elements(v_section->'coupons') as elements(item)
      ),true);
    end loop;
    v_result:=jsonb_set(v_result,'{sections}',(
      select jsonb_agg(case when item->>'id'=v_section->>'id' then v_section else item end)
      from jsonb_array_elements(v_result->'sections') as elements(item)
    ),true);
  end loop;
  return v_result;
end;
$$;

create or replace function public.localized_available_coupons(
  p_branch_id uuid default null,
  p_locale text default 'en'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb := public.available_coupons(p_branch_id);
  v_item jsonb;
  v_title text;
  v_description text;
begin
  if p_locale <> 'hi' then return v_result; end if;
  for v_item in select value from jsonb_array_elements(coalesce(v_result, '[]'::jsonb)) loop
    select c.title_hi, c.description_hi into v_title, v_description
    from public.coupons c where c.id = (v_item ->> 'id')::uuid;
    if v_title is not null then v_item := jsonb_set(v_item, '{title}', to_jsonb(v_title), true); end if;
    if v_description is not null then v_item := jsonb_set(v_item, '{description}', to_jsonb(v_description), true); end if;
    v_result := (
      select jsonb_agg(case when item ->> 'id' = v_item ->> 'id' then v_item else item end)
      from jsonb_array_elements(v_result) as elements(item)
    );
  end loop;
  return coalesce(v_result, '[]'::jsonb);
end;
$$;

create or replace function public.set_my_favorite(p_product_id uuid, p_favorite boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then perform app.fail('UNAUTHENTICATED', 'Sign in to save favorites.'); end if;
  if coalesce(p_favorite, false) then
    if not exists (
      select 1 from public.products p
      where p.id = p_product_id and p.is_active and p.deleted_at is null
    ) then
      perform app.fail('ITEM_NOT_FOUND', 'This dish is no longer available to save.');
    end if;
    insert into public.customer_favorites (user_id, product_id)
    values (auth.uid(), p_product_id)
    on conflict (user_id, product_id) do nothing;
  else
    delete from public.customer_favorites where user_id = auth.uid() and product_id = p_product_id;
  end if;
  return jsonb_build_object('product_id', p_product_id, 'is_favorite', coalesce(p_favorite, false));
end;
$$;

create or replace function public.my_favorites(p_branch_id uuid default null, p_locale text default 'en')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  if auth.uid() is null then perform app.fail('UNAUTHENTICATED', 'Sign in to view favorites.'); end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'name', case when p_locale = 'hi' then coalesce(p.name_hi, p.name) else p.name end,
      'slug', p.slug,
      'description', case when p_locale = 'hi' then coalesce(p.description_hi, p.description) else p.description end,
      'short_description', case when p_locale = 'hi' then coalesce(p.short_description_hi, p.short_description) else p.short_description end,
      'thumbnail_path', p.thumbnail_path, 'base_price', p.base_price,
      'food_type', p.food_type, 'is_active', p.is_active and p.deleted_at is null,
      'is_available', p.is_active and p.deleted_at is null and app.product_orderable(p.id, v_branch),
      'created_at', f.created_at
    ) order by f.created_at desc)
    from public.customer_favorites f join public.products p on p.id = f.product_id
    where f.user_id = auth.uid()
  ), '[]'::jsonb);
end;
$$;

create or replace function public.attribute_referral(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
  v_inviter public.profiles;
  v_code text := upper(btrim(coalesce(p_code, '')));
begin
  if v_uid is null then perform app.fail('UNAUTHENTICATED', 'Sign in to use a referral code.'); end if;
  if not exists (
    select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id
    where ur.user_id = v_uid and ur.is_active and r.code = 'CUSTOMER'
  ) then perform app.fail('PERMISSION_DENIED', 'Only customer accounts can use referral codes.'); end if;
  if not app.consume_rate_limit('referral-code', v_uid::text, 8, 3600, 1800) then
    perform app.fail('RATE_LIMITED', 'Too many referral attempts. Please try again later.');
  end if;
  if not public.feature_enabled('referrals') then
    perform app.fail('FEATURE_UNAVAILABLE', 'The referral program is not active yet.');
  end if;
  if not exists (select 1 from public.referral_program_settings s where s.id and s.enabled) then
    perform app.fail('FEATURE_UNAVAILABLE', 'The referral program is not configured yet.');
  end if;
  select * into v_profile from public.profiles where id = v_uid for update;
  if v_profile.referred_by is not null or exists (select 1 from public.referrals where referred_user_id = v_uid) then
    perform app.fail('REFERRAL_ALREADY_USED', 'A referral code has already been applied to this account.');
  end if;
  if exists (
    select 1 from public.orders o where o.user_id = v_uid
      and o.status in ('DELIVERED', 'COMPLETED') and o.payment_status = 'CAPTURED'
  ) then perform app.fail('REFERRAL_ORDER_EXISTS', 'A referral code must be applied before your first eligible order.'); end if;
  select * into v_inviter from public.profiles where referral_code = v_code and id <> v_uid and status = 'ACTIVE';
  if not found or not exists (
    select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id
    where ur.user_id = v_inviter.id and ur.is_active and r.code = 'CUSTOMER'
  ) then perform app.fail('INVALID_REFERRAL_CODE', 'That referral code is not valid.'); end if;
  insert into public.referrals (inviter_id, referred_user_id, referral_code)
  values (v_inviter.id, v_uid, v_code);
  update public.profiles set referred_by = v_inviter.id where id = v_uid;
  insert into public.referral_events (referral_id, event_key, event_type, actor_id, beneficiary_id)
  select r.id, 'referral:' || r.id::text || ':attributed', 'ATTRIBUTED', v_uid, v_inviter.id
  from public.referrals r where r.referred_user_id = v_uid;
  return jsonb_build_object('attributed', true, 'referral_code', v_code);
end;
$$;

create or replace function public.my_referral_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then perform app.fail('UNAUTHENTICATED', 'Sign in to view referrals.'); end if;
  return jsonb_build_object(
    'code', (select referral_code from public.profiles where id = v_uid),
    'share_path', (select '/r/' || referral_code from public.profiles where id = v_uid),
    'program_active', public.feature_enabled('referrals') and exists (
      select 1 from public.referral_program_settings s where s.id and s.enabled
    ),
    'attributed_count', (select count(*) from public.referrals where inviter_id = v_uid),
    'qualified_count', (select count(*) from public.referrals where inviter_id = v_uid and status in ('QUALIFIED','REWARDED','REVERSED')),
    'rewarded_count', (select count(*) from public.referrals where inviter_id = v_uid and rewarded_at is not null),
    'referrals', coalesce((
      select jsonb_agg(jsonb_build_object('status', r.status, 'attributed_at', r.attributed_at,
        'qualified_at', r.qualified_at, 'rewarded_at', r.rewarded_at) order by r.created_at desc)
      from public.referrals r where r.inviter_id = v_uid
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.update_referral_program(
  p_enabled boolean,
  p_referrer_reward numeric,
  p_referred_reward numeric,
  p_minimum_order_amount numeric,
  p_max_rewards_per_referrer int,
  p_reward_expiry_days int default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb;
  v_new jsonb;
begin
  if not app.has_permission('referral.manage') or coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    perform app.fail('MFA_REQUIRED', 'An authorized owner or administrator with verified MFA is required.');
  end if;
  if p_referrer_reward <= 0 or p_referred_reward <= 0 or p_minimum_order_amount <= 0
     or (p_max_rewards_per_referrer is not null and (p_max_rewards_per_referrer < 1 or p_max_rewards_per_referrer > 1000))
     or (p_reward_expiry_days is not null and (p_reward_expiry_days < 1 or p_reward_expiry_days > 3650)) then
    perform app.fail('INVALID_REFERRAL_TERMS', 'Enter positive reward and order amounts and valid caps/expiry.');
  end if;
  select to_jsonb(s) - 'updated_by' into v_old
  from public.referral_program_settings s where s.id;
  v_new := jsonb_build_object(
    'enabled', coalesce(p_enabled, false),
    'referrer_reward', p_referrer_reward,
    'referred_reward', p_referred_reward,
    'minimum_order_amount', p_minimum_order_amount,
    'max_rewards_per_referrer', p_max_rewards_per_referrer,
    'reward_expiry_days', p_reward_expiry_days
  );
  insert into public.referral_program_settings as s (
    id, enabled, referrer_reward, referred_reward, minimum_order_amount,
    max_rewards_per_referrer, reward_expiry_days, updated_by, updated_at
  ) values (true, coalesce(p_enabled, false), p_referrer_reward, p_referred_reward,
            p_minimum_order_amount, p_max_rewards_per_referrer, p_reward_expiry_days, auth.uid(), now())
  on conflict (id) do update set enabled = excluded.enabled,
    referrer_reward = excluded.referrer_reward, referred_reward = excluded.referred_reward,
    minimum_order_amount = excluded.minimum_order_amount,
    max_rewards_per_referrer = excluded.max_rewards_per_referrer,
    reward_expiry_days = excluded.reward_expiry_days,
    updated_by = excluded.updated_by, updated_at = excluded.updated_at;
  perform app.audit(
    'SETTINGS_CHANGE', 'referral_program_settings', 'true', v_old, v_new,
    'Referral program terms changed', null, null
  );
  return jsonb_build_object('enabled', coalesce(p_enabled, false), 'configured', true,
    'feature_flag_enabled', public.feature_enabled('referrals'));
end;
$$;

create or replace function public.save_menu_translations(
  p_product_id uuid,
  p_translations jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
  v_variant jsonb;
  v_group jsonb;
  v_modifier jsonb;
  v_variant_id uuid;
  v_group_id uuid;
  v_modifier_id uuid;
  v_old jsonb;
begin
  if auth.uid() is null then perform app.fail('UNAUTHENTICATED', 'Sign in to update menu translations.'); end if;
  if jsonb_typeof(p_translations) <> 'object' then
    perform app.fail('INVALID_INPUT', 'Translation content is invalid.');
  end if;
  select p.branch_id into v_branch_id from public.products p
  where p.id = p_product_id and p.deleted_at is null for update;
  if not found then perform app.fail('ITEM_NOT_FOUND', 'This dish is no longer on the menu.'); end if;
  perform app.require_permission('menu.update', v_branch_id);
  select jsonb_build_object(
    'product', jsonb_build_object('name_hi', p.name_hi, 'short_description_hi', p.short_description_hi, 'description_hi', p.description_hi),
    'variants', coalesce((select jsonb_agg(jsonb_build_object('id', v.id, 'name_hi', v.name_hi, 'option_group_hi', v.option_group_hi)) from public.product_variants v where v.product_id = p.id), '[]'::jsonb),
    'modifier_groups', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'name_hi', g.name_hi, 'description_hi', g.description_hi))
      from public.product_modifier_groups pmg join public.modifier_groups g on g.id = pmg.modifier_group_id where pmg.product_id = p.id), '[]'::jsonb)
  ) into v_old from public.products p where p.id = p_product_id;

  if jsonb_typeof(p_translations -> 'product') = 'object' then
    update public.products set
      name_hi = nullif(btrim(p_translations #>> '{product,name_hi}'), ''),
      short_description_hi = nullif(btrim(p_translations #>> '{product,short_description_hi}'), ''),
      description_hi = nullif(btrim(p_translations #>> '{product,description_hi}'), '')
    where id = p_product_id;
  end if;
  if p_translations ? 'variants' then
    if jsonb_typeof(p_translations -> 'variants') <> 'array' then perform app.fail('INVALID_INPUT', 'Variant translations must be a list.'); end if;
    for v_variant in select value from jsonb_array_elements(p_translations -> 'variants') loop
      v_variant_id := (v_variant ->> 'id')::uuid;
      update public.product_variants set
        name_hi = nullif(btrim(v_variant ->> 'name_hi'), ''),
        option_group_hi = nullif(btrim(v_variant ->> 'option_group_hi'), '')
      where id = v_variant_id and product_id = p_product_id;
      if not found then perform app.fail('INVALID_INPUT', 'A variant does not belong to this dish.'); end if;
    end loop;
  end if;
  if p_translations ? 'modifier_groups' then
    if jsonb_typeof(p_translations -> 'modifier_groups') <> 'array' then perform app.fail('INVALID_INPUT', 'Modifier group translations must be a list.'); end if;
    for v_group in select value from jsonb_array_elements(p_translations -> 'modifier_groups') loop
      v_group_id := (v_group ->> 'id')::uuid;
      update public.modifier_groups g set
        name_hi = nullif(btrim(v_group ->> 'name_hi'), ''),
        description_hi = nullif(btrim(v_group ->> 'description_hi'), '')
      where g.id = v_group_id and exists (
        select 1 from public.product_modifier_groups pmg where pmg.product_id = p_product_id and pmg.modifier_group_id = g.id
      );
      if not found then perform app.fail('INVALID_INPUT', 'A modifier group does not belong to this dish.'); end if;
      if v_group ? 'modifiers' then
        if jsonb_typeof(v_group -> 'modifiers') <> 'array' then perform app.fail('INVALID_INPUT', 'Modifier translations must be a list.'); end if;
        for v_modifier in select value from jsonb_array_elements(v_group -> 'modifiers') loop
          v_modifier_id := (v_modifier ->> 'id')::uuid;
          update public.modifiers set
            name_hi = nullif(btrim(v_modifier ->> 'name_hi'), ''),
            description_hi = nullif(btrim(v_modifier ->> 'description_hi'), '')
          where id = v_modifier_id and modifier_group_id = v_group_id;
          if not found then perform app.fail('INVALID_INPUT', 'A modifier does not belong to this group.'); end if;
        end loop;
      end if;
    end loop;
  end if;
  perform app.audit(
    'BULK_UPDATE', 'menu_translations', p_product_id::text, v_old, p_translations,
    'Human-reviewed Hindi menu copy changed', null, v_branch_id
  );
  return jsonb_build_object('product_id', p_product_id, 'saved', true);
end;
$$;

create or replace function public.referral_admin_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app.has_permission('referral.manage') or coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    perform app.fail('MFA_REQUIRED', 'An authorized owner or administrator with verified MFA is required.');
  end if;
  return jsonb_build_object(
    'settings', (select to_jsonb(s) - 'updated_by' from public.referral_program_settings s where s.id),
    'feature_flag_enabled', public.feature_enabled('referrals'),
    'metrics', jsonb_build_object(
      'codes_issued', (select count(*) from public.profiles where referral_code is not null and status = 'ACTIVE'),
      'attributed', (select count(*) from public.referrals),
      'qualified', (select count(*) from public.referrals where status in ('QUALIFIED','REWARDED','REVERSED')),
      'rewarded', (select count(*) from public.referrals where rewarded_at is not null),
      'reversed', (select count(*) from public.referrals where status = 'REVERSED'),
      'first_order_conversion_rate', case
        when (select count(*) from public.referrals) = 0 then 0
        else round((select count(*) from public.referrals where status in ('QUALIFIED','REWARDED','REVERSED'))::numeric
          / (select count(*) from public.referrals), 4)
      end
    ),
    'activity', coalesce((select jsonb_agg(jsonb_build_object(
      'id', r.id, 'status', r.status, 'referral_code', r.referral_code,
      'qualifying_order_id', r.qualifying_order_id, 'branch_id', r.branch_id,
      'referrer_reward', r.referrer_reward, 'referred_reward', r.referred_reward,
      'reversal_shortfall', r.reversal_shortfall, 'attributed_at', r.attributed_at,
      'qualified_at', r.qualified_at, 'rewarded_at', r.rewarded_at, 'reversed_at', r.reversed_at
    ) order by r.created_at desc) from (select * from public.referrals order by created_at desc limit 100) r), '[]'::jsonb)
  );
end;
$$;

create or replace function app.try_qualify_referral(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_referral public.referrals;
  v_settings public.referral_program_settings;
  v_first_eligible boolean;
  v_expiry timestamptz;
  v_shortfall numeric := 0;
begin
  select * into v_order from public.orders where id = p_order_id;
  if not found or v_order.status not in ('DELIVERED','COMPLETED') or v_order.payment_status <> 'CAPTURED'
     or v_order.refunded_amount > 0 then return; end if;
  if v_order.payment_mode in ('COD','SPLIT_WALLET_COD') and not exists (
    select 1 from public.cod_collections cc where cc.order_id = v_order.id and cc.status = 'COD_COLLECTED' and cc.settled_at is not null
  ) then return; end if;

  select * into v_referral from public.referrals where referred_user_id = v_order.user_id for update;
  if not found or v_referral.status <> 'ATTRIBUTED' then return; end if;
  select * into v_settings from public.referral_program_settings where id and enabled;
  if not found or not public.feature_enabled('referrals') or v_order.grand_total < v_settings.minimum_order_amount then return; end if;
  select not exists (
    select 1 from public.orders prior
    where prior.user_id = v_order.user_id and prior.id <> v_order.id
      and prior.status in ('DELIVERED','COMPLETED') and prior.payment_status = 'CAPTURED'
      and prior.refunded_amount = 0
      and prior.created_at <= v_order.created_at
  ) into v_first_eligible;
  if not v_first_eligible then return; end if;
  if v_settings.max_rewards_per_referrer is not null and
     (select count(*) from public.referrals where inviter_id = v_referral.inviter_id and status in ('REWARDED','REVERSED'))
       >= v_settings.max_rewards_per_referrer then return; end if;

  update public.referrals set status = 'QUALIFIED', qualifying_order_id = v_order.id,
    branch_id = v_order.branch_id, qualified_at = now(),
    referrer_reward = v_settings.referrer_reward, referred_reward = v_settings.referred_reward
  where id = v_referral.id;
  insert into public.referral_events (referral_id,event_key,event_type,actor_id,order_id,details)
  values (v_referral.id, 'referral:' || v_referral.id::text || ':qualified', 'QUALIFIED', null,
    v_order.id, jsonb_build_object('branch_id',v_order.branch_id,'minimum_met',true))
  on conflict (event_key) do nothing;

  v_expiry := case when v_settings.reward_expiry_days is null then null
    else now() + make_interval(days => v_settings.reward_expiry_days) end;
  -- Sort user IDs before locking wallet rows to avoid reciprocal referral deadlocks.
  if v_referral.inviter_id < v_referral.referred_user_id then
    perform app.post_wallet_entry(v_referral.inviter_id,'PROMOTION',v_settings.referrer_reward,
      'Referral reward',null,null,'referral:' || v_referral.id::text || ':inviter',v_expiry);
    perform app.post_wallet_entry(v_referral.referred_user_id,'PROMOTION',v_settings.referred_reward,
      'Welcome referral reward',v_order.id,null,'referral:' || v_referral.id::text || ':referred',v_expiry);
  else
    perform app.post_wallet_entry(v_referral.referred_user_id,'PROMOTION',v_settings.referred_reward,
      'Welcome referral reward',v_order.id,null,'referral:' || v_referral.id::text || ':referred',v_expiry);
    perform app.post_wallet_entry(v_referral.inviter_id,'PROMOTION',v_settings.referrer_reward,
      'Referral reward',null,null,'referral:' || v_referral.id::text || ':inviter',v_expiry);
  end if;
  update public.referrals set status = 'REWARDED', rewarded_at = now() where id = v_referral.id;
  insert into public.referral_events (referral_id,event_key,event_type,beneficiary_id,order_id,amount)
  values
    (v_referral.id,'referral:' || v_referral.id::text || ':rewarded:inviter','REWARDED',v_referral.inviter_id,v_order.id,v_settings.referrer_reward),
    (v_referral.id,'referral:' || v_referral.id::text || ':rewarded:referred','REWARDED',v_referral.referred_user_id,v_order.id,v_settings.referred_reward)
  on conflict (event_key) do nothing;
end;
$$;

create or replace function app.on_order_referral_state_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.try_qualify_referral(new.id);
  return new;
end;
$$;

create trigger orders_try_referral_reward
  after insert or update of status, payment_status, refunded_amount on public.orders
  for each row execute function app.on_order_referral_state_change();

create or replace function app.on_cod_settlement_try_referral()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.settled_at is not null and old.settled_at is null then
    perform app.try_qualify_referral(new.order_id);
  end if;
  return new;
end;
$$;

create trigger cod_settlement_try_referral
  after update of settled_at on public.cod_collections
  for each row execute function app.on_cod_settlement_try_referral();

create or replace function app.reverse_referral_on_refund()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_referral public.referrals;
  v_recipient record;
  v_balance numeric;
  v_recover numeric;
  v_shortfall numeric := 0;
  v_inviter_recovered numeric := 0;
  v_referred_recovered numeric := 0;
begin
  if new.status <> 'COMPLETED' or old.status = 'COMPLETED' then return new; end if;
  select * into v_referral from public.referrals where qualifying_order_id = new.order_id for update;
  if not found or v_referral.status <> 'REWARDED' then return new; end if;
  for v_recipient in
    select * from (values
      (v_referral.inviter_id, v_referral.referrer_reward, 'inviter'),
      (v_referral.referred_user_id, v_referral.referred_reward, 'referred')
    ) as recipients(user_id, amount, recipient_key)
    order by user_id
  loop
    select wa.balance into v_balance from public.wallet_accounts wa where wa.user_id = v_recipient.user_id for update;
    v_recover := least(coalesce(v_balance,0), v_recipient.amount);
    if v_recover > 0 then
      perform app.post_wallet_entry(v_recipient.user_id,'REVERSAL',-v_recover,
        'Referral reward reversal',new.order_id,new.id,
        'referral:' || v_referral.id::text || ':reversal:' || v_recipient.recipient_key,null);
    end if;
    v_shortfall := v_shortfall + v_recipient.amount - v_recover;
    if v_recipient.recipient_key = 'inviter' then v_inviter_recovered := v_recover;
    else v_referred_recovered := v_recover; end if;
  end loop;
  update public.referrals set status = 'REVERSED', reversed_at = now(),
    referrer_recovered = v_inviter_recovered, referred_recovered = v_referred_recovered,
    reversal_shortfall = v_shortfall
  where id = v_referral.id;
  insert into public.referral_events (referral_id,event_key,event_type,actor_id,order_id,amount,details)
  values (v_referral.id,'referral:' || v_referral.id::text || ':reversed','REVERSED',new.approved_by,
    new.order_id,-(v_inviter_recovered + v_referred_recovered),
    jsonb_build_object('refund_id',new.id,'refund_amount',new.amount_processed,'shortfall',v_shortfall,
      'policy','any completed partial or full refund reverses all unspent referral wallet credit'))
  on conflict (event_key) do nothing;
  return new;
end;
$$;

create trigger refunds_reverse_referral_reward
  after update of status on public.refunds
  for each row execute function app.reverse_referral_on_refund();

grant execute on function public.set_preferred_branch(uuid) to authenticated;
grant execute on function public.public_outlets() to anon, authenticated;
grant execute on function public.public_storefront_offers(uuid,text) to anon, authenticated;
grant execute on function public.serviceable_outlets(numeric,numeric) to anon, authenticated;
grant execute on function public.localized_menu_catalog(uuid,uuid,text) to anon, authenticated;
grant execute on function public.localized_product_detail(uuid,text,uuid,text) to anon, authenticated;
grant execute on function public.localized_search_menu(text,uuid,int,text) to anon, authenticated;
grant execute on function public.localized_home_feed(uuid,text) to anon, authenticated;
grant execute on function public.localized_available_coupons(uuid,text) to authenticated;
grant execute on function public.save_menu_translations(uuid,jsonb) to authenticated;
grant execute on function public.set_my_favorite(uuid,boolean) to authenticated;
grant execute on function public.my_favorites(uuid,text) to authenticated;
grant execute on function public.attribute_referral(text) to authenticated;
grant execute on function public.my_referral_summary() to authenticated;
grant execute on function public.update_referral_program(boolean,numeric,numeric,numeric,int,int) to authenticated;
grant execute on function public.referral_admin_overview() to authenticated;
grant execute on function public.record_storefront_event(uuid,text,uuid,uuid) to anon, authenticated;
grant execute on function public.storefront_event_metrics(uuid,timestamptz,timestamptz) to authenticated;

revoke all on function public.public_outlets() from public;
revoke all on function public.public_storefront_offers(uuid,text) from public;
revoke all on function public.serviceable_outlets(numeric,numeric) from public;
revoke all on function public.localized_menu_catalog(uuid,uuid,text) from public;
revoke all on function public.localized_product_detail(uuid,text,uuid,text) from public;
revoke all on function public.localized_search_menu(text,uuid,int,text) from public;
revoke all on function public.localized_home_feed(uuid,text) from public;
revoke all on function public.localized_available_coupons(uuid,text) from public, anon;
revoke all on function public.save_menu_translations(uuid,jsonb) from public, anon;
grant execute on function public.public_outlets() to anon, authenticated;
grant execute on function public.public_storefront_offers(uuid,text) to anon, authenticated;
grant execute on function public.serviceable_outlets(numeric,numeric) to anon, authenticated;
grant execute on function public.localized_menu_catalog(uuid,uuid,text) to anon, authenticated;
grant execute on function public.localized_product_detail(uuid,text,uuid,text) to anon, authenticated;
grant execute on function public.localized_search_menu(text,uuid,int,text) to anon, authenticated;
grant execute on function public.localized_home_feed(uuid,text) to anon, authenticated;
grant execute on function public.localized_available_coupons(uuid,text) to authenticated;
grant execute on function public.save_menu_translations(uuid,jsonb) to authenticated;

revoke all on function public.set_preferred_branch(uuid) from public, anon;
revoke all on function public.set_my_favorite(uuid,boolean) from public, anon;
revoke all on function public.my_favorites(uuid,text) from public, anon;
revoke all on function public.attribute_referral(text) from public, anon;
revoke all on function public.my_referral_summary() from public, anon;
revoke all on function public.update_referral_program(boolean,numeric,numeric,numeric,int,int) from public, anon;
revoke all on function public.referral_admin_overview() from public, anon;
revoke all on function public.record_storefront_event(uuid,text,uuid,uuid) from public;
revoke all on function public.storefront_event_metrics(uuid,timestamptz,timestamptz) from public, anon;
grant execute on function public.set_preferred_branch(uuid) to authenticated;
grant execute on function public.set_my_favorite(uuid,boolean) to authenticated;
grant execute on function public.my_favorites(uuid,text) to authenticated;
grant execute on function public.attribute_referral(text) to authenticated;
grant execute on function public.my_referral_summary() to authenticated;
grant execute on function public.update_referral_program(boolean,numeric,numeric,numeric,int,int) to authenticated;
grant execute on function public.referral_admin_overview() to authenticated;
grant execute on function public.record_storefront_event(uuid,text,uuid,uuid) to anon, authenticated;
grant execute on function public.storefront_event_metrics(uuid,timestamptz,timestamptz) to authenticated;
revoke all on function public.attribute_referral(text) from public, anon;
revoke all on function public.my_referral_summary() from public, anon;
revoke all on function public.update_referral_program(boolean,numeric,numeric,numeric,int,int) from public, anon;
revoke all on function public.referral_admin_overview() from public, anon;
revoke all on function public.record_storefront_event(uuid,text,uuid,uuid) from public;
revoke all on function public.storefront_event_metrics(uuid,timestamptz,timestamptz) from public, anon;

comment on function public.attribute_referral is 'One-time server-validated referral attribution. Applies before the first qualifying paid and delivered order.';
comment on function app.try_qualify_referral is 'Rewards only the first delivered, fully captured, not-refunded order; COD must also be settled.';
