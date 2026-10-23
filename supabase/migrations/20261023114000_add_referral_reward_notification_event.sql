-- A wallet reward is a transactional account event, not a marketing campaign.
-- Keep its channel preferences independent from marketing-consent suppression.
alter type public.notification_event add value if not exists 'REFERRAL_REWARD';
