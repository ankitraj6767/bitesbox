-- ═══════════════════════════════════════════════════════════════════════════
-- 0008 · ORDERS
--
-- Orders are immutable financial records with a snapshot of everything the
-- customer bought. Historical orders NEVER read live product rows: names,
-- prices, images, taxes and modifiers are copied at placement time.
--
-- Every money column is computed by app.calculate_checkout() on the server.
-- ═══════════════════════════════════════════════════════════════════════════

-- Human-facing order numbers: BB-BKP01-260815-0042
create sequence public.order_number_seq;

create table public.orders (
  id                        uuid primary key default gen_random_uuid(),
  order_number              text not null,
  branch_id                 uuid not null references public.branches (id) on delete restrict,
  user_id                   uuid not null references auth.users (id) on delete restrict,

  -- Idempotency: the client sends a UUID per checkout attempt. A second attempt
  -- with the same key returns the original order instead of creating a new one.
  idempotency_key           text not null,

  channel                   public.order_channel not null default 'MOBILE_APP',
  fulfilment_type           public.fulfilment_type not null default 'DELIVERY',
  timing                    public.order_timing not null default 'NOW',
  scheduled_for             timestamptz,

  status                    public.order_status not null default 'PENDING_PAYMENT',
  previous_status           public.order_status,
  status_changed_at         timestamptz not null default now(),

  -- ── Customer snapshot (support must see what was true at order time) ──
  customer_name             text,
  customer_phone            app.phone,
  customer_email            app.email,

  -- ── Delivery address snapshot ──
  address_id                uuid references public.addresses (id) on delete set null,
  delivery_address_line1    text,
  delivery_address_line2    text,
  delivery_landmark         text,
  delivery_area             text,
  delivery_city             text,
  delivery_state            text,
  delivery_postal_code      text,
  delivery_latitude         app.latitude,
  delivery_longitude        app.longitude,
  delivery_instructions     text,
  delivery_contact_name     text,
  delivery_contact_phone    app.phone,

  -- ── Zone / distance snapshot ──
  delivery_zone_id          uuid references public.delivery_zones (id) on delete set null,
  delivery_zone_name        text,
  distance_km               numeric(6, 2),

  -- ── Money (all server-computed) ──
  currency_code             char(3) not null default 'INR',
  items_subtotal            app.money not null default 0,
  items_discount            app.money not null default 0,
  coupon_id                 uuid references public.coupons (id) on delete set null,
  coupon_code               text,
  coupon_discount           app.money not null default 0,
  promotion_id              uuid references public.promotions (id) on delete set null,
  promotion_discount        app.money not null default 0,
  total_discount            app.money not null default 0,
  taxable_amount            app.money not null default 0,
  tax_amount                app.money not null default 0,
  cgst_amount               app.money not null default 0,
  sgst_amount               app.money not null default 0,
  igst_amount               app.money not null default 0,
  cess_amount               app.money not null default 0,
  packaging_charge          app.money not null default 0,
  delivery_fee              app.money not null default 0,
  delivery_fee_waived       app.money not null default 0,
  -- Optional operator-configured convenience/platform fee.
  service_fee               app.money not null default 0,
  tip_amount                app.money not null default 0,
  round_off                 numeric(5, 2) not null default 0,
  wallet_applied            app.money not null default 0,
  loyalty_points_redeemed   int not null default 0,
  loyalty_discount          app.money not null default 0,
  grand_total               app.money not null default 0,
  -- Amount still to be collected through the gateway or in cash.
  payable_amount            app.money not null default 0,
  refunded_amount           app.money not null default 0,

  -- ── Payment ──
  payment_mode              public.payment_mode not null default 'ONLINE',
  payment_status            public.payment_status not null default 'CREATED',
  cod_status                public.cod_status,
  paid_at                   timestamptz,

  -- ── Timing / SLA ──
  placed_at                 timestamptz,
  accepted_at               timestamptz,
  preparing_at              timestamptz,
  ready_at                  timestamptz,
  assigned_at               timestamptz,
  picked_up_at              timestamptz,
  delivered_at              timestamptz,
  completed_at              timestamptz,
  cancelled_at              timestamptz,

  prep_minutes_estimate     int,
  delivery_minutes_estimate int,
  promised_at               timestamptz,
  -- Flipped by the stale-order job so live ops can highlight the row.
  is_delayed                boolean not null default false,
  delay_notified_at         timestamptz,

  -- ── Verification secrets (hashes only) ──
  pickup_code_hash          text,
  delivery_code_hash        text,
  delivery_code_salt        text,
  delivery_code_attempts    smallint not null default 0,
  delivery_verified_at      timestamptz,
  delivery_verification_method text,

  -- ── Cancellation ──
  cancelled_by              uuid references auth.users (id) on delete set null,
  cancellation_actor        public.cancellation_actor,
  cancellation_reason       public.cancellation_reason,
  cancellation_note         text,
  cancellation_fee          app.money not null default 0,

  -- ── Notes & meta ──
  customer_note             text,
  internal_note             text,
  item_count                int not null default 0,
  unit_count                int not null default 0,
  is_first_order            boolean not null default false,
  app_version               text,
  device_platform           public.device_platform,
  metadata                  jsonb not null default '{}'::jsonb,

  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  created_by                uuid references auth.users (id) on delete set null,

  constraint orders_scheduled_shape check (timing <> 'SCHEDULED' or scheduled_for is not null),
  constraint orders_delivery_address check (
    fulfilment_type <> 'DELIVERY'
    or (delivery_latitude is not null and delivery_longitude is not null and delivery_address_line1 is not null)
  ),
  constraint orders_cod_shape check (
    payment_mode not in ('COD', 'SPLIT_WALLET_COD') or cod_status is not null
  ),
  constraint orders_totals_non_negative check (grand_total >= 0 and payable_amount >= 0),
  constraint orders_refund_bounds check (refunded_amount <= grand_total),
  constraint orders_delivery_attempts check (delivery_code_attempts between 0 and 10),
  constraint orders_cancellation_shape check (
    status not in ('CUSTOMER_CANCELLED', 'ADMIN_CANCELLED', 'STORE_REJECTED')
    or cancellation_actor is not null
  )
);

create unique index orders_number_key on public.orders (order_number);
create unique index orders_idempotency_key on public.orders (user_id, idempotency_key);
create index orders_user_idx on public.orders (user_id, created_at desc);
create index orders_branch_status_idx on public.orders (branch_id, status, created_at desc);
create index orders_status_idx on public.orders (status) where status not in
  ('DELIVERED', 'COMPLETED', 'REFUNDED', 'CUSTOMER_CANCELLED', 'ADMIN_CANCELLED', 'STORE_REJECTED');
create index orders_created_idx on public.orders (created_at desc);
create index orders_scheduled_idx on public.orders (scheduled_for)
  where timing = 'SCHEDULED' and status = 'PAYMENT_CONFIRMED';
create index orders_payment_status_idx on public.orders (payment_status, created_at desc);
create index orders_delayed_idx on public.orders (promised_at)
  where status in ('STORE_ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP', 'OUT_FOR_DELIVERY');
create index orders_coupon_idx on public.orders (coupon_id) where coupon_id is not null;
create index orders_phone_idx on public.orders (customer_phone);

select app.attach_updated_at('public.orders');

comment on table public.orders is
  'Immutable-by-convention order records. Money is server-computed; status changes go through app.transition_order().';
comment on column public.orders.idempotency_key is
  'Client-generated per checkout attempt. Unique per user so double taps cannot duplicate an order.';
comment on column public.orders.delivery_code_hash is
  'Salted SHA-256 of the delivery OTP. Plaintext exists only in the notification.';

-- Link the redemption ledger now that orders exists.
alter table public.coupon_redemptions
  add constraint coupon_redemptions_order_fk
  foreign key (order_id) references public.orders (id) on delete set null;

alter table public.carts
  add constraint carts_converted_order_fk
  foreign key (converted_order_id) references public.orders (id) on delete set null;

alter table public.carts
  add constraint carts_coupon_fk
  foreign key (coupon_id) references public.coupons (id) on delete set null;

-- ─── Order items (full snapshot) ───────────────────────────────────────────
create table public.order_items (
  id                    uuid primary key default gen_random_uuid(),
  order_id              uuid not null references public.orders (id) on delete cascade,

  -- References are advisory only; the snapshot columns are authoritative.
  product_id            uuid references public.products (id) on delete set null,
  variant_id            uuid references public.product_variants (id) on delete set null,
  category_id           uuid references public.categories (id) on delete set null,

  -- ── Snapshot ──
  product_name          text not null,
  product_slug          text,
  variant_name          text,
  variant_option_group  text,
  category_name         text,
  food_type             public.food_type not null default 'VEG',
  image_path            text,
  short_description     text,

  quantity              smallint not null,
  -- Base price of the product/variant at order time
  unit_price            app.money not null,
  -- Sum of modifier prices for a single unit
  modifiers_price       app.money not null default 0,
  -- (unit_price + modifiers_price) × quantity, before discounts
  gross_amount          app.money not null,
  discount_amount       app.money not null default 0,
  -- Proportional share of the order-level coupon/promotion discount
  allocated_discount    app.money not null default 0,
  net_amount            app.money not null,
  packaging_charge      app.money not null default 0,

  tax_category_id       uuid references public.tax_categories (id) on delete set null,
  tax_rate              app.rate not null default 0,
  tax_inclusive         boolean not null default true,
  taxable_amount        app.money not null default 0,
  tax_amount            app.money not null default 0,
  cgst_amount           app.money not null default 0,
  sgst_amount           app.money not null default 0,
  igst_amount           app.money not null default 0,
  cess_amount           app.money not null default 0,
  hsn_sac_code          text,

  special_instructions  text,
  preparation_minutes   int,

  -- Item-level refund tracking for partial/item refunds
  refunded_quantity     smallint not null default 0,
  refunded_amount       app.money not null default 0,
  -- Kitchen may mark a single line unavailable during preparation
  is_cancelled          boolean not null default false,
  cancellation_note     text,

  display_order         int not null default 0,
  created_at            timestamptz not null default now(),

  constraint order_items_quantity check (quantity between 1 and 100),
  constraint order_items_refund_bounds check (
    refunded_quantity <= quantity and refunded_amount <= net_amount + tax_amount
  )
);

create index order_items_order_idx on public.order_items (order_id, display_order);
create index order_items_product_idx on public.order_items (product_id);
create index order_items_category_idx on public.order_items (category_id);

comment on table public.order_items is
  'Immutable line snapshots. Never join to products to render order history.';

create table public.order_item_modifiers (
  id                uuid primary key default gen_random_uuid(),
  order_item_id     uuid not null references public.order_items (id) on delete cascade,
  modifier_id       uuid references public.modifiers (id) on delete set null,
  modifier_group_id uuid references public.modifier_groups (id) on delete set null,
  -- Snapshot
  group_name        text not null,
  modifier_name     text not null,
  unit_price        app.money not null default 0,
  quantity          smallint not null default 1,
  total_price       app.money not null default 0,
  food_type         public.food_type not null default 'VEG',
  created_at        timestamptz not null default now()
);

create index order_item_modifiers_item_idx on public.order_item_modifiers (order_item_id);

-- ─── Status history (append-only timeline) ──────────────────────────────────
create table public.order_status_history (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references public.orders (id) on delete cascade,
  from_status     public.order_status,
  to_status       public.order_status not null,
  -- Customer-facing label rendered in the tracking timeline.
  label           text not null,
  note            text,
  actor_id        uuid references auth.users (id) on delete set null,
  actor_kind      public.actor_kind not null default 'USER',
  actor_role      public.app_role,
  -- True when a privileged user forced a transition the state machine disallows.
  is_override     boolean not null default false,
  metadata        jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

create index order_status_history_order_idx
  on public.order_status_history (order_id, created_at);

select app.make_append_only('public.order_status_history');

comment on table public.order_status_history is
  'Append-only order timeline. Source of truth for the customer tracking screen.';

-- ─── Internal notes ────────────────────────────────────────────────────────
create table public.order_notes (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references public.orders (id) on delete cascade,
  author_id   uuid references auth.users (id) on delete set null,
  note        text not null,
  is_internal boolean not null default true,
  created_at  timestamptz not null default now()
);

create index order_notes_order_idx on public.order_notes (order_id, created_at desc);

-- ─── Cancellation policy (admin configurable) ──────────────────────────────
-- Determines whether a customer may cancel at a given status, whether approval
-- is required, and how much of the order is refundable.
create table public.cancellation_policies (
  id                      uuid primary key default gen_random_uuid(),
  branch_id               uuid references public.branches (id) on delete cascade,
  status                  public.order_status not null,
  customer_can_cancel     boolean not null default false,
  requires_approval       boolean not null default false,
  -- Percentage of the order value refunded when cancelled at this status.
  refund_percentage       app.percent not null default 100,
  -- Flat fee retained by the restaurant.
  cancellation_fee        app.money not null default 0,
  -- Free-cancellation grace period measured from placed_at.
  grace_period_seconds    int not null default 0,
  customer_message        text,
  is_active               boolean not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create unique index cancellation_policies_key
  on public.cancellation_policies (coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid), status);

select app.attach_updated_at('public.cancellation_policies');

comment on table public.cancellation_policies is
  'Per-status cancellation rules. Drives both the customer CTA and the refund amount.';

-- ─── Order number generation ───────────────────────────────────────────────
create or replace function app.next_order_number(p_branch_id uuid)
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_code text;
  v_tz text;
  v_seq bigint;
begin
  select regexp_replace(code, '[^A-Z0-9]', '', 'g'), timezone
  into v_code, v_tz
  from public.branches where id = p_branch_id;

  v_seq := nextval('public.order_number_seq');

  return format(
    'BB-%s-%s-%s',
    coalesce(v_code, 'BB'),
    to_char(now() at time zone coalesce(v_tz, 'Asia/Kolkata'), 'YYMMDD'),
    lpad((v_seq % 100000)::text, 5, '0')
  );
end;
$$;

-- ─── Customer stat maintenance ─────────────────────────────────────────────
-- Lifetime value only counts money the restaurant actually kept.
create or replace function app.tg_orders_customer_stats()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_terminal_success boolean;
  v_terminal_cancel boolean;
begin
  v_terminal_success := new.status in ('DELIVERED', 'COMPLETED')
                        and (old.status is null or old.status not in ('DELIVERED', 'COMPLETED'));

  v_terminal_cancel := new.status in ('CUSTOMER_CANCELLED', 'ADMIN_CANCELLED', 'STORE_REJECTED', 'DELIVERY_FAILED')
                       and (old.status is null or old.status not in
                            ('CUSTOMER_CANCELLED', 'ADMIN_CANCELLED', 'STORE_REJECTED', 'DELIVERY_FAILED'));

  if v_terminal_success then
    update public.profiles p
    set completed_orders = p.completed_orders + 1,
        lifetime_value = p.lifetime_value + (new.grand_total - new.refunded_amount),
        average_order_value = case
          when p.completed_orders + 1 > 0
          then app.money_round((p.lifetime_value + (new.grand_total - new.refunded_amount)) / (p.completed_orders + 1))
          else 0
        end,
        last_order_at = greatest(coalesce(p.last_order_at, new.created_at), new.created_at),
        first_order_at = least(coalesce(p.first_order_at, new.created_at), new.created_at),
        updated_at = now()
    where p.id = new.user_id;

    -- Popularity counters for merchandising rails.
    update public.products pr
    set order_count = pr.order_count + oi.qty
    from (
      select product_id, sum(quantity)::int as qty
      from public.order_items
      where order_id = new.id and product_id is not null and not is_cancelled
      group by product_id
    ) oi
    where pr.id = oi.product_id;
  end if;

  if v_terminal_cancel then
    update public.profiles
    set cancelled_orders = cancelled_orders + 1, updated_at = now()
    where id = new.user_id;
  end if;

  return new;
end;
$$;

create trigger orders_customer_stats
  after update of status on public.orders
  for each row execute function app.tg_orders_customer_stats();

-- Count total orders as soon as one is placed.
create or replace function app.tg_orders_placed_stats()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set total_orders = total_orders + 1, updated_at = now()
  where id = new.user_id;

  return new;
end;
$$;

create trigger orders_placed_stats
  after insert on public.orders
  for each row execute function app.tg_orders_placed_stats();
