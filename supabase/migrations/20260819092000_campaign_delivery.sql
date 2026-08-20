-- ═══════════════════════════════════════════════════════════════════════════
-- 0030 · CAMPAIGN DELIVERY
--
-- `notification_campaigns`, `campaign_recipients` and the seven-value
-- `audience_segment` enum all existed, and the admin dashboard already had a
-- "Send now" button wired to the send-notification function — but nothing
-- resolved a segment into people. The button could not work.
--
-- Design notes:
--
--   · The audience is resolved in Postgres, never in the browser. An operator
--     sending to "high value customers" must not be handed a customer list to do
--     it, and the segment definition has to be auditable in one place.
--   · Campaign copy lives on the campaign, not in `notification_templates`, so
--     these rows are inserted directly rather than through
--     `app.enqueue_notification`. That means this function owns the two checks
--     that function would have made: per-channel preference, and marketing
--     opt-out. Both are honoured below.
--   · Sending is idempotent. `dedupe_key` is
--     `campaign:{campaign_id}:{channel}:{user_id}`, so a double-clicked Send, a
--     retried Edge Function or an overlapping scheduled run cannot notify anyone
--     twice.
-- ═══════════════════════════════════════════════════════════════════════════

insert into public.settings (key, value, value_type, "group", label, description, is_public)
values
  (
    'campaign.high_value_lifetime_value',
    '5000'::jsonb,
    'money',
    'growth',
    'High-value customer threshold',
    'Lifetime spend at or above which a customer counts as high value.',
    false
  ),
  (
    'campaign.inactive_days',
    '30'::jsonb,
    'number',
    'growth',
    'Inactive after (days)',
    'Days since the last order before a customer is treated as lapsed.',
    false
  ),
  (
    'campaign.new_customer_days',
    '30'::jsonb,
    'number',
    'growth',
    'New customer window (days)',
    'How recently an account must have been created to count as new.',
    false
  ),
  (
    'campaign.max_recipients',
    '20000'::jsonb,
    'number',
    'growth',
    'Campaign recipient ceiling',
    'Safety limit on a single campaign so a mistargeted send cannot fan out without bound.',
    false
  )
on conflict (key) do nothing;

-- ═══════════════════════════════════════════════════════════════════════════
-- AUDIENCE RESOLUTION
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.campaign_audience(p_campaign_id uuid)
returns setof uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_campaign public.notification_campaigns;
  v_filter jsonb;
  v_days int;
  v_threshold numeric;
  v_limit int := app.setting_int('campaign.max_recipients', 20000);
begin
  select * into v_campaign
  from public.notification_campaigns
  where id = p_campaign_id;

  if not found then
    perform app.fail('ITEM_NOT_FOUND', 'That campaign no longer exists.');
  end if;

  v_filter := coalesce(v_campaign.segment_filter, '{}'::jsonb);

  -- Every branch below draws from the same base: a live, non-blocked account that
  -- actually holds the CUSTOMER role. Staff accounts are never marketed to.
  return query
  with eligible as (
    select p.id, p.total_orders, p.lifetime_value, p.last_order_at, p.created_at
    from public.profiles p
    where p.deleted_at is null
      and p.status = 'ACTIVE'
      and exists (
        select 1
        from public.user_roles ur
        join public.roles r on r.id = ur.role_id
        where ur.user_id = p.id
          and r.code = 'CUSTOMER'
          and ur.is_active
          and (ur.expires_at is null or ur.expires_at > now())
      )
  )
  select e.id
  from eligible e
  where case v_campaign.segment
    when 'ALL_CUSTOMERS' then true

    when 'NEW_CUSTOMERS' then
      e.created_at >= now() - make_interval(
        days => coalesce(
          (v_filter ->> 'days')::int,
          app.setting_int('campaign.new_customer_days', 30)
        )
      )

    when 'INACTIVE_CUSTOMERS' then
      e.total_orders > 0
      and (
        e.last_order_at is null
        or e.last_order_at < now() - make_interval(
          days => coalesce(
            (v_filter ->> 'days')::int,
            app.setting_int('campaign.inactive_days', 30)
          )
        )
      )

    when 'HIGH_VALUE_CUSTOMERS' then
      e.lifetime_value >= coalesce(
        (v_filter ->> 'min_lifetime_value')::numeric,
        app.setting_numeric('campaign.high_value_lifetime_value', 5000)
      )

    when 'CATEGORY_BUYERS' then
      exists (
        select 1
        from public.orders o
        join public.order_items oi on oi.order_id = o.id
        join public.products pr on pr.id = oi.product_id
        where o.user_id = e.id
          and not o.status = any (array['PAYMENT_FAILED', 'PENDING_PAYMENT']::public.order_status[])
          and o.placed_at >= now() - make_interval(days => coalesce((v_filter ->> 'days')::int, 90))
          and (
            pr.category_id = (v_filter ->> 'category_id')::uuid
            or pr.subcategory_id = (v_filter ->> 'subcategory_id')::uuid
          )
      )

    when 'ABANDONED_CART' then
      exists (
        select 1
        from public.carts c
        join public.cart_items ci on ci.cart_id = c.id
        where c.user_id = e.id
          and c.updated_at < now() - make_interval(
            hours => coalesce((v_filter ->> 'hours')::int, 6)
          )
          -- Nothing ordered since the cart went quiet.
          and not exists (
            select 1 from public.orders o
            where o.user_id = e.id and o.placed_at > c.updated_at
          )
      )

    when 'CUSTOM_LIST' then
      exists (
        select 1 from public.campaign_recipients cr
        where cr.campaign_id = p_campaign_id and cr.user_id = e.id
      )

    else false
  end
  limit v_limit;
end;
$$;

comment on function app.campaign_audience is
  'Resolves a campaign segment to user ids. Server-side only; a browser never receives a customer list.';

create or replace function public.campaign_audience_size(p_campaign_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_total int;
  v_reachable int;
begin
  perform app.require_permission('campaign.manage');

  select count(*) into v_total from app.campaign_audience(p_campaign_id);

  -- How many will actually receive it once opt-outs are applied. Showing this
  -- before sending stops the "why did only half of them get it?" conversation.
  select count(*) into v_reachable
  from app.campaign_audience(p_campaign_id) as a(user_id)
  join public.profiles p on p.id = a.user_id
  where p.marketing_opt_in;

  return jsonb_build_object(
    'campaign_id', p_campaign_id,
    'audience', v_total,
    'reachable', v_reachable,
    'opted_out', v_total - v_reachable
  );
end;
$$;

comment on function public.campaign_audience_size is
  'Dry run: how many customers a campaign would reach, before and after marketing opt-outs.';

-- ═══════════════════════════════════════════════════════════════════════════
-- SENDING
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.dispatch_campaign(p_campaign_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign public.notification_campaigns;
  v_channel public.notification_channel;
  v_targeted int := 0;
  v_queued int := 0;
  v_inserted int;
begin
  select * into v_campaign
  from public.notification_campaigns
  where id = p_campaign_id
  for update;

  if not found then
    perform app.fail('ITEM_NOT_FOUND', 'That campaign no longer exists.');
  end if;

  if v_campaign.status in ('RUNNING', 'COMPLETED') then
    return jsonb_build_object(
      'campaign_id', p_campaign_id,
      'status', v_campaign.status,
      'targeted', v_campaign.target_count,
      'queued', v_campaign.queued_count,
      'changed', false
    );
  end if;

  if v_campaign.status = 'CANCELLED' then
    perform app.fail('CHECKOUT_INVALID', 'This campaign was cancelled.');
  end if;

  update public.notification_campaigns
  set status = 'RUNNING', started_at = coalesce(started_at, now()), updated_at = now()
  where id = p_campaign_id;

  -- Freeze the audience into campaign_recipients so a resend, a report and an
  -- audit all agree on who was targeted, even if the segment drifts later.
  insert into public.campaign_recipients (campaign_id, user_id)
  select p_campaign_id, a.user_id
  from app.campaign_audience(p_campaign_id) as a(user_id)
  on conflict (campaign_id, user_id) do nothing;

  select count(*) into v_targeted
  from public.campaign_recipients
  where campaign_id = p_campaign_id;

  foreach v_channel in array v_campaign.channels loop
    with recipients as (
      select cr.user_id, p.marketing_opt_in, p.push_enabled, p.sms_enabled,
             p.email_enabled, p.whatsapp_enabled, p.phone, p.email
      from public.campaign_recipients cr
      join public.profiles p on p.id = cr.user_id
      where cr.campaign_id = p_campaign_id
        and p.deleted_at is null
        and p.status = 'ACTIVE'
        -- A campaign is marketing by definition, so an opt-out is absolute.
        and p.marketing_opt_in
        and case v_channel
          when 'PUSH' then p.push_enabled
          when 'SMS' then p.sms_enabled
          when 'EMAIL' then p.email_enabled
          when 'WHATSAPP' then p.whatsapp_enabled
          else true
        end
    ),
    queued as (
      insert into public.notifications (
        user_id, event, channel, title, body, action_route, image_path,
        data, campaign_id, dedupe_key, scheduled_for, destination
      )
      select
        r.user_id,
        'CAMPAIGN',
        v_channel,
        v_campaign.title,
        v_campaign.body,
        v_campaign.action_route,
        v_campaign.image_path,
        jsonb_build_object(
          'campaign_id', p_campaign_id,
          'campaign_name', v_campaign.name,
          'coupon_id', v_campaign.coupon_id
        ),
        p_campaign_id,
        format('campaign:%s:%s:%s', p_campaign_id, v_channel, r.user_id),
        v_campaign.scheduled_for,
        case v_channel
          when 'SMS' then r.phone::text
          when 'WHATSAPP' then r.phone::text
          when 'EMAIL' then r.email::text
          else null
        end
      from recipients r
      -- Channels that need an address are skipped when we do not have one.
      where v_channel in ('PUSH', 'IN_APP')
         or (v_channel in ('SMS', 'WHATSAPP') and r.phone is not null)
         or (v_channel = 'EMAIL' and r.email is not null)
      on conflict (dedupe_key) where dedupe_key is not null do nothing
      returning 1
    )
    select count(*) into v_inserted from queued;

    v_queued := v_queued + coalesce(v_inserted, 0);
  end loop;

  update public.notification_campaigns
  set target_count = v_targeted,
      queued_count = queued_count + v_queued,
      -- Scheduled sends stay RUNNING until their slot passes; an immediate send
      -- is done as soon as the rows are queued. The worker updates sent_count.
      status = case
        when v_campaign.scheduled_for is null or v_campaign.scheduled_for <= now()
        then 'COMPLETED'::public.campaign_status
        else 'RUNNING'::public.campaign_status
      end,
      completed_at = case
        when v_campaign.scheduled_for is null or v_campaign.scheduled_for <= now()
        then now()
        else null
      end,
      updated_at = now()
  where id = p_campaign_id;

  return jsonb_build_object(
    'campaign_id', p_campaign_id,
    'status', case when v_campaign.scheduled_for is null or v_campaign.scheduled_for <= now()
                   then 'COMPLETED' else 'RUNNING' end,
    'targeted', v_targeted,
    'queued', v_queued,
    'changed', true
  );
end;
$$;

comment on function app.dispatch_campaign is
  'Freezes a campaign audience and queues one notification per channel per reachable customer. Idempotent by dedupe key.';

-- Operator-triggered send. The admin dashboard reaches this through the
-- send-notification Edge Function, which re-checks campaign.manage first.
create or replace function public.launch_campaign(p_campaign_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_campaign public.notification_campaigns;
begin
  perform app.require_permission('campaign.manage');

  select * into v_campaign from public.notification_campaigns where id = p_campaign_id;

  if not found then
    perform app.fail('ITEM_NOT_FOUND', 'That campaign no longer exists.');
  end if;

  v_result := app.dispatch_campaign(p_campaign_id);

  perform app.audit(
    'BULK_UPDATE',
    'notification_campaign',
    p_campaign_id::text,
    jsonb_build_object('status', v_campaign.status),
    v_result,
    null,
    v_campaign.name,
    null
  );

  return v_result;
end;
$$;

-- Service-role entry point for the scheduled worker.
create or replace function public.svc_launch_campaign(p_campaign_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();
  return app.dispatch_campaign(p_campaign_id);
end;
$$;

create or replace function public.cancel_campaign(p_campaign_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign public.notification_campaigns;
begin
  perform app.require_permission('campaign.manage');

  select * into v_campaign
  from public.notification_campaigns
  where id = p_campaign_id
  for update;

  if not found then
    perform app.fail('ITEM_NOT_FOUND', 'That campaign no longer exists.');
  end if;

  if v_campaign.status = 'COMPLETED' then
    perform app.fail('CHECKOUT_INVALID', 'This campaign has already been sent.');
  end if;

  update public.notification_campaigns
  set status = 'CANCELLED', updated_at = now()
  where id = p_campaign_id;

  -- Anything still queued and unsent is withdrawn; already-sent rows stand.
  update public.notifications
  set status = 'SUPPRESSED', updated_at = now()
  where campaign_id = p_campaign_id and status = 'QUEUED';

  perform app.audit(
    'UPDATE', 'notification_campaign', p_campaign_id::text,
    jsonb_build_object('status', v_campaign.status),
    jsonb_build_object('status', 'CANCELLED'),
    p_reason, v_campaign.name, null
  );

  return jsonb_build_object('campaign_id', p_campaign_id, 'status', 'CANCELLED');
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEDULED SENDS
-- Campaigns whose slot has arrived are dispatched by the same job that drains
-- notifications, so an operator can set one up and log off.
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_launch_scheduled_campaigns()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign record;
  v_count int := 0;
begin
  for v_campaign in
    select id
    from public.notification_campaigns
    where status = 'SCHEDULED'
      and scheduled_for is not null
      and scheduled_for <= now()
    order by scheduled_for
    limit 20
  loop
    perform app.dispatch_campaign(v_campaign.id);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- Mark a scheduled campaign complete once its queue has drained.
create or replace function app.job_settle_running_campaigns()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  with settled as (
    update public.notification_campaigns c
    set status = 'COMPLETED', completed_at = now(), updated_at = now()
    where c.status = 'RUNNING'
      and c.started_at < now() - interval '10 minutes'
      and not exists (
        select 1 from public.notifications n
        where n.campaign_id = c.id and n.status = 'QUEUED'
      )
    returning 1
  )
  select count(*) into v_count from settled;

  -- Keep the delivery statistics honest for whatever has been attempted so far.
  update public.notification_campaigns c
  set sent_count = stats.sent,
      failed_count = stats.failed,
      read_count = stats.read,
      updated_at = now()
  from (
    select campaign_id,
           count(*) filter (where status in ('SENT', 'DELIVERED', 'READ')) as sent,
           count(*) filter (where status = 'FAILED') as failed,
           count(*) filter (where read_at is not null) as read
    from public.notifications
    where campaign_id is not null
    group by campaign_id
  ) as stats
  where stats.campaign_id = c.id
    and (c.sent_count <> stats.sent or c.failed_count <> stats.failed or c.read_count <> stats.read);

  return coalesce(v_count, 0);
end;
$$;

-- ─── Grants ─────────────────────────────────────────────────────────────────
grant execute on function public.launch_campaign(uuid) to authenticated;
grant execute on function public.cancel_campaign(uuid, text) to authenticated;
grant execute on function public.campaign_audience_size(uuid) to authenticated;

-- Service-only. The blanket revoke in migration 0025 covers `svc_%`, but this
-- function is created later, so it states its own exposure.
revoke all on function public.svc_launch_campaign(uuid) from public, anon, authenticated;
grant execute on function public.svc_launch_campaign(uuid) to service_role;

grant execute on function app.campaign_audience(uuid) to service_role;
grant execute on function app.dispatch_campaign(uuid) to service_role;
grant execute on function app.job_launch_scheduled_campaigns() to service_role;
grant execute on function app.job_settle_running_campaigns() to service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- Register the new jobs with the cadence orchestrator.
-- Replaced wholesale rather than patched so the full schedule stays readable in
-- one place, which is how an on-call operator will read it.
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.run_scheduled_jobs(p_cadence text default 'MINUTE')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_results jsonb := '{}'::jsonb;
begin
  -- Only the service role (Edge Function / pg_cron) may drive the scheduler.
  if not app.is_service_role() and not app.has_role('OWNER') then
    perform app.fail('PERMISSION_DENIED', 'Scheduled jobs are service-only.');
  end if;

  if upper(p_cadence) = 'MINUTE' then
    v_results := v_results
      || jsonb_build_object('restore_availability', app.run_job('restore_availability', 'select app.job_restore_availability()'))
      || jsonb_build_object('auto_resume_branches', app.run_job('auto_resume_branches', 'select app.job_auto_resume_branches()'))
      || jsonb_build_object('activate_scheduled_orders', app.run_job('activate_scheduled_orders', 'select app.job_activate_scheduled_orders()'))
      || jsonb_build_object('expire_assignments', app.run_job('expire_assignments', 'select app.job_expire_assignments()'))
      || jsonb_build_object('detect_delays', app.run_job('detect_delays', 'select app.job_detect_delays()'))
      || jsonb_build_object('expire_unpaid_orders', app.run_job('expire_unpaid_orders', 'select app.job_expire_unpaid_orders()'))
      || jsonb_build_object('launch_scheduled_campaigns', app.run_job('launch_scheduled_campaigns', 'select app.job_launch_scheduled_campaigns()'));

  elsif upper(p_cadence) = 'HOURLY' then
    v_results := v_results
      || jsonb_build_object('complete_delivered_orders', app.run_job('complete_delivered_orders', 'select app.job_complete_delivered_orders()'))
      || jsonb_build_object('expire_coupons', app.run_job('expire_coupons', 'select app.job_expire_coupons()'))
      || jsonb_build_object('abandoned_carts', app.run_job('abandoned_carts', 'select app.job_abandoned_carts()'))
      || jsonb_build_object('unreconciled_payments', app.run_job('unreconciled_payments', 'select app.job_flag_unreconciled_payments()'))
      || jsonb_build_object('settle_running_campaigns', app.run_job('settle_running_campaigns', 'select app.job_settle_running_campaigns()'));

  elsif upper(p_cadence) = 'DAILY' then
    v_results := v_results
      || jsonb_build_object('daily_reset', app.run_job('daily_reset', 'select app.job_daily_reset()'))
      || jsonb_build_object('rider_document_expiry', app.run_job('rider_document_expiry', 'select app.job_rider_document_expiry()'))
      || jsonb_build_object('prune_location_history', app.run_job('prune_location_history', 'select app.job_prune_location_history()'));
  else
    perform app.fail('UNKNOWN_CADENCE', 'Cadence must be MINUTE, HOURLY or DAILY.');
  end if;

  return jsonb_build_object('cadence', upper(p_cadence), 'ran_at', now(), 'results', v_results);
end;
$$;

comment on function public.run_scheduled_jobs is
  'Cadence orchestrator. Driven by pg_cron in production or the scheduled-jobs Edge Function.';

grant execute on function public.run_scheduled_jobs(text) to service_role;
