-- ═══════════════════════════════════════════════════════════════════════════
-- 0003 · ORGANISATION
-- Branches, trading hours, delivery zones, tax categories, platform settings
-- and feature flags.
--
-- Launch runs a single branch (Bakhtiyarpur). Every downstream table carries
-- branch_id so additional branches can be switched on without a rewrite; the
-- customer app simply resolves the nearest serviceable branch.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Branches ──────────────────────────────────────────────────────────────
create table public.branches (
  id                        uuid primary key default gen_random_uuid(),
  code                      text not null,
  name                      text not null,
  legal_name                text,
  slug                      app.slug not null,

  -- Location
  address_line1             text not null,
  address_line2             text,
  landmark                  text,
  city                      text not null,
  state                     text not null,
  postal_code               text not null,
  country_code              char(2) not null default 'IN',
  latitude                  app.latitude not null,
  longitude                 app.longitude not null,
  google_place_id           text,
  google_maps_url           text,

  -- Contact
  phone                     app.phone not null,
  alternate_phone           app.phone,
  whatsapp_phone            app.phone,
  email                     app.email,

  -- Compliance
  gstin                     text,
  fssai_licence_no          text,
  fssai_valid_till          date,

  -- Operations
  timezone                  text not null default 'Asia/Kolkata',
  currency_code             char(3) not null default 'INR',
  service_mode              public.service_mode not null default 'BOTH',
  status                    public.branch_status not null default 'CLOSED',
  status_reason             public.branch_closure_reason,
  status_note               text,
  status_changed_at         timestamptz not null default now(),
  status_changed_by         uuid references auth.users (id) on delete set null,
  -- When paused temporarily, the branch auto-reopens at this time.
  auto_resume_at            timestamptz,

  accepting_orders          boolean not null default true,
  default_prep_minutes      int not null default 20,
  -- Extra minutes added to every ETA when the kitchen is under pressure.
  rush_buffer_minutes       int not null default 0,
  max_concurrent_orders     int,

  is_default                boolean not null default false,
  is_active                 boolean not null default true,
  display_order             int not null default 0,

  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  created_by                uuid references auth.users (id) on delete set null,
  updated_by                uuid references auth.users (id) on delete set null,
  deleted_at                timestamptz,

  constraint branches_code_format check (code ~ '^[A-Z0-9-]{3,20}$'),
  constraint branches_prep_positive check (default_prep_minutes between 1 and 240),
  constraint branches_rush_buffer check (rush_buffer_minutes between 0 and 180),
  constraint branches_status_reason_required check (
    status <> 'CLOSED' or status_reason is not null or accepting_orders = false
  )
);

create unique index branches_code_key on public.branches (code) where deleted_at is null;
create unique index branches_slug_key on public.branches (slug) where deleted_at is null;
-- Exactly one default branch at a time.
create unique index branches_single_default on public.branches (is_default)
  where is_default and deleted_at is null;
create index branches_active_idx on public.branches (is_active) where deleted_at is null;

select app.attach_updated_at('public.branches');

comment on table public.branches is 'Physical Bites Box outlets. Single-brand, multi-branch ready.';
comment on column public.branches.auto_resume_at is
  'Scheduled job flips status back to OPEN at this instant when a pause was temporary.';

-- ─── Branch status history (append-only) ───────────────────────────────────
create table public.branch_status_log (
  id                uuid primary key default gen_random_uuid(),
  branch_id         uuid not null references public.branches (id) on delete cascade,
  previous_status   public.branch_status,
  status            public.branch_status not null,
  reason            public.branch_closure_reason,
  note              text,
  accepting_orders  boolean not null,
  changed_by        uuid references auth.users (id) on delete set null,
  actor_kind        public.actor_kind not null default 'USER',
  created_at        timestamptz not null default now()
);

create index branch_status_log_branch_idx
  on public.branch_status_log (branch_id, created_at desc);

select app.make_append_only('public.branch_status_log');

-- ─── Trading hours ─────────────────────────────────────────────────────────
create table public.branch_hours (
  id            uuid primary key default gen_random_uuid(),
  branch_id     uuid not null references public.branches (id) on delete cascade,
  -- 0 = Sunday … 6 = Saturday (matches Postgres EXTRACT(dow))
  day_of_week   smallint not null,
  opens_at      time not null,
  closes_at     time not null,
  -- Slots crossing midnight (e.g. 18:00 → 02:00) set this flag.
  closes_next_day boolean not null default false,
  day_part      public.day_part not null default 'ALL_DAY',
  is_closed     boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint branch_hours_dow check (day_of_week between 0 and 6),
  constraint branch_hours_window check (closes_next_day or closes_at > opens_at)
);

create index branch_hours_lookup_idx on public.branch_hours (branch_id, day_of_week);
create unique index branch_hours_unique_slot
  on public.branch_hours (branch_id, day_of_week, day_part, opens_at);

select app.attach_updated_at('public.branch_hours');

comment on table public.branch_hours is
  'Recurring weekly trading windows per branch. Overridden by branch_holidays.';

-- ─── Holiday / exception calendar ──────────────────────────────────────────
create table public.branch_holidays (
  id          uuid primary key default gen_random_uuid(),
  branch_id   uuid not null references public.branches (id) on delete cascade,
  holiday_on  date not null,
  label       text not null,
  is_closed   boolean not null default true,
  opens_at    time,
  closes_at   time,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint branch_holidays_partial_hours check (
    is_closed or (opens_at is not null and closes_at is not null and closes_at > opens_at)
  )
);

create unique index branch_holidays_unique on public.branch_holidays (branch_id, holiday_on);
select app.attach_updated_at('public.branch_holidays');

-- ─── Delivery zones ────────────────────────────────────────────────────────
-- Fully admin-controlled. No distance or fee is ever hard-coded in an app.
create table public.delivery_zones (
  id                        uuid primary key default gen_random_uuid(),
  branch_id                 uuid not null references public.branches (id) on delete cascade,
  name                      text not null,
  description               text,
  kind                      public.zone_kind not null default 'RADIUS',

  -- RADIUS zones: ring between two distances from the branch.
  min_distance_km           numeric(6, 2),
  max_distance_km           numeric(6, 2),

  -- POLYGON zones: GeoJSON-style ring [[lng,lat], …]. Evaluated by app.point_in_ring().
  polygon                   jsonb,

  -- Pricing
  delivery_fee              app.money not null default 0,
  min_order_amount          app.money not null default 0,
  free_delivery_threshold   app.money,
  -- Additional fee charged per km beyond `surcharge_after_km`.
  per_km_surcharge          app.money not null default 0,
  surcharge_after_km        numeric(6, 2),
  peak_surcharge            app.money not null default 0,
  peak_starts_at            time,
  peak_ends_at              time,
  -- Reserved: weather / demand surcharge switched on by ops without a deploy.
  dynamic_surcharge         app.money not null default 0,

  -- Timing
  base_eta_minutes          int not null default 30,
  extra_eta_minutes         int not null default 0,

  -- Restrictions
  cod_enabled               boolean not null default true,
  max_cod_amount            app.money,
  is_serviceable            boolean not null default true,
  is_active                 boolean not null default true,
  -- Lower number wins when a point falls inside multiple zones.
  priority                  int not null default 100,

  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  created_by                uuid references auth.users (id) on delete set null,
  updated_by                uuid references auth.users (id) on delete set null,
  deleted_at                timestamptz,

  constraint delivery_zones_radius_shape check (
    kind <> 'RADIUS' or (
      min_distance_km is not null
      and max_distance_km is not null
      and min_distance_km >= 0
      and max_distance_km > min_distance_km
    )
  ),
  constraint delivery_zones_polygon_shape check (
    kind <> 'POLYGON' or (polygon is not null and jsonb_typeof(polygon) = 'array')
  ),
  constraint delivery_zones_peak_window check (
    (peak_starts_at is null) = (peak_ends_at is null)
  ),
  constraint delivery_zones_eta check (base_eta_minutes between 5 and 240)
);

create index delivery_zones_branch_idx
  on public.delivery_zones (branch_id, priority)
  where is_active and deleted_at is null;
create unique index delivery_zones_name_key
  on public.delivery_zones (branch_id, name) where deleted_at is null;

select app.attach_updated_at('public.delivery_zones');

comment on table public.delivery_zones is
  'Admin-configured serviceability + delivery pricing. Radius rings or geofenced polygons.';

-- ─── Tax categories ────────────────────────────────────────────────────────
create table public.tax_categories (
  id              uuid primary key default gen_random_uuid(),
  code            text not null,
  name            text not null,
  description     text,
  -- Composite GST rate applied to the taxable line value.
  rate            app.rate not null default 0,
  cgst_rate       app.rate not null default 0,
  sgst_rate       app.rate not null default 0,
  igst_rate       app.rate not null default 0,
  cess_rate       app.rate not null default 0,
  hsn_sac_code    text,
  -- Restaurant GST in India is normally inclusive of the menu price.
  is_inclusive    boolean not null default true,
  is_default      boolean not null default false,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,

  constraint tax_categories_split check (
    round((cgst_rate + sgst_rate + igst_rate)::numeric, 4) = round(rate::numeric, 4)
  )
);

create unique index tax_categories_code_key on public.tax_categories (code) where deleted_at is null;
create unique index tax_categories_single_default on public.tax_categories (is_default)
  where is_default and deleted_at is null;

select app.attach_updated_at('public.tax_categories');

-- ─── Platform settings (typed key/value) ───────────────────────────────────
-- Anything an operator may need to change without a deploy lives here.
create table public.settings (
  key             text primary key,
  value           jsonb not null,
  value_type      text not null default 'string',
  "group"         text not null default 'general',
  label           text not null,
  description     text,
  -- Non-sensitive settings are readable by signed-in clients (branding, policies…).
  is_public       boolean not null default false,
  -- Sensitive settings are readable only by service role / permission holders.
  is_secret       boolean not null default false,
  branch_id       uuid references public.branches (id) on delete cascade,
  updated_at      timestamptz not null default now(),
  updated_by      uuid references auth.users (id) on delete set null,

  constraint settings_value_type check (
    value_type in ('string', 'number', 'boolean', 'json', 'array', 'money', 'time', 'date')
  ),
  constraint settings_secret_not_public check (not (is_public and is_secret))
);

create index settings_group_idx on public.settings ("group");
create index settings_public_idx on public.settings (is_public) where is_public;

select app.attach_updated_at('public.settings');

comment on table public.settings is
  'Operator-editable configuration. is_public rows are exposed to signed-in clients.';

-- Settings change history for audit + rollback.
create table public.settings_history (
  id          uuid primary key default gen_random_uuid(),
  key         text not null,
  old_value   jsonb,
  new_value   jsonb,
  changed_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);

create index settings_history_key_idx on public.settings_history (key, created_at desc);
select app.make_append_only('public.settings_history');

create or replace function app.tg_settings_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.value is not distinct from old.value then
    return new;
  end if;

  insert into public.settings_history (key, old_value, new_value, changed_by)
  values (
    new.key,
    case when tg_op = 'UPDATE' then old.value else null end,
    new.value,
    auth.uid()
  );

  return new;
end;
$$;

create trigger settings_history_trigger
  after insert or update of value on public.settings
  for each row execute function app.tg_settings_history();

-- ─── Feature flags ─────────────────────────────────────────────────────────
create table public.feature_flags (
  key                 text primary key,
  label               text not null,
  description         text,
  is_enabled          boolean not null default false,
  -- Optional gradual rollout: 0-100 % of users bucketed by a stable hash.
  rollout_percentage  app.percent not null default 100,
  -- Restrict the flag to specific roles (null = everyone).
  enabled_for_roles   public.app_role[],
  branch_id           uuid references public.branches (id) on delete cascade,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  updated_by          uuid references auth.users (id) on delete set null
);

select app.attach_updated_at('public.feature_flags');

comment on table public.feature_flags is
  'Operational toggles (COD, scheduled orders, wallet, maintenance mode…). No deploy needed.';

-- ─── Setting / flag accessors ──────────────────────────────────────────────
create or replace function app.setting(p_key text, p_default jsonb default null)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce((select s.value from public.settings s where s.key = p_key), p_default);
$$;

create or replace function app.setting_text(p_key text, p_default text default null)
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select case
              when jsonb_typeof(s.value) = 'string' then s.value #>> '{}'
              else s.value::text
            end
     from public.settings s where s.key = p_key),
    p_default
  );
$$;

create or replace function app.setting_numeric(p_key text, p_default numeric default 0)
returns numeric
language plpgsql
stable
set search_path = ''
as $$
declare
  v jsonb := app.setting(p_key);
begin
  if v is null then
    return p_default;
  end if;
  return (v #>> '{}')::numeric;
exception when others then
  return p_default;
end;
$$;

create or replace function app.setting_int(p_key text, p_default int default 0)
returns int
language sql
stable
set search_path = ''
as $$
  select floor(app.setting_numeric(p_key, p_default))::int;
$$;

create or replace function app.setting_bool(p_key text, p_default boolean default false)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  v jsonb := app.setting(p_key);
begin
  if v is null then
    return p_default;
  end if;
  return (v #>> '{}')::boolean;
exception when others then
  return p_default;
end;
$$;

-- Feature flag evaluation with stable per-user bucketing.
create or replace function public.feature_enabled(p_key text, p_user_id uuid default null)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  v_flag public.feature_flags;
  v_user uuid := coalesce(p_user_id, auth.uid());
  v_bucket int;
begin
  select * into v_flag from public.feature_flags where key = p_key;

  if not found then
    return false;
  end if;

  if not v_flag.is_enabled then
    return false;
  end if;

  if v_flag.rollout_percentage >= 100 then
    return true;
  end if;

  if v_user is null then
    return false;
  end if;

  -- Deterministic bucket so a user's experience never flickers between requests.
  -- 7 hex chars = 28 bits, always positive once cast, avoiding sign issues.
  v_bucket := mod(
    ('x0' || substr(
      pg_catalog.encode(extensions.digest(p_key || v_user::text, 'sha256'), 'hex'), 1, 7
    ))::bit(32)::bigint,
    100
  )::int;

  return v_bucket < v_flag.rollout_percentage;
end;
$$;

comment on function public.feature_enabled is
  'Evaluates a feature flag for a user, honouring percentage rollout with stable bucketing.';

-- ─── Default branch resolution ─────────────────────────────────────────────
create or replace function app.default_branch_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select b.id
  from public.branches b
  where b.deleted_at is null and b.is_active
  order by b.is_default desc, b.display_order, b.created_at
  limit 1;
$$;

-- ─── Trading-hours evaluation ──────────────────────────────────────────────
-- True when the branch's weekly schedule (and holiday overrides) say it is open
-- at the supplied instant. Independent of the manual OPEN/CLOSED/PAUSED switch.
create or replace function app.is_within_trading_hours(
  p_branch_id uuid,
  p_at timestamptz default now()
)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  v_tz text;
  v_local timestamp;
  v_date date;
  v_time time;
  v_dow smallint;
  v_holiday public.branch_holidays;
  v_open boolean := false;
begin
  select timezone into v_tz from public.branches where id = p_branch_id;
  if v_tz is null then
    return false;
  end if;

  v_local := p_at at time zone v_tz;
  v_date  := v_local::date;
  v_time  := v_local::time;
  v_dow   := extract(dow from v_local)::smallint;

  -- Holiday overrides win outright.
  select * into v_holiday
  from public.branch_holidays
  where branch_id = p_branch_id and holiday_on = v_date;

  if found then
    if v_holiday.is_closed then
      return false;
    end if;
    return v_time between v_holiday.opens_at and v_holiday.closes_at;
  end if;

  -- Same-day windows
  select true into v_open
  from public.branch_hours h
  where h.branch_id = p_branch_id
    and h.day_of_week = v_dow
    and not h.is_closed
    and not h.closes_next_day
    and v_time >= h.opens_at
    and v_time < h.closes_at
  limit 1;

  if v_open then
    return true;
  end if;

  -- Windows that opened today and run past midnight
  select true into v_open
  from public.branch_hours h
  where h.branch_id = p_branch_id
    and h.day_of_week = v_dow
    and not h.is_closed
    and h.closes_next_day
    and v_time >= h.opens_at
  limit 1;

  if v_open then
    return true;
  end if;

  -- Windows that opened yesterday and are still running
  select true into v_open
  from public.branch_hours h
  where h.branch_id = p_branch_id
    and h.day_of_week = ((v_dow + 6) % 7)::smallint
    and not h.is_closed
    and h.closes_next_day
    and v_time < h.closes_at
  limit 1;

  return coalesce(v_open, false);
end;
$$;

-- Single source of truth for "can this branch take an order right now?".
create or replace function public.branch_ordering_state(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_branch public.branches;
  v_in_hours boolean;
  v_maintenance boolean;
  v_accepting boolean;
  v_reason text;
begin
  select * into v_branch
  from public.branches
  where id = coalesce(p_branch_id, app.default_branch_id())
    and deleted_at is null;

  if not found then
    return jsonb_build_object(
      'accepting_orders', false,
      'reason_code', 'BRANCH_NOT_FOUND',
      'message', 'We could not find a Bites Box outlet for this location.'
    );
  end if;

  v_maintenance := coalesce(app.setting_bool('maintenance.enabled', false), false);
  v_in_hours := app.is_within_trading_hours(v_branch.id);

  if v_maintenance then
    v_accepting := false;
    v_reason := 'MAINTENANCE_MODE';
  elsif not v_branch.is_active then
    v_accepting := false;
    v_reason := 'BRANCH_INACTIVE';
  elsif v_branch.status = 'CLOSED' or not v_branch.accepting_orders then
    v_accepting := false;
    v_reason := coalesce(v_branch.status_reason::text, 'RESTAURANT_CLOSED');
  elsif v_branch.status = 'PAUSED' then
    v_accepting := false;
    v_reason := 'ORDERING_PAUSED';
  elsif not v_in_hours then
    v_accepting := false;
    v_reason := 'OUTSIDE_TRADING_HOURS';
  else
    v_accepting := true;
    v_reason := null;
  end if;

  return jsonb_build_object(
    'branch_id',        v_branch.id,
    'branch_name',      v_branch.name,
    'status',           v_branch.status,
    'accepting_orders', v_accepting,
    'is_busy',          v_branch.status = 'BUSY',
    'within_hours',     v_in_hours,
    'maintenance',      v_maintenance,
    'reason_code',      v_reason,
    'status_note',      v_branch.status_note,
    'service_mode',     v_branch.service_mode,
    'prep_minutes',     v_branch.default_prep_minutes + v_branch.rush_buffer_minutes,
    'auto_resume_at',   v_branch.auto_resume_at,
    'next_opens_at',    null::timestamptz
  );
end;
$$;

comment on function public.branch_ordering_state is
  'Authoritative ordering availability for a branch: manual switch + trading hours + maintenance mode.';
