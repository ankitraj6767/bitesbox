-- ═══════════════════════════════════════════════════════════════════════════
-- 0006 · ADDRESSES, SERVICEABILITY & CART
--
-- Serviceability is evaluated three times, always server-side:
--   1. when the customer picks a location
--   2. before checkout is rendered
--   3. again inside create-order, immediately before the order row is written
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Saved addresses ───────────────────────────────────────────────────────
create table public.addresses (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users (id) on delete cascade,
  label               text not null default 'HOME',
  contact_name        text,
  contact_phone       app.phone,

  address_line1       text not null,
  address_line2       text,
  landmark            text,
  area                text,
  city                text not null,
  state               text not null,
  postal_code         text,
  country_code        char(2) not null default 'IN',

  latitude            app.latitude not null,
  longitude           app.longitude not null,
  -- Raw string returned by reverse geocoding, kept for support investigations.
  formatted_address   text,
  google_place_id     text,
  -- Distinguishes a GPS fix from a map pin the customer dragged.
  location_source     text not null default 'GPS',

  delivery_instructions text,
  -- Cached resolution so the cart does not re-run geo maths on every read.
  resolved_zone_id    uuid references public.delivery_zones (id) on delete set null,
  resolved_branch_id  uuid references public.branches (id) on delete set null,
  distance_km         numeric(6, 2),
  is_serviceable      boolean,
  serviceability_checked_at timestamptz,

  is_default          boolean not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,

  constraint addresses_label check (label in ('HOME', 'WORK', 'HOTEL', 'OTHER')),
  constraint addresses_source check (location_source in ('GPS', 'MAP_PIN', 'MANUAL', 'GEOCODED'))
);

create index addresses_user_idx on public.addresses (user_id) where deleted_at is null;
create unique index addresses_single_default on public.addresses (user_id)
  where is_default and deleted_at is null;

select app.attach_updated_at('public.addresses');

-- Guarantees the customer always has exactly one default address.
create or replace function app.tg_addresses_single_default()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_default then
    update public.addresses
    set is_default = false, updated_at = now()
    where user_id = new.user_id
      and id <> new.id
      and is_default
      and deleted_at is null;
  elsif not exists (
    select 1 from public.addresses
    where user_id = new.user_id and is_default and deleted_at is null and id <> new.id
  ) then
    new.is_default := true;
  end if;

  return new;
end;
$$;

create trigger addresses_single_default
  before insert or update of is_default on public.addresses
  for each row execute function app.tg_addresses_single_default();

-- ═══════════════════════════════════════════════════════════════════════════
-- SERVICEABILITY ENGINE
-- ═══════════════════════════════════════════════════════════════════════════

-- Resolves the best matching zone for a coordinate pair.
-- Returns the zone with the lowest priority value among all zones that contain
-- the point (polygon) or whose radius ring covers the distance.
create or replace function app.resolve_delivery_zone(
  p_latitude numeric,
  p_longitude numeric,
  p_branch_id uuid default null
)
returns table (
  zone_id uuid,
  branch_id uuid,
  distance_km numeric,
  zone_name text,
  delivery_fee numeric,
  min_order_amount numeric,
  free_delivery_threshold numeric,
  base_eta_minutes int,
  extra_eta_minutes int,
  cod_enabled boolean,
  max_cod_amount numeric,
  is_serviceable boolean,
  per_km_surcharge numeric,
  surcharge_after_km numeric,
  peak_surcharge numeric,
  peak_starts_at time,
  peak_ends_at time,
  dynamic_surcharge numeric
)
language sql
stable
set search_path = ''
as $$
  with target_branches as (
    select b.id, b.latitude, b.longitude
    from public.branches b
    where b.deleted_at is null
      and b.is_active
      and (p_branch_id is null or b.id = p_branch_id)
  ),
  candidates as (
    select
      z.id                as zone_id,
      z.branch_id         as branch_id,
      app.haversine_km(tb.latitude, tb.longitude, p_latitude, p_longitude) as distance_km,
      z.name              as zone_name,
      z.delivery_fee,
      z.min_order_amount,
      z.free_delivery_threshold,
      z.base_eta_minutes,
      z.extra_eta_minutes,
      z.cod_enabled,
      z.max_cod_amount,
      z.is_serviceable,
      z.per_km_surcharge,
      z.surcharge_after_km,
      z.peak_surcharge,
      z.peak_starts_at,
      z.peak_ends_at,
      z.dynamic_surcharge,
      z.priority,
      z.kind,
      z.min_distance_km,
      z.max_distance_km,
      z.polygon
    from public.delivery_zones z
    join target_branches tb on tb.id = z.branch_id
    where z.is_active and z.deleted_at is null
  )
  select
    c.zone_id, c.branch_id, c.distance_km, c.zone_name,
    c.delivery_fee, c.min_order_amount, c.free_delivery_threshold,
    c.base_eta_minutes, c.extra_eta_minutes,
    c.cod_enabled, c.max_cod_amount, c.is_serviceable,
    c.per_km_surcharge, c.surcharge_after_km,
    c.peak_surcharge, c.peak_starts_at, c.peak_ends_at, c.dynamic_surcharge
  from candidates c
  where
    (c.kind = 'RADIUS'
      and c.distance_km >= c.min_distance_km
      and c.distance_km <= c.max_distance_km)
    or
    (c.kind = 'POLYGON'
      and app.point_in_ring(p_latitude, p_longitude, c.polygon -> 0))
  order by c.priority, c.distance_km
  limit 1;
$$;

comment on function app.resolve_delivery_zone is
  'Lowest-priority matching delivery zone for a coordinate. Radius rings and polygons.';

-- Public serviceability check used by the address picker and checkout screen.
create or replace function public.check_serviceability(
  p_latitude numeric,
  p_longitude numeric,
  p_branch_id uuid default null,
  p_order_amount numeric default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_zone record;
  v_branch_state jsonb;
  v_max_distance numeric;
  v_branch uuid;
  v_branch_lat numeric;
  v_branch_lng numeric;
  v_distance numeric;
  v_fee numeric;
  v_eta int;
begin
  v_branch := coalesce(p_branch_id, app.default_branch_id());
  v_max_distance := app.setting_numeric('delivery.max_distance_km', 12);

  if v_branch is null then
    return jsonb_build_object(
      'serviceable', false,
      'reason_code', 'BRANCH_NOT_FOUND',
      'message', 'No Bites Box outlet is configured yet.'
    );
  end if;

  select b.latitude, b.longitude
  into v_branch_lat, v_branch_lng
  from public.branches b where b.id = v_branch;

  v_distance := app.haversine_km(v_branch_lat, v_branch_lng, p_latitude, p_longitude);

  -- Zero rows leaves v_zone assigned with NULL fields, which the checks below expect.
  select * into v_zone
  from app.resolve_delivery_zone(p_latitude, p_longitude, v_branch);

  v_branch_state := public.branch_ordering_state(v_branch);

  if v_zone.zone_id is null or not v_zone.is_serviceable then
    return jsonb_build_object(
      'serviceable', false,
      'reason_code', 'ADDRESS_NOT_SERVICEABLE',
      'message', format(
        'We do not deliver to this location yet. It is about %s km from our Bakhtiyarpur kitchen.',
        round(v_distance, 1)
      ),
      'distance_km', v_distance,
      'max_distance_km', v_max_distance,
      'branch_id', v_branch,
      'pickup_available', (v_branch_state ->> 'service_mode') in ('PICKUP', 'BOTH')
    );
  end if;

  if v_distance > v_max_distance then
    return jsonb_build_object(
      'serviceable', false,
      'reason_code', 'OUTSIDE_MAX_DISTANCE',
      'message', format('This address is %s km away, beyond our %s km delivery limit.',
                        round(v_distance, 1), v_max_distance),
      'distance_km', v_distance,
      'max_distance_km', v_max_distance,
      'branch_id', v_branch
    );
  end if;

  -- Fee preview. Authoritative computation happens in app.compute_delivery_fee().
  v_fee := app.compute_delivery_fee(v_zone.zone_id, v_distance, coalesce(p_order_amount, 0));
  v_eta := v_zone.base_eta_minutes
           + v_zone.extra_eta_minutes
           + coalesce((v_branch_state ->> 'prep_minutes')::int, 20);

  return jsonb_build_object(
    'serviceable', true,
    'branch_id', v_zone.branch_id,
    'zone_id', v_zone.zone_id,
    'zone_name', v_zone.zone_name,
    'distance_km', v_distance,
    'delivery_fee', v_fee,
    'min_order_amount', v_zone.min_order_amount,
    'free_delivery_threshold', v_zone.free_delivery_threshold,
    'eta_minutes', v_eta,
    'cod_enabled', v_zone.cod_enabled and app.setting_bool('cod.enabled', true),
    'max_cod_amount', least(
      coalesce(v_zone.max_cod_amount, 999999),
      app.setting_numeric('cod.max_amount', 2000)
    ),
    'branch', v_branch_state
  );
end;
$$;

comment on function public.check_serviceability is
  'Serviceability + delivery fee preview for a coordinate. Never trusted from the client.';

-- Delivery fee: zone base + distance surcharge + peak surcharge + dynamic surcharge,
-- waived entirely once the free-delivery threshold is met.
create or replace function app.compute_delivery_fee(
  p_zone_id uuid,
  p_distance_km numeric,
  p_order_amount numeric,
  p_at timestamptz default now()
)
returns numeric
language plpgsql
stable
set search_path = ''
as $$
declare
  v_zone public.delivery_zones;
  v_fee numeric := 0;
  v_local_time time;
  v_tz text;
begin
  select * into v_zone from public.delivery_zones where id = p_zone_id;

  if not found then
    return app.setting_numeric('delivery.fallback_fee', 40);
  end if;

  if v_zone.free_delivery_threshold is not null
     and p_order_amount >= v_zone.free_delivery_threshold then
    return 0;
  end if;

  v_fee := v_zone.delivery_fee;

  -- Distance surcharge beyond the zone's included radius.
  if v_zone.surcharge_after_km is not null
     and v_zone.per_km_surcharge > 0
     and p_distance_km > v_zone.surcharge_after_km then
    v_fee := v_fee + ceil(p_distance_km - v_zone.surcharge_after_km) * v_zone.per_km_surcharge;
  end if;

  -- Peak-hour surcharge.
  if v_zone.peak_surcharge > 0 and v_zone.peak_starts_at is not null then
    select timezone into v_tz from public.branches where id = v_zone.branch_id;
    v_local_time := (p_at at time zone coalesce(v_tz, 'Asia/Kolkata'))::time;

    if v_zone.peak_ends_at > v_zone.peak_starts_at then
      if v_local_time between v_zone.peak_starts_at and v_zone.peak_ends_at then
        v_fee := v_fee + v_zone.peak_surcharge;
      end if;
    else
      -- Window crosses midnight
      if v_local_time >= v_zone.peak_starts_at or v_local_time <= v_zone.peak_ends_at then
        v_fee := v_fee + v_zone.peak_surcharge;
      end if;
    end if;
  end if;

  v_fee := v_fee + v_zone.dynamic_surcharge;

  return app.money_round(v_fee);
end;
$$;

-- Persists the resolved zone on an address so subsequent reads are cheap.
create or replace function public.refresh_address_serviceability(p_address_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_address public.addresses;
  v_result jsonb;
begin
  select * into v_address from public.addresses
  where id = p_address_id and deleted_at is null;

  if not found then
    perform app.fail('ADDRESS_NOT_FOUND', 'That address no longer exists.');
  end if;

  if v_address.user_id <> auth.uid() and not app.is_staff() then
    perform app.fail('PERMISSION_DENIED', 'You cannot access this address.');
  end if;

  v_result := public.check_serviceability(v_address.latitude, v_address.longitude);

  update public.addresses
  set resolved_zone_id = nullif(v_result ->> 'zone_id', '')::uuid,
      resolved_branch_id = nullif(v_result ->> 'branch_id', '')::uuid,
      distance_km = nullif(v_result ->> 'distance_km', '')::numeric,
      is_serviceable = (v_result ->> 'serviceable')::boolean,
      serviceability_checked_at = now(),
      updated_at = now()
  where id = p_address_id;

  return v_result;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- CART
-- The cart is a server-owned draft. Clients send intent (add/update/remove);
-- prices are always read from the catalog, never from the request body.
-- ═══════════════════════════════════════════════════════════════════════════
create table public.carts (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  branch_id         uuid not null references public.branches (id) on delete cascade,
  fulfilment_type   public.fulfilment_type not null default 'DELIVERY',
  address_id        uuid references public.addresses (id) on delete set null,
  -- Applied coupon is stored by id; validity is re-checked at every calculation.
  coupon_id         uuid,
  coupon_code       text,
  timing            public.order_timing not null default 'NOW',
  scheduled_for     timestamptz,
  delivery_instructions text,
  cooking_instructions  text,
  use_wallet        boolean not null default false,
  -- Cached totals from the last app.calculate_checkout() run. Display only.
  last_totals       jsonb,
  last_calculated_at timestamptz,
  is_active         boolean not null default true,
  -- Set once the cart converts, so abandoned-cart jobs skip it.
  converted_order_id uuid,
  abandoned_notified_at timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint carts_scheduled_shape check (timing <> 'SCHEDULED' or scheduled_for is not null)
);

-- One live cart per customer per branch.
create unique index carts_active_key on public.carts (user_id, branch_id) where is_active;
create index carts_abandoned_idx on public.carts (updated_at)
  where is_active and converted_order_id is null;

select app.attach_updated_at('public.carts');

create table public.cart_items (
  id                  uuid primary key default gen_random_uuid(),
  cart_id             uuid not null references public.carts (id) on delete cascade,
  product_id          uuid not null references public.products (id) on delete cascade,
  variant_id          uuid references public.product_variants (id) on delete cascade,
  quantity            smallint not null default 1,
  special_instructions text,
  -- Stable hash of (product, variant, modifier set, instructions) so identical
  -- configurations merge into one line instead of stacking duplicates.
  config_hash         text not null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint cart_items_quantity check (quantity between 1 and 50)
);

create index cart_items_cart_idx on public.cart_items (cart_id);
create unique index cart_items_config_key on public.cart_items (cart_id, config_hash);

select app.attach_updated_at('public.cart_items');

create table public.cart_item_modifiers (
  id            uuid primary key default gen_random_uuid(),
  cart_item_id  uuid not null references public.cart_items (id) on delete cascade,
  modifier_id   uuid not null references public.modifiers (id) on delete cascade,
  quantity      smallint not null default 1,
  created_at    timestamptz not null default now(),

  constraint cart_item_modifiers_quantity check (quantity between 1 and 20)
);

create unique index cart_item_modifiers_key
  on public.cart_item_modifiers (cart_item_id, modifier_id);

-- Recent searches / trending queries feed the search experience.
create table public.search_queries (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references auth.users (id) on delete cascade,
  query         text not null,
  normalized    text not null,
  result_count  int not null default 0,
  clicked_product_id uuid references public.products (id) on delete set null,
  created_at    timestamptz not null default now()
);

create index search_queries_user_idx on public.search_queries (user_id, created_at desc);
create index search_queries_trending_idx on public.search_queries (normalized, created_at desc);

comment on table public.search_queries is
  'Search telemetry powering recent searches, trending queries and zero-result reporting.';
