-- ═══════════════════════════════════════════════════════════════════════════
-- 0011 · NOTIFICATIONS
--
-- Templates are data, editable by marketing without a deploy. Sending is a
-- two-step pipeline: enqueue in Postgres (transactional, survives restarts) then
-- deliver from the send-notification Edge Function per channel.
-- ═══════════════════════════════════════════════════════════════════════════

create table public.notification_templates (
  id                uuid primary key default gen_random_uuid(),
  event             public.notification_event not null,
  channel           public.notification_channel not null,
  locale            text not null default 'en',
  -- Push/email subject line
  title             text,
  body              text not null,
  -- Optional deep link, e.g. bitesbox://orders/{{order_id}}
  action_route      text,
  image_path        text,
  -- Provider template ids (DLT-registered SMS templates in India)
  provider_template_id text,
  -- Documented variables so the admin editor can validate before saving.
  variables         text[] not null default '{}',
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  updated_by        uuid references auth.users (id) on delete set null,

  constraint notification_templates_locale check (locale in ('en', 'hi'))
);

create unique index notification_templates_key
  on public.notification_templates (event, channel, locale);

select app.attach_updated_at('public.notification_templates');

comment on table public.notification_templates is
  'Editable message templates. {{variable}} placeholders resolved by app.render_template().';

-- ─── Device tokens ─────────────────────────────────────────────────────────
create table public.device_tokens (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  token         text not null,
  platform      public.device_platform not null,
  device_id     text,
  device_model  text,
  os_version    text,
  app_version   text,
  locale        text,
  timezone      text,
  is_active     boolean not null default true,
  -- FCM returns UNREGISTERED for stale tokens; the sender deactivates them.
  last_used_at  timestamptz,
  failure_count smallint not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create unique index device_tokens_token_key on public.device_tokens (token);
create index device_tokens_user_idx on public.device_tokens (user_id) where is_active;

select app.attach_updated_at('public.device_tokens');

comment on table public.device_tokens is
  'FCM registration tokens. Multiple devices per user; deactivated on logout or UNREGISTERED.';

-- ─── Notification queue / log ──────────────────────────────────────────────
create table public.notifications (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid references auth.users (id) on delete cascade,
  event             public.notification_event not null,
  channel           public.notification_channel not null,
  status            public.notification_status not null default 'QUEUED',

  title             text,
  body              text not null,
  action_route      text,
  image_path        text,
  data              jsonb not null default '{}'::jsonb,

  -- Correlation
  order_id          uuid references public.orders (id) on delete set null,
  support_ticket_id uuid,
  campaign_id       uuid,
  -- Direct destination when there is no user row (e.g. OTP before signup).
  destination       text,

  -- Idempotency: one notification per (user, event, order) unless forced.
  dedupe_key        text,
  scheduled_for     timestamptz,
  attempts          smallint not null default 0,
  sent_at           timestamptz,
  delivered_at      timestamptz,
  read_at           timestamptz,
  failed_at         timestamptz,
  failure_reason    text,
  provider_message_id text,
  provider          text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint notifications_attempts check (attempts between 0 and 10)
);

create unique index notifications_dedupe_key on public.notifications (dedupe_key)
  where dedupe_key is not null;
create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index notifications_pending_idx on public.notifications (scheduled_for, created_at)
  where status in ('QUEUED', 'SENDING');
create index notifications_unread_idx on public.notifications (user_id)
  where channel = 'IN_APP' and read_at is null;
create index notifications_order_idx on public.notifications (order_id);

select app.attach_updated_at('public.notifications');

-- ─── Campaigns ─────────────────────────────────────────────────────────────
create table public.notification_campaigns (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null,
  description         text,
  channels            public.notification_channel[] not null default '{PUSH}',
  segment             public.audience_segment not null default 'ALL_CUSTOMERS',
  -- Extra filter for the segment, e.g. {"category_id": "...", "days": 30}
  segment_filter      jsonb not null default '{}'::jsonb,
  title               text not null,
  body                text not null,
  image_path          text,
  action_route        text,
  coupon_id           uuid references public.coupons (id) on delete set null,

  status              public.campaign_status not null default 'DRAFT',
  scheduled_for       timestamptz,
  started_at          timestamptz,
  completed_at        timestamptz,

  -- Delivery statistics
  target_count        int not null default 0,
  queued_count        int not null default 0,
  sent_count          int not null default 0,
  failed_count        int not null default 0,
  read_count          int not null default 0,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  created_by          uuid references auth.users (id) on delete set null
);

create index notification_campaigns_status_idx
  on public.notification_campaigns (status, scheduled_for);

select app.attach_updated_at('public.notification_campaigns');

alter table public.notifications
  add constraint notifications_campaign_fk
  foreign key (campaign_id) references public.notification_campaigns (id) on delete set null;

-- Explicit recipient list for CUSTOM_LIST campaigns.
create table public.campaign_recipients (
  campaign_id uuid not null references public.notification_campaigns (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  primary key (campaign_id, user_id)
);

-- ─── OTP verification (provider-agnostic) ──────────────────────────────────
-- Used for delivery OTPs, pickup codes and any provider-side flow we own.
-- Supabase Auth handles login OTPs; this table covers operational codes.
create table public.verification_codes (
  id            uuid primary key default gen_random_uuid(),
  purpose       text not null,
  -- Phone, email or an entity id depending on purpose.
  subject       text not null,
  code_hash     text not null,
  salt          text not null,
  order_id      uuid references public.orders (id) on delete cascade,
  user_id       uuid references auth.users (id) on delete cascade,
  attempts      smallint not null default 0,
  max_attempts  smallint not null default 5,
  expires_at    timestamptz not null,
  consumed_at   timestamptz,
  created_ip    inet,
  created_at    timestamptz not null default now(),

  constraint verification_codes_purpose check (purpose in (
    'DELIVERY_OTP', 'PICKUP_CODE', 'PHONE_CHANGE', 'REFUND_CONFIRM', 'STAFF_OVERRIDE'
  ))
);

create index verification_codes_lookup_idx
  on public.verification_codes (purpose, subject, expires_at desc)
  where consumed_at is null;
create index verification_codes_order_idx on public.verification_codes (order_id);

-- ─── Rate limiting (OTP spam, coupon probing, refund abuse) ────────────────
create table public.rate_limits (
  id            bigserial primary key,
  bucket        text not null,
  identifier    text not null,
  window_start  timestamptz not null,
  hit_count     int not null default 1,
  blocked_until timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create unique index rate_limits_key on public.rate_limits (bucket, identifier, window_start);
create index rate_limits_blocked_idx on public.rate_limits (blocked_until)
  where blocked_until is not null;

comment on table public.rate_limits is
  'Fixed-window counters for OTP sends, coupon attempts, refund requests and login attempts.';

-- Atomic consume-or-reject. Returns true when the action is allowed.
create or replace function app.consume_rate_limit(
  p_bucket text,
  p_identifier text,
  p_max_hits int,
  p_window_seconds int,
  p_block_seconds int default 0
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window timestamptz;
  v_row public.rate_limits;
begin
  -- Fixed window: truncate now() to the window size.
  v_window := to_timestamp(
    floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds
  );

  insert into public.rate_limits as rl (bucket, identifier, window_start, hit_count)
  values (p_bucket, p_identifier, v_window, 1)
  on conflict (bucket, identifier, window_start) do update
    set hit_count = rl.hit_count + 1,
        updated_at = now()
  returning * into v_row;

  if v_row.blocked_until is not null and v_row.blocked_until > now() then
    return false;
  end if;

  if v_row.hit_count > p_max_hits then
    if p_block_seconds > 0 then
      update public.rate_limits
      set blocked_until = now() + make_interval(secs => p_block_seconds)
      where id = v_row.id;
    end if;
    return false;
  end if;

  return true;
end;
$$;

comment on function app.consume_rate_limit is
  'Atomic fixed-window rate limiter. Returns false when the caller must be rejected.';

-- ═══════════════════════════════════════════════════════════════════════════
-- TEMPLATE RENDERING & ENQUEUE
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.render_template(p_template text, p_vars jsonb)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_out text := coalesce(p_template, '');
  v_key text;
  v_val text;
begin
  if p_vars is null then
    return v_out;
  end if;

  for v_key, v_val in select key, value #>> '{}' from jsonb_each(p_vars) loop
    v_out := replace(v_out, '{{' || v_key || '}}', coalesce(v_val, ''));
    v_out := replace(v_out, '{{ ' || v_key || ' }}', coalesce(v_val, ''));
  end loop;

  -- Strip any unresolved placeholders so customers never see raw handlebars.
  return regexp_replace(v_out, '\{\{\s*[a-zA-Z0-9_.]+\s*\}\}', '', 'g');
end;
$$;

-- Enqueues one notification per channel, honouring user preferences and dedupe.
create or replace function app.enqueue_notification(
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
declare
  v_channel public.notification_channel;
  v_channels public.notification_channel[];
  v_template public.notification_templates;
  v_locale text := 'en';
  v_profile public.profiles;
  v_count int := 0;
  v_dedupe text;
  v_allowed boolean;
begin
  if p_user_id is not null then
    select * into v_profile from public.profiles where id = p_user_id;
    v_locale := coalesce(v_profile.preferred_language, 'en');
  end if;

  v_channels := coalesce(p_channels, array['PUSH', 'IN_APP']::public.notification_channel[]);

  foreach v_channel in array v_channels loop
    -- Respect notification preferences. Transactional order events always send
    -- in-app; only marketing is fully suppressible.
    v_allowed := true;

    if v_profile.id is not null then
      v_allowed := case v_channel
        when 'PUSH' then v_profile.push_enabled
        when 'SMS' then v_profile.sms_enabled
        when 'EMAIL' then v_profile.email_enabled
        when 'WHATSAPP' then v_profile.whatsapp_enabled
        else true
      end;

      if p_event in ('PROMOTION', 'CAMPAIGN') and not v_profile.marketing_opt_in then
        v_allowed := false;
      end if;
    end if;

    if not v_allowed then
      continue;
    end if;

    select * into v_template
    from public.notification_templates
    where event = p_event and channel = v_channel and locale = v_locale and is_active
    limit 1;

    -- Fall back to English if a localised template is missing.
    if not found then
      select * into v_template
      from public.notification_templates
      where event = p_event and channel = v_channel and locale = 'en' and is_active
      limit 1;
    end if;

    if not found then
      continue;
    end if;

    v_dedupe := case
      when p_dedupe_key is null then null
      else p_dedupe_key || ':' || v_channel::text
    end;

    insert into public.notifications (
      user_id, event, channel, title, body, action_route, image_path,
      data, order_id, dedupe_key, scheduled_for, destination
    )
    values (
      p_user_id,
      p_event,
      v_channel,
      app.render_template(v_template.title, p_vars),
      app.render_template(v_template.body, p_vars),
      app.render_template(v_template.action_route, p_vars),
      v_template.image_path,
      p_vars,
      p_order_id,
      v_dedupe,
      p_scheduled_for,
      p_destination
    )
    on conflict (dedupe_key) where dedupe_key is not null do nothing;

    if found then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

comment on function app.enqueue_notification is
  'Transactional notification enqueue. Honours channel preferences and dedupe keys.';

-- Customer-facing helpers
create or replace function public.mark_notifications_read(p_ids uuid[] default null)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  if auth.uid() is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to continue.');
  end if;

  update public.notifications
  set read_at = now(), status = 'READ', updated_at = now()
  where user_id = auth.uid()
    and channel = 'IN_APP'
    and read_at is null
    and (p_ids is null or id = any (p_ids));

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.register_device_token(
  p_token text,
  p_platform public.device_platform,
  p_device_id text default null,
  p_device_model text default null,
  p_os_version text default null,
  p_app_version text default null,
  p_locale text default null,
  p_timezone text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to continue.');
  end if;

  insert into public.device_tokens as dt (
    user_id, token, platform, device_id, device_model, os_version,
    app_version, locale, timezone, last_used_at
  )
  values (
    auth.uid(), p_token, p_platform, p_device_id, p_device_model, p_os_version,
    p_app_version, p_locale, p_timezone, now()
  )
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        device_id = coalesce(excluded.device_id, dt.device_id),
        device_model = coalesce(excluded.device_model, dt.device_model),
        os_version = coalesce(excluded.os_version, dt.os_version),
        app_version = coalesce(excluded.app_version, dt.app_version),
        locale = coalesce(excluded.locale, dt.locale),
        timezone = coalesce(excluded.timezone, dt.timezone),
        is_active = true,
        failure_count = 0,
        last_used_at = now(),
        updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.unregister_device_token(p_token text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.device_tokens
  set is_active = false, updated_at = now()
  where token = p_token and user_id = auth.uid();

  return found;
end;
$$;

comment on function public.unregister_device_token is
  'Called on logout so a shared device stops receiving another user''s notifications.';
