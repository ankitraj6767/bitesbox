-- ═══════════════════════════════════════════════════════════════════════════
-- 0014 · WALLET, LOYALTY & INVENTORY (future-ready, launch-safe)
--
-- Balances are NEVER stored as a bare mutable number. Every wallet account and
-- loyalty account has an append-only transaction ledger; the cached balance is
-- maintained by trigger and can always be rebuilt from the ledger.
--
-- Inventory is modelled so ingredient-level tracking can be switched on later
-- without touching the menu schema. Launch uses menu-level availability only.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Wallet ────────────────────────────────────────────────────────────────
create table public.wallet_accounts (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  currency_code     char(3) not null default 'INR',
  -- Cached from the ledger by trigger. Never written directly by clients.
  balance           app.money not null default 0,
  lifetime_credited app.money not null default 0,
  lifetime_debited  app.money not null default 0,
  is_frozen         boolean not null default false,
  frozen_reason     text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create unique index wallet_accounts_user_key on public.wallet_accounts (user_id);
select app.attach_updated_at('public.wallet_accounts');

comment on column public.wallet_accounts.balance is
  'Derived cache of wallet_transactions. Rebuildable via app.rebuild_wallet_balance().';

create table public.wallet_transactions (
  id                uuid primary key default gen_random_uuid(),
  wallet_account_id uuid not null references public.wallet_accounts (id) on delete cascade,
  user_id           uuid not null references auth.users (id) on delete cascade,
  kind              public.wallet_entry_kind not null,
  -- Positive for credits, negative for debits. The sign is enforced below.
  amount            app.money_signed not null,
  balance_after     app.money not null,
  description       text not null,
  order_id          uuid references public.orders (id) on delete set null,
  refund_id         uuid references public.refunds (id) on delete set null,
  support_ticket_id uuid references public.support_tickets (id) on delete set null,
  -- Promotional credit can expire.
  expires_at        timestamptz,
  reference         text,
  idempotency_key   text,
  created_by        uuid references auth.users (id) on delete set null,
  created_at        timestamptz not null default now(),

  constraint wallet_transactions_sign check (
    (kind in ('CREDIT', 'REFUND', 'PROMOTION', 'CASHBACK') and amount > 0)
    or (kind in ('DEBIT', 'EXPIRY') and amount < 0)
    or (kind in ('ADJUSTMENT', 'REVERSAL'))
  ),
  constraint wallet_transactions_amount_nonzero check (amount <> 0)
);

create index wallet_transactions_account_idx
  on public.wallet_transactions (wallet_account_id, created_at desc);
create unique index wallet_transactions_idempotency_key
  on public.wallet_transactions (idempotency_key) where idempotency_key is not null;
create index wallet_transactions_expiring_idx on public.wallet_transactions (expires_at)
  where expires_at is not null;

select app.make_append_only('public.wallet_transactions');

comment on table public.wallet_transactions is
  'Append-only wallet ledger. Immutable: corrections are posted as REVERSAL entries.';

-- Atomic ledger post: locks the account, validates funds, writes the entry and
-- updates the cached balance in one transaction.
create or replace function app.post_wallet_entry(
  p_user_id uuid,
  p_kind public.wallet_entry_kind,
  p_amount numeric,
  p_description text,
  p_order_id uuid default null,
  p_refund_id uuid default null,
  p_idempotency_key text default null,
  p_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account public.wallet_accounts;
  v_existing public.wallet_transactions;
  v_new_balance numeric;
  v_txn public.wallet_transactions;
begin
  if p_amount = 0 then
    perform app.fail('INVALID_AMOUNT', 'Wallet amount must be non-zero.');
  end if;

  -- Idempotency: replay returns the original entry.
  if p_idempotency_key is not null then
    select * into v_existing from public.wallet_transactions
    where idempotency_key = p_idempotency_key;

    if found then
      return jsonb_build_object(
        'transaction_id', v_existing.id,
        'balance', v_existing.balance_after,
        'replayed', true
      );
    end if;
  end if;

  insert into public.wallet_accounts (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select * into v_account from public.wallet_accounts
  where user_id = p_user_id
  for update;

  if v_account.is_frozen and p_amount < 0 then
    perform app.fail('WALLET_FROZEN', 'This wallet is temporarily frozen.');
  end if;

  v_new_balance := v_account.balance + p_amount;

  if v_new_balance < 0 then
    perform app.fail(
      'INSUFFICIENT_WALLET_BALANCE',
      'Your wallet balance is not enough for this transaction.',
      jsonb_build_object('balance', v_account.balance, 'requested', abs(p_amount))
    );
  end if;

  insert into public.wallet_transactions (
    wallet_account_id, user_id, kind, amount, balance_after, description,
    order_id, refund_id, idempotency_key, expires_at, created_by
  )
  values (
    v_account.id, p_user_id, p_kind, p_amount, v_new_balance, p_description,
    p_order_id, p_refund_id, p_idempotency_key, p_expires_at, auth.uid()
  )
  returning * into v_txn;

  update public.wallet_accounts
  set balance = v_new_balance,
      lifetime_credited = lifetime_credited + greatest(p_amount, 0),
      lifetime_debited = lifetime_debited + greatest(-p_amount, 0),
      updated_at = now()
  where id = v_account.id;

  return jsonb_build_object(
    'transaction_id', v_txn.id,
    'balance', v_new_balance,
    'replayed', false
  );
end;
$$;

comment on function app.post_wallet_entry is
  'Only sanctioned way to move wallet money. Row-locks the account and is idempotent.';

create or replace function app.rebuild_wallet_balance(p_user_id uuid)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_balance numeric;
begin
  select coalesce(sum(wt.amount), 0)
  into v_balance
  from public.wallet_transactions wt
  join public.wallet_accounts wa on wa.id = wt.wallet_account_id
  where wa.user_id = p_user_id;

  update public.wallet_accounts
  set balance = v_balance, updated_at = now()
  where user_id = p_user_id;

  return v_balance;
end;
$$;

create or replace function public.my_wallet()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to continue.');
  end if;

  return jsonb_build_object(
    'enabled', public.feature_enabled('wallet'),
    'balance', coalesce((select balance from public.wallet_accounts where user_id = v_uid), 0),
    'is_frozen', coalesce((select is_frozen from public.wallet_accounts where user_id = v_uid), false),
    'transactions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', wt.id,
          'kind', wt.kind,
          'amount', wt.amount,
          'balance_after', wt.balance_after,
          'description', wt.description,
          'order_id', wt.order_id,
          'created_at', wt.created_at
        ) order by wt.created_at desc
      )
      from public.wallet_transactions wt
      where wt.user_id = v_uid
      limit 50
    ), '[]'::jsonb)
  );
end;
$$;

-- ─── Loyalty ───────────────────────────────────────────────────────────────
create table public.loyalty_accounts (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  points_balance  int not null default 0,
  lifetime_earned int not null default 0,
  lifetime_redeemed int not null default 0,
  tier            text not null default 'BRONZE',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint loyalty_accounts_balance check (points_balance >= 0),
  constraint loyalty_accounts_tier check (tier in ('BRONZE', 'SILVER', 'GOLD', 'PLATINUM'))
);

create unique index loyalty_accounts_user_key on public.loyalty_accounts (user_id);
select app.attach_updated_at('public.loyalty_accounts');

create table public.loyalty_transactions (
  id                  uuid primary key default gen_random_uuid(),
  loyalty_account_id  uuid not null references public.loyalty_accounts (id) on delete cascade,
  user_id             uuid not null references auth.users (id) on delete cascade,
  kind                public.loyalty_entry_kind not null,
  points              int not null,
  balance_after       int not null,
  description         text not null,
  order_id            uuid references public.orders (id) on delete set null,
  monetary_value      app.money not null default 0,
  expires_at          timestamptz,
  idempotency_key     text,
  created_at          timestamptz not null default now(),

  constraint loyalty_transactions_sign check (
    (kind = 'EARN' and points > 0)
    or (kind in ('REDEEM', 'EXPIRE') and points < 0)
    or (kind in ('ADJUSTMENT', 'REVERSAL'))
  )
);

create index loyalty_transactions_account_idx
  on public.loyalty_transactions (loyalty_account_id, created_at desc);
create unique index loyalty_transactions_idempotency_key
  on public.loyalty_transactions (idempotency_key) where idempotency_key is not null;

select app.make_append_only('public.loyalty_transactions');

create or replace function app.post_loyalty_entry(
  p_user_id uuid,
  p_kind public.loyalty_entry_kind,
  p_points int,
  p_description text,
  p_order_id uuid default null,
  p_monetary_value numeric default 0,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account public.loyalty_accounts;
  v_existing public.loyalty_transactions;
  v_new_balance int;
  v_txn public.loyalty_transactions;
begin
  if p_idempotency_key is not null then
    select * into v_existing from public.loyalty_transactions
    where idempotency_key = p_idempotency_key;
    if found then
      return jsonb_build_object('transaction_id', v_existing.id,
                                'points_balance', v_existing.balance_after, 'replayed', true);
    end if;
  end if;

  insert into public.loyalty_accounts (user_id) values (p_user_id)
  on conflict (user_id) do nothing;

  select * into v_account from public.loyalty_accounts where user_id = p_user_id for update;

  v_new_balance := v_account.points_balance + p_points;

  if v_new_balance < 0 then
    perform app.fail('INSUFFICIENT_LOYALTY_POINTS', 'You do not have enough points.',
      jsonb_build_object('balance', v_account.points_balance, 'requested', abs(p_points)));
  end if;

  insert into public.loyalty_transactions (
    loyalty_account_id, user_id, kind, points, balance_after, description,
    order_id, monetary_value, idempotency_key
  )
  values (
    v_account.id, p_user_id, p_kind, p_points, v_new_balance, p_description,
    p_order_id, coalesce(p_monetary_value, 0), p_idempotency_key
  )
  returning * into v_txn;

  update public.loyalty_accounts
  set points_balance = v_new_balance,
      lifetime_earned = lifetime_earned + greatest(p_points, 0),
      lifetime_redeemed = lifetime_redeemed + greatest(-p_points, 0),
      tier = case
        when lifetime_earned + greatest(p_points, 0) >= 5000 then 'PLATINUM'
        when lifetime_earned + greatest(p_points, 0) >= 2000 then 'GOLD'
        when lifetime_earned + greatest(p_points, 0) >= 500 then 'SILVER'
        else 'BRONZE'
      end,
      updated_at = now()
  where id = v_account.id;

  return jsonb_build_object('transaction_id', v_txn.id, 'points_balance', v_new_balance, 'replayed', false);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- INVENTORY — schema present, ingredient tracking off at launch
-- ═══════════════════════════════════════════════════════════════════════════
create table public.ingredients (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null,
  sku                   text,
  unit                  public.unit_of_measure not null default 'GRAM',
  category              text,
  -- Weighted average cost, recalculated on each purchase.
  average_cost_per_unit app.money not null default 0,
  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz
);

create unique index ingredients_name_key on public.ingredients (lower(name)) where deleted_at is null;
select app.attach_updated_at('public.ingredients');

create table public.inventory_items (
  id                  uuid primary key default gen_random_uuid(),
  branch_id           uuid not null references public.branches (id) on delete cascade,
  ingredient_id       uuid not null references public.ingredients (id) on delete cascade,
  quantity_on_hand    numeric(12, 3) not null default 0,
  low_stock_threshold numeric(12, 3),
  reorder_quantity    numeric(12, 3),
  last_counted_at     timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create unique index inventory_items_key on public.inventory_items (branch_id, ingredient_id);
create index inventory_items_low_stock_idx on public.inventory_items (branch_id)
  where low_stock_threshold is not null;

select app.attach_updated_at('public.inventory_items');

-- Recipes link a sellable product/variant to the ingredients it consumes.
create table public.recipes (
  id                  uuid primary key default gen_random_uuid(),
  product_id          uuid not null references public.products (id) on delete cascade,
  variant_id          uuid references public.product_variants (id) on delete cascade,
  ingredient_id       uuid not null references public.ingredients (id) on delete restrict,
  quantity            numeric(12, 3) not null,
  unit                public.unit_of_measure not null,
  is_optional         boolean not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint recipes_quantity check (quantity > 0)
);

create unique index recipes_key on public.recipes (
  product_id,
  coalesce(variant_id, '00000000-0000-0000-0000-000000000000'::uuid),
  ingredient_id
);

select app.attach_updated_at('public.recipes');

create table public.stock_movements (
  id              uuid primary key default gen_random_uuid(),
  branch_id       uuid not null references public.branches (id) on delete cascade,
  ingredient_id   uuid not null references public.ingredients (id) on delete restrict,
  kind            public.stock_movement_kind not null,
  quantity        numeric(12, 3) not null,
  unit            public.unit_of_measure not null,
  quantity_after  numeric(12, 3),
  unit_cost       app.money not null default 0,
  total_cost      app.money not null default 0,
  order_id        uuid references public.orders (id) on delete set null,
  reference       text,
  note            text,
  created_by      uuid references auth.users (id) on delete set null,
  created_at      timestamptz not null default now()
);

create index stock_movements_item_idx
  on public.stock_movements (branch_id, ingredient_id, created_at desc);
create index stock_movements_order_idx on public.stock_movements (order_id)
  where order_id is not null;

select app.make_append_only('public.stock_movements');

comment on table public.stock_movements is
  'Append-only stock ledger. Enabled by the inventory.ingredient_tracking feature flag.';

create table public.purchase_entries (
  id            uuid primary key default gen_random_uuid(),
  branch_id     uuid not null references public.branches (id) on delete cascade,
  supplier_name text,
  invoice_number text,
  invoice_date  date not null default current_date,
  total_amount  app.money not null default 0,
  note          text,
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

select app.attach_updated_at('public.purchase_entries');

create table public.purchase_entry_items (
  id                  uuid primary key default gen_random_uuid(),
  purchase_entry_id   uuid not null references public.purchase_entries (id) on delete cascade,
  ingredient_id       uuid not null references public.ingredients (id) on delete restrict,
  quantity            numeric(12, 3) not null,
  unit                public.unit_of_measure not null,
  unit_cost           app.money not null default 0,
  total_cost          app.money not null default 0,
  created_at          timestamptz not null default now(),

  constraint purchase_entry_items_quantity check (quantity > 0)
);

create index purchase_entry_items_entry_idx on public.purchase_entry_items (purchase_entry_id);
