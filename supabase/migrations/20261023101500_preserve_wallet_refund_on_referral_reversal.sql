-- A referral reversal must never consume the wallet credit issued for the same
-- completed refund. The wallet is fungible, so recover only from the balance
-- that remains after excluding credits linked to this refund; any unrecovered
-- amount is recorded as a shortfall for operators.
create or replace function app.reverse_referral_on_refund()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_referral public.referrals;
  v_recipient record;
  v_balance numeric;
  v_recover numeric;
  v_shortfall numeric := 0;
  v_inviter_recovered numeric := 0;
  v_referred_recovered numeric := 0;
begin
  if new.status <> 'COMPLETED' or old.status = 'COMPLETED' then return new; end if;
  select * into v_referral
  from public.referrals
  where qualifying_order_id = new.order_id
  for update;
  if not found or v_referral.status <> 'REWARDED' then return new; end if;

  for v_recipient in
    select * from (values
      (v_referral.inviter_id, v_referral.referrer_reward, 'inviter'),
      (v_referral.referred_user_id, v_referral.referred_reward, 'referred')
    ) as recipients(user_id, amount, recipient_key)
    order by user_id
  loop
    select greatest(
      wa.balance - coalesce((
        select sum(wt.amount)
        from public.wallet_transactions wt
        where wt.user_id = v_recipient.user_id
          and wt.refund_id = new.id
          and wt.kind = 'REFUND'
      ), 0),
      0
    )
    into v_balance
    from public.wallet_accounts wa
    where wa.user_id = v_recipient.user_id
    for update;

    v_recover := least(coalesce(v_balance, 0), v_recipient.amount);
    if v_recover > 0 then
      perform app.post_wallet_entry(
        v_recipient.user_id, 'REVERSAL', -v_recover,
        'Referral reward reversal', new.order_id, new.id,
        'referral:' || v_referral.id::text || ':reversal:' || v_recipient.recipient_key,
        null
      );
    end if;
    v_shortfall := v_shortfall + v_recipient.amount - v_recover;
    if v_recipient.recipient_key = 'inviter' then
      v_inviter_recovered := v_recover;
    else
      v_referred_recovered := v_recover;
    end if;
  end loop;

  update public.referrals
  set status = 'REVERSED', reversed_at = now(),
      referrer_recovered = v_inviter_recovered,
      referred_recovered = v_referred_recovered,
      reversal_shortfall = v_shortfall
  where id = v_referral.id;

  insert into public.referral_events (
    referral_id, event_key, event_type, actor_id, order_id, amount, details
  )
  values (
    v_referral.id,
    'referral:' || v_referral.id::text || ':reversed',
    'REVERSED', new.approved_by, new.order_id,
    -(v_inviter_recovered + v_referred_recovered),
    jsonb_build_object(
      'refund_id', new.id,
      'refund_amount', new.amount_processed,
      'shortfall', v_shortfall,
      'refund_wallet_credit_preserved', true,
      'policy', 'completed partial or full refunds reverse available referral value without consuming the refund credit'
    )
  )
  on conflict (event_key) do nothing;
  return new;
end;
$$;

comment on function app.reverse_referral_on_refund() is
  'Reverses referral value on completed refunds while preserving wallet credits linked to that refund.';
