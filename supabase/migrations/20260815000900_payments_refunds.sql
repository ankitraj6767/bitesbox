-- ═══════════════════════════════════════════════════════════════════════════
-- 0009 · PAYMENTS & REFUNDS
--
-- Trust model
--   · The Flutter callback is a hint, never proof.
--   · A payment becomes CAPTURED only after the backend verifies the Razorpay
--     signature (verify-payment) or processes a signed webhook.
--   · Both paths converge on app.record_payment_capture(), which is idempotent.
--   · Every gateway message lands in payment_events (append-only) and is
--     deduplicated by provider event id.
-- ═══════════════════════════════════════════════════════════════════════════

create table public.payments (
  id                      uuid primary key default gen_random_uuid(),
  order_id                uuid not null references public.orders (id) on delete restrict,
  user_id                 uuid not null references auth.users (id) on delete restrict,
  branch_id               uuid not null references public.branches (id) on delete restrict,

  gateway                 public.payment_gateway not null default 'RAZORPAY',
  mode                    public.payment_mode not null,
  method                  public.payment_method,
  status                  public.payment_status not null default 'CREATED',

  -- Amounts. `amount` is the intended capture; `amount_captured` is what the
  -- gateway confirmed. They can differ transiently and must reconcile.
  currency_code           char(3) not null default 'INR',
  amount                  app.money not null,
  amount_captured         app.money not null default 0,
  amount_refunded         app.money not null default 0,
  -- Gateway fee + tax, used for net settlement reporting.
  gateway_fee             app.money not null default 0,
  gateway_tax             app.money not null default 0,

  -- ── Razorpay identifiers ──
  provider_order_id       text,
  provider_payment_id     text,
  provider_signature      text,
  provider_reference_id   text,
  -- Bank/UPI details the gateway returns, useful for support and reconciliation.
  provider_method_detail  jsonb not null default '{}'::jsonb,
  vpa                     text,
  card_last4              text,
  card_network            text,
  bank_name               text,
  wallet_provider         text,

  -- ── Idempotency & lifecycle ──
  idempotency_key         text not null,
  attempt_number          smallint not null default 1,
  failure_code            text,
  failure_reason          text,
  failure_source          text,
  authorized_at           timestamptz,
  captured_at             timestamptz,
  failed_at               timestamptz,
  -- Razorpay orders expire; the reconciliation job closes stale rows.
  expires_at              timestamptz,
  verified_by_callback    boolean not null default false,
  verified_by_webhook     boolean not null default false,
  reconciled_at           timestamptz,

  notes                   jsonb not null default '{}'::jsonb,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),

  constraint payments_captured_bounds check (amount_captured <= amount),
  constraint payments_refund_bounds check (amount_refunded <= amount_captured),
  constraint payments_failure_shape check (status <> 'FAILED' or failure_code is not null)
);

create unique index payments_idempotency_key on public.payments (idempotency_key);
create unique index payments_provider_order_key on public.payments (provider_order_id)
  where provider_order_id is not null;
create unique index payments_provider_payment_key on public.payments (provider_payment_id)
  where provider_payment_id is not null;
create index payments_order_idx on public.payments (order_id, created_at desc);
create index payments_status_idx on public.payments (status, created_at desc);
create index payments_reconcile_idx on public.payments (created_at)
  where status in ('CREATED', 'PENDING', 'AUTHORIZED');
create index payments_user_idx on public.payments (user_id, created_at desc);

select app.attach_updated_at('public.payments');

comment on table public.payments is
  'One row per payment attempt. CAPTURED only via signature or webhook verification.';
comment on column public.payments.verified_by_webhook is
  'True once a signed Razorpay webhook confirmed this payment. Required for full reconciliation.';

-- ─── Gateway event log (append-only, deduplicated) ─────────────────────────
create table public.payment_events (
  id                  uuid primary key default gen_random_uuid(),
  payment_id          uuid references public.payments (id) on delete cascade,
  order_id            uuid references public.orders (id) on delete cascade,
  gateway             public.payment_gateway not null default 'RAZORPAY',
  -- Razorpay `x-razorpay-event-id` header. The unique index makes webhook
  -- processing exactly-once even if Razorpay retries.
  provider_event_id   text,
  event_type          text not null,
  source              text not null default 'WEBHOOK',
  signature_verified  boolean not null default false,
  payload             jsonb not null,
  processed           boolean not null default false,
  processed_at        timestamptz,
  processing_error    text,
  received_at         timestamptz not null default now(),

  constraint payment_events_source check (source in ('WEBHOOK', 'CALLBACK', 'POLL', 'MANUAL'))
);

create unique index payment_events_provider_event_key
  on public.payment_events (gateway, provider_event_id)
  where provider_event_id is not null;
create index payment_events_payment_idx on public.payment_events (payment_id, received_at desc);
create index payment_events_unprocessed_idx on public.payment_events (received_at)
  where not processed;

comment on table public.payment_events is
  'Append-only gateway messages. Unique provider_event_id gives exactly-once webhook processing.';

-- ─── COD collection tracking ───────────────────────────────────────────────
create table public.cod_collections (
  id                  uuid primary key default gen_random_uuid(),
  order_id            uuid not null references public.orders (id) on delete cascade,
  delivery_partner_id uuid,
  expected_amount     app.money not null,
  collected_amount    app.money not null default 0,
  status              public.cod_status not null default 'COD_PENDING',
  collected_at        timestamptz,
  -- Cash handover from rider to the branch till.
  settled_at          timestamptz,
  settled_by          uuid references auth.users (id) on delete set null,
  settlement_note     text,
  discrepancy_amount  app.money_signed not null default 0,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create unique index cod_collections_order_key on public.cod_collections (order_id);
create index cod_collections_rider_idx on public.cod_collections (delivery_partner_id, status);
create index cod_collections_unsettled_idx on public.cod_collections (collected_at)
  where status = 'COD_COLLECTED' and settled_at is null;

select app.attach_updated_at('public.cod_collections');

-- ─── Refunds ───────────────────────────────────────────────────────────────
create table public.refunds (
  id                    uuid primary key default gen_random_uuid(),
  order_id              uuid not null references public.orders (id) on delete restrict,
  payment_id            uuid references public.payments (id) on delete restrict,
  user_id               uuid not null references auth.users (id) on delete restrict,

  kind                  public.refund_kind not null,
  destination           public.refund_destination not null default 'ORIGINAL_PAYMENT_METHOD',
  status                public.refund_status not null default 'REQUESTED',
  reason                public.refund_reason not null,
  reason_note           text,

  amount                app.money not null,
  -- Gateway refunds are asynchronous; this is what the provider confirmed.
  amount_processed      app.money not null default 0,

  -- Workflow
  requested_by          uuid references auth.users (id) on delete set null,
  requested_at          timestamptz not null default now(),
  approved_by           uuid references auth.users (id) on delete set null,
  approved_at           timestamptz,
  rejected_by           uuid references auth.users (id) on delete set null,
  rejected_at           timestamptz,
  rejection_note        text,
  processed_at          timestamptz,
  completed_at          timestamptz,
  failed_at             timestamptz,
  failure_code          text,
  failure_reason        text,

  -- Gateway
  provider_refund_id    text,
  provider_status       text,
  idempotency_key       text not null,
  speed_requested       text not null default 'normal',

  support_ticket_id     uuid,
  metadata              jsonb not null default '{}'::jsonb,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  constraint refunds_amount_positive check (amount > 0),
  constraint refunds_processed_bounds check (amount_processed <= amount),
  constraint refunds_speed check (speed_requested in ('normal', 'optimum')),
  constraint refunds_rejection_shape check (status <> 'REJECTED' or rejected_at is not null)
);

create unique index refunds_idempotency_key on public.refunds (idempotency_key);
create unique index refunds_provider_key on public.refunds (provider_refund_id)
  where provider_refund_id is not null;
create index refunds_order_idx on public.refunds (order_id, created_at desc);
create index refunds_status_idx on public.refunds (status, created_at desc);
create index refunds_pending_approval_idx on public.refunds (requested_at)
  where status in ('REQUESTED', 'APPROVAL_PENDING');

select app.attach_updated_at('public.refunds');

comment on table public.refunds is
  'Audited refund workflow: request → permission check → amount validation → gateway → webhook.';

-- Item-level refund lines for ITEM_REFUND / partial refunds.
create table public.refund_items (
  id              uuid primary key default gen_random_uuid(),
  refund_id       uuid not null references public.refunds (id) on delete cascade,
  order_item_id   uuid not null references public.order_items (id) on delete restrict,
  quantity        smallint not null,
  amount          app.money not null,
  created_at      timestamptz not null default now(),

  constraint refund_items_quantity check (quantity >= 1)
);

create index refund_items_refund_idx on public.refund_items (refund_id);
create unique index refund_items_key on public.refund_items (refund_id, order_item_id);

-- ─── Refund policy (who may refund how much without approval) ──────────────
create table public.refund_policies (
  id                        uuid primary key default gen_random_uuid(),
  role_code                 public.app_role not null,
  -- Refunds at or below this value are auto-approved for the role.
  auto_approve_limit        app.money not null default 0,
  -- Hard ceiling the role can request at all.
  max_request_amount        app.money,
  requires_second_approval_above app.money,
  is_active                 boolean not null default true,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

create unique index refund_policies_role_key on public.refund_policies (role_code);
select app.attach_updated_at('public.refund_policies');

-- ═══════════════════════════════════════════════════════════════════════════
-- REFUNDABLE AMOUNT — single source of truth
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.refundable_amount(p_order_id uuid)
returns numeric
language sql
stable
set search_path = ''
as $$
  select greatest(
    0,
    coalesce(o.grand_total, 0)
      - coalesce(o.refunded_amount, 0)
      -- Money still locked in in-flight refunds must not be promised twice.
      - coalesce((
          select sum(r.amount)
          from public.refunds r
          where r.order_id = o.id
            and r.status in ('REQUESTED', 'APPROVAL_PENDING', 'APPROVED', 'PROCESSING')
        ), 0)
  )
  from public.orders o
  where o.id = p_order_id;
$$;

comment on function app.refundable_amount is
  'Grand total minus completed refunds minus in-flight refunds. Prevents double refunds.';

-- Recomputes order.refunded_amount and the money-back status from the ledger.
create or replace function app.sync_order_refund_state(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total numeric;
  v_completed numeric;
  v_pending int;
  v_status public.order_status;
  v_target public.order_status;
begin
  select o.grand_total, o.status into v_total, v_status
  from public.orders o where o.id = p_order_id;

  select coalesce(sum(amount_processed), 0)
  into v_completed
  from public.refunds
  where order_id = p_order_id and status = 'COMPLETED';

  select count(*)
  into v_pending
  from public.refunds
  where order_id = p_order_id
    and status in ('REQUESTED', 'APPROVAL_PENDING', 'APPROVED', 'PROCESSING');

  update public.orders
  set refunded_amount = v_completed,
      payment_status = case
        when v_completed >= v_total and v_total > 0 then 'REFUNDED'::public.payment_status
        when v_completed > 0 then 'PARTIALLY_REFUNDED'::public.payment_status
        when v_pending > 0 then 'REFUND_PENDING'::public.payment_status
        else payment_status
      end,
      updated_at = now()
  where id = p_order_id;

  -- Reflect the refund in the ORDER status, but only through the state machine so
  -- the customer timeline stays complete. A missing edge (for example a refund on
  -- an order that is still in the kitchen) must not break the refund itself.
  if v_completed > 0 or v_pending > 0 then
    v_target := case
      when v_completed >= v_total and v_total > 0 then 'REFUNDED'::public.order_status
      when v_completed > 0 then 'PARTIALLY_REFUNDED'::public.order_status
      when v_pending > 0 then 'REFUND_PENDING'::public.order_status
      else null
    end;

    if v_target is not null and v_target <> v_status then
      begin
        perform app.transition_order(
          p_order_id, v_target, 'Refund state synchronised', 'SYSTEM'
        );
      exception when others then
        -- Money state is already correct; the fulfilment status simply stays put.
        null;
      end;
    end if;
  end if;

  -- Keep the payment row in step.
  update public.payments p
  set amount_refunded = coalesce((
        select sum(r.amount_processed) from public.refunds r
        where r.payment_id = p.id and r.status = 'COMPLETED'
      ), 0),
      status = case
        when coalesce((
          select sum(r.amount_processed) from public.refunds r
          where r.payment_id = p.id and r.status = 'COMPLETED'
        ), 0) >= p.amount_captured and p.amount_captured > 0 then 'REFUNDED'::public.payment_status
        when coalesce((
          select sum(r.amount_processed) from public.refunds r
          where r.payment_id = p.id and r.status = 'COMPLETED'
        ), 0) > 0 then 'PARTIALLY_REFUNDED'::public.payment_status
        else p.status
      end,
      updated_at = now()
  where p.order_id = p_order_id and p.status in ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED', 'REFUND_PENDING');
end;
$$;

create or replace function app.tg_refunds_sync_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.sync_order_refund_state(new.order_id);
  return new;
end;
$$;

create trigger refunds_sync_order
  after insert or update of status, amount_processed on public.refunds
  for each row execute function app.tg_refunds_sync_order();

-- Item-level refund quantities roll up to order_items for accurate invoicing.
create or replace function app.tg_refund_items_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.order_items oi
  set refunded_quantity = coalesce((
        select sum(ri.quantity)
        from public.refund_items ri
        join public.refunds r on r.id = ri.refund_id
        where ri.order_item_id = oi.id and r.status = 'COMPLETED'
      ), 0),
      refunded_amount = coalesce((
        select sum(ri.amount)
        from public.refund_items ri
        join public.refunds r on r.id = ri.refund_id
        where ri.order_item_id = oi.id and r.status = 'COMPLETED'
      ), 0)
  where oi.id = new.order_item_id;

  return new;
end;
$$;

create trigger refund_items_sync
  after insert or update on public.refund_items
  for each row execute function app.tg_refund_items_sync();

-- ═══════════════════════════════════════════════════════════════════════════
-- PAYMENT CAPTURE — the single idempotent path both callback and webhook use
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.record_payment_capture(
  p_payment_id uuid,
  p_provider_payment_id text,
  p_amount_captured numeric,
  p_method public.payment_method default null,
  p_source text default 'WEBHOOK',
  p_method_detail jsonb default '{}'::jsonb,
  p_gateway_fee numeric default 0,
  p_gateway_tax numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment public.payments;
  v_order public.orders;
  v_already boolean := false;
begin
  -- Row lock serialises a racing callback and webhook for the same payment.
  select * into v_payment
  from public.payments
  where id = p_payment_id
  for update;

  if not found then
    perform app.fail('PAYMENT_NOT_FOUND', 'Payment record not found.');
  end if;

  if v_payment.status in ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED') then
    v_already := true;
  end if;

  update public.payments
  set status = case when v_already then status else 'CAPTURED'::public.payment_status end,
      provider_payment_id = coalesce(p_provider_payment_id, provider_payment_id),
      amount_captured = greatest(amount_captured, coalesce(p_amount_captured, amount)),
      method = coalesce(p_method, method),
      provider_method_detail = case
        when p_method_detail = '{}'::jsonb then provider_method_detail
        else p_method_detail
      end,
      vpa = coalesce(p_method_detail ->> 'vpa', vpa),
      card_last4 = coalesce(p_method_detail ->> 'last4', card_last4),
      card_network = coalesce(p_method_detail ->> 'network', card_network),
      bank_name = coalesce(p_method_detail ->> 'bank', bank_name),
      wallet_provider = coalesce(p_method_detail ->> 'wallet', wallet_provider),
      gateway_fee = greatest(gateway_fee, coalesce(p_gateway_fee, 0)),
      gateway_tax = greatest(gateway_tax, coalesce(p_gateway_tax, 0)),
      captured_at = coalesce(captured_at, now()),
      verified_by_callback = verified_by_callback or p_source = 'CALLBACK',
      verified_by_webhook = verified_by_webhook or p_source = 'WEBHOOK',
      reconciled_at = case
        when (verified_by_callback or p_source = 'CALLBACK')
         and (verified_by_webhook or p_source = 'WEBHOOK')
        then now() else reconciled_at
      end,
      updated_at = now()
  where id = p_payment_id
  returning * into v_payment;

  select * into v_order from public.orders where id = v_payment.order_id for update;

  -- Advance the order exactly once, whichever verification path arrives first.
  if v_order.status = 'PENDING_PAYMENT' then
    perform app.transition_order(
      v_order.id,
      'PAYMENT_CONFIRMED'::public.order_status,
      format('Payment verified via %s', lower(p_source)),
      'WEBHOOK'::public.actor_kind,
      null,
      jsonb_build_object('payment_id', v_payment.id, 'source', p_source)
    );
  elsif v_order.payment_status <> 'CAPTURED' then
    update public.orders
    set payment_status = 'CAPTURED', paid_at = coalesce(paid_at, now()), updated_at = now()
    where id = v_order.id;
  end if;

  return jsonb_build_object(
    'payment_id', v_payment.id,
    'order_id', v_payment.order_id,
    'status', v_payment.status,
    'already_captured', v_already,
    'amount_captured', v_payment.amount_captured,
    'fully_reconciled', v_payment.verified_by_callback and v_payment.verified_by_webhook
  );
end;
$$;

comment on function app.record_payment_capture is
  'Idempotent capture used by both verify-payment and razorpay-webhook. Safe under retries.';

create or replace function app.record_payment_failure(
  p_payment_id uuid,
  p_failure_code text,
  p_failure_reason text,
  p_source text default 'WEBHOOK'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment public.payments;
begin
  select * into v_payment from public.payments where id = p_payment_id for update;

  if not found then
    perform app.fail('PAYMENT_NOT_FOUND', 'Payment record not found.');
  end if;

  -- A captured payment can never be downgraded by a late failure event.
  if v_payment.status in ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED') then
    return jsonb_build_object(
      'payment_id', v_payment.id,
      'status', v_payment.status,
      'ignored', true,
      'reason', 'Payment already captured; failure event ignored.'
    );
  end if;

  update public.payments
  set status = 'FAILED',
      failure_code = coalesce(p_failure_code, 'PAYMENT_FAILED'),
      failure_reason = p_failure_reason,
      failure_source = p_source,
      failed_at = now(),
      updated_at = now()
  where id = p_payment_id
  returning * into v_payment;

  update public.orders
  set payment_status = 'FAILED', updated_at = now()
  where id = v_payment.order_id and payment_status <> 'CAPTURED';

  return jsonb_build_object('payment_id', v_payment.id, 'status', 'FAILED', 'ignored', false);
end;
$$;
