-- Production readiness: consent-safe preferences, assignment-scoped GPS and
-- signed-JWT AAL2 checks. Forward-only; recovery is to restore a backup or apply
-- a reviewed forward migration. No hosted project is changed by this file.

-- Marketing is optional consent. Existing rows retain their explicit value.
alter table public.profiles alter column marketing_opt_in set default false;
alter table public.profiles alter column whatsapp_enabled set default false;

-- Return persisted delivery and marketing preferences in the authenticated
-- session payload, keeping profile screens from inventing opt-in defaults.
create or replace function public.my_session()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
  v_roles jsonb;
  v_permissions text[];
  v_primary public.app_role;
  v_branches jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('authenticated', false);
  end if;

  select * into v_profile from public.profiles where id = v_uid;

  select jsonb_agg(grant_row order by grant_row.is_primary desc, grant_row.rank desc)
  into v_roles
  from (
    select distinct r.code, r.label, ur.branch_id, ur.is_primary, r.surfaces, r.rank
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = v_uid
      and ur.is_active
      and (ur.expires_at is null or ur.expires_at > now())
  ) grant_row;

  select jsonb_agg(jsonb_build_object(
    'role', entry ->> 'code',
    'label', entry ->> 'label',
    'branch_id', entry -> 'branch_id',
    'is_primary', entry -> 'is_primary',
    'surfaces', entry -> 'surfaces'
  ))
  into v_roles
  from jsonb_array_elements(coalesce(v_roles, '[]'::jsonb)) entry;

  select coalesce(array_agg(distinct p.code), '{}')
  into v_permissions
  from public.user_roles ur
  join public.role_permissions rp on rp.role_id = ur.role_id
  join public.permissions p on p.id = rp.permission_id
  where ur.user_id = v_uid
    and ur.is_active
    and (ur.expires_at is null or ur.expires_at > now());

  v_primary := app.primary_role();

  select jsonb_agg(jsonb_build_object(
    'id', b.id, 'code', b.code, 'name', b.name, 'status', b.status
  ) order by b.display_order)
  into v_branches
  from public.branches b
  where b.deleted_at is null and b.is_active and app.can_access_branch(b.id);

  return jsonb_build_object(
    'authenticated', true,
    'user_id', v_uid,
    'profile', case when v_profile.id is null then null else jsonb_build_object(
      'id', v_profile.id,
      'phone', v_profile.phone,
      'email', v_profile.email,
      'full_name', v_profile.full_name,
      'avatar_url', v_profile.avatar_url,
      'status', v_profile.status,
      'preferred_language', v_profile.preferred_language,
      'onboarding_completed', v_profile.onboarding_completed,
      'total_orders', v_profile.total_orders,
      'marketing_opt_in', v_profile.marketing_opt_in,
      'push_enabled', v_profile.push_enabled,
      'sms_enabled', v_profile.sms_enabled,
      'email_enabled', v_profile.email_enabled,
      'whatsapp_enabled', v_profile.whatsapp_enabled
    ) end,
    'primary_role', v_primary,
    'roles', coalesce(v_roles, '[]'::jsonb),
    'permissions', to_jsonb(coalesce(v_permissions, '{}')),
    'branches', coalesce(v_branches, '[]'::jsonb),
    'account_active', coalesce(v_profile.status = 'ACTIVE', false)
  );
end;
$$;

-- AAL is read from the signed Supabase JWT. No mutable profile metadata or
-- client-supplied flags participate in the decision. Customers are not required
-- to enroll in MFA; these checks apply only to users holding a non-customer role.
create or replace function app.is_aal2()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    auth.jwt() ->> 'aal' = 'aal2'
    and (auth.jwt() ->> 'exp') ~ '^[0-9]+$'
    and (auth.jwt() ->> 'exp')::bigint > extract(epoch from now())::bigint,
    false
  );
$$;

create or replace function app.is_staff_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = auth.uid()
      and ur.is_active
      and (ur.expires_at is null or ur.expires_at > now())
      and r.code <> 'CUSTOMER'
  );
$$;

create or replace function app.permission_requires_aal2(p_permission text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_permission = any (array[
    'refund.create', 'refund.approve', 'refund.reject',
    'payment.adjust', 'payment.reconcile', 'payment.settings', 'wallet.adjust', 'cod.settle',
    'role.assign', 'role.manage', 'staff.create', 'staff.update',
    'campaign.manage', 'notification.send', 'notification.template',
    'report.view', 'report.export', 'customer.view', 'customer.update',
    'customer.block', 'customer.credit', 'delivery.override',
    'rider.approve', 'rider.suspend', 'settings.update', 'branch.manage',
    'feature_flag.update', 'coupon.update', 'coupon.delete', 'promotion.manage',
    'order.override'
  ]::text[]);
$$;

create or replace function app.has_permission(p_permission text, p_branch_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app.is_service_role()
    or (
      (not app.is_staff_user() or not app.permission_requires_aal2(p_permission) or app.is_aal2())
      and exists (
        select 1
        from public.user_roles ur
        join public.role_permissions rp on rp.role_id = ur.role_id
        join public.permissions p on p.id = rp.permission_id
        where ur.user_id = auth.uid()
          and ur.is_active
          and (ur.expires_at is null or ur.expires_at > now())
          and p.code = p_permission
          and (ur.branch_id is null or p_branch_id is null or ur.branch_id = p_branch_id)
      )
    );
$$;

create or replace function app.has_any_permission(p_permissions text[], p_branch_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app.is_service_role()
    or (
      (not app.is_staff_user()
       or not exists (
         select 1 from unnest(p_permissions) as requested(permission)
         where app.permission_requires_aal2(requested.permission)
       )
       or app.is_aal2())
      and exists (
        select 1
        from public.user_roles ur
        join public.role_permissions rp on rp.role_id = ur.role_id
        join public.permissions p on p.id = rp.permission_id
        where ur.user_id = auth.uid()
          and ur.is_active
          and (ur.expires_at is null or ur.expires_at > now())
          and p.code = any (p_permissions)
          and (ur.branch_id is null or p_branch_id is null or ur.branch_id = p_branch_id)
      )
    );
$$;

comment on function app.is_aal2() is
  'True only for the signed Supabase JWT assurance claim aal2.';
comment on function app.permission_requires_aal2(text) is
  'Sensitive staff permissions that require a Supabase-verified AAL2 session.';

revoke all on function app.is_aal2() from public, anon, authenticated;
revoke all on function app.is_staff_user() from public, anon, authenticated;
revoke all on function app.permission_requires_aal2(text) from public, anon, authenticated;

-- Add explicit consent for live GPS per assignment. Existing active jobs must
-- request consent again after this release; no historical location is replayed.
alter table public.delivery_assignments
  add column location_sharing_enabled boolean not null default false,
  add column location_sharing_started_at timestamptz;

-- Location writes must go through the timestamped, assignment-aware RPC below.
-- The historical self-write policies allowed riders to bypass capture-time,
-- consent and assignment checks with direct PostgREST table writes.
drop policy if exists delivery_partner_locations_self_write on public.delivery_partner_locations;
revoke insert, update, delete on public.delivery_partner_locations from authenticated;
drop policy if exists delivery_location_events_insert on public.delivery_location_events;
revoke insert on public.delivery_location_events from authenticated;
drop policy if exists delivery_partner_availability_insert on public.delivery_partner_availability;
revoke insert on public.delivery_partner_availability from authenticated;

create or replace function app.tg_reset_assignment_location_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.delivery_partner_id is distinct from old.delivery_partner_id
     or new.order_id is distinct from old.order_id
     or new.status not in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER') then
    new.location_sharing_enabled := false;
    new.location_sharing_started_at := null;
  end if;
  return new;
end;
$$;

create trigger reset_assignment_location_consent
  before update of delivery_partner_id, order_id, status on public.delivery_assignments
  for each row execute function app.tg_reset_assignment_location_consent();

create or replace function app.tg_clear_terminal_assignment_location()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.delivery_partner_id is distinct from new.delivery_partner_id
     or (old.status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
         and new.status not in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')) then
    delete from public.delivery_partner_locations
    where delivery_partner_id = old.delivery_partner_id
      and assignment_id = old.id;
  end if;
  return new;
end;
$$;

create trigger clear_terminal_assignment_location
  after update of delivery_partner_id, order_id, status on public.delivery_assignments
  for each row execute function app.tg_clear_terminal_assignment_location();

-- A rider with multiple active jobs shares only the server-selected current
-- assignment. When priority changes, revoke the previous assignment's consent
-- and detach its point immediately rather than waiting for the next GPS tick.
create or replace function app.reconcile_location_sharing_for_partner(p_partner_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_assignment_id uuid;
begin
  if p_partner_id is null then return; end if;

  select da.id into v_current_assignment_id
  from public.delivery_assignments da
  where da.delivery_partner_id = p_partner_id
    and da.status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
  order by case da.status when 'AT_CUSTOMER' then 1 when 'PICKED_UP' then 2
    when 'AT_STORE' then 3 else 4 end
  limit 1;

  update public.delivery_assignments da
  set location_sharing_enabled = false,
      location_sharing_started_at = null,
      updated_at = now()
  where da.delivery_partner_id = p_partner_id
    and da.location_sharing_enabled
    and (v_current_assignment_id is null or da.id <> v_current_assignment_id);

  update public.delivery_partner_locations loc
  set order_id = null, assignment_id = null, updated_at = now()
  where loc.delivery_partner_id = p_partner_id
    and loc.assignment_id is not null
    and (v_current_assignment_id is null or loc.assignment_id <> v_current_assignment_id);
end;
$$;

revoke all on function app.reconcile_location_sharing_for_partner(uuid) from public, anon, authenticated;

create or replace function app.tg_reconcile_assignment_location_sharing()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and old.delivery_partner_id is distinct from new.delivery_partner_id then
    perform app.reconcile_location_sharing_for_partner(old.delivery_partner_id);
  end if;
  perform app.reconcile_location_sharing_for_partner(new.delivery_partner_id);
  return new;
end;
$$;

revoke all on function app.tg_reset_assignment_location_consent() from public, anon, authenticated;
revoke all on function app.tg_clear_terminal_assignment_location() from public, anon, authenticated;
revoke all on function app.tg_reconcile_assignment_location_sharing() from public, anon, authenticated;

create trigger reconcile_assignment_location_sharing_insert
  after insert on public.delivery_assignments
  for each row execute function app.tg_reconcile_assignment_location_sharing();
create trigger reconcile_assignment_location_sharing_update
  after update of delivery_partner_id, order_id, status on public.delivery_assignments
  for each row execute function app.tg_reconcile_assignment_location_sharing();

-- Remove old idle coordinates from dispatch and customer surfaces. Breadcrumbs
-- remain available only for the existing 30-day dispute window.
delete from public.delivery_partner_locations loc
where not exists (
  select 1 from public.delivery_assignments da
  where da.id = loc.assignment_id
    and da.delivery_partner_id = loc.delivery_partner_id
    and da.location_sharing_enabled
    and da.status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
);

-- Preserve the old set_duty_state RPC shape for installed clients, but never
-- store a rider's position while they are merely available for dispatch.
create or replace function public.set_duty_state(
  p_state public.rider_duty_state,
  p_latitude numeric default null,
  p_longitude numeric default null,
  p_battery_level smallint default null,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_partner public.delivery_partners;
  v_previous public.rider_duty_state;
  v_load int;
begin
  select * into v_partner from public.delivery_partners
  where user_id = auth.uid() and deleted_at is null;
  if not found then
    perform app.fail('NOT_A_DELIVERY_PARTNER', 'This account is not a delivery partner.');
  end if;
  if v_partner.onboarding_status <> 'ACTIVE' then
    perform app.fail('RIDER_NOT_ACTIVE', 'Your rider account is not active.');
  end if;

  v_previous := v_partner.duty_state;
  v_load := app.rider_active_load(v_partner.id);
  if p_state = 'OFFLINE' and v_load > 0 then
    perform app.fail(
      'ACTIVE_DELIVERIES_PENDING',
      format('Finish your %s active delivery(ies) before going offline.', v_load),
      jsonb_build_object('active_deliveries', v_load)
    );
  end if;

  update public.delivery_partners
  set duty_state = p_state,
      last_online_at = case when p_state <> 'OFFLINE' then now() else last_online_at end,
      updated_at = now()
  where id = v_partner.id;

  insert into public.delivery_partner_availability (
    delivery_partner_id, duty_state, previous_state, reason, battery_level
  ) values (v_partner.id, p_state, v_previous, p_reason, p_battery_level);

  return jsonb_build_object(
    'delivery_partner_id', v_partner.id,
    'duty_state', p_state,
    'previous_state', v_previous,
    'active_deliveries', v_load
  );
end;
$$;

-- The legacy RPC has no capture timestamp and therefore cannot safely be used.
create or replace function public.publish_rider_location(
  p_latitude numeric,
  p_longitude numeric,
  p_accuracy_meters numeric default null,
  p_heading_degrees numeric default null,
  p_speed_kmph numeric default null,
  p_battery_level smallint default null,
  p_is_moving boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if app.current_delivery_partner_id() is null then
    perform app.fail('NOT_A_DELIVERY_PARTNER', 'This account is not a delivery partner.');
  end if;
  perform app.fail(
    'LOCATION_CAPTURE_TIME_REQUIRED',
    'Update Bites Box to continue secure delivery tracking.'
  );
  return '{}'::jsonb;
end;
$$;

create or replace function public.set_delivery_location_sharing(
  p_assignment_id uuid,
  p_enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_partner_id uuid := app.current_delivery_partner_id();
  v_assignment public.delivery_assignments;
  v_current_assignment_id uuid;
begin
  if v_partner_id is null then
    perform app.fail('NOT_A_DELIVERY_PARTNER', 'This account is not a delivery partner.');
  end if;

  select * into v_assignment
  from public.delivery_assignments
  where id = p_assignment_id and delivery_partner_id = v_partner_id
  for update;
  if not found then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is no longer assigned to you.');
  end if;

  if p_enabled and v_assignment.status not in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER') then
    perform app.fail('LOCATION_SHARING_NOT_AVAILABLE', 'This delivery is not active.');
  end if;

  if p_enabled then
    select da.id into v_current_assignment_id
    from public.delivery_assignments da
    where da.delivery_partner_id = v_partner_id
      and da.status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
    order by case da.status when 'AT_CUSTOMER' then 1 when 'PICKED_UP' then 2
      when 'AT_STORE' then 3 else 4 end
    limit 1;
    if v_current_assignment_id is distinct from p_assignment_id then
      perform app.fail('LOCATION_SHARING_NOT_AVAILABLE', 'Only your current delivery can share location.');
    end if;
    perform app.reconcile_location_sharing_for_partner(v_partner_id);
  end if;

  update public.delivery_assignments
  set location_sharing_enabled = p_enabled,
      location_sharing_started_at = case when p_enabled then now() else null end,
      updated_at = now()
  where id = p_assignment_id;

  if not p_enabled then
    update public.delivery_partner_locations
    set order_id = null, assignment_id = null, updated_at = now()
    where delivery_partner_id = v_partner_id and assignment_id = p_assignment_id;
  end if;

  return jsonb_build_object(
    'assignment_id', p_assignment_id,
    'location_sharing_enabled', p_enabled,
    'changed_at', case when p_enabled then now() else null end
  );
end;
$$;

create or replace function public.my_delivery_location_sharing()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_partner_id uuid := app.current_delivery_partner_id();
  v_assignment public.delivery_assignments;
  v_location_recorded_at timestamptz;
begin
  if v_partner_id is null then
    perform app.fail('NOT_A_DELIVERY_PARTNER', 'This account is not a delivery partner.');
  end if;

  select * into v_assignment
  from public.delivery_assignments
  where delivery_partner_id = v_partner_id
    and status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
  order by case status when 'AT_CUSTOMER' then 1 when 'PICKED_UP' then 2
    when 'AT_STORE' then 3 else 4 end
  limit 1;

  if v_assignment.id is not null then
    select recorded_at into v_location_recorded_at
    from public.delivery_partner_locations
    where delivery_partner_id = v_partner_id
      and assignment_id = v_assignment.id;
  end if;

  return jsonb_build_object(
    'assignment_id', v_assignment.id,
    'location_sharing_enabled', coalesce(v_assignment.location_sharing_enabled, false),
    'location_recorded_at', v_location_recorded_at
  );
end;
$$;

-- Called before local auth sign-out so consent and the customer-visible point
-- are revoked while the rider JWT is still available. Non-riders get a no-op.
create or replace function public.stop_my_delivery_location_sharing()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_partner_id uuid := app.current_delivery_partner_id();
  v_stopped int := 0;
begin
  if v_partner_id is null then
    return jsonb_build_object('stopped', true, 'assignments', 0);
  end if;

  update public.delivery_assignments
  set location_sharing_enabled = false,
      location_sharing_started_at = null,
      updated_at = now()
  where delivery_partner_id = v_partner_id
    and location_sharing_enabled;
  get diagnostics v_stopped = row_count;

  update public.delivery_partner_locations
  set order_id = null, assignment_id = null, updated_at = now()
  where delivery_partner_id = v_partner_id;

  return jsonb_build_object('stopped', true, 'assignments', v_stopped);
end;
$$;

create or replace function public.publish_rider_location_v2(
  p_latitude numeric,
  p_longitude numeric,
  p_captured_at timestamptz,
  p_accuracy_meters numeric default null,
  p_heading_degrees numeric default null,
  p_speed_kmph numeric default null,
  p_battery_level smallint default null,
  p_is_moving boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_partner_id uuid := app.current_delivery_partner_id();
  v_assignment public.delivery_assignments;
  v_order public.orders;
  v_dest_lat numeric;
  v_dest_lng numeric;
  v_distance numeric;
  v_eta int;
  v_last_event timestamptz;
  v_last_fix timestamptz;
  v_sample_seconds int;
  v_speed numeric;
begin
  if v_partner_id is null then
    perform app.fail('NOT_A_DELIVERY_PARTNER', 'This account is not a delivery partner.');
  end if;
  if p_captured_at is null
     or p_captured_at < now() - interval '2 minutes'
     or p_captured_at > now() + interval '15 seconds' then
    perform app.fail('LOCATION_CAPTURE_TIME_INVALID', 'This location fix is too old or has an invalid time.');
  end if;

  select * into v_assignment
  from public.delivery_assignments
  where delivery_partner_id = v_partner_id
    and status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
  order by case status when 'AT_CUSTOMER' then 1 when 'PICKED_UP' then 2
    when 'AT_STORE' then 3 else 4 end
  limit 1
  for update;

  if not found or not v_assignment.location_sharing_enabled then
    return jsonb_build_object('recorded', false, 'should_keep_publishing', false);
  end if;

  select recorded_at into v_last_fix
  from public.delivery_partner_locations
  where delivery_partner_id = v_partner_id
    and assignment_id = v_assignment.id
  for update;
  if v_last_fix is not null and p_captured_at <= v_last_fix then
    perform app.fail('LOCATION_FIX_OUT_OF_ORDER', 'A newer location has already been recorded.');
  end if;

  select * into v_order from public.orders where id = v_assignment.order_id;
  if v_assignment.status in ('PICKED_UP', 'AT_CUSTOMER') then
    v_dest_lat := v_order.delivery_latitude;
    v_dest_lng := v_order.delivery_longitude;
  else
    select latitude, longitude into v_dest_lat, v_dest_lng
    from public.branches where id = v_assignment.branch_id;
  end if;

  if v_dest_lat is not null then
    v_distance := app.haversine_km(p_latitude, p_longitude, v_dest_lat, v_dest_lng);
    v_speed := greatest(coalesce(nullif(p_speed_kmph, 0), 18), 8);
    v_eta := greatest(ceil(v_distance / v_speed * 60)::int, 1);
  end if;

  insert into public.delivery_partner_locations as l (
    delivery_partner_id, order_id, assignment_id, latitude, longitude,
    accuracy_meters, heading_degrees, speed_kmph, battery_level, is_moving,
    distance_to_destination_km, eta_minutes, recorded_at
  ) values (
    v_partner_id, v_assignment.order_id, v_assignment.id, p_latitude, p_longitude,
    p_accuracy_meters, p_heading_degrees, p_speed_kmph, p_battery_level,
    coalesce(p_is_moving, true), v_distance, v_eta, p_captured_at
  ) on conflict (delivery_partner_id) do update
    set order_id = excluded.order_id,
        assignment_id = excluded.assignment_id,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        accuracy_meters = excluded.accuracy_meters,
        heading_degrees = excluded.heading_degrees,
        speed_kmph = excluded.speed_kmph,
        battery_level = coalesce(excluded.battery_level, l.battery_level),
        is_moving = excluded.is_moving,
        distance_to_destination_km = excluded.distance_to_destination_km,
        eta_minutes = excluded.eta_minutes,
        recorded_at = excluded.recorded_at,
        updated_at = now();

  v_sample_seconds := app.setting_int('delivery.location_sample_seconds', 20);
  select max(recorded_at) into v_last_event
  from public.delivery_location_events where assignment_id = v_assignment.id;
  if v_last_event is null
     or v_last_event < p_captured_at - make_interval(secs => v_sample_seconds) then
    insert into public.delivery_location_events (
      delivery_partner_id, order_id, assignment_id, latitude, longitude,
      accuracy_meters, speed_kmph, recorded_at
    ) values (
      v_partner_id, v_assignment.order_id, v_assignment.id, p_latitude, p_longitude,
      p_accuracy_meters, p_speed_kmph, p_captured_at
    );
  end if;

  if v_assignment.status = 'PICKED_UP'
     and v_distance is not null
     and v_distance <= app.setting_numeric('delivery.nearby_radius_km', 0.5) then
    perform app.enqueue_notification(
      v_order.user_id, 'RIDER_NEARBY',
      jsonb_build_object('order_number', v_order.order_number, 'order_id', v_order.id::text),
      array['PUSH', 'IN_APP']::public.notification_channel[],
      v_order.id, 'rider_nearby:' || v_order.id::text
    );
  end if;

  return jsonb_build_object(
    'recorded', true,
    'order_id', v_assignment.order_id,
    'assignment_id', v_assignment.id,
    'captured_at', p_captured_at,
    'distance_to_destination_km', v_distance,
    'eta_minutes', v_eta,
    'should_keep_publishing', true
  );
end;
$$;

comment on function public.publish_rider_location_v2 is
  'Accepts only recent, ordered OS capture times for an active rider-approved assignment.';

-- Track retries as operational evidence without retaining duplicate payloads.
alter table public.payment_events
  add column duplicate_delivery_count integer not null default 0,
  add column last_duplicate_at timestamptz;

create or replace function public.svc_note_duplicate_webhook_delivery(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();
  update public.payment_events
  set duplicate_delivery_count = duplicate_delivery_count + 1,
      last_duplicate_at = now()
  where id = p_event_id;
end;
$$;

revoke all on function public.svc_note_duplicate_webhook_delivery(uuid) from public, anon, authenticated;
grant execute on function public.svc_note_duplicate_webhook_delivery(uuid) to service_role;

-- Low-noise, branch-scoped alerts for operational failures that otherwise only
-- exist in database logs. Payloads contain counts and ages, never customer data.
create or replace function public.operational_health_alerts(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  perform app.require_permission('order.view', v_branch);

  return coalesce((
    select jsonb_agg(alert order by alert ->> 'severity', alert ->> 'type')
    from (
      select jsonb_build_object(
        'type', 'PAYMENT_WEBHOOK_FAILED', 'severity', '1',
        'count', count(*),
        'oldest_minutes', ceil(extract(epoch from now() - min(pe.received_at)) / 60)::int,
        'message', format('%s signed payment webhook(s) have not completed for at least 5 minutes.', count(*))
      ) as alert
      from public.payment_events pe
      left join public.orders o on o.id = pe.order_id
      where pe.signature_verified
        and not pe.processed
        and pe.received_at < now() - interval '5 minutes'
        and (o.branch_id = v_branch or pe.order_id is null)
      having count(*) > 0

      union all

      select jsonb_build_object(
        'type', 'PAYMENT_WEBHOOK_REPEATED', 'severity', '2',
        'count', count(*),
        'oldest_minutes', ceil(extract(epoch from now() - min(pe.last_duplicate_at)) / 60)::int,
        'message', format('%s payment webhook event(s) were delivered 3 or more times in the last hour.', count(*))
      )
      from public.payment_events pe
      left join public.orders o on o.id = pe.order_id
      where pe.duplicate_delivery_count >= 3
        and pe.last_duplicate_at > now() - interval '1 hour'
        and (o.branch_id = v_branch or pe.order_id is null)
      having count(*) > 0

      union all

      select jsonb_build_object(
        'type', 'REFUND_STUCK', 'severity', '1',
        'count', count(*),
        'oldest_minutes', ceil(extract(epoch from now() - min(r.updated_at)) / 60)::int,
        'message', format('%s approved or processing refund(s) have not changed for 15 minutes.', count(*))
      )
      from public.refunds r
      join public.orders o on o.id = r.order_id
      where o.branch_id = v_branch
        and r.status in ('APPROVED', 'PROCESSING')
        and r.updated_at < now() - interval '15 minutes'
      having count(*) > 0

      union all

      select jsonb_build_object(
        'type', 'SCHEDULED_JOB_FAILED', 'severity', '1',
        'count', count(*),
        'oldest_minutes', ceil(extract(epoch from now() - min(jr.started_at)) / 60)::int,
        'message', format('%s scheduled or reconciliation job run(s) failed in the last 24 hours.', count(*))
      )
      from public.job_runs jr
      where jr.status = 'FAILED'
        and jr.started_at > now() - interval '24 hours'
      having count(*) > 0

      union all

      select jsonb_build_object(
        'type', 'ORDER_STATE_PROLONGED', 'severity', '1',
        'count', count(*),
        'oldest_minutes', ceil(extract(epoch from now() - min(o.status_changed_at)) / 60)::int,
        'message', format('%s active order(s) have remained in one state longer than the service threshold.', count(*))
      )
      from public.orders o
      where o.branch_id = v_branch
        and ((o.status = 'PENDING_PAYMENT' and o.status_changed_at < now() - interval '15 minutes')
          or (o.status = 'PAYMENT_CONFIRMED' and o.status_changed_at < now() - interval '5 minutes')
          or (o.status = 'ORDER_PLACED' and o.status_changed_at < now() - interval '10 minutes')
          or (o.status = 'STORE_ACCEPTED' and o.status_changed_at < now() - interval '20 minutes')
          or (o.status = 'PREPARING' and o.status_changed_at < now() - interval '30 minutes')
          or (o.status = 'READY_FOR_PICKUP' and o.status_changed_at < now() - interval '10 minutes')
          or (o.status in ('RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE') and o.status_changed_at < now() - interval '10 minutes')
          or (o.status in ('PICKED_UP', 'OUT_FOR_DELIVERY', 'RIDER_ARRIVED_CUSTOMER') and o.status_changed_at < now() - interval '60 minutes'))
      having count(*) > 0

      union all

      select jsonb_build_object(
        'type', 'DELIVERY_LOCATION_STALE', 'severity', '2',
        'count', count(*),
        'oldest_minutes', ceil(extract(epoch from now() - min(coalesce(loc.recorded_at, da.location_sharing_started_at))) / 60)::int,
        'message', format('%s active delivery location(s) have no fresh GPS update for 2 minutes.', count(*))
      )
      from public.delivery_assignments da
      left join public.delivery_partner_locations loc
        on loc.assignment_id = da.id and loc.delivery_partner_id = da.delivery_partner_id
      where da.branch_id = v_branch
        and da.location_sharing_enabled
        and da.status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
        and (loc.recorded_at is null or loc.recorded_at < now() - interval '2 minutes')
      having count(*) > 0
    ) alerts
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.operational_health_alerts(uuid) from public, anon;
grant execute on function public.operational_health_alerts(uuid) to authenticated;

revoke all on function public.set_delivery_location_sharing(uuid, boolean) from public, anon;
revoke all on function public.my_delivery_location_sharing() from public, anon;
revoke all on function public.stop_my_delivery_location_sharing() from public, anon;
revoke all on function public.publish_rider_location_v2(numeric, numeric, timestamptz, numeric, numeric, numeric, smallint, boolean) from public, anon;
grant execute on function public.set_delivery_location_sharing(uuid, boolean) to authenticated;
grant execute on function public.my_delivery_location_sharing() to authenticated;
grant execute on function public.stop_my_delivery_location_sharing() to authenticated;
grant execute on function public.publish_rider_location_v2(numeric, numeric, timestamptz, numeric, numeric, numeric, smallint, boolean) to authenticated;
