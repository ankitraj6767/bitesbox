-- ═══════════════════════════════════════════════════════════════════════════
-- 0007 · COUPONS & PROMOTIONS
--
-- A rule-based engine. Coupons are code-driven; promotions apply automatically.
-- Validation and discount computation happen exclusively in Postgres so the
-- client can never fabricate a discount.
-- ═══════════════════════════════════════════════════════════════════════════

create table public.coupons (
  id                      uuid primary key default gen_random_uuid(),
  code                    text not null,
  title                   text not null,
  description             text,
  terms                   text,
  -- Shown on the customer coupon sheet; hidden coupons are link/campaign only.
  is_visible              boolean not null default true,
  banner_path             text,

  discount_kind           public.discount_kind not null,
  discount_value          numeric(12, 2) not null default 0,
  max_discount_amount     app.money,
  min_order_amount        app.money not null default 0,

  -- BUY_X_GET_Y support
  buy_quantity            smallint,
  get_quantity            smallint,
  get_product_id          uuid references public.products (id) on delete set null,

  -- Usage limits
  max_total_uses          int,
  max_uses_per_customer   int not null default 1,
  -- Reserved count guards against two concurrent checkouts consuming the last use.
  total_used              int not null default 0,

  -- Eligibility
  audience                public.coupon_audience not null default 'ALL',
  segment                 public.audience_segment,
  eligible_product_ids    uuid[] not null default '{}',
  eligible_category_ids   uuid[] not null default '{}',
  excluded_product_ids    uuid[] not null default '{}',
  eligible_payment_modes  public.payment_mode[] not null default '{}',
  eligible_fulfilment     public.fulfilment_type[] not null default '{}',
  eligible_zone_ids       uuid[] not null default '{}',
  -- Restricts the coupon to specific weekdays / hours (happy-hour offers).
  valid_days_of_week      smallint[] not null default '{0,1,2,3,4,5,6}',
  valid_from_time         time,
  valid_to_time           time,
  first_order_only        boolean not null default false,
  new_customer_days       int,

  branch_id               uuid references public.branches (id) on delete cascade,

  starts_at               timestamptz not null default now(),
  ends_at                 timestamptz,
  is_active               boolean not null default true,

  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  created_by              uuid references auth.users (id) on delete set null,
  updated_by              uuid references auth.users (id) on delete set null,
  deleted_at              timestamptz,

  constraint coupons_code_shape check (code ~ '^[A-Z0-9_-]{3,32}$'),
  constraint coupons_window check (ends_at is null or ends_at > starts_at),
  constraint coupons_percentage_bounds check (
    discount_kind <> 'PERCENTAGE' or (discount_value > 0 and discount_value <= 100)
  ),
  constraint coupons_flat_bounds check (
    discount_kind <> 'FLAT' or discount_value > 0
  ),
  constraint coupons_bxgy_shape check (
    discount_kind <> 'BUY_X_GET_Y'
    or (buy_quantity is not null and get_quantity is not null and get_product_id is not null)
  ),
  constraint coupons_time_window check ((valid_from_time is null) = (valid_to_time is null)),
  constraint coupons_uses check (max_uses_per_customer >= 1)
);

create unique index coupons_code_key on public.coupons (upper(code)) where deleted_at is null;
create index coupons_active_idx on public.coupons (starts_at, ends_at)
  where is_active and deleted_at is null;
create index coupons_visible_idx on public.coupons (created_at desc)
  where is_active and is_visible and deleted_at is null;

select app.attach_updated_at('public.coupons');

comment on table public.coupons is
  'Code-driven promotions. Every field is a rule input for app.evaluate_coupon().';

-- Customers explicitly targeted by a SPECIFIC_CUSTOMERS coupon.
create table public.coupon_customers (
  coupon_id  uuid not null references public.coupons (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (coupon_id, user_id)
);

-- ─── Additional stackable rules ────────────────────────────────────────────
-- Kept separate so complex offers can be composed without schema churn.
create table public.coupon_rules (
  id          uuid primary key default gen_random_uuid(),
  coupon_id   uuid not null references public.coupons (id) on delete cascade,
  rule_type   text not null,
  operator    text not null default 'EQ',
  value       jsonb not null,
  created_at  timestamptz not null default now(),

  constraint coupon_rules_type check (rule_type in (
    'MIN_ITEM_COUNT', 'MAX_ITEM_COUNT', 'MIN_DISTINCT_CATEGORIES',
    'CUSTOMER_ORDER_COUNT', 'DAYS_SINCE_LAST_ORDER', 'MIN_LIFETIME_VALUE',
    'REQUIRES_PRODUCT', 'EXCLUDES_PRODUCT', 'DEVICE_PLATFORM', 'APP_VERSION_MIN'
  )),
  constraint coupon_rules_operator check (operator in ('EQ', 'NEQ', 'GT', 'GTE', 'LT', 'LTE', 'IN', 'NOT_IN'))
);

create index coupon_rules_coupon_idx on public.coupon_rules (coupon_id);

-- ─── Redemptions (append-only ledger) ──────────────────────────────────────
create table public.coupon_redemptions (
  id              uuid primary key default gen_random_uuid(),
  coupon_id       uuid not null references public.coupons (id) on delete restrict,
  user_id         uuid not null references auth.users (id) on delete cascade,
  order_id        uuid,
  code            text not null,
  discount_amount app.money not null,
  order_amount    app.money not null,
  created_at      timestamptz not null default now()
);

create index coupon_redemptions_coupon_idx on public.coupon_redemptions (coupon_id);
create index coupon_redemptions_user_idx on public.coupon_redemptions (user_id, coupon_id);
create unique index coupon_redemptions_order_key on public.coupon_redemptions (order_id)
  where order_id is not null;

comment on table public.coupon_redemptions is
  'One row per successful coupon use. Drives per-customer and global usage caps.';

-- ─── Automatic promotions (no code required) ────────────────────────────────
create table public.promotions (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null,
  headline              text not null,
  description           text,
  badge_text            text,
  banner_path           text,
  trigger               public.promotion_trigger not null default 'AUTOMATIC',

  discount_kind         public.discount_kind not null,
  discount_value        numeric(12, 2) not null default 0,
  max_discount_amount   app.money,
  min_order_amount      app.money not null default 0,

  eligible_product_ids  uuid[] not null default '{}',
  eligible_category_ids uuid[] not null default '{}',
  eligible_fulfilment   public.fulfilment_type[] not null default '{}',
  valid_days_of_week    smallint[] not null default '{0,1,2,3,4,5,6}',
  valid_from_time       time,
  valid_to_time         time,

  branch_id             uuid references public.branches (id) on delete cascade,
  -- Higher priority wins when several automatic promotions could apply.
  priority              int not null default 100,
  -- Automatic promotions do not stack with coupons unless this is true.
  stacks_with_coupon    boolean not null default false,

  starts_at             timestamptz not null default now(),
  ends_at               timestamptz,
  is_active             boolean not null default true,

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  created_by            uuid references auth.users (id) on delete set null,
  deleted_at            timestamptz,

  constraint promotions_window check (ends_at is null or ends_at > starts_at),
  constraint promotions_percentage_bounds check (
    discount_kind <> 'PERCENTAGE' or (discount_value > 0 and discount_value <= 100)
  )
);

create index promotions_active_idx on public.promotions (priority)
  where is_active and deleted_at is null;

select app.attach_updated_at('public.promotions');

comment on table public.promotions is
  'Automatic offers such as "20% off Biryani" or "Free delivery tonight". No code needed.';
