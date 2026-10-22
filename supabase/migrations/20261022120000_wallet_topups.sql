-- Wallet top-ups are separate from order payments: they have no order or branch,
-- and may credit the wallet only after Razorpay confirms a captured payment.
create table public.wallet_topups (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references auth.users (id) on delete restrict,
  amount                app.money not null,
  currency_code         char(3) not null default 'INR',
  status                public.payment_status not null default 'CREATED',
  idempotency_key       text not null,
  provider_order_id     text,
  provider_payment_id   text,
  payment_source        text check (payment_source in ('CALLBACK', 'WEBHOOK')),
  expires_at            timestamptz,
  captured_at           timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  constraint wallet_topups_amount check (amount between 100 and 10000),
  constraint wallet_topups_currency check (currency_code = 'INR')
);

create unique index wallet_topups_user_idempotency_key
  on public.wallet_topups (user_id, idempotency_key);
create unique index wallet_topups_provider_order_key
  on public.wallet_topups (provider_order_id)
  where provider_order_id is not null;
create unique index wallet_topups_provider_payment_key
  on public.wallet_topups (provider_payment_id)
  where provider_payment_id is not null;
create index wallet_topups_user_created_idx
  on public.wallet_topups (user_id, created_at desc);

select app.attach_updated_at('public.wallet_topups');

alter table public.wallet_topups enable row level security;
revoke all on public.wallet_topups from anon, authenticated;
grant select, insert, update on public.wallet_topups to service_role;

comment on table public.wallet_topups is
  'Server-only Razorpay top-up attempts. Wallet value is posted only by the capture RPC.';

create or replace function public.svc_record_wallet_topup_capture(
  p_topup_id uuid,
  p_provider_payment_id text,
  p_amount_captured numeric,
  p_source text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_topup public.wallet_topups;
  v_ledger jsonb;
begin
  perform app.assert_service_role();

  if p_source not in ('CALLBACK', 'WEBHOOK') then
    perform app.fail('VALIDATION_FAILED', 'Unsupported wallet top-up capture source.');
  end if;
  if p_provider_payment_id is null or length(p_provider_payment_id) < 6 then
    perform app.fail('VALIDATION_FAILED', 'A valid provider payment id is required.');
  end if;

  select * into v_topup
  from public.wallet_topups
  where id = p_topup_id
  for update;

  if not found then
    perform app.fail('WALLET_TOPUP_NOT_FOUND', 'We could not find that wallet top-up.');
  end if;

  if p_amount_captured <> v_topup.amount then
    perform app.fail(
      'PAYMENT_AMOUNT_MISMATCH',
      'The captured amount does not match the wallet top-up.'
    );
  end if;

  if v_topup.status = 'CAPTURED' then
    if v_topup.provider_payment_id <> p_provider_payment_id then
      perform app.fail('PAYMENT_ALREADY_CAPTURED', 'This top-up was captured by another payment.');
    end if;

    select jsonb_build_object(
      'transaction_id', wt.id,
      'balance', wt.balance_after,
      'replayed', true
    ) into v_ledger
    from public.wallet_transactions wt
    where wt.idempotency_key = 'wallet_topup:' || v_topup.id::text;

    return coalesce(v_ledger, jsonb_build_object('balance', 0, 'replayed', true))
      || jsonb_build_object('already_captured', true);
  end if;

  -- A delayed webhook may arrive after an attempt was marked failed or expired.
  -- Captured funds still belong in the wallet, so only a prior capture blocks it.
  v_ledger := app.post_wallet_entry(
    v_topup.user_id,
    'CREDIT',
    v_topup.amount,
    'Wallet top-up',
    null,
    null,
    'wallet_topup:' || v_topup.id::text
  );

  update public.wallet_topups
  set status = 'CAPTURED',
      provider_payment_id = p_provider_payment_id,
      payment_source = p_source,
      captured_at = now()
  where id = v_topup.id;

  return v_ledger || jsonb_build_object('already_captured', false);
end;
$$;

revoke all on function public.svc_record_wallet_topup_capture(uuid, text, numeric, text)
  from public, anon, authenticated;
grant execute on function public.svc_record_wallet_topup_capture(uuid, text, numeric, text)
  to service_role;
