-- ═══════════════════════════════════════════════════════════════════════════
-- 0031 · RIDER PRIVILEGE SCOPE
--
-- The DELIVERY_PARTNER role held `delivery.view`, `delivery.pickup` and
-- `delivery.complete`. Those look necessary — a rider does pick up and complete
-- deliveries — but they are not, and granting them opened three holes:
--
--   1. `delivery_assignments_read` grants read on any assignment in the branch to
--      a holder of `delivery.view`. Every rider could therefore list every other
--      rider's live jobs, with the customer name, phone number and address on the
--      joined order.
--   2. `available_riders` treats `delivery.view` as sufficient, so a rider could
--      pull the full roster: colleagues' names, numbers and live proximity.
--   3. `complete_delivery` lets a holder of `delivery.complete` finish a delivery
--      that is not theirs — the deliberate manager override. A rider holding the
--      same permission could complete a colleague's delivery.
--
-- None of it was needed. `app.transition_order` authorises a rider through the
-- `rider_allowed` column on `order_status_transitions`, checked against
-- `delivery_assignments` for *that order*:
--
--     elsif v_transition.rider_allowed and v_is_rider then v_authorised := true;
--
-- and every read a rider needs — the order, its items, its history — resolves
-- through `app.is_rider_for_order`, never through `delivery.view`.
--
-- So the permissions come off the role, and the two surfaces that conflated
-- "may advance my own delivery" with "may see the whole dispatch board" now say
-- `app.is_staff()` explicitly.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 1 · A rider's authority comes from their assignment, not from a grant ───
delete from public.role_permissions rp
using public.roles r, public.permissions p
where rp.role_id = r.id
  and rp.permission_id = p.id
  and r.code = 'DELIVERY_PARTNER'
  and p.code in ('delivery.view', 'delivery.pickup', 'delivery.complete');

comment on table public.role_permissions is
  'Role → permission mapping. DELIVERY_PARTNER deliberately holds none: a rider is authorised by being the assigned partner, which app.transition_order and app.is_rider_for_order both verify per order.';

-- ─── 2 · Dispatch visibility is a staff concern ─────────────────────────────
drop policy if exists delivery_assignments_read on public.delivery_assignments;

create policy delivery_assignments_read on public.delivery_assignments
  for select to authenticated
  using (
    -- The rider carrying it.
    exists (
      select 1 from public.delivery_partners dp
      where dp.id = delivery_partner_id and dp.user_id = auth.uid()
    )
    -- Operations. `is_staff` is stated as well as the permission so that
    -- re-granting delivery.view to riders cannot silently reopen the board.
    or (app.is_staff() and app.has_permission('delivery.view', branch_id))
    -- The customer, so they can see who is bringing their food. The helper avoids
    -- recursing back into the orders policy, which reads this table.
    or app.owns_order(order_id)
  );

-- Proof-of-delivery photos: a rider keeps their own uploads through owner_id.
drop policy if exists storage_delivery_proofs_read on storage.objects;

create policy storage_delivery_proofs_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'delivery-proofs'
    and (
      (app.is_staff() and app.has_permission('delivery.view'))
      or owner_id = auth.uid()::text
    )
  );

-- ─── 3 · The roster is a dispatch tool ──────────────────────────────────────
create or replace function public.available_riders(
  p_branch_id uuid default null,
  p_order_id uuid default null
)
returns table (
  delivery_partner_id uuid,
  full_name text,
  phone text,
  photo_path text,
  vehicle_type public.vehicle_type,
  duty_state public.rider_duty_state,
  active_load int,
  max_concurrent_orders smallint,
  distance_to_store_km numeric,
  last_location_at timestamptz,
  rating_average numeric,
  successful_deliveries int,
  score numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  if not (
    app.is_staff()
    and app.has_any_permission(
      array['delivery.assign', 'delivery.view', 'rider.view'],
      v_branch
    )
  ) then
    perform app.fail(
      'PERMISSION_DENIED',
      'You do not have permission to view delivery partners.',
      jsonb_build_object('permission', 'delivery.view')
    );
  end if;

  return query
  with branch as (
    select b.id, b.latitude, b.longitude
    from public.branches b
    where b.id = v_branch
  )
  select
    dp.id,
    dp.full_name,
    dp.phone::text,
    dp.photo_path,
    dp.vehicle_type,
    dp.duty_state,
    app.rider_active_load(dp.id) as active_load,
    dp.max_concurrent_orders,
    case
      when loc.latitude is not null
      then app.haversine_km(loc.latitude, loc.longitude, br.latitude, br.longitude)
      else null
    end as distance_to_store_km,
    loc.recorded_at,
    dp.rating_average,
    dp.successful_deliveries,
    (
      app.rider_active_load(dp.id) * 100
      + coalesce(
          case
            when loc.latitude is not null
            then app.haversine_km(loc.latitude, loc.longitude, br.latitude, br.longitude)
            else 15
          end, 15
        ) * 10
      + (5 - dp.rating_average) * 5
      + case when dp.duty_state = 'AVAILABLE' then 0 else 50 end
    )::numeric as score
  from public.delivery_partners dp
  cross join branch br
  left join public.delivery_partner_locations loc on loc.delivery_partner_id = dp.id
  where dp.deleted_at is null
    and dp.onboarding_status = 'ACTIVE'
    and dp.branch_id = br.id
    and dp.duty_state in ('AVAILABLE', 'BUSY')
    and app.rider_active_load(dp.id) < dp.max_concurrent_orders
  order by score;
end;
$$;

comment on function public.available_riders is
  'Dispatch candidate list, ranked. Staff only, and requires delivery.assign, delivery.view or rider.view.';

-- ─── 4 · Rider directory is likewise staff-only ─────────────────────────────
-- `rider_directory` is granted to `authenticated` and returns phone numbers and
-- performance history. Riders do not hold rider.view, but stating is_staff makes
-- the boundary explicit rather than incidental.
drop policy if exists delivery_partners_self_read on public.delivery_partners;

create policy delivery_partners_self_read on public.delivery_partners
  for select to authenticated
  using (
    user_id = auth.uid()
    or (app.is_staff() and app.has_permission('rider.view', branch_id))
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- 5 · The state machine must still recognise the rider that just acted
--
-- Removing `delivery.complete` from the role exposed an ordering bug that the
-- permission had been masking. `complete_delivery` does this:
--
--     update delivery_assignments set status = 'COMPLETED' ...
--     perform app.transition_order(order_id, 'DELIVERED', ...)
--
-- but `transition_order` decided "is this the assigned rider?" by looking for an
-- assignment in ('ACCEPTED','AT_STORE','PICKED_UP','AT_CUSTOMER'). By the time it
-- ran, the row said COMPLETED — so the rider was not recognised, authorisation
-- fell through to `app.has_permission('delivery.complete')`, and the flow only
-- worked because every rider happened to hold that permission. The same applies
-- to `fail_delivery`, which sets FAILED before transitioning to DELIVERY_FAILED.
--
-- The window is widened to include the two terminal states a rider writes
-- themselves, matching `app.is_rider_for_order`, which already counts COMPLETED.
-- This grants no extra authority: no transition out of DELIVERED,
-- DELIVERY_FAILED or COMPLETED has `rider_allowed = true`, so the only edges a
-- rider can drive still start from an in-flight status.
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.is_assigned_rider(p_order_id uuid, p_actor uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_actor is not null and exists (
    select 1
    from public.delivery_assignments da
    join public.delivery_partners dp on dp.id = da.delivery_partner_id
    where da.order_id = p_order_id
      and dp.user_id = p_actor
      -- COMPLETED and FAILED are included because the rider sets them a moment
      -- before the matching order transition is requested.
      and da.status in (
        'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER', 'COMPLETED', 'FAILED'
      )
  );
$$;

comment on function app.is_assigned_rider is
  'True when this actor is the delivery partner on this order. Used by the state machine to authorise rider-driven transitions.';

create or replace function app.transition_order(
  p_order_id uuid,
  p_to_status public.order_status,
  p_note text default null,
  p_actor_kind public.actor_kind default 'USER',
  p_actor_id uuid default null,
  p_metadata jsonb default '{}'::jsonb,
  p_allow_override boolean default false,
  p_cancellation_actor public.cancellation_actor default null,
  p_cancellation_reason public.cancellation_reason default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_transition public.order_status_transitions;
  v_actor uuid := coalesce(p_actor_id, auth.uid());
  v_is_customer boolean := false;
  v_is_rider boolean := false;
  v_authorised boolean := false;
  v_override boolean := false;
  v_label text;
  v_now timestamptz := now();
begin
  -- Serialise concurrent transitions on the same order.
  select * into v_order from public.orders where id = p_order_id for update;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'Order not found.');
  end if;

  -- Idempotent no-op: re-delivering the same event must not fail.
  if v_order.status = p_to_status then
    return jsonb_build_object(
      'order_id', v_order.id,
      'status', v_order.status,
      'changed', false,
      'reason', 'Order is already in this state.'
    );
  end if;

  select * into v_transition
  from public.order_status_transitions
  where from_status = v_order.status and to_status = p_to_status;

  -- Plain assignments do not disturb FOUND, so the `not found` below still refers
  -- to the transition lookup above. Kept in this order deliberately.
  v_is_customer := v_actor is not null and v_actor = v_order.user_id;
  v_is_rider := app.is_assigned_rider(p_order_id, v_actor);

  if not found then
    -- No edge exists. Only an explicit, permissioned override may proceed.
    if not (p_allow_override and app.has_permission('order.override', v_order.branch_id)) then
      perform app.fail(
        'INVALID_ORDER_TRANSITION',
        format('An order cannot move from %s to %s.', v_order.status, p_to_status),
        jsonb_build_object('from', v_order.status, 'to', p_to_status)
      );
    end if;

    v_override := true;
    v_label := format('Status forced to %s', p_to_status);
  else
    v_label := v_transition.label;

    -- Authorisation
    if p_actor_kind in ('SYSTEM', 'WEBHOOK', 'SCHEDULER') or app.is_service_role() then
      v_authorised := true;
    elsif v_transition.required_permission is null then
      -- System-only edge attempted by a human: allow only with override rights.
      v_authorised := app.has_permission('order.override', v_order.branch_id);
    elsif v_transition.customer_allowed and v_is_customer then
      v_authorised := true;
    elsif v_transition.rider_allowed and v_is_rider then
      v_authorised := true;
    else
      v_authorised := app.has_permission(v_transition.required_permission, v_order.branch_id);
    end if;

    if not v_authorised then
      perform app.fail(
        'PERMISSION_DENIED',
        'You are not allowed to make this change.',
        jsonb_build_object('required_permission', v_transition.required_permission)
      );
    end if;
  end if;

  -- Apply the change with the guard temporarily lifted for this statement.
  perform set_config('bitesbox.transition_ok', 'on', true);

  update public.orders
  set status = p_to_status,
      previous_status = v_order.status,
      status_changed_at = v_now,
      updated_at = v_now,
      -- Lifecycle stamps
      placed_at = case when p_to_status = 'ORDER_PLACED' then coalesce(placed_at, v_now) else placed_at end,
      paid_at = case when p_to_status = 'PAYMENT_CONFIRMED' then coalesce(paid_at, v_now) else paid_at end,
      accepted_at = case when p_to_status = 'STORE_ACCEPTED' then coalesce(accepted_at, v_now) else accepted_at end,
      preparing_at = case when p_to_status = 'PREPARING' then coalesce(preparing_at, v_now) else preparing_at end,
      ready_at = case when p_to_status = 'READY_FOR_PICKUP' then coalesce(ready_at, v_now) else ready_at end,
      assigned_at = case when p_to_status = 'RIDER_ASSIGNED' then coalesce(assigned_at, v_now) else assigned_at end,
      picked_up_at = case when p_to_status = 'PICKED_UP' then coalesce(picked_up_at, v_now) else picked_up_at end,
      delivered_at = case when p_to_status = 'DELIVERED' then coalesce(delivered_at, v_now) else delivered_at end,
      completed_at = case when p_to_status = 'COMPLETED' then coalesce(completed_at, v_now) else completed_at end,
      cancelled_at = case
        when app.is_cancelled_status(p_to_status) then coalesce(cancelled_at, v_now)
        else cancelled_at
      end,
      cancelled_by = case
        when app.is_cancelled_status(p_to_status) then coalesce(cancelled_by, v_actor)
        else cancelled_by
      end,
      cancellation_actor = case
        when app.is_cancelled_status(p_to_status)
        then coalesce(p_cancellation_actor, cancellation_actor,
                      case
                        when p_to_status = 'CUSTOMER_CANCELLED' then 'CUSTOMER'::public.cancellation_actor
                        when p_to_status = 'STORE_REJECTED' then 'STORE'::public.cancellation_actor
                        when p_to_status = 'ADMIN_CANCELLED' then 'ADMIN'::public.cancellation_actor
                        when p_to_status = 'DELIVERY_FAILED' then 'RIDER'::public.cancellation_actor
                        else 'SYSTEM'::public.cancellation_actor
                      end)
        else cancellation_actor
      end,
      cancellation_reason = case
        when app.is_cancelled_status(p_to_status)
        then coalesce(p_cancellation_reason, cancellation_reason)
        else cancellation_reason
      end,
      cancellation_note = case
        when app.is_cancelled_status(p_to_status) then coalesce(cancellation_note, p_note)
        else cancellation_note
      end,
      payment_status = case
        when p_to_status = 'PAYMENT_CONFIRMED' then 'CAPTURED'::public.payment_status
        when p_to_status = 'PAYMENT_FAILED' then 'FAILED'::public.payment_status
        else payment_status
      end,
      -- Once delivered, a delayed flag is no longer meaningful.
      is_delayed = case when p_to_status in ('DELIVERED', 'COMPLETED') then false else is_delayed end
  where id = p_order_id;

  perform set_config('bitesbox.transition_ok', 'off', true);

  insert into public.order_status_history (
    order_id, from_status, to_status, label, note, actor_id, actor_kind, actor_role,
    is_override, metadata
  )
  values (
    p_order_id, v_order.status, p_to_status, v_label, p_note, v_actor, p_actor_kind,
    case when v_actor is null then null else app.primary_role() end,
    v_override,
    coalesce(p_metadata, '{}'::jsonb)
  );

  if v_override then
    perform app.audit(
      'ORDER_STATUS_OVERRIDE', 'order', p_order_id::text,
      jsonb_build_object('status', v_order.status),
      jsonb_build_object('status', p_to_status),
      p_note, v_order.order_number, v_order.branch_id
    );
  end if;

  -- ── Side effects ──
  perform app.on_order_status_changed(p_order_id, v_order.status, p_to_status, p_metadata);

  return jsonb_build_object(
    'order_id', p_order_id,
    'from_status', v_order.status,
    'status', p_to_status,
    'changed', true,
    'is_override', v_override,
    'label', v_label,
    'changed_at', v_now
  );
end;
$$;

grant execute on function app.is_assigned_rider(uuid, uuid) to service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- 6 · A rider could rewrite their own record
--
-- `delivery_partners_self_update` allowed any authenticated rider to UPDATE their
-- own row, with no restriction on which columns:
--
--     for update to authenticated
--     using (user_id = auth.uid()) with check (user_id = auth.uid())
--
-- combined with the table-level `grant update on public.delivery_partners to
-- authenticated`. Verified against the local stack, a rider could:
--
--   · set `onboarding_status` to VERIFIED, skipping document review;
--   · set `cash_in_hand` to 0, erasing the COD they owe the outlet;
--   · set `rating_average` to 5.00 and `total_deliveries` to any number;
--   · raise `max_concurrent_orders`, taking more orders than dispatch intends.
--
-- Only ACTIVE was blocked, and only incidentally, by the
-- `delivery_partners_approval` check constraint.
--
-- Column-level grants cannot fix this, because staff and riders are both the
-- `authenticated` role and staff legitimately need those columns. So the policy is
-- removed outright and riders get a narrow function for the handful of fields they
-- genuinely maintain.
--
-- Nothing else breaks: every trusted writer — `set_duty_state`, `settle_cod`,
-- `app.tg_assignment_metrics`, `approve_rider`, `suspend_rider` — is SECURITY
-- DEFINER owned by the table owner, and RLS is enabled but NOT forced, so the
-- owner is exempt. Suites 040 and 070 cover that end to end.
-- ═══════════════════════════════════════════════════════════════════════════
drop policy if exists delivery_partners_self_update on public.delivery_partners;

create or replace function public.update_my_rider_profile(
  p_alternate_phone text default null,
  p_emergency_contact_name text default null,
  p_emergency_contact_phone text default null,
  p_upi_id text default null,
  p_photo_path text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_partner public.delivery_partners;
begin
  select * into v_partner
  from public.delivery_partners
  where user_id = auth.uid() and deleted_at is null
  for update;

  if not found then
    perform app.fail('NOT_A_DELIVERY_PARTNER', 'This account is not a delivery partner.');
  end if;

  -- A photo must live under the rider's own storage prefix, matching the
  -- staff-photos bucket policy.
  if p_photo_path is not null
     and split_part(p_photo_path, '/', 1) <> auth.uid()::text then
    perform app.fail(
      'PERMISSION_DENIED',
      'That file does not belong to you.',
      jsonb_build_object('storage_path', p_photo_path)
    );
  end if;

  update public.delivery_partners
  set alternate_phone = coalesce(app.normalize_phone(p_alternate_phone), alternate_phone),
      emergency_contact_name = coalesce(
        nullif(btrim(p_emergency_contact_name), ''), emergency_contact_name
      ),
      emergency_contact_phone = coalesce(
        app.normalize_phone(p_emergency_contact_phone), emergency_contact_phone
      ),
      upi_id = coalesce(nullif(btrim(p_upi_id), ''), upi_id),
      photo_path = coalesce(nullif(btrim(p_photo_path), ''), photo_path),
      updated_at = now()
  where id = v_partner.id;

  return jsonb_build_object(
    'delivery_partner_id', v_partner.id,
    'updated', true
  );
end;
$$;

comment on function public.update_my_rider_profile is
  'The only fields a rider may change on their own record. Identity, vehicle, pay and onboarding status are a manager''s responsibility and are audited when they change.';

grant execute on function public.update_my_rider_profile(text, text, text, text, text)
  to authenticated;
