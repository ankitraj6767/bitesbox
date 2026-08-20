-- ═══════════════════════════════════════════════════════════════════════════
-- CAMPAIGNS & REVIEW MODERATION
--
-- Covers migration 0030, which gave the admin dashboard's "Send now" button
-- something to call, and the review moderation added in 0028.
--
-- The properties that matter for a campaign are: the audience is resolved in the
-- database and never handed to a browser, a marketing opt-out is absolute, and
-- sending twice does not notify anyone twice.
-- ═══════════════════════════════════════════════════════════════════════════
begin;

select tap.suite('Campaigns & review moderation');

select tap.reset();

select tap.remember('draft', id::text) from public.notification_campaigns
  where name = 'Win Back Inactive';
select tap.remember('scheduled', id::text) from public.notification_campaigns
  where name = 'Weekend Biryani Push';

-- A campaign that targets everyone, so the audience is predictable.
insert into public.notification_campaigns (name, channels, segment, title, body, status)
values (
  'Test broadcast',
  array['PUSH', 'IN_APP']::public.notification_channel[],
  'ALL_CUSTOMERS',
  'Fresh from the tandoor',
  'Two hours of 20% off, starting now.',
  'DRAFT'
);

select tap.remember('broadcast', id::text) from public.notification_campaigns
  where name = 'Test broadcast';

-- ─── Only marketing may send ────────────────────────────────────────────────
select tap.as_user(tap.seed('customer_a'));

select tap.throws(
  format('select public.launch_campaign(%L)', tap.recall_uuid('broadcast')),
  'PERMISSION_DENIED',
  'a customer cannot send a campaign'
);

select tap.throws(
  format('select public.campaign_audience_size(%L)', tap.recall_uuid('broadcast')),
  'PERMISSION_DENIED',
  'a customer cannot count the audience'
);

select tap.eq(
  tap.visible_count('select 1 from public.notification_campaigns'),
  0::bigint,
  'a customer cannot even see that campaigns exist'
);

select tap.reset();

select tap.as_user(tap.seed('kitchen'));

select tap.throws(
  format('select public.launch_campaign(%L)', tap.recall_uuid('broadcast')),
  'PERMISSION_DENIED',
  'kitchen staff cannot send a campaign'
);

select tap.reset();

-- ─── A dry run before committing ────────────────────────────────────────────
select tap.as_user(tap.seed('marketing'));

select tap.no_throw(
  format('select public.campaign_audience_size(%L)', tap.recall_uuid('broadcast')),
  'marketing can size the audience before sending'
);

select tap.ok(
  (select (public.campaign_audience_size(tap.recall_uuid('broadcast')) ->> 'audience')::int > 0),
  'the broadcast audience is not empty'
);

-- Staff accounts are not customers and must never be marketed to.
--
-- Asserted as the OWNER role rather than as marketing: `campaign_audience_size`
-- is SECURITY DEFINER and counts every profile, while the direct count runs under
-- the caller's RLS. As marketing that would compare 18 against the single row
-- marketing may read, which says nothing about the segment.
select tap.as_user(tap.seed('owner'));

select tap.eq(
  (select (public.campaign_audience_size(tap.recall_uuid('broadcast')) ->> 'audience')::int),
  (select count(*)::int from public.profiles p
    where p.deleted_at is null and p.status = 'ACTIVE'
      and exists (
        select 1 from public.user_roles ur
        join public.roles r on r.id = ur.role_id
        where ur.user_id = p.id and r.code = 'CUSTOMER' and ur.is_active
      )),
  'the audience is exactly the active customers'
);

-- ─── Marketing opt-out is absolute ──────────────────────────────────────────
update public.profiles
set marketing_opt_in = false
where id = tap.seed('customer_b');

select tap.as_user(tap.seed('marketing'));

select tap.ok(
  (select (public.campaign_audience_size(tap.recall_uuid('broadcast')) ->> 'opted_out')::int >= 1),
  'the dry run reports who has opted out'
);

-- ─── Sending ────────────────────────────────────────────────────────────────
select tap.remember(
  'result',
  (public.launch_campaign(tap.recall_uuid('broadcast')))::text
);

select tap.reset();

select tap.eq(
  (select status::text from public.notification_campaigns
    where id = tap.recall_uuid('broadcast')),
  'COMPLETED',
  'an immediate send completes'
);

select tap.ok(
  (select target_count > 0 and queued_count > 0
     from public.notification_campaigns where id = tap.recall_uuid('broadcast')),
  'the campaign records what it targeted and queued'
);

-- The audience is frozen into campaign_recipients so a later report, a resend and
-- an audit all agree on who was targeted, even if the segment drifts.
select tap.eq(
  (select count(*) from public.campaign_recipients
    where campaign_id = tap.recall_uuid('broadcast')),
  (select target_count::bigint from public.notification_campaigns
    where id = tap.recall_uuid('broadcast')),
  'the targeted audience is recorded against the campaign'
);

select tap.eq(
  (select count(*) from public.notifications
    where campaign_id = tap.recall_uuid('broadcast') and user_id = tap.seed('customer_b')),
  0::bigint,
  'an opted-out customer receives nothing'
);

select tap.ok(
  (select count(*) from public.notifications
    where campaign_id = tap.recall_uuid('broadcast')) > 0,
  'everyone else is queued'
);

-- Campaign copy comes from the campaign, not from a notification template.
select tap.eq(
  (select distinct title from public.notifications
    where campaign_id = tap.recall_uuid('broadcast') limit 1),
  'Fresh from the tandoor',
  'the queued notification carries the campaign copy'
);

select tap.eq(
  (select count(distinct channel) from public.notifications
    where campaign_id = tap.recall_uuid('broadcast')),
  2::bigint,
  'one notification per requested channel'
);

-- ─── Sending twice must not notify twice ────────────────────────────────────
select tap.remember(
  'queued_first',
  (select count(*)::text from public.notifications
    where campaign_id = tap.recall_uuid('broadcast'))
);

select tap.as_user(tap.seed('marketing'));

select tap.eq(
  (public.launch_campaign(tap.recall_uuid('broadcast')) ->> 'changed')::boolean,
  false,
  'resending a completed campaign is refused as a no-op'
);

select tap.reset();

select tap.eq(
  (select count(*)::text from public.notifications
    where campaign_id = tap.recall_uuid('broadcast')),
  tap.recall('queued_first'),
  'no additional notifications are queued'
);

-- Even forcing the campaign back to DRAFT cannot double-notify, because the
-- dedupe key is per campaign, channel and recipient.
update public.notification_campaigns set status = 'DRAFT' where id = tap.recall_uuid('broadcast');

select tap.as_user(tap.seed('marketing'));
select public.launch_campaign(tap.recall_uuid('broadcast'));
select tap.reset();

select tap.eq(
  (select count(*)::text from public.notifications
    where campaign_id = tap.recall_uuid('broadcast')),
  tap.recall('queued_first'),
  'a replayed send is idempotent on the dedupe key'
);

-- ─── Segments ───────────────────────────────────────────────────────────────
select tap.as_user(tap.seed('marketing'));

-- The inactive segment must be a subset of everyone, and both must resolve.
select tap.ok(
  (select (public.campaign_audience_size(tap.recall_uuid('draft')) ->> 'audience')::int
       <= (public.campaign_audience_size(tap.recall_uuid('broadcast')) ->> 'audience')::int),
  'the inactive segment is a subset of all customers'
);

-- ─── Cancelling ─────────────────────────────────────────────────────────────
select tap.no_throw(
  format('select public.cancel_campaign(%L, ''Wrong offer attached'')',
         tap.recall_uuid('scheduled')),
  'marketing can cancel a scheduled campaign'
);

select tap.reset();

select tap.eq(
  (select status::text from public.notification_campaigns
    where id = tap.recall_uuid('scheduled')),
  'CANCELLED',
  'the campaign is cancelled'
);

select tap.as_user(tap.seed('marketing'));

select tap.throws(
  format('select public.cancel_campaign(%L)', tap.recall_uuid('broadcast')),
  'CHECKOUT_INVALID',
  'a campaign that has already gone out cannot be cancelled'
);

select tap.reset();

-- ═══════════════════════════════════════════════════════════════════════════
-- REVIEW MODERATION
-- ═══════════════════════════════════════════════════════════════════════════
select tap.remember('review', id::text) from public.reviews order by created_at limit 1;

-- ─── Direct table writes are gone ───────────────────────────────────────────
-- The admin dashboard used to update `reviews` through a table grant, which
-- recorded neither who hid a review nor why.
select tap.as_user(tap.seed('support'));

select tap.throws(
  format('update public.reviews set status = ''HIDDEN'' where id = %L',
         tap.recall_uuid('review')),
  'PERMISSION_DENIED',
  'a review cannot be hidden with a direct update'
);

select tap.reset();

-- ─── Only a moderator may moderate ──────────────────────────────────────────
select tap.as_user(tap.seed('customer_a'));

select tap.throws(
  format('select public.moderate_review(%L, ''HIDDEN'')', tap.recall_uuid('review')),
  'PERMISSION_DENIED',
  'a customer cannot hide a review'
);

select tap.reset();

select tap.as_user(tap.seed('manager'));

select tap.throws(
  format('select public.moderate_review(%L, null, null, null, null)',
         tap.recall_uuid('review')),
  'CHECKOUT_INVALID',
  'moderating nothing is refused'
);

select tap.no_throw(
  format('select public.moderate_review(%L, ''HIDDEN'', null, ''Names another customer'')',
         tap.recall_uuid('review')),
  'a manager can hide a review'
);

select tap.reset();

select tap.eq(
  (select status::text from public.reviews where id = tap.recall_uuid('review')),
  'HIDDEN',
  'the review is hidden'
);

select tap.ok(
  (select moderated_by = tap.seed('manager') and moderated_at is not null
     from public.reviews where id = tap.recall_uuid('review')),
  'the moderator is recorded'
);

select tap.ok(
  (select count(*) from public.audit_logs
    where entity_type = 'review' and entity_id = tap.recall('review')) >= 1,
  'hiding a review is audited'
);

-- ─── A hidden review disappears from the storefront ─────────────────────────
select tap.as_anon();

select tap.eq(
  (select count(*) from public.reviews where id = tap.recall_uuid('review')),
  0::bigint,
  'a guest cannot see a hidden review'
);

select tap.reset();

-- ─── Publishing a reply ─────────────────────────────────────────────────────
select tap.as_user(tap.seed('manager'));

select tap.no_throw(
  format(
    'select public.moderate_review(%L, ''PUBLISHED'', ''Sorry about this — we have spoken to the kitchen.'')',
    tap.recall_uuid('review')
  ),
  'a manager can publish a reply and restore the review'
);

select tap.reset();

select tap.ok(
  (select response_body is not null
      and responded_by = tap.seed('manager')
      and responded_at is not null
      and status = 'PUBLISHED'
     from public.reviews where id = tap.recall_uuid('review')),
  'the reply is attributed and the review is visible again'
);

select tap.as_anon();

select tap.eq(
  (select count(*) from public.reviews where id = tap.recall_uuid('review')),
  1::bigint,
  'a guest can see the review again'
);

select tap.reset();

select tap.done('Campaigns & review moderation');

rollback;
