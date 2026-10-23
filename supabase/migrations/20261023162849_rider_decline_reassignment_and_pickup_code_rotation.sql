-- Riders can release an assignment before leaving with the parcel. Keep the
-- order in its real kitchen stage so operations can assign a replacement.
insert into public.order_status_transitions
  (from_status, to_status, required_permission, customer_allowed, rider_allowed, label, customer_label)
values
  ('RIDER_ASSIGNED', 'STORE_ACCEPTED', 'delivery.assign', false, false,
   'Rider released', 'Finding another delivery partner'),
  ('RIDER_ASSIGNED', 'PREPARING', 'delivery.assign', false, false,
   'Rider released', 'Finding another delivery partner'),
  ('RIDER_ARRIVED_STORE', 'STORE_ACCEPTED', 'delivery.assign', false, false,
   'Rider released', 'Finding another delivery partner'),
  ('RIDER_ARRIVED_STORE', 'PREPARING', 'delivery.assign', false, false,
   'Rider released', 'Finding another delivery partner')
on conflict (from_status, to_status) do nothing;

-- Attempt numbers must remain monotonic even after a declined/failed assignment
-- is no longer considered live. This also prevents old order-scoped legacy
-- pickup codes from being accepted for a replacement rider.
create or replace function app.tg_next_delivery_attempt()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_next_attempt smallint;
begin
  select (coalesce(max(da.attempt_number), 0) + 1)::smallint
    into v_next_attempt
  from public.delivery_assignments da
  where da.order_id = new.order_id;

  new.attempt_number := greatest(coalesce(new.attempt_number, 1), coalesce(v_next_attempt, 1));
  return new;
end;
$$;

revoke all on function app.tg_next_delivery_attempt() from public, anon, authenticated;
drop trigger if exists next_delivery_attempt on public.delivery_assignments;
create trigger next_delivery_attempt
  before insert on public.delivery_assignments
  for each row execute function app.tg_next_delivery_attempt();

-- Product creators can upload menu images even when their role has menu.create
-- without the separate menu.update permission. The product row still has its
-- existing RLS checks, and uploaded files remain inside the public menu bucket.
drop policy if exists storage_menu_images_write on storage.objects;
create policy storage_menu_images_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'menu-images'
    and (app.has_permission('menu.create') or app.has_permission('menu.update'))
  );

create or replace function public.respond_to_assignment(
  p_assignment_id uuid,
  p_accept boolean,
  p_rejection_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.delivery_assignments;
  v_order public.orders;
  v_order_id uuid;
  v_partner_id uuid := app.current_delivery_partner_id();
  v_target_status public.order_status;
  v_reason text := left(coalesce(nullif(btrim(p_rejection_reason), ''), 'Not provided'), 180);
begin
  if v_partner_id is null then
    perform app.fail('NOT_A_DELIVERY_PARTNER', 'This account is not a delivery partner.');
  end if;

  -- Dispatch and pickup both lock the order before the assignment. Read its id
  -- first without a lock, then follow that same order to prevent stale releases.
  select da.order_id into v_order_id
  from public.delivery_assignments da
  where da.id = p_assignment_id
    and da.delivery_partner_id = v_partner_id;

  if not found then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is not assigned to you.');
  end if;

  select * into v_order
  from public.orders
  where id = v_order_id
  for update;

  if not found then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is no longer available.');
  end if;

  select * into v_assignment
  from public.delivery_assignments da
  where da.id = p_assignment_id
    and da.order_id = v_order.id
    and da.delivery_partner_id = v_partner_id
  for update;

  if not found then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is no longer assigned to you.');
  end if;

  if p_accept then
    if v_assignment.status <> 'OFFERED' then
      return jsonb_build_object(
        'assignment_id', p_assignment_id,
        'status', v_assignment.status,
        'changed', false
      );
    end if;

    if v_assignment.expires_at is not null and v_assignment.expires_at < now() then
      update public.delivery_assignments
      set status = 'EXPIRED', updated_at = now()
      where id = p_assignment_id;

      return jsonb_build_object(
        'assignment_id', p_assignment_id,
        'status', 'EXPIRED',
        'changed', true
      );
    end if;

    update public.delivery_assignments
    set status = 'ACCEPTED', accepted_at = now(), updated_at = now()
    where id = p_assignment_id;

    return jsonb_build_object(
      'assignment_id', p_assignment_id,
      'status', 'ACCEPTED',
      'order_id', v_order.id,
      'changed', true
    );
  end if;

  if v_assignment.status not in ('OFFERED', 'ACCEPTED', 'AT_STORE') then
    if v_assignment.status in ('PICKED_UP', 'AT_CUSTOMER') then
      perform app.fail(
        'ORDER_ALREADY_PICKED_UP',
        'The parcel has already been collected. Report a delivery problem instead.'
      );
    end if;

    return jsonb_build_object(
      'assignment_id', p_assignment_id,
      'status', v_assignment.status,
      'changed', false
    );
  end if;

  if v_order.status not in ('RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE') then
    perform app.fail(
      'ASSIGNMENT_NOT_ACTIVE',
      'This delivery assignment is no longer active for the order.'
    );
  end if;

  update public.delivery_assignments
  set status = 'REJECTED',
      rejected_at = now(),
      rejection_reason = v_reason,
      updated_at = now()
  where id = p_assignment_id;

  -- A pickup code belongs to the assignment it was issued for. Retire it before
  -- dispatch offers this order to another rider; delivery OTPs are untouched.
  update public.verification_codes
  set consumed_at = now()
  where purpose = 'PICKUP_CODE'
    and order_id = v_order.id
    and consumed_at is null;

  if v_order.status in ('RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE') then
    v_target_status := case
      when v_order.ready_at is not null then 'READY_FOR_PICKUP'::public.order_status
      when v_order.preparing_at is not null then 'PREPARING'::public.order_status
      else 'STORE_ACCEPTED'::public.order_status
    end;

    perform app.transition_order(
      v_order.id,
      v_target_status,
      'Delivery partner released the order before pickup. Reason: ' || v_reason,
      'SYSTEM',
      null,
      jsonb_build_object('assignment_id', p_assignment_id, 'reason', v_reason)
    );
  end if;

  insert into public.order_notes (order_id, author_id, note)
  values (
    v_order.id,
    auth.uid(),
    format('Delivery partner released this order before pickup. Reason: %s', v_reason)
  );

  return jsonb_build_object(
    'assignment_id', p_assignment_id,
    'status', 'REJECTED',
    'order_id', v_order.id,
    'order_status', coalesce(v_target_status, v_order.status),
    'changed', true
  );
end;
$$;

comment on function public.respond_to_assignment(uuid, boolean, text) is
  'Accepts rider offers and releases offered, accepted or at-store assignments before pickup. A release restores the actual kitchen stage and retires the pickup code.';

revoke all on function public.respond_to_assignment(uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.respond_to_assignment(uuid, boolean, text) to authenticated;

-- Keep the shared pickup code length aligned with the rider app's existing
-- six-digit entry field and the older kitchen ticket contract.
create or replace function public.issue_pickup_handoff_code(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_assignment public.delivery_assignments;
  v_code text;
  v_salt text;
  v_expires_at timestamptz;
  v_rider_name text;
  v_rider_phone text;
begin
  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'This order is no longer available.');
  end if;

  perform app.require_permission('kitchen.operate', v_order.branch_id);

  if v_order.fulfilment_type <> 'DELIVERY'
     or v_order.ready_at is null
     or v_order.status not in ('READY_FOR_PICKUP', 'RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE') then
    perform app.fail(
      'PICKUP_CODE_UNAVAILABLE',
      'The pickup code is available after this delivery order is ready.'
    );
  end if;

  select * into v_assignment
  from public.delivery_assignments
  where order_id = p_order_id
    and branch_id = v_order.branch_id
    and status in ('ACCEPTED', 'AT_STORE')
  order by attempt_number desc
  limit 1;

  if not found then
    perform app.fail(
      'ASSIGNMENT_NOT_FOUND',
      'Assign an active delivery partner before sharing the pickup code.'
    );
  end if;

  select full_name, phone
  into v_rider_name, v_rider_phone
  from public.delivery_partners
  where id = v_assignment.delivery_partner_id
    and deleted_at is null;

  if not found then
    perform app.fail(
      'ASSIGNMENT_NOT_FOUND',
      'The assigned delivery partner is no longer available.'
    );
  end if;

  if not app.consume_rate_limit('pickup_handoff_code', p_order_id::text, 5, 600, 600) then
    perform app.fail(
      'TOO_MANY_ATTEMPTS',
      'A new pickup code was issued recently. Please wait before trying again.'
    );
  end if;

  v_code := app.random_numeric_code(6);
  v_salt := app.random_alnum_code(12);
  v_expires_at := now() + interval '6 hours';

  -- Reissuing invalidates any code previously sent to an earlier rider.
  update public.verification_codes
  set consumed_at = now()
  where purpose = 'PICKUP_CODE'
    and order_id = p_order_id
    and consumed_at is null;

  update public.orders
  set pickup_code_hash = app.hash_code(v_code, v_salt),
      updated_at = now()
  where id = p_order_id;

  insert into public.verification_codes (
    purpose, subject, code_hash, salt, order_id, user_id, expires_at
  )
  values (
    'PICKUP_CODE', 'PICKUP_CODE:' || v_assignment.id::text,
    app.hash_code(v_code, v_salt), v_salt,
    p_order_id, v_order.user_id, v_expires_at
  );

  perform app.audit(
    'UPDATE', 'PICKUP_CODE', p_order_id::text, null,
    jsonb_build_object('assignment_id', v_assignment.id, 'expires_at', v_expires_at),
    'Pickup code issued for rider handoff', v_order.order_number, v_order.branch_id
  );

  return jsonb_build_object(
    'code', v_code,
    'expires_at', v_expires_at,
    'rider_name', v_rider_name,
    'rider_phone', v_rider_phone
  );
end;
$$;

comment on function public.issue_pickup_handoff_code(uuid) is
  'Issues a one-time six-digit pickup code to authorized kitchen staff for the currently assigned rider on a ready delivery.';

revoke all on function public.issue_pickup_handoff_code(uuid) from public, anon, authenticated;
grant execute on function public.issue_pickup_handoff_code(uuid) to authenticated;
