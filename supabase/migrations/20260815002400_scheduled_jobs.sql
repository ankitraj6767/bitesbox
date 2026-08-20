-- ═══════════════════════════════════════════════════════════════════════════
-- 0024 · BACKGROUND JOBS
--
-- Job bodies live in Postgres so they run inside a transaction and are safe to
-- retry. They are driven by pg_cron when available; otherwise the
-- `scheduled-jobs` Edge Function invokes the same functions on a schedule.
-- Every run is recorded in job_runs for observability.
-- ═══════════════════════════════════════════════════════════════════════════

create table public.job_runs (
  id            bigserial primary key,
  job_name      text not null,
  started_at    timestamptz not null default now(),
  finished_at   timestamptz,
  duration_ms   int,
  status        text not null default 'RUNNING',
  processed     int not null default 0,
  result        jsonb,
  error_message text,

  constraint job_runs_status check (status in ('RUNNING', 'SUCCESS', 'FAILED'))
);

create index job_runs_name_idx on public.job_runs (job_name, started_at desc);

alter table public.job_runs enable row level security;

create policy job_runs_read on public.job_runs
  for select to authenticated using (app.has_permission('audit.view'));

grant select on public.job_runs to authenticated;
grant all on public.job_runs to service_role;
grant usage, select on sequence public.job_runs_id_seq to service_role;

-- Wraps a job body with timing, result capture and error isolation.
create or replace function app.run_job(p_job_name text, p_sql text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run_id bigint;
  v_start timestamptz := clock_timestamp();
  v_result jsonb;
begin
  insert into public.job_runs (job_name) values (p_job_name) returning id into v_run_id;

  begin
    execute p_sql into v_result;

    update public.job_runs
    set finished_at = now(),
        duration_ms = extract(milliseconds from (clock_timestamp() - v_start))::int,
        status = 'SUCCESS',
        processed = coalesce((v_result ->> 'processed')::int, 0),
        result = v_result
    where id = v_run_id;

    return v_result;
  exception when others then
    update public.job_runs
    set finished_at = now(),
        duration_ms = extract(milliseconds from (clock_timestamp() - v_start))::int,
        status = 'FAILED',
        error_message = sqlerrm
    where id = v_run_id;

    -- Never let one failing job abort a scheduler batch.
    return jsonb_build_object('job', p_job_name, 'error', sqlerrm, 'processed', 0);
  end;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: restore temporary out-of-stock items
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_restore_availability()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_products int;
  v_variants int;
  v_modifiers int;
begin
  with restored as (
    update public.product_availability
    set state = 'AVAILABLE',
        out_of_stock_until = null,
        out_of_stock_reason = null,
        changed_at = now(),
        updated_at = now()
    where state = 'TEMPORARILY_UNAVAILABLE'
      and out_of_stock_until is not null
      and out_of_stock_until <= now()
    returning 1
  )
  select count(*) into v_products from restored;

  with restored as (
    update public.product_variants
    set availability = 'AVAILABLE', out_of_stock_until = null, updated_at = now()
    where availability = 'TEMPORARILY_UNAVAILABLE'
      and out_of_stock_until is not null
      and out_of_stock_until <= now()
    returning 1
  )
  select count(*) into v_variants from restored;

  with restored as (
    update public.modifiers
    set availability = 'AVAILABLE', out_of_stock_until = null, updated_at = now()
    where availability = 'TEMPORARILY_UNAVAILABLE'
      and out_of_stock_until is not null
      and out_of_stock_until <= now()
    returning 1
  )
  select count(*) into v_modifiers from restored;

  return jsonb_build_object(
    'processed', v_products + v_variants + v_modifiers,
    'products', v_products, 'variants', v_variants, 'modifiers', v_modifiers
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: nightly daily reset — restore auto-reset items and clear day counters
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_daily_reset()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  with reset as (
    update public.product_availability
    set state = 'AVAILABLE',
        remaining_quantity = null,
        out_of_stock_until = null,
        out_of_stock_reason = null,
        changed_at = now(),
        updated_at = now()
    where auto_reset_daily and state <> 'AVAILABLE'
    returning 1
  )
  select count(*) into v_count from reset;

  -- Retire rate-limit windows that can no longer matter.
  delete from public.rate_limits
  where window_start < now() - interval '2 days'
    and (blocked_until is null or blocked_until < now());

  return jsonb_build_object('processed', v_count, 'availability_reset', v_count);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: branch auto-resume after a temporary pause
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_auto_resume_branches()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch public.branches;
  v_count int := 0;
begin
  for v_branch in
    select * from public.branches
    where auto_resume_at is not null
      and auto_resume_at <= now()
      and status <> 'OPEN'
      and deleted_at is null
  loop
    update public.branches
    set status = 'OPEN',
        status_reason = null,
        status_note = null,
        accepting_orders = true,
        auto_resume_at = null,
        status_changed_at = now(),
        updated_at = now()
    where id = v_branch.id;

    insert into public.branch_status_log (
      branch_id, previous_status, status, note, accepting_orders, actor_kind
    )
    values (v_branch.id, v_branch.status, 'OPEN', 'Auto-resumed after scheduled pause', true, 'SCHEDULER');

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('processed', v_count);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: activate scheduled orders when their slot arrives
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_activate_scheduled_orders()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_count int := 0;
  v_lead int := app.setting_int('ordering.schedule_lead_minutes', 45);
begin
  for v_order in
    select * from public.orders
    where timing = 'SCHEDULED'
      and status = 'PAYMENT_CONFIRMED'
      and scheduled_for is not null
      -- Release into the kitchen queue prep-time ahead of the promised slot.
      and scheduled_for - make_interval(mins => v_lead) <= now()
    order by scheduled_for
    limit 200
  loop
    perform app.transition_order(
      v_order.id, 'ORDER_PLACED',
      'Scheduled order released to the kitchen', 'SCHEDULER'
    );
    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('processed', v_count);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: expire stale rider offers
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_expire_assignments()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.delivery_assignments;
  v_count int := 0;
begin
  for v_assignment in
    select * from public.delivery_assignments
    where status = 'OFFERED' and expires_at is not null and expires_at < now()
    limit 200
  loop
    update public.delivery_assignments
    set status = 'EXPIRED', updated_at = now()
    where id = v_assignment.id;

    -- Return the order to dispatch so operations can reassign immediately.
    update public.orders o
    set status = 'READY_FOR_PICKUP'
    where o.id = v_assignment.order_id and false; -- guarded: use transition_order below

    begin
      perform app.transition_order(
        v_assignment.order_id, 'READY_FOR_PICKUP',
        'Rider offer expired without response', 'SCHEDULER'
      );
    exception when others then
      null; -- order already moved on; nothing to do
    end;

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('processed', v_count);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: detect delayed orders and alert
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_detect_delays()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_count int := 0;
begin
  for v_order in
    select * from public.orders
    where promised_at is not null
      and promised_at < now()
      and not is_delayed
      and status in ('ORDER_PLACED', 'STORE_ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP',
                     'RIDER_ASSIGNED', 'PICKED_UP', 'OUT_FOR_DELIVERY')
    limit 200
  loop
    update public.orders
    set is_delayed = true, delay_notified_at = now(), updated_at = now()
    where id = v_order.id;

    -- Keep the customer informed rather than letting them wonder.
    perform app.enqueue_notification(
      v_order.user_id, 'SYSTEM_ALERT',
      jsonb_build_object(
        'order_number', v_order.order_number,
        'order_id', v_order.id::text,
        'minutes_late', ceil(extract(epoch from (now() - v_order.promised_at)) / 60)::text
      ),
      array['PUSH', 'IN_APP']::public.notification_channel[],
      v_order.id,
      'order_delayed:' || v_order.id::text
    );

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('processed', v_count);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: expire abandoned unpaid orders
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_expire_unpaid_orders()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_count int := 0;
  v_ttl int := app.setting_int('payment.pending_ttl_minutes', 20);
begin
  for v_order in
    select * from public.orders
    where status = 'PENDING_PAYMENT'
      and created_at < now() - make_interval(mins => v_ttl)
    limit 200
  loop
    -- A payment may have captured without the app returning; never cancel then.
    if exists (
      select 1 from public.payments p
      where p.order_id = v_order.id
        and p.status in ('CAPTURED', 'AUTHORIZED', 'PARTIALLY_REFUNDED', 'REFUNDED')
    ) then
      continue;
    end if;

    perform app.transition_order(
      v_order.id, 'PAYMENT_FAILED',
      format('Payment not completed within %s minutes', v_ttl), 'SCHEDULER'
    );

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('processed', v_count);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: auto-complete delivered orders
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_complete_delivered_orders()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_count int := 0;
  v_hours int := app.setting_int('ordering.auto_complete_hours', 6);
begin
  for v_order in
    select * from public.orders
    where status = 'DELIVERED'
      and delivered_at < now() - make_interval(hours => v_hours)
    limit 500
  loop
    perform app.transition_order(v_order.id, 'COMPLETED', 'Auto-completed', 'SCHEDULER');
    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('processed', v_count);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: coupon expiry housekeeping
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_expire_coupons()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  with expired as (
    update public.coupons
    set is_active = false, updated_at = now()
    where is_active
      and ends_at is not null
      and ends_at < now()
      and deleted_at is null
    returning 1
  )
  select count(*) into v_count from expired;

  update public.promotions
  set is_active = false, updated_at = now()
  where is_active and ends_at is not null and ends_at < now() and deleted_at is null;

  -- Clear expired coupons still sitting on live carts.
  update public.carts c
  set coupon_id = null, coupon_code = null, updated_at = now()
  where c.is_active
    and c.coupon_id is not null
    and exists (
      select 1 from public.coupons cp
      where cp.id = c.coupon_id
        and (not cp.is_active or (cp.ends_at is not null and cp.ends_at < now()))
    );

  return jsonb_build_object('processed', v_count);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: abandoned cart nudge
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_abandoned_carts()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cart record;
  v_count int := 0;
  v_delay int := app.setting_int('cart.abandon_minutes', 60);
begin
  if not public.feature_enabled('abandoned_cart_nudge') then
    return jsonb_build_object('processed', 0, 'skipped', 'feature disabled');
  end if;

  for v_cart in
    select c.*, (select count(*) from public.cart_items ci where ci.cart_id = c.id) as item_count
    from public.carts c
    where c.is_active
      and c.converted_order_id is null
      and c.abandoned_notified_at is null
      and c.updated_at < now() - make_interval(mins => v_delay)
      and c.updated_at > now() - interval '3 days'
      and exists (select 1 from public.cart_items ci where ci.cart_id = c.id)
    limit 200
  loop
    perform app.enqueue_notification(
      v_cart.user_id, 'PROMOTION',
      jsonb_build_object('item_count', v_cart.item_count::text),
      array['PUSH']::public.notification_channel[],
      null,
      'abandoned_cart:' || v_cart.id::text
    );

    update public.carts set abandoned_notified_at = now() where id = v_cart.id;
    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('processed', v_count);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: payment reconciliation sweep
-- Flags payments that captured but never received a webhook (or vice versa) so
-- finance can act. The Edge Function polls Razorpay for these ids.
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_flag_unreconciled_payments()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_stale jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
    'payment_id', p.id,
    'order_id', p.order_id,
    'order_number', o.order_number,
    'provider_order_id', p.provider_order_id,
    'provider_payment_id', p.provider_payment_id,
    'status', p.status,
    'amount', p.amount,
    'verified_by_callback', p.verified_by_callback,
    'verified_by_webhook', p.verified_by_webhook,
    'created_at', p.created_at
  )), '[]'::jsonb)
  into v_stale
  from public.payments p
  join public.orders o on o.id = p.order_id
  where (
      -- Captured but only one verification path completed
      (p.status = 'CAPTURED' and p.reconciled_at is null
       and p.captured_at < now() - interval '10 minutes')
      -- Or created/pending far beyond a realistic checkout window
      or (p.status in ('CREATED', 'PENDING', 'AUTHORIZED')
          and p.created_at < now() - interval '30 minutes')
    )
    and p.created_at > now() - interval '7 days';

  return jsonb_build_object(
    'processed', jsonb_array_length(v_stale),
    'payments', v_stale
  );
end;
$$;

comment on function app.job_flag_unreconciled_payments is
  'Returns payments needing a Razorpay poll. Consumed by the scheduled-jobs Edge Function.';

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: rider document expiry warning
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_rider_document_expiry()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doc record;
  v_count int := 0;
begin
  -- Expire documents that have lapsed.
  update public.delivery_partner_documents
  set status = 'EXPIRED', updated_at = now()
  where status = 'APPROVED' and expires_on is not null and expires_on < current_date;

  -- Warn 15 days ahead.
  for v_doc in
    select d.*, dp.user_id, dp.full_name
    from public.delivery_partner_documents d
    join public.delivery_partners dp on dp.id = d.delivery_partner_id
    where d.status = 'APPROVED'
      and d.expires_on is not null
      and d.expires_on between current_date and current_date + 15
    limit 200
  loop
    perform app.enqueue_notification(
      v_doc.user_id, 'SYSTEM_ALERT',
      jsonb_build_object(
        'document_type', replace(v_doc.document_type::text, '_', ' '),
        'expires_on', to_char(v_doc.expires_on, 'DD Mon YYYY')
      ),
      array['PUSH', 'IN_APP']::public.notification_channel[],
      null,
      'doc_expiry:' || v_doc.id::text || ':' || v_doc.expires_on::text
    );
    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('processed', v_count);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- JOB: retention — trim the location breadcrumb trail
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.job_prune_location_history()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
  v_days int := app.setting_int('delivery.location_retention_days', 30);
begin
  with pruned as (
    delete from public.delivery_location_events
    where recorded_at < now() - make_interval(days => v_days)
    returning 1
  )
  select count(*) into v_count from pruned;

  -- Search telemetry beyond 180 days has no analytical value.
  delete from public.search_queries where created_at < now() - interval '180 days';

  -- Notification log beyond a year.
  delete from public.notifications
  where created_at < now() - interval '365 days'
    and status in ('SENT', 'DELIVERED', 'READ', 'FAILED', 'SUPPRESSED');

  return jsonb_build_object('processed', v_count);
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORCHESTRATORS — one entry point per cadence
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
      || jsonb_build_object('expire_unpaid_orders', app.run_job('expire_unpaid_orders', 'select app.job_expire_unpaid_orders()'));

  elsif upper(p_cadence) = 'HOURLY' then
    v_results := v_results
      || jsonb_build_object('complete_delivered_orders', app.run_job('complete_delivered_orders', 'select app.job_complete_delivered_orders()'))
      || jsonb_build_object('expire_coupons', app.run_job('expire_coupons', 'select app.job_expire_coupons()'))
      || jsonb_build_object('abandoned_carts', app.run_job('abandoned_carts', 'select app.job_abandoned_carts()'))
      || jsonb_build_object('unreconciled_payments', app.run_job('unreconciled_payments', 'select app.job_flag_unreconciled_payments()'));

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

-- ═══════════════════════════════════════════════════════════════════════════
-- pg_cron registration (best effort — the Edge Function is the fallback)
-- ═══════════════════════════════════════════════════════════════════════════
do $$
begin
  create extension if not exists pg_cron;

  -- Replace existing schedules so re-running migrations stays idempotent.
  perform cron.unschedule(jobid)
  from cron.job
  where jobname in ('bitesbox_minute', 'bitesbox_hourly', 'bitesbox_daily');

  perform cron.schedule(
    'bitesbox_minute', '* * * * *',
    $job$select public.run_scheduled_jobs('MINUTE')$job$
  );

  perform cron.schedule(
    'bitesbox_hourly', '5 * * * *',
    $job$select public.run_scheduled_jobs('HOURLY')$job$
  );

  -- 03:30 UTC = 09:00 IST, safely before the breakfast service.
  perform cron.schedule(
    'bitesbox_daily', '30 3 * * *',
    $job$select public.run_scheduled_jobs('DAILY')$job$
  );

  raise notice 'pg_cron schedules registered for Bites Box.';
exception when others then
  raise notice 'pg_cron unavailable (%). The scheduled-jobs Edge Function will drive the schedule.', sqlerrm;
end;
$$;
