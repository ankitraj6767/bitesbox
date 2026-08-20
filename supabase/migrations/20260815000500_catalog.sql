-- ═══════════════════════════════════════════════════════════════════════════
-- 0005 · CATALOG
--
--   categories ─► subcategories ─► products ─► product_variants
--                                      │
--                                      └─► product_modifier_groups ─► modifier_groups ─► modifiers
--
-- Availability is branch-scoped and realtime. Scheduling (breakfast/lunch/dinner,
-- specific days and times) is data, never code.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Categories ────────────────────────────────────────────────────────────
create table public.categories (
  id                uuid primary key default gen_random_uuid(),
  -- null = available at every branch
  branch_id         uuid references public.branches (id) on delete cascade,
  name              text not null,
  slug              app.slug not null,
  short_description text,
  description       text,
  image_path        text,
  thumbnail_path    text,
  icon_name         text,
  banner_path       text,
  -- Brand accent used by the customer app category chips.
  accent_color      text,

  display_order     int not null default 0,
  is_active         boolean not null default true,
  is_featured       boolean not null default false,
  -- Restricts the whole category to a day part (e.g. BREAKFAST only).
  day_part          public.day_part not null default 'ALL_DAY',

  -- Web/SEO readiness for the future ordering website
  meta_title        text,
  meta_description  text,
  search_keywords   text[] not null default '{}',

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid references auth.users (id) on delete set null,
  updated_by        uuid references auth.users (id) on delete set null,
  deleted_at        timestamptz,

  constraint categories_color check (accent_color is null or accent_color ~ '^#[0-9A-Fa-f]{6}$')
);

create unique index categories_slug_key on public.categories (slug) where deleted_at is null;
create index categories_active_idx on public.categories (display_order)
  where is_active and deleted_at is null;
create index categories_branch_idx on public.categories (branch_id);

select app.attach_updated_at('public.categories');

-- ─── Subcategories ─────────────────────────────────────────────────────────
create table public.subcategories (
  id                uuid primary key default gen_random_uuid(),
  category_id       uuid not null references public.categories (id) on delete cascade,
  name              text not null,
  slug              app.slug not null,
  description       text,
  image_path        text,
  display_order     int not null default 0,
  is_active         boolean not null default true,
  meta_title        text,
  meta_description  text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);

create unique index subcategories_slug_key
  on public.subcategories (category_id, slug) where deleted_at is null;
create index subcategories_category_idx on public.subcategories (category_id, display_order)
  where is_active and deleted_at is null;

select app.attach_updated_at('public.subcategories');

-- ─── Products ──────────────────────────────────────────────────────────────
create table public.products (
  id                    uuid primary key default gen_random_uuid(),
  branch_id             uuid references public.branches (id) on delete cascade,
  category_id           uuid not null references public.categories (id) on delete restrict,
  subcategory_id        uuid references public.subcategories (id) on delete set null,

  name                  text not null,
  slug                  app.slug not null,
  short_description     text,
  description           text,

  -- Media (Supabase Storage object paths, never absolute URLs)
  thumbnail_path        text,
  hero_image_path       text,

  -- Classification
  food_type             public.food_type not null default 'VEG',
  spice_level           public.spice_level not null default 'NONE',
  allergens             text[] not null default '{}',
  dietary_tags          text[] not null default '{}',

  -- Pricing (base price applies when the product has no variants)
  base_price            app.money not null default 0,
  compare_price         app.money,
  -- Charged once per unit of this product, excluded from item discounts.
  packaging_charge      app.money not null default 0,
  tax_category_id       uuid references public.tax_categories (id) on delete set null,

  -- Kitchen
  preparation_minutes   int not null default 15,
  serves_count          smallint,
  calories              int,
  weight_grams          int,

  -- Merchandising
  is_active             boolean not null default true,
  is_featured           boolean not null default false,
  is_best_seller        boolean not null default false,
  is_new                boolean not null default false,
  is_recommended        boolean not null default false,
  is_combo              boolean not null default false,
  display_order         int not null default 0,

  -- Ordering rules
  min_quantity_per_order smallint not null default 1,
  max_quantity_per_order smallint,
  allows_special_instructions boolean not null default true,

  -- Denormalised review aggregates (trigger maintained)
  rating_average        numeric(3, 2) not null default 0,
  rating_count          int not null default 0,
  -- Rolling popularity score used by "Popular Tonight" style sections.
  order_count           int not null default 0,

  -- Search / SEO
  search_keywords       text[] not null default '{}',
  meta_title            text,
  meta_description      text,
  search_vector         tsvector,

  metadata              jsonb not null default '{}'::jsonb,

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  created_by            uuid references auth.users (id) on delete set null,
  updated_by            uuid references auth.users (id) on delete set null,
  deleted_at            timestamptz,

  constraint products_compare_price check (compare_price is null or compare_price >= base_price),
  constraint products_prep check (preparation_minutes between 1 and 240),
  constraint products_qty_bounds check (
    max_quantity_per_order is null or max_quantity_per_order >= min_quantity_per_order
  ),
  constraint products_min_qty check (min_quantity_per_order >= 1),
  constraint products_rating check (rating_average >= 0 and rating_average <= 5)
);

create unique index products_slug_key on public.products (slug) where deleted_at is null;
create index products_category_idx on public.products (category_id, display_order)
  where is_active and deleted_at is null;
create index products_subcategory_idx on public.products (subcategory_id)
  where is_active and deleted_at is null;
create index products_best_seller_idx on public.products (order_count desc)
  where is_best_seller and is_active and deleted_at is null;
create index products_featured_idx on public.products (display_order)
  where is_featured and is_active and deleted_at is null;
create index products_price_idx on public.products (base_price)
  where is_active and deleted_at is null;
create index products_search_vector_idx on public.products using gin (search_vector);
create index products_name_trgm_idx on public.products
  using gin (name extensions.gin_trgm_ops);
create index products_branch_idx on public.products (branch_id);

select app.attach_updated_at('public.products');

comment on table public.products is
  'Menu products. Historical orders never read from here — they store snapshots.';

-- Search vector: name weighted highest, then keywords, then descriptions.
create or replace function app.tg_products_search_vector()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_category text;
begin
  select c.name into v_category from public.categories c where c.id = new.category_id;

  new.search_vector :=
      setweight(to_tsvector('simple', coalesce(new.name, '')), 'A')
   || setweight(to_tsvector('simple', coalesce(array_to_string(new.search_keywords, ' '), '')), 'A')
   || setweight(to_tsvector('simple', coalesce(v_category, '')), 'B')
   || setweight(to_tsvector('simple', coalesce(new.short_description, '')), 'C')
   || setweight(to_tsvector('simple', coalesce(new.description, '')), 'D');

  return new;
end;
$$;

create trigger products_search_vector
  before insert or update of name, search_keywords, short_description, description, category_id
  on public.products
  for each row execute function app.tg_products_search_vector();

-- ─── Product images ────────────────────────────────────────────────────────
create table public.product_images (
  id            uuid primary key default gen_random_uuid(),
  product_id    uuid not null references public.products (id) on delete cascade,
  storage_path  text not null,
  alt_text      text,
  width         int,
  height        int,
  -- Pre-generated responsive variants: {"thumb": "...", "medium": "...", "large": "..."}
  variants      jsonb not null default '{}'::jsonb,
  display_order int not null default 0,
  is_primary    boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index product_images_product_idx on public.product_images (product_id, display_order);
create unique index product_images_single_primary on public.product_images (product_id)
  where is_primary;

select app.attach_updated_at('public.product_images');

-- ─── Variants ──────────────────────────────────────────────────────────────
create table public.product_variants (
  id                  uuid primary key default gen_random_uuid(),
  product_id          uuid not null references public.products (id) on delete cascade,
  name                text not null,
  -- Grouping label shown above the options, e.g. "Size", "Crust", "Portion".
  option_group        text not null default 'Size',
  sku                 text,
  price               app.money not null,
  compare_price       app.money,
  packaging_charge    app.money not null default 0,
  calories            int,
  weight_grams        int,
  serves_count        smallint,
  preparation_minutes int,
  availability        public.availability_state not null default 'AVAILABLE',
  out_of_stock_until  timestamptz,
  is_default          boolean not null default false,
  is_active           boolean not null default true,
  display_order       int not null default 0,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,

  constraint product_variants_compare check (compare_price is null or compare_price >= price)
);

create index product_variants_product_idx on public.product_variants (product_id, display_order)
  where is_active and deleted_at is null;
create unique index product_variants_single_default on public.product_variants (product_id)
  where is_default and deleted_at is null;
create unique index product_variants_sku_key on public.product_variants (sku)
  where sku is not null and deleted_at is null;
create unique index product_variants_name_key
  on public.product_variants (product_id, option_group, name) where deleted_at is null;

select app.attach_updated_at('public.product_variants');

-- ─── Modifier groups ───────────────────────────────────────────────────────
-- Reusable across products (e.g. "Add-ons", "Choice of crust").
create table public.modifier_groups (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  slug              app.slug not null,
  description       text,
  selection         public.modifier_selection not null default 'SINGLE',
  min_select        smallint not null default 0,
  max_select        smallint,
  is_required       boolean not null default false,
  -- Free choices before per-modifier pricing starts (e.g. 2 free toppings).
  free_selections   smallint not null default 0,
  display_order     int not null default 0,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,

  constraint modifier_groups_bounds check (
    min_select >= 0
    and (max_select is null or max_select >= greatest(min_select, 1))
    and (selection <> 'SINGLE' or coalesce(max_select, 1) = 1)
  ),
  constraint modifier_groups_required check (not is_required or min_select >= 1)
);

create unique index modifier_groups_slug_key on public.modifier_groups (slug) where deleted_at is null;
select app.attach_updated_at('public.modifier_groups');

-- ─── Modifiers ─────────────────────────────────────────────────────────────
create table public.modifiers (
  id                 uuid primary key default gen_random_uuid(),
  modifier_group_id  uuid not null references public.modifier_groups (id) on delete cascade,
  name               text not null,
  description        text,
  image_path         text,
  price              app.money not null default 0,
  food_type          public.food_type not null default 'VEG',
  calories           int,
  max_quantity       smallint not null default 1,
  availability       public.availability_state not null default 'AVAILABLE',
  out_of_stock_until timestamptz,
  is_default         boolean not null default false,
  is_active          boolean not null default true,
  display_order      int not null default 0,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  deleted_at         timestamptz,

  constraint modifiers_max_quantity check (max_quantity between 1 and 20)
);

create index modifiers_group_idx on public.modifiers (modifier_group_id, display_order)
  where is_active and deleted_at is null;
create unique index modifiers_name_key
  on public.modifiers (modifier_group_id, name) where deleted_at is null;

select app.attach_updated_at('public.modifiers');

-- ─── Product ⇄ Modifier group ──────────────────────────────────────────────
create table public.product_modifier_groups (
  id                 uuid primary key default gen_random_uuid(),
  product_id         uuid not null references public.products (id) on delete cascade,
  modifier_group_id  uuid not null references public.modifier_groups (id) on delete cascade,
  -- Per-product overrides of the group defaults.
  is_required        boolean,
  min_select         smallint,
  max_select         smallint,
  display_order      int not null default 0,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create unique index product_modifier_groups_key
  on public.product_modifier_groups (product_id, modifier_group_id);
create index product_modifier_groups_product_idx
  on public.product_modifier_groups (product_id, display_order);

select app.attach_updated_at('public.product_modifier_groups');

-- ─── Branch availability (realtime kitchen switch) ─────────────────────────
create table public.product_availability (
  id                    uuid primary key default gen_random_uuid(),
  product_id            uuid not null references public.products (id) on delete cascade,
  branch_id             uuid not null references public.branches (id) on delete cascade,
  state                 public.availability_state not null default 'AVAILABLE',
  -- Phase 1 inventory: a simple countdown the kitchen can set for the day.
  remaining_quantity    int,
  low_stock_threshold   int,
  -- TEMPORARILY_UNAVAILABLE items auto-restore at this instant.
  out_of_stock_until    timestamptz,
  out_of_stock_reason   text,
  -- Set true so the nightly job restores availability for the next service.
  auto_reset_daily      boolean not null default true,
  changed_by            uuid references auth.users (id) on delete set null,
  changed_at            timestamptz not null default now(),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  constraint product_availability_quantity check (remaining_quantity is null or remaining_quantity >= 0)
);

create unique index product_availability_key
  on public.product_availability (product_id, branch_id);
create index product_availability_state_idx
  on public.product_availability (branch_id, state);
create index product_availability_restore_idx
  on public.product_availability (out_of_stock_until)
  where out_of_stock_until is not null;

select app.attach_updated_at('public.product_availability');

comment on table public.product_availability is
  'Per-branch availability. Published over Supabase Realtime to every customer app.';

-- Every product automatically gets an availability row per active branch.
create or replace function app.tg_seed_product_availability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.product_availability (product_id, branch_id)
  select new.id, b.id
  from public.branches b
  where b.deleted_at is null and b.is_active
  on conflict (product_id, branch_id) do nothing;

  return new;
end;
$$;

create trigger seed_product_availability
  after insert on public.products
  for each row execute function app.tg_seed_product_availability();

-- ─── Scheduled availability windows ────────────────────────────────────────
-- A product with zero windows is orderable whenever the branch is open.
create table public.product_schedules (
  id              uuid primary key default gen_random_uuid(),
  product_id      uuid not null references public.products (id) on delete cascade,
  branch_id       uuid references public.branches (id) on delete cascade,
  label           text,
  day_part        public.day_part not null default 'ALL_DAY',
  -- Bitmask-free representation: which weekdays this window applies to.
  days_of_week    smallint[] not null default '{0,1,2,3,4,5,6}',
  starts_at       time not null default '00:00',
  ends_at         time not null default '23:59',
  valid_from      date,
  valid_until     date,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint product_schedules_window check (ends_at > starts_at),
  constraint product_schedules_dates check (valid_until is null or valid_from is null or valid_until >= valid_from)
);

create index product_schedules_product_idx on public.product_schedules (product_id)
  where is_active;

select app.attach_updated_at('public.product_schedules');

-- ─── Collections (curated merchandising lists) ─────────────────────────────
create table public.collections (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  slug              app.slug not null,
  description       text,
  image_path        text,
  -- Optional dynamic rule, e.g. {"max_price": 199} for an "Under ₹199" rail.
  rule              jsonb,
  display_order     int not null default 0,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);

create unique index collections_slug_key on public.collections (slug) where deleted_at is null;
select app.attach_updated_at('public.collections');

create table public.collection_products (
  collection_id uuid not null references public.collections (id) on delete cascade,
  product_id    uuid not null references public.products (id) on delete cascade,
  display_order int not null default 0,
  primary key (collection_id, product_id)
);

create index collection_products_product_idx on public.collection_products (product_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- AVAILABILITY EVALUATION
-- ═══════════════════════════════════════════════════════════════════════════

-- True when at least one active schedule window covers `p_at`, or none exist.
create or replace function app.product_in_schedule(
  p_product_id uuid,
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
  v_dow smallint;
  v_time time;
  v_has_windows boolean;
begin
  select timezone into v_tz from public.branches where id = p_branch_id;
  v_tz := coalesce(v_tz, 'Asia/Kolkata');
  v_local := p_at at time zone v_tz;
  v_dow := extract(dow from v_local)::smallint;
  v_time := v_local::time;

  select exists (
    select 1 from public.product_schedules s
    where s.product_id = p_product_id
      and s.is_active
      and (s.branch_id is null or s.branch_id = p_branch_id)
  ) into v_has_windows;

  if not v_has_windows then
    return true;
  end if;

  return exists (
    select 1 from public.product_schedules s
    where s.product_id = p_product_id
      and s.is_active
      and (s.branch_id is null or s.branch_id = p_branch_id)
      and v_dow = any (s.days_of_week)
      and v_time between s.starts_at and s.ends_at
      and (s.valid_from is null or v_local::date >= s.valid_from)
      and (s.valid_until is null or v_local::date <= s.valid_until)
  );
end;
$$;

-- The single authority on "can this product be ordered right now?".
-- Used by the pricing engine, order placement and the customer menu view.
create or replace function app.product_orderable(
  p_product_id uuid,
  p_branch_id uuid default null,
  p_at timestamptz default now()
)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_state public.availability_state;
  v_until timestamptz;
  v_remaining int;
  v_active boolean;
begin
  select p.is_active and p.deleted_at is null
  into v_active
  from public.products p
  where p.id = p_product_id;

  if not coalesce(v_active, false) then
    return false;
  end if;

  select pa.state, pa.out_of_stock_until, pa.remaining_quantity
  into v_state, v_until, v_remaining
  from public.product_availability pa
  where pa.product_id = p_product_id and pa.branch_id = v_branch;

  -- No row yet (new branch) → treat as available.
  if v_state is null then
    return app.product_in_schedule(p_product_id, v_branch, p_at);
  end if;

  if v_state = 'OUT_OF_STOCK' then
    return false;
  end if;

  if v_state = 'TEMPORARILY_UNAVAILABLE' then
    if v_until is null or v_until > p_at then
      return false;
    end if;
  end if;

  if v_remaining is not null and v_remaining <= 0 then
    return false;
  end if;

  return app.product_in_schedule(p_product_id, v_branch, p_at);
end;
$$;

comment on function app.product_orderable is
  'Authoritative orderability: active + branch availability + stock countdown + schedule window.';

create or replace function app.variant_orderable(p_variant_id uuid, p_at timestamptz default now())
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (
      select v.is_active
             and v.deleted_at is null
             and (
               v.availability = 'AVAILABLE'
               or (v.availability = 'TEMPORARILY_UNAVAILABLE'
                   and v.out_of_stock_until is not null
                   and v.out_of_stock_until <= p_at)
             )
      from public.product_variants v
      where v.id = p_variant_id
    ),
    false
  );
$$;

create or replace function app.modifier_orderable(p_modifier_id uuid, p_at timestamptz default now())
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (
      select m.is_active
             and m.deleted_at is null
             and (
               m.availability = 'AVAILABLE'
               or (m.availability = 'TEMPORARILY_UNAVAILABLE'
                   and m.out_of_stock_until is not null
                   and m.out_of_stock_until <= p_at)
             )
      from public.modifiers m
      where m.id = p_modifier_id
    ),
    false
  );
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- AVAILABILITY MUTATION (kitchen / admin entry point)
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.set_product_availability(
  p_product_id uuid,
  p_state public.availability_state,
  p_branch_id uuid default null,
  p_minutes int default null,
  p_reason text default null,
  p_remaining_quantity int default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_until timestamptz;
  v_row public.product_availability;
begin
  perform app.require_permission('menu.availability', v_branch);

  if p_state = 'TEMPORARILY_UNAVAILABLE' then
    v_until := now() + make_interval(mins => coalesce(p_minutes, 60));
  end if;

  insert into public.product_availability as pa (
    product_id, branch_id, state, out_of_stock_until, out_of_stock_reason,
    remaining_quantity, changed_by, changed_at
  )
  values (
    p_product_id, v_branch, p_state, v_until, p_reason,
    p_remaining_quantity, auth.uid(), now()
  )
  on conflict (product_id, branch_id) do update
    set state = excluded.state,
        out_of_stock_until = excluded.out_of_stock_until,
        out_of_stock_reason = excluded.out_of_stock_reason,
        remaining_quantity = coalesce(excluded.remaining_quantity, pa.remaining_quantity),
        changed_by = excluded.changed_by,
        changed_at = now(),
        updated_at = now()
  returning * into v_row;

  return jsonb_build_object(
    'product_id', v_row.product_id,
    'branch_id', v_row.branch_id,
    'state', v_row.state,
    'out_of_stock_until', v_row.out_of_stock_until,
    'remaining_quantity', v_row.remaining_quantity
  );
end;
$$;

comment on function public.set_product_availability is
  'Kitchen/admin availability toggle. Permission checked server-side, broadcast via Realtime.';

-- Bulk toggle used by the admin menu grid.
create or replace function public.set_products_availability(
  p_product_ids uuid[],
  p_state public.availability_state,
  p_branch_id uuid default null,
  p_minutes int default null,
  p_reason text default null
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_count int := 0;
begin
  foreach v_id in array p_product_ids loop
    perform public.set_product_availability(v_id, p_state, p_branch_id, p_minutes, p_reason);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;
