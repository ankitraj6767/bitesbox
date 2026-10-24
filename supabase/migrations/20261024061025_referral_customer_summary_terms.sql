-- Expose only customer-safe referral terms and progress in the existing summary RPC.
-- The function signature and grants stay unchanged; this migration is forward-only.

create or replace function public.my_referral_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_settings public.referral_program_settings;
  v_program_active boolean;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to view referrals.');
  end if;

  select * into v_settings
  from public.referral_program_settings s
  where s.id;

  v_program_active := public.feature_enabled('referrals')
    and coalesce(v_settings.enabled, false);

  return jsonb_build_object(
    'code', (select p.referral_code from public.profiles p where p.id = v_uid),
    'share_path', (select '/r/' || p.referral_code from public.profiles p where p.id = v_uid),
    'program_active', v_program_active,
    'terms', case when v_program_active then jsonb_build_object(
      'referrer_reward', v_settings.referrer_reward,
      'referred_reward', v_settings.referred_reward,
      'minimum_order_amount', v_settings.minimum_order_amount,
      'reward_expiry_days', v_settings.reward_expiry_days
    ) else null end,
    'attributed_count', (select count(*) from public.referrals r where r.inviter_id = v_uid),
    'qualified_count', (select count(*) from public.referrals r where r.inviter_id = v_uid and r.status in ('QUALIFIED','REWARDED','REVERSED')),
    'rewarded_count', (select count(*) from public.referrals r where r.inviter_id = v_uid and r.rewarded_at is not null),
    'referrals', coalesce((
      select jsonb_agg(jsonb_build_object(
        'status', r.status,
        'attributed_at', r.attributed_at,
        'qualified_at', r.qualified_at,
        'rewarded_at', r.rewarded_at,
        'reward_amount', r.referrer_reward
      ) order by r.created_at desc)
      from public.referrals r
      where r.inviter_id = v_uid
    ), '[]'::jsonb)
  );
end;
$$;

-- Report the actual global rollout switch to staff; feature_enabled() is
-- customer-bucket aware and can be false for an operator during a partial
-- rollout even while the global switch is on.
create or replace function public.referral_admin_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_flag_enabled boolean;
begin
  if not app.has_permission('referral.manage') or coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    perform app.fail('MFA_REQUIRED', 'An authorized owner or administrator with verified MFA is required.');
  end if;

  select f.is_enabled into v_flag_enabled
  from public.feature_flags f
  where f.key = 'referrals';

  return jsonb_build_object(
    'settings', (select to_jsonb(s) - 'updated_by' from public.referral_program_settings s where s.id),
    'feature_flag_enabled', coalesce(v_flag_enabled, false),
    'metrics', jsonb_build_object(
      'codes_issued', (select count(*) from public.profiles where referral_code is not null and status = 'ACTIVE'),
      'attributed', (select count(*) from public.referrals),
      'qualified', (select count(*) from public.referrals where status in ('QUALIFIED','REWARDED','REVERSED')),
      'rewarded', (select count(*) from public.referrals where rewarded_at is not null),
      'reversed', (select count(*) from public.referrals where status = 'REVERSED'),
      'first_order_conversion_rate', case
        when (select count(*) from public.referrals) = 0 then 0
        else round((select count(*) from public.referrals where status in ('QUALIFIED','REWARDED','REVERSED'))::numeric
          / (select count(*) from public.referrals), 4)
      end
    ),
    'activity', coalesce((select jsonb_agg(jsonb_build_object(
      'id', r.id, 'status', r.status, 'referral_code', r.referral_code,
      'qualifying_order_id', r.qualifying_order_id, 'branch_id', r.branch_id,
      'referrer_reward', r.referrer_reward, 'referred_reward', r.referred_reward,
      'reversal_shortfall', r.reversal_shortfall, 'attributed_at', r.attributed_at,
      'qualified_at', r.qualified_at, 'rewarded_at', r.rewarded_at, 'reversed_at', r.reversed_at
    ) order by r.created_at desc) from (select * from public.referrals order by created_at desc limit 100) r), '[]'::jsonb)
  );
end;
$$;
