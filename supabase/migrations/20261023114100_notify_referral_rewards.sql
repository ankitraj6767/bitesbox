-- Notify both referral parties from the existing durable queue. The queue picks
-- the profile's language, honors PUSH preference, and always retains IN_APP
-- transactional messages. Referral reward notices contain no promotional offer.
insert into public.notification_templates (event, channel, locale, title, body, action_route, variables)
values
  ('REFERRAL_REWARD', 'PUSH', 'en', 'Referral reward added',
   '₹{{amount}} has been added to your Bites Box wallet.', '/referrals', array['amount']),
  ('REFERRAL_REWARD', 'IN_APP', 'en', 'Referral reward added',
   '₹{{amount}} has been added to your Bites Box wallet.', '/referrals', array['amount']),
  ('REFERRAL_REWARD', 'PUSH', 'hi', 'रेफ़रल इनाम जुड़ गया',
   '₹{{amount}} आपके Bites Box वॉलेट में जोड़े गए हैं।', '/referrals', array['amount']),
  ('REFERRAL_REWARD', 'IN_APP', 'hi', 'रेफ़रल इनाम जुड़ गया',
   '₹{{amount}} आपके Bites Box वॉलेट में जोड़े गए हैं।', '/referrals', array['amount'])
on conflict (event, channel, locale) do nothing;

create or replace function app.notify_referral_reward()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status is distinct from 'REWARDED' and new.status = 'REWARDED' then
    begin
      perform app.enqueue_notification(
        new.inviter_id,
        'REFERRAL_REWARD'::public.notification_event,
        jsonb_build_object('amount', to_char(new.referrer_reward::numeric, 'FM9999999990.00')),
        array['PUSH', 'IN_APP']::public.notification_channel[],
        null,
        'referral:' || new.id::text || ':notification:inviter'
      );
    exception when others then
      -- Never make order/wallet qualification depend on a notification provider
      -- or queue issue. Keep the log free of recipient details and message text.
      raise warning 'Referral reward notification enqueue failed (SQLSTATE %).', SQLSTATE;
    end;

    begin
      perform app.enqueue_notification(
        new.referred_user_id,
        'REFERRAL_REWARD'::public.notification_event,
        jsonb_build_object('amount', to_char(new.referred_reward::numeric, 'FM9999999990.00')),
        array['PUSH', 'IN_APP']::public.notification_channel[],
        null,
        'referral:' || new.id::text || ':notification:referred'
      );
    exception when others then
      raise warning 'Referral reward notification enqueue failed (SQLSTATE %).', SQLSTATE;
    end;
  end if;
  return new;
end;
$$;

revoke all on function app.notify_referral_reward() from public, anon, authenticated;

create trigger referrals_notify_reward
  after update of status on public.referrals
  for each row execute function app.notify_referral_reward();
