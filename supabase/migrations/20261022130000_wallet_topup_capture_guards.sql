-- Keep the service-only capture RPC defensive if it is ever called with an
-- incomplete or malformed gateway payload.
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

  if p_source is null or p_source not in ('CALLBACK', 'WEBHOOK') then
    perform app.fail('VALIDATION_FAILED', 'Unsupported wallet top-up capture source.');
  end if;
  if p_provider_payment_id is null or length(p_provider_payment_id) < 6
     or length(p_provider_payment_id) > 64 then
    perform app.fail('VALIDATION_FAILED', 'A valid provider payment id is required.');
  end if;
  if p_amount_captured is null or p_amount_captured <= 0 then
    perform app.fail('INVALID_AMOUNT', 'The captured wallet top-up amount must be positive.');
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
