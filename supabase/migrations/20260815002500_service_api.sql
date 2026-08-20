-- ═══════════════════════════════════════════════════════════════════════════
-- 0025 · SERVICE API
--
-- The `app` schema is deliberately not exposed through PostgREST, so Edge
-- Functions cannot call app.* directly. This migration publishes a small, named
-- set of `svc_*` wrappers in `public`, executable ONLY by service_role.
--
-- Everything privileged therefore has exactly one door, and that door is listed
-- here in full. A reviewer can audit the entire trusted-server surface by reading
-- this one file.
-- ═══════════════════════════════════════════════════════════════════════════

-- Guard: every wrapper refuses to run unless the caller is the service role.
create or replace function app.assert_service_role()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if not app.is_service_role() then
    perform app.fail(
      'PERMISSION_DENIED',
      'This operation is only available to trusted server code.'
    );
  end if;
end;
$$;

-- ─── Order placement ───────────────────────────────────────────────────────
create or replace function public.svc_place_order(
  p_user_id uuid,
  p_idempotency_key text,
  p_payment_mode public.payment_mode default 'ONLINE',
  p_cart_id uuid default null,
  p_branch_id uuid default null,
  p_tip_amount numeric default 0,
  p_loyalty_points int default 0,
  p_channel public.order_channel default 'MOBILE_APP',
  p_app_version text default null,
  p_device_platform public.device_platform default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();

  return app.place_order(
    p_user_id, p_idempotency_key, p_payment_mode, p_cart_id, p_branch_id,
    p_tip_amount, p_loyalty_points, p_channel, p_app_version, p_device_platform
  );
end;
$$;

comment on function public.svc_place_order is
  'create-order Edge Function entry point. Recalculates all money before writing the order.';

-- ─── Payment lifecycle ─────────────────────────────────────────────────────
create or replace function public.svc_record_payment_capture(
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
begin
  perform app.assert_service_role();

  return app.record_payment_capture(
    p_payment_id, p_provider_payment_id, p_amount_captured, p_method,
    p_source, p_method_detail, p_gateway_fee, p_gateway_tax
  );
end;
$$;

comment on function public.svc_record_payment_capture is
  'Idempotent capture shared by verify-payment (callback) and razorpay-webhook.';

create or replace function public.svc_record_payment_failure(
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
begin
  perform app.assert_service_role();
  return app.record_payment_failure(p_payment_id, p_failure_code, p_failure_reason, p_source);
end;
$$;

-- ─── Refund lifecycle ──────────────────────────────────────────────────────
create or replace function public.svc_complete_refund(
  p_refund_id uuid,
  p_amount_processed numeric default null,
  p_provider_refund_id text default null,
  p_provider_status text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();
  return app.complete_refund(p_refund_id, p_amount_processed, p_provider_refund_id, p_provider_status);
end;
$$;

create or replace function public.svc_fail_refund(
  p_refund_id uuid,
  p_failure_code text,
  p_failure_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();
  return app.fail_refund(p_refund_id, p_failure_code, p_failure_reason);
end;
$$;

-- ─── Order state machine (system-initiated transitions) ────────────────────
create or replace function public.svc_transition_order(
  p_order_id uuid,
  p_to_status public.order_status,
  p_note text default null,
  p_actor_kind public.actor_kind default 'SYSTEM',
  p_actor_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();
  return app.transition_order(
    p_order_id, p_to_status, p_note, p_actor_kind, p_actor_id, p_metadata
  );
end;
$$;

-- ─── Notifications ─────────────────────────────────────────────────────────
create or replace function public.svc_enqueue_notification(
  p_user_id uuid,
  p_event public.notification_event,
  p_vars jsonb default '{}'::jsonb,
  p_channels public.notification_channel[] default null,
  p_order_id uuid default null,
  p_dedupe_key text default null,
  p_scheduled_for timestamptz default null,
  p_destination text default null
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();
  return app.enqueue_notification(
    p_user_id, p_event, p_vars, p_channels, p_order_id,
    p_dedupe_key, p_scheduled_for, p_destination
  );
end;
$$;

/**
 * Claims a batch of queued notifications for delivery.
 *
 * FOR UPDATE SKIP LOCKED makes this safe to run concurrently: two workers never
 * pick up the same row, so a customer cannot receive the same push twice.
 */
create or replace function public.svc_claim_notifications(
  p_limit int default 50,
  p_channels public.notification_channel[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_batch jsonb;
begin
  perform app.assert_service_role();

  with claimed as (
    select n.id
    from public.notifications n
    where n.status = 'QUEUED'
      and (n.scheduled_for is null or n.scheduled_for <= now())
      and n.attempts < 5
      and (p_channels is null or n.channel = any (p_channels))
    order by n.created_at
    limit least(coalesce(p_limit, 50), 200)
    for update skip locked
  ),
  marked as (
    update public.notifications n
    set status = 'SENDING', attempts = n.attempts + 1, updated_at = now()
    where n.id in (select id from claimed)
    returning n.*
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'user_id', m.user_id,
      'event', m.event,
      'channel', m.channel,
      'title', m.title,
      'body', m.body,
      'action_route', m.action_route,
      'image_path', m.image_path,
      'data', m.data,
      'order_id', m.order_id,
      'destination', coalesce(
        m.destination,
        case m.channel
          when 'SMS' then (select p.phone::text from public.profiles p where p.id = m.user_id)
          when 'EMAIL' then (select p.email::text from public.profiles p where p.id = m.user_id)
          else null
        end
      ),
      'push_tokens', case
        when m.channel = 'PUSH' then coalesce((
          select jsonb_agg(jsonb_build_object('id', dt.id, 'token', dt.token, 'platform', dt.platform))
          from public.device_tokens dt
          where dt.user_id = m.user_id and dt.is_active
        ), '[]'::jsonb)
        else '[]'::jsonb
      end,
      'locale', coalesce((select p.preferred_language from public.profiles p where p.id = m.user_id), 'en'),
      'attempts', m.attempts
    ) order by m.created_at
  ), '[]'::jsonb)
  into v_batch
  from marked m;

  return v_batch;
end;
$$;

comment on function public.svc_claim_notifications is
  'Atomically claims queued notifications using SKIP LOCKED so workers never duplicate a send.';

create or replace function public.svc_settle_notification(
  p_id uuid,
  p_status public.notification_status,
  p_provider text default null,
  p_provider_message_id text default null,
  p_failure_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();

  update public.notifications
  set
      -- A retryable failure returns to the queue until the attempt budget is spent.
      status = case
        when p_status = 'FAILED' and attempts < 5 then 'QUEUED'::public.notification_status
        else p_status
      end,
      provider = coalesce(p_provider, provider),
      provider_message_id = coalesce(p_provider_message_id, provider_message_id),
      failure_reason = p_failure_reason,
      sent_at = case when p_status in ('SENT', 'DELIVERED') then coalesce(sent_at, now()) else sent_at end,
      delivered_at = case when p_status = 'DELIVERED' then now() else delivered_at end,
      failed_at = case when p_status = 'FAILED' then now() else failed_at end,
      updated_at = now()
  where id = p_id;
end;
$$;

create or replace function public.svc_deactivate_device_token(p_token_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();

  update public.device_tokens
  set is_active = false, failure_count = failure_count + 1, updated_at = now()
  where id = p_token_id;
end;
$$;

comment on function public.svc_deactivate_device_token is
  'Called when FCM reports UNREGISTERED so dead tokens stop consuming send budget.';

-- ─── Webhook event bookkeeping ─────────────────────────────────────────────
/**
 * Records a gateway webhook exactly once.
 *
 * The unique index on (gateway, provider_event_id) is what makes webhook
 * processing exactly-once: a Razorpay retry inserts nothing and this function
 * reports already_processed, so the caller skips the side effects.
 */
create or replace function public.svc_register_webhook_event(
  p_gateway public.payment_gateway,
  p_provider_event_id text,
  p_event_type text,
  p_payload jsonb,
  p_signature_verified boolean,
  p_payment_id uuid default null,
  p_order_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.payment_events;
  v_existing public.payment_events;
begin
  perform app.assert_service_role();

  if p_provider_event_id is not null then
    select * into v_existing
    from public.payment_events
    where gateway = p_gateway and provider_event_id = p_provider_event_id;

    if found then
      return jsonb_build_object(
        'event_id', v_existing.id,
        'already_processed', v_existing.processed,
        'duplicate', true
      );
    end if;
  end if;

  insert into public.payment_events (
    payment_id, order_id, gateway, provider_event_id, event_type, source,
    signature_verified, payload
  )
  values (
    p_payment_id, p_order_id, p_gateway, p_provider_event_id, p_event_type,
    'WEBHOOK', p_signature_verified, p_payload
  )
  on conflict (gateway, provider_event_id) where provider_event_id is not null
  do nothing
  returning * into v_event;

  if v_event.id is null then
    -- Lost the race with a concurrent delivery of the same event.
    select * into v_existing
    from public.payment_events
    where gateway = p_gateway and provider_event_id = p_provider_event_id;

    return jsonb_build_object(
      'event_id', v_existing.id,
      'already_processed', v_existing.processed,
      'duplicate', true
    );
  end if;

  return jsonb_build_object(
    'event_id', v_event.id,
    'already_processed', false,
    'duplicate', false
  );
end;
$$;

create or replace function public.svc_settle_webhook_event(
  p_event_id uuid,
  p_processed boolean,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();

  update public.payment_events
  set processed = p_processed,
      processed_at = case when p_processed then now() else processed_at end,
      processing_error = p_error
  where id = p_event_id;
end;
$$;

-- ─── Payment lookup helpers for webhook handling ────────────────────────────
create or replace function public.svc_find_payment(
  p_provider_order_id text default null,
  p_provider_payment_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment public.payments;
begin
  perform app.assert_service_role();

  select * into v_payment
  from public.payments
  where (p_provider_payment_id is not null and provider_payment_id = p_provider_payment_id)
     or (p_provider_order_id is not null and provider_order_id = p_provider_order_id)
  order by created_at desc
  limit 1;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_payment.id,
    'order_id', v_payment.order_id,
    'user_id', v_payment.user_id,
    'status', v_payment.status,
    'amount', v_payment.amount,
    'amount_captured', v_payment.amount_captured,
    'currency_code', v_payment.currency_code,
    'provider_order_id', v_payment.provider_order_id,
    'provider_payment_id', v_payment.provider_payment_id,
    'verified_by_callback', v_payment.verified_by_callback,
    'verified_by_webhook', v_payment.verified_by_webhook
  );
end;
$$;

create or replace function public.svc_find_refund(p_provider_refund_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_refund public.refunds;
begin
  perform app.assert_service_role();

  select * into v_refund from public.refunds where provider_refund_id = p_provider_refund_id;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_refund.id,
    'order_id', v_refund.order_id,
    'status', v_refund.status,
    'amount', v_refund.amount,
    'amount_processed', v_refund.amount_processed
  );
end;
$$;

/** Attaches the gateway refund id once Razorpay accepts the refund request. */
create or replace function public.svc_mark_refund_processing(
  p_refund_id uuid,
  p_provider_refund_id text,
  p_provider_status text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();

  update public.refunds
  set status = case when status = 'COMPLETED' then status else 'PROCESSING' end,
      provider_refund_id = coalesce(p_provider_refund_id, provider_refund_id),
      provider_status = coalesce(p_provider_status, provider_status),
      processed_at = coalesce(processed_at, now()),
      updated_at = now()
  where id = p_refund_id;
end;
$$;

-- ─── Grants: service_role only ─────────────────────────────────────────────
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'svc\_%'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', fn.sig);
    execute format('grant execute on function %s to service_role', fn.sig);
  end loop;
end;
$$;
