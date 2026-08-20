-- ═══════════════════════════════════════════════════════════════════════════
-- 0010 · DELIVERY
--
-- Live location design
--   · delivery_partner_locations  → ONE row per rider, updated in place. This is
--     what the customer app subscribes to. No row-per-second growth.
--   · delivery_location_events    → sampled breadcrumb trail for disputes and
--     distance auditing, written at a throttled interval only during an active
--     delivery.
-- ═══════════════════════════════════════════════════════════════════════════

create table public.delivery_partners (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references auth.users (id) on delete cascade,
  branch_id             uuid not null references public.branches (id) on delete restrict,
  partner_code          text,

  full_name             text not null,
  phone                 app.phone not null,
  alternate_phone       app.phone,
  email                 app.email,
  photo_path            text,
  date_of_birth         date,

  address_line1         text,
  address_line2         text,
  city                  text,
  state                 text,
  postal_code           text,

  vehicle_type          public.vehicle_type not null default 'MOTORCYCLE',
  vehicle_number        text,
  vehicle_model         text,
  driving_licence_no    text,
  licence_expiry        date,

  -- Bank details for salary/settlement. Account number is stored masked; the
  -- full value lives with payroll, outside this platform.
  bank_account_masked   text,
  bank_ifsc             text,
  bank_holder_name      text,
  upi_id                text,

  emergency_contact_name  text,
  emergency_contact_phone app.phone,

  onboarding_status     public.rider_onboarding_status not null default 'PENDING',
  duty_state            public.rider_duty_state not null default 'OFFLINE',
  -- Salaried staff rider vs. future gig partner. Affects earnings treatment.
  is_salaried           boolean not null default true,

  approved_by           uuid references auth.users (id) on delete set null,
  approved_at           timestamptz,
  rejection_reason      text,
  suspended_reason      text,
  suspended_until       timestamptz,

  max_concurrent_orders smallint not null default 2,
  -- Rolling performance metrics (trigger maintained).
  total_deliveries      int not null default 0,
  successful_deliveries int not null default 0,
  failed_deliveries     int not null default 0,
  rejected_assignments  int not null default 0,
  rating_average        numeric(3, 2) not null default 0,
  rating_count          int not null default 0,
  cash_in_hand          app.money not null default 0,

  last_online_at        timestamptz,
  last_delivery_at      timestamptz,
  notes                 text,

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  created_by            uuid references auth.users (id) on delete set null,
  deleted_at            timestamptz,

  constraint delivery_partners_concurrency check (max_concurrent_orders between 1 and 10),
  constraint delivery_partners_rating check (rating_average >= 0 and rating_average <= 5),
  constraint delivery_partners_approval check (
    onboarding_status <> 'ACTIVE' or approved_at is not null
  )
);

create unique index delivery_partners_user_key on public.delivery_partners (user_id)
  where deleted_at is null;
create unique index delivery_partners_code_key on public.delivery_partners (partner_code)
  where partner_code is not null and deleted_at is null;
create index delivery_partners_available_idx
  on public.delivery_partners (branch_id, duty_state)
  where onboarding_status = 'ACTIVE' and deleted_at is null;
create index delivery_partners_status_idx on public.delivery_partners (onboarding_status);

select app.attach_updated_at('public.delivery_partners');

comment on table public.delivery_partners is
  'Delivery staff. Must reach ACTIVE (documents approved) before receiving assignments.';

alter table public.cod_collections
  add constraint cod_collections_rider_fk
  foreign key (delivery_partner_id) references public.delivery_partners (id) on delete set null;

-- ─── Documents ─────────────────────────────────────────────────────────────
create table public.delivery_partner_documents (
  id                  uuid primary key default gen_random_uuid(),
  delivery_partner_id uuid not null references public.delivery_partners (id) on delete cascade,
  document_type       public.rider_document_type not null,
  storage_path        text not null,
  document_number     text,
  issued_on           date,
  expires_on          date,
  status              public.document_status not null default 'PENDING',
  reviewed_by         uuid references auth.users (id) on delete set null,
  reviewed_at         timestamptz,
  rejection_reason    text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create unique index delivery_partner_documents_key
  on public.delivery_partner_documents (delivery_partner_id, document_type);
create index delivery_partner_documents_expiry_idx
  on public.delivery_partner_documents (expires_on)
  where status = 'APPROVED' and expires_on is not null;

select app.attach_updated_at('public.delivery_partner_documents');

-- ─── Duty / availability log ───────────────────────────────────────────────
create table public.delivery_partner_availability (
  id                  uuid primary key default gen_random_uuid(),
  delivery_partner_id uuid not null references public.delivery_partners (id) on delete cascade,
  duty_state          public.rider_duty_state not null,
  previous_state      public.rider_duty_state,
  reason              text,
  -- Duration of the previous state, filled when the next transition arrives.
  duration_seconds    int,
  latitude            app.latitude,
  longitude           app.longitude,
  battery_level       smallint,
  created_at          timestamptz not null default now()
);

create index delivery_partner_availability_partner_idx
  on public.delivery_partner_availability (delivery_partner_id, created_at desc);

select app.make_append_only('public.delivery_partner_availability');

-- ─── Assignments ───────────────────────────────────────────────────────────
create table public.delivery_assignments (
  id                    uuid primary key default gen_random_uuid(),
  order_id              uuid not null references public.orders (id) on delete cascade,
  delivery_partner_id   uuid not null references public.delivery_partners (id) on delete restrict,
  branch_id             uuid not null references public.branches (id) on delete restrict,

  status                public.assignment_status not null default 'OFFERED',
  mode                  public.assignment_mode not null default 'MANUAL',
  -- Sequence number so reassignments are traceable (1 = first attempt).
  attempt_number        smallint not null default 1,

  assigned_by           uuid references auth.users (id) on delete set null,
  offered_at            timestamptz not null default now(),
  -- Riders must respond within this window or the offer expires.
  expires_at            timestamptz,
  accepted_at           timestamptz,
  rejected_at           timestamptz,
  rejection_reason      text,
  arrived_store_at      timestamptz,
  picked_up_at          timestamptz,
  arrived_customer_at   timestamptz,
  completed_at          timestamptz,
  failed_at             timestamptz,
  failure_reason        text,
  cancelled_at          timestamptz,

  -- Distance / duration actuals for performance reporting.
  distance_to_store_km  numeric(6, 2),
  distance_to_customer_km numeric(6, 2),
  total_distance_km     numeric(6, 2),
  pickup_duration_seconds int,
  delivery_duration_seconds int,

  -- Earnings for this trip.
  base_payout           app.money not null default 0,
  distance_payout       app.money not null default 0,
  surge_payout          app.money not null default 0,
  tip_amount            app.money not null default 0,
  total_payout          app.money not null default 0,
  cash_collected        app.money not null default 0,

  -- Proof of delivery
  proof_photo_path      text,
  delivery_note         text,
  customer_signature_path text,

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- Only one live assignment per order; historical rejected/expired rows remain.
create unique index delivery_assignments_active_order_key
  on public.delivery_assignments (order_id)
  where status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER');
create index delivery_assignments_order_idx on public.delivery_assignments (order_id, attempt_number);
create index delivery_assignments_partner_idx
  on public.delivery_assignments (delivery_partner_id, created_at desc);
create index delivery_assignments_active_partner_idx
  on public.delivery_assignments (delivery_partner_id)
  where status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER');
create index delivery_assignments_expiring_idx on public.delivery_assignments (expires_at)
  where status = 'OFFERED';

select app.attach_updated_at('public.delivery_assignments');

comment on table public.delivery_assignments is
  'Rider ⇄ order assignment lifecycle with per-trip earnings and proof of delivery.';

-- ─── Current live location (one row per rider, updated in place) ────────────
create table public.delivery_partner_locations (
  delivery_partner_id uuid primary key references public.delivery_partners (id) on delete cascade,
  order_id            uuid references public.orders (id) on delete set null,
  assignment_id       uuid references public.delivery_assignments (id) on delete set null,
  latitude            app.latitude not null,
  longitude           app.longitude not null,
  accuracy_meters     numeric(8, 2),
  heading_degrees     numeric(6, 2),
  speed_kmph          numeric(6, 2),
  battery_level       smallint,
  is_moving           boolean not null default true,
  -- Straight-line distance and ETA to the current destination, refreshed on write.
  distance_to_destination_km numeric(6, 2),
  eta_minutes         int,
  recorded_at         timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index delivery_partner_locations_order_idx on public.delivery_partner_locations (order_id)
  where order_id is not null;
create index delivery_partner_locations_fresh_idx on public.delivery_partner_locations (recorded_at desc);

comment on table public.delivery_partner_locations is
  'Single mutable row per rider. Customer tracking subscribes here — no unbounded growth.';

-- ─── Sampled breadcrumb trail ──────────────────────────────────────────────
create table public.delivery_location_events (
  id                  bigserial primary key,
  delivery_partner_id uuid not null references public.delivery_partners (id) on delete cascade,
  order_id            uuid references public.orders (id) on delete set null,
  assignment_id       uuid references public.delivery_assignments (id) on delete set null,
  latitude            app.latitude not null,
  longitude           app.longitude not null,
  accuracy_meters     numeric(8, 2),
  speed_kmph          numeric(6, 2),
  recorded_at         timestamptz not null default now()
);

create index delivery_location_events_order_idx
  on public.delivery_location_events (order_id, recorded_at);
create index delivery_location_events_partner_idx
  on public.delivery_location_events (delivery_partner_id, recorded_at desc);

select app.make_append_only('public.delivery_location_events');

comment on table public.delivery_location_events is
  'Throttled historical trail (default 1 sample / 20 s) retained for dispute resolution.';

-- ─── Earnings ledger ───────────────────────────────────────────────────────
create table public.delivery_earnings (
  id                  uuid primary key default gen_random_uuid(),
  delivery_partner_id uuid not null references public.delivery_partners (id) on delete cascade,
  assignment_id       uuid references public.delivery_assignments (id) on delete set null,
  order_id            uuid references public.orders (id) on delete set null,
  entry_type          text not null,
  amount              app.money_signed not null,
  description         text,
  earned_on           date not null default current_date,
  created_by          uuid references auth.users (id) on delete set null,
  created_at          timestamptz not null default now(),

  constraint delivery_earnings_type check (entry_type in (
    'DELIVERY_PAYOUT', 'DISTANCE_BONUS', 'SURGE_BONUS', 'TIP',
    'INCENTIVE', 'PENALTY', 'ADJUSTMENT', 'CASH_SHORTFALL'
  ))
);

create index delivery_earnings_partner_idx
  on public.delivery_earnings (delivery_partner_id, earned_on desc);
create unique index delivery_earnings_assignment_key
  on public.delivery_earnings (assignment_id, entry_type)
  where assignment_id is not null;

select app.make_append_only('public.delivery_earnings');

comment on table public.delivery_earnings is
  'Append-only earnings ledger. Balances are always derived, never stored mutable.';

-- ─── Delivery pricing / payout config ──────────────────────────────────────
create table public.delivery_payout_config (
  id                  uuid primary key default gen_random_uuid(),
  branch_id           uuid references public.branches (id) on delete cascade,
  base_payout         app.money not null default 20,
  per_km_payout       app.money not null default 5,
  free_km             numeric(5, 2) not null default 2,
  peak_bonus          app.money not null default 0,
  peak_starts_at      time,
  peak_ends_at        time,
  is_active           boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create unique index delivery_payout_config_branch_key
  on public.delivery_payout_config (coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where is_active;

select app.attach_updated_at('public.delivery_payout_config');

-- ═══════════════════════════════════════════════════════════════════════════
-- RIDER HELPERS
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.current_delivery_partner_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.delivery_partners
  where user_id = auth.uid() and deleted_at is null
  limit 1;
$$;

create or replace function app.rider_active_load(p_partner_id uuid)
returns int
language sql
stable
set search_path = ''
as $$
  select count(*)::int
  from public.delivery_assignments
  where delivery_partner_id = p_partner_id
    and status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER');
$$;

-- Available riders ranked for dispatch. Manual assignment consumes this list;
-- automatic assignment (future) reuses the identical score.
create or replace function public.available_riders(
  p_branch_id uuid default null,
  p_order_id uuid default null
)
returns table (
  delivery_partner_id uuid,
  full_name text,
  phone text,
  photo_path text,
  vehicle_type public.vehicle_type,
  duty_state public.rider_duty_state,
  active_load int,
  max_concurrent_orders smallint,
  distance_to_store_km numeric,
  last_location_at timestamptz,
  rating_average numeric,
  successful_deliveries int,
  score numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with branch as (
    select b.id, b.latitude, b.longitude
    from public.branches b
    where b.id = coalesce(p_branch_id, app.default_branch_id())
  )
  select
    dp.id,
    dp.full_name,
    dp.phone::text,
    dp.photo_path,
    dp.vehicle_type,
    dp.duty_state,
    app.rider_active_load(dp.id) as active_load,
    dp.max_concurrent_orders,
    case
      when loc.latitude is not null
      then app.haversine_km(loc.latitude, loc.longitude, br.latitude, br.longitude)
      else null
    end as distance_to_store_km,
    loc.recorded_at,
    dp.rating_average,
    dp.successful_deliveries,
    -- Lower score = better candidate.
    (
      app.rider_active_load(dp.id) * 100
      + coalesce(
          case
            when loc.latitude is not null
            then app.haversine_km(loc.latitude, loc.longitude, br.latitude, br.longitude)
            else 15
          end, 15
        ) * 10
      + (5 - dp.rating_average) * 5
      + case when dp.duty_state = 'AVAILABLE' then 0 else 50 end
    )::numeric as score
  from public.delivery_partners dp
  cross join branch br
  left join public.delivery_partner_locations loc on loc.delivery_partner_id = dp.id
  where dp.deleted_at is null
    and dp.onboarding_status = 'ACTIVE'
    and dp.branch_id = br.id
    and dp.duty_state in ('AVAILABLE', 'BUSY')
    and app.rider_active_load(dp.id) < dp.max_concurrent_orders
  order by score;
$$;

comment on function public.available_riders is
  'Dispatch candidate list with a deterministic score (load, proximity, rating, duty state).';

-- ─── Rider metric maintenance ──────────────────────────────────────────────
create or replace function app.tg_assignment_metrics()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'COMPLETED' and coalesce(old.status, 'OFFERED') <> 'COMPLETED' then
    update public.delivery_partners
    set total_deliveries = total_deliveries + 1,
        successful_deliveries = successful_deliveries + 1,
        last_delivery_at = now(),
        cash_in_hand = cash_in_hand + new.cash_collected,
        updated_at = now()
    where id = new.delivery_partner_id;

  elsif new.status = 'FAILED' and coalesce(old.status, 'OFFERED') <> 'FAILED' then
    update public.delivery_partners
    set total_deliveries = total_deliveries + 1,
        failed_deliveries = failed_deliveries + 1,
        updated_at = now()
    where id = new.delivery_partner_id;

  elsif new.status = 'REJECTED' and coalesce(old.status, 'OFFERED') <> 'REJECTED' then
    update public.delivery_partners
    set rejected_assignments = rejected_assignments + 1, updated_at = now()
    where id = new.delivery_partner_id;
  end if;

  -- Duty state follows workload automatically.
  if new.status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER') then
    update public.delivery_partners
    set duty_state = 'BUSY', updated_at = now()
    where id = new.delivery_partner_id and duty_state = 'AVAILABLE';
  elsif new.status in ('COMPLETED', 'FAILED', 'CANCELLED', 'REJECTED', 'EXPIRED') then
    update public.delivery_partners dp
    set duty_state = 'AVAILABLE', updated_at = now()
    where dp.id = new.delivery_partner_id
      and dp.duty_state = 'BUSY'
      and app.rider_active_load(dp.id) = 0;
  end if;

  return new;
end;
$$;

create trigger assignment_metrics
  after update of status on public.delivery_assignments
  for each row execute function app.tg_assignment_metrics();
