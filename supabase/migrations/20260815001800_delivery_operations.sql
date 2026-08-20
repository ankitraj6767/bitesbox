-- ═══════════════════════════════════════════════════════════════════════════
-- 0018 · DELIVERY OPERATIONS
--
-- Assignment → acceptance → arrival at store → pickup verification →
-- navigation → arrival at customer → OTP verification → delivered.
--
-- A rider can never mark an order delivered without either the customer OTP or
-- an audited manager override.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Rider duty toggle ─────────────────────────────────────────────────────
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
    perform app.fail(
      'RIDER_NOT_ACTIVE',
      case v_partner.onboarding_status
        when 'PENDING' then 'Complete your onboarding to start accepting deliveries.'
        when 'DOCUMENTS_SUBMITTED' then 'Your documents are under review.'
        when 'VERIFIED' then 'Your account is verified and awaiting activation.'
        when 'SUSPENDED' then 'Your account is suspended. Please contact your manager.'
        when 'REJECTED' then 'Your application was not approved.'
        else 'Your account is not active.'
      end,
      jsonb_build_object('onboarding_status', v_partner.onboarding_status)
    );
  end if;

  v_previous := v_partner.duty_state;
  v_load := app.rider_active_load(v_partner.id);

  -- Going offline with live deliveries would orphan customers.
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
    delivery_partner_id, duty_state, previous_state, reason, latitude, longitude, battery_level
  )
  values (v_partner.id, p_state, v_previous, p_reason, p_latitude, p_longitude, p_battery_level);

  -- Seed the live location row so dispatch can rank by proximity right away.
  if p_latitude is not null and p_longitude is not null then
    insert into public.delivery_partner_locations (
      delivery_partner_id, latitude, longitude, battery_level, recorded_at
    )
    values (v_partner.id, p_latitude, p_longitude, p_battery_level, now())
    on conflict (delivery_partner_id) do update
      set latitude = excluded.latitude,
          longitude = excluded.longitude,
          battery_level = excluded.battery_level,
          recorded_at = now(),
          updated_at = now();
  end if;

  return jsonb_build_object(
    'delivery_partner_id', v_partner.id,
    'duty_state', p_state,
    'previous_state', v_previous,
    'active_deliveries', v_load
  );
end;
$$;

-- ─── Assignment ────────────────────────────────────────────────────────────
create or replace function public.assign_rider(
  p_order_id uuid,
  p_delivery_partner_id uuid,
  p_mode public.assignment_mode default 'MANUAL',
  p_offer_ttl_seconds int default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_partner public.delivery_partners;
  v_existing public.delivery_assignments;
  v_assignment public.delivery_assignments;
  v_attempt smallint := 1;
  v_config public.delivery_payout_config;
  v_distance numeric;
  v_ttl int;
begin
  perform app.require_permission('delivery.assign');

  select * into v_order from public.orders where id = p_order_id for update;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'Order not found.');
  end if;

  perform app.require_permission('delivery.assign', v_order.branch_id);

  if v_order.fulfilment_type <> 'DELIVERY' then
    perform app.fail('NOT_A_DELIVERY_ORDER', 'This is a self-pickup order.');
  end if;

  if not app.is_active_status(v_order.status) then
    perform app.fail('ORDER_NOT_ASSIGNABLE', 'This order is no longer active.');
  end if;

  select * into v_partner from public.delivery_partners
  where id = p_delivery_partner_id and deleted_at is null;

  if not found then
    perform app.fail('RIDER_NOT_FOUND', 'Delivery partner not found.');
  end if;

  if v_partner.onboarding_status <> 'ACTIVE' then
    perform app.fail('RIDER_NOT_ACTIVE', 'That delivery partner is not active.');
  end if;

  if v_partner.branch_id <> v_order.branch_id then
    perform app.fail('RIDER_WRONG_BRANCH', 'That delivery partner belongs to another outlet.');
  end if;

  if app.rider_active_load(p_delivery_partner_id) >= v_partner.max_concurrent_orders then
    perform app.fail(
      'RIDER_AT_CAPACITY',
      format('%s already has %s active deliveries.', v_partner.full_name, v_partner.max_concurrent_orders)
    );
  end if;

  -- Retire a live assignment (reassignment path).
  select * into v_existing
  from public.delivery_assignments
  where order_id = p_order_id
    and status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER');

  if found then
    if v_existing.delivery_partner_id = p_delivery_partner_id then
      return jsonb_build_object(
        'assignment_id', v_existing.id,
        'delivery_partner_id', v_existing.delivery_partner_id,
        'status', v_existing.status,
        'changed', false
      );
    end if;

    if v_existing.status in ('PICKED_UP', 'AT_CUSTOMER') then
      perform app.fail(
        'ORDER_ALREADY_PICKED_UP',
        'This order has already been picked up and cannot be reassigned.'
      );
    end if;

    update public.delivery_assignments
    set status = 'CANCELLED', cancelled_at = now(), updated_at = now()
    where id = v_existing.id;

    v_attempt := v_existing.attempt_number + 1;

    perform app.audit(
      'RIDER_REASSIGN', 'order', p_order_id::text,
      jsonb_build_object('delivery_partner_id', v_existing.delivery_partner_id),
      jsonb_build_object('delivery_partner_id', p_delivery_partner_id),
      null, v_order.order_number, v_order.branch_id
    );
  end if;

  select * into v_config from public.delivery_payout_config
  where (branch_id = v_order.branch_id or branch_id is null) and is_active
  order by branch_id nulls last
  limit 1;

  v_distance := coalesce(v_order.distance_km, 0);
  v_ttl := coalesce(p_offer_ttl_seconds, app.setting_int('delivery.offer_ttl_seconds', 120));

  insert into public.delivery_assignments (
    order_id, delivery_partner_id, branch_id, status, mode, attempt_number,
    assigned_by, expires_at, distance_to_customer_km,
    base_payout, distance_payout, total_payout
  )
  values (
    p_order_id, p_delivery_partner_id, v_order.branch_id,
    -- Manual dispatch by staff is authoritative; the rider is informed, not asked.
    case when p_mode = 'MANUAL' then 'ACCEPTED'::public.assignment_status
         else 'OFFERED'::public.assignment_status end,
    p_mode, v_attempt, auth.uid(),
    case when p_mode = 'MANUAL' then null else now() + make_interval(secs => v_ttl) end,
    v_distance,
    coalesce(v_config.base_payout, 20),
    app.money_round(greatest(v_distance - coalesce(v_config.free_km, 2), 0) * coalesce(v_config.per_km_payout, 5)),
    app.money_round(
      coalesce(v_config.base_payout, 20)
      + greatest(v_distance - coalesce(v_config.free_km, 2), 0) * coalesce(v_config.per_km_payout, 5)
    )
  )
  returning * into v_assignment;

  if p_mode = 'MANUAL' then
    update public.delivery_assignments
    set accepted_at = now() where id = v_assignment.id;
  end if;

  if v_order.status in ('STORE_ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP') then
    perform app.transition_order(
      p_order_id, 'RIDER_ASSIGNED',
      format('Assigned to %s', v_partner.full_name),
      'USER', auth.uid(),
      jsonb_build_object('assignment_id', v_assignment.id, 'delivery_partner_id', p_delivery_partner_id)
    );
  end if;

  perform app.enqueue_notification(
    v_partner.user_id, 'NEW_ASSIGNMENT_RIDER',
    jsonb_build_object(
      'order_number', v_order.order_number,
      'order_id', v_order.id::text,
      'area', coalesce(v_order.delivery_area, v_order.delivery_city, ''),
      'distance_km', to_char(v_distance, 'FM990.0')
    ),
    array['PUSH', 'IN_APP']::public.notification_channel[],
    p_order_id,
    'rider_assignment:' || v_assignment.id::text
  );

  perform app.audit(
    'RIDER_ASSIGN', 'order', p_order_id::text, null,
    jsonb_build_object('delivery_partner_id', p_delivery_partner_id, 'mode', p_mode),
    null, v_order.order_number, v_order.branch_id
  );

  return jsonb_build_object(
    'assignment_id', v_assignment.id,
    'order_id', p_order_id,
    'delivery_partner_id', p_delivery_partner_id,
    'rider_name', v_partner.full_name,
    'status', v_assignment.status,
    'attempt_number', v_attempt,
    'expires_at', v_assignment.expires_at,
    'changed', true
  );
end;
$$;

comment on function public.assign_rider is
  'Manual dispatch (auto-accepted) or an offer with a TTL. Handles reassignment and audits both.';

-- ─── Rider responds to an offer ────────────────────────────────────────────
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
  v_partner_id uuid := app.current_delivery_partner_id();
  v_order public.orders;
begin
  if v_partner_id is null then
    perform app.fail('NOT_A_DELIVERY_PARTNER', 'This account is not a delivery partner.');
  end if;

  select * into v_assignment from public.delivery_assignments
  where id = p_assignment_id for update;

  if not found or v_assignment.delivery_partner_id <> v_partner_id then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is not assigned to you.');
  end if;

  if v_assignment.status <> 'OFFERED' then
    return jsonb_build_object(
      'assignment_id', p_assignment_id,
      'status', v_assignment.status,
      'changed', false
    );
  end if;

  if v_assignment.expires_at is not null and v_assignment.expires_at < now() then
    update public.delivery_assignments
    set status = 'EXPIRED', updated_at = now() where id = p_assignment_id;

    perform app.fail('ASSIGNMENT_EXPIRED', 'This delivery offer has expired.');
  end if;

  select * into v_order from public.orders where id = v_assignment.order_id;

  if p_accept then
    update public.delivery_assignments
    set status = 'ACCEPTED', accepted_at = now(), updated_at = now()
    where id = p_assignment_id;
  else
    update public.delivery_assignments
    set status = 'REJECTED',
        rejected_at = now(),
        rejection_reason = p_rejection_reason,
        updated_at = now()
    where id = p_assignment_id;

    -- Send the order back to dispatch so operations can reassign.
    if v_order.status = 'RIDER_ASSIGNED' then
      perform app.transition_order(
        v_assignment.order_id, 'READY_FOR_PICKUP',
        'Delivery partner declined the assignment', 'SYSTEM'
      );
    end if;

    insert into public.order_notes (order_id, author_id, note)
    values (
      v_assignment.order_id, auth.uid(),
      format('Delivery declined by rider. Reason: %s', coalesce(p_rejection_reason, 'not given'))
    );
  end if;

  return jsonb_build_object(
    'assignment_id', p_assignment_id,
    'status', case when p_accept then 'ACCEPTED' else 'REJECTED' end,
    'order_id', v_assignment.order_id,
    'changed', true
  );
end;
$$;

-- ─── Rider arrives at the restaurant ───────────────────────────────────────
create or replace function public.rider_arrived_at_store(p_assignment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.delivery_assignments;
  v_partner_id uuid := app.current_delivery_partner_id();
begin
  select * into v_assignment from public.delivery_assignments where id = p_assignment_id;

  if not found or (v_assignment.delivery_partner_id <> v_partner_id and not app.is_staff()) then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is not assigned to you.');
  end if;

  update public.delivery_assignments
  set status = 'AT_STORE', arrived_store_at = coalesce(arrived_store_at, now()), updated_at = now()
  where id = p_assignment_id;

  perform app.transition_order(
    v_assignment.order_id, 'RIDER_ARRIVED_STORE', null, 'USER', auth.uid()
  );

  return jsonb_build_object(
    'assignment_id', p_assignment_id,
    'order_id', v_assignment.order_id,
    'status', 'AT_STORE',
    -- Tells the rider app whether to show the code entry sheet.
    'pickup_verification_required', app.setting_bool('delivery.require_pickup_verification', true)
  );
end;
$$;

-- ─── Pickup verification ───────────────────────────────────────────────────
-- Prevents a rider collecting the wrong parcel. Either the code shown on the
-- kitchen ticket or a scanned QR containing the same code.
create or replace function public.verify_pickup(
  p_assignment_id uuid,
  p_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.delivery_assignments;
  v_order public.orders;
  v_partner_id uuid := app.current_delivery_partner_id();
  v_verification public.verification_codes;
  v_required boolean;
begin
  select * into v_assignment from public.delivery_assignments
  where id = p_assignment_id for update;

  if not found or (v_assignment.delivery_partner_id <> v_partner_id and not app.is_staff()) then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is not assigned to you.');
  end if;

  if v_assignment.status = 'PICKED_UP' then
    return jsonb_build_object('assignment_id', p_assignment_id, 'verified', true, 'changed', false);
  end if;

  select * into v_order from public.orders where id = v_assignment.order_id;
  v_required := app.setting_bool('delivery.require_pickup_verification', true);

  if v_required then
    if not app.consume_rate_limit('pickup_code', p_assignment_id::text, 6, 600, 300) then
      perform app.fail('TOO_MANY_ATTEMPTS', 'Too many incorrect codes. Ask the kitchen for help.');
    end if;

    select * into v_verification
    from public.verification_codes
    where purpose = 'PICKUP_CODE'
      and order_id = v_assignment.order_id
      and consumed_at is null
      and expires_at > now()
    order by created_at desc
    limit 1;

    if not found then
      perform app.fail('PICKUP_CODE_UNAVAILABLE', 'No pickup code is active for this order.');
    end if;

    if v_verification.attempts >= v_verification.max_attempts then
      perform app.fail('TOO_MANY_ATTEMPTS', 'Too many incorrect attempts. Ask the kitchen for help.');
    end if;

    if app.hash_code(btrim(p_code), v_verification.salt) <> v_verification.code_hash then
      update public.verification_codes
      set attempts = attempts + 1 where id = v_verification.id;

      perform app.fail(
        'PICKUP_CODE_INVALID',
        'That pickup code is incorrect. Please check the kitchen ticket.',
        jsonb_build_object('attempts_left', v_verification.max_attempts - v_verification.attempts - 1)
      );
    end if;

    update public.verification_codes
    set consumed_at = now() where id = v_verification.id;
  end if;

  update public.delivery_assignments
  set status = 'PICKED_UP',
      picked_up_at = now(),
      pickup_duration_seconds = case
        when arrived_store_at is not null
        then extract(epoch from (now() - arrived_store_at))::int
        else null
      end,
      updated_at = now()
  where id = p_assignment_id;

  perform app.transition_order(
    v_assignment.order_id, 'PICKED_UP', null, 'USER', auth.uid()
  );

  -- Immediately move to out-for-delivery so the customer sees motion.
  perform app.transition_order(
    v_assignment.order_id, 'OUT_FOR_DELIVERY', null, 'SYSTEM'
  );

  return jsonb_build_object(
    'assignment_id', p_assignment_id,
    'order_id', v_assignment.order_id,
    'verified', true,
    'changed', true,
    'destination', jsonb_build_object(
      'latitude', v_order.delivery_latitude,
      'longitude', v_order.delivery_longitude,
      'address', concat_ws(', ', v_order.delivery_address_line1, v_order.delivery_address_line2,
                           v_order.delivery_landmark, v_order.delivery_city),
      'contact_name', v_order.delivery_contact_name,
      'contact_phone', v_order.delivery_contact_phone,
      'instructions', v_order.delivery_instructions
    ),
    'cod_amount', case when v_order.payment_mode in ('COD', 'SPLIT_WALLET_COD')
                       then v_order.payable_amount else 0 end
  );
end;
$$;

comment on function public.verify_pickup is
  'Pickup OTP/QR verification. Stops riders leaving with the wrong order.';

create or replace function public.rider_arrived_at_customer(p_assignment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.delivery_assignments;
  v_partner_id uuid := app.current_delivery_partner_id();
begin
  select * into v_assignment from public.delivery_assignments where id = p_assignment_id;

  if not found or (v_assignment.delivery_partner_id <> v_partner_id and not app.is_staff()) then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is not assigned to you.');
  end if;

  update public.delivery_assignments
  set status = 'AT_CUSTOMER',
      arrived_customer_at = coalesce(arrived_customer_at, now()),
      updated_at = now()
  where id = p_assignment_id;

  perform app.transition_order(
    v_assignment.order_id, 'RIDER_ARRIVED_CUSTOMER', null, 'USER', auth.uid()
  );

  return jsonb_build_object(
    'assignment_id', p_assignment_id,
    'order_id', v_assignment.order_id,
    'status', 'AT_CUSTOMER'
  );
end;
$$;

-- ─── Delivery completion with OTP ──────────────────────────────────────────
create or replace function public.complete_delivery(
  p_assignment_id uuid,
  p_otp text default null,
  p_cash_collected numeric default null,
  p_proof_photo_path text default null,
  p_note text default null,
  p_manager_override boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.delivery_assignments;
  v_order public.orders;
  v_partner_id uuid := app.current_delivery_partner_id();
  v_verification public.verification_codes;
  v_is_override boolean := false;
  v_expected_cash numeric := 0;
  v_config public.delivery_payout_config;
  v_payout numeric;
begin
  select * into v_assignment from public.delivery_assignments
  where id = p_assignment_id for update;

  if not found then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'Delivery not found.');
  end if;

  if v_assignment.delivery_partner_id <> v_partner_id
     and not app.has_permission('delivery.complete') then
    perform app.fail('PERMISSION_DENIED', 'This delivery is not assigned to you.');
  end if;

  if v_assignment.status = 'COMPLETED' then
    return jsonb_build_object('assignment_id', p_assignment_id, 'status', 'COMPLETED', 'changed', false);
  end if;

  if v_assignment.status not in ('PICKED_UP', 'AT_CUSTOMER') then
    perform app.fail(
      'DELIVERY_NOT_IN_PROGRESS',
      'Pick the order up before completing the delivery.'
    );
  end if;

  select * into v_order from public.orders where id = v_assignment.order_id for update;

  -- ── Verification ──
  if p_manager_override then
    -- Overrides are a privileged, audited escape hatch (dead phone, lost OTP…).
    if not app.has_permission('delivery.override', v_order.branch_id) then
      perform app.fail(
        'OVERRIDE_NOT_PERMITTED',
        'A manager must approve completing a delivery without the customer OTP.'
      );
    end if;

    v_is_override := true;
  else
    if not app.consume_rate_limit('delivery_otp', p_assignment_id::text, 6, 900, 600) then
      perform app.fail('TOO_MANY_ATTEMPTS', 'Too many incorrect OTP attempts. Ask your manager for help.');
    end if;

    if p_otp is null or btrim(p_otp) = '' then
      perform app.fail('DELIVERY_OTP_REQUIRED', 'Ask the customer for their delivery OTP.');
    end if;

    select * into v_verification
    from public.verification_codes
    where purpose = 'DELIVERY_OTP'
      and order_id = v_assignment.order_id
      and consumed_at is null
      and expires_at > now()
    order by created_at desc
    limit 1;

    if not found then
      perform app.fail('DELIVERY_OTP_UNAVAILABLE', 'No delivery OTP is active. Ask your manager for help.');
    end if;

    if v_verification.attempts >= v_verification.max_attempts then
      perform app.fail('TOO_MANY_ATTEMPTS', 'This OTP is locked after too many attempts. Ask your manager.');
    end if;

    if app.hash_code(btrim(p_otp), v_verification.salt) <> v_verification.code_hash then
      update public.verification_codes set attempts = attempts + 1 where id = v_verification.id;
      update public.orders set delivery_code_attempts = delivery_code_attempts + 1
      where id = v_order.id;

      perform app.fail(
        'DELIVERY_OTP_INVALID',
        'That OTP is incorrect. Please re-check with the customer.',
        jsonb_build_object('attempts_left', v_verification.max_attempts - v_verification.attempts - 1)
      );
    end if;

    update public.verification_codes set consumed_at = now() where id = v_verification.id;
  end if;

  -- ── Cash on delivery reconciliation ──
  if v_order.payment_mode in ('COD', 'SPLIT_WALLET_COD') then
    v_expected_cash := v_order.payable_amount;

    if coalesce(p_cash_collected, 0) < v_expected_cash then
      perform app.fail(
        'COD_AMOUNT_MISMATCH',
        format('Collect ₹%s from the customer before completing the delivery.',
               to_char(v_expected_cash, 'FM999999990.00')),
        jsonb_build_object('expected', v_expected_cash, 'collected', coalesce(p_cash_collected, 0))
      );
    end if;

    update public.cod_collections
    set status = 'COD_COLLECTED',
        collected_amount = p_cash_collected,
        delivery_partner_id = v_assignment.delivery_partner_id,
        collected_at = now(),
        discrepancy_amount = coalesce(p_cash_collected, 0) - v_expected_cash,
        updated_at = now()
    where order_id = v_order.id;

    update public.orders
    set cod_status = 'COD_COLLECTED', payment_status = 'CAPTURED', paid_at = coalesce(paid_at, now()),
        updated_at = now()
    where id = v_order.id;
  end if;

  -- ── Complete ──
  update public.delivery_assignments
  set status = 'COMPLETED',
      completed_at = now(),
      cash_collected = coalesce(p_cash_collected, 0),
      proof_photo_path = p_proof_photo_path,
      delivery_note = p_note,
      delivery_duration_seconds = case
        when picked_up_at is not null then extract(epoch from (now() - picked_up_at))::int
        else null
      end,
      updated_at = now()
  where id = p_assignment_id;

  update public.orders
  set delivery_verified_at = now(),
      delivery_verification_method = case when v_is_override then 'MANAGER_OVERRIDE' else 'CUSTOMER_OTP' end,
      updated_at = now()
  where id = v_order.id;

  perform app.transition_order(
    v_assignment.order_id, 'DELIVERED', p_note, 'USER', auth.uid(),
    jsonb_build_object('verification', case when v_is_override then 'MANAGER_OVERRIDE' else 'CUSTOMER_OTP' end)
  );

  -- ── Rider payout ──
  select * into v_config from public.delivery_payout_config
  where (branch_id = v_order.branch_id or branch_id is null) and is_active
  order by branch_id nulls last limit 1;

  v_payout := coalesce(v_assignment.total_payout, coalesce(v_config.base_payout, 20));

  insert into public.delivery_earnings (
    delivery_partner_id, assignment_id, order_id, entry_type, amount, description
  )
  values (
    v_assignment.delivery_partner_id, p_assignment_id, v_order.id,
    'DELIVERY_PAYOUT', v_payout,
    format('Delivery payout for order %s', v_order.order_number)
  )
  on conflict (assignment_id, entry_type) where assignment_id is not null do nothing;

  if v_order.tip_amount > 0 then
    insert into public.delivery_earnings (
      delivery_partner_id, assignment_id, order_id, entry_type, amount, description
    )
    values (
      v_assignment.delivery_partner_id, p_assignment_id, v_order.id,
      'TIP', v_order.tip_amount,
      format('Customer tip on order %s', v_order.order_number)
    )
    on conflict (assignment_id, entry_type) where assignment_id is not null do nothing;
  end if;

  if v_is_override then
    perform app.audit(
      'MANUAL_DELIVERY_OVERRIDE', 'order', v_order.id::text, null,
      jsonb_build_object('assignment_id', p_assignment_id, 'note', p_note),
      p_note, v_order.order_number, v_order.branch_id
    );
  end if;

  -- Stop publishing this rider's location for the finished order.
  update public.delivery_partner_locations
  set order_id = null, assignment_id = null, updated_at = now()
  where delivery_partner_id = v_assignment.delivery_partner_id
    and order_id = v_order.id;

  return jsonb_build_object(
    'assignment_id', p_assignment_id,
    'order_id', v_order.id,
    'status', 'COMPLETED',
    'changed', true,
    'verification_method', case when v_is_override then 'MANAGER_OVERRIDE' else 'CUSTOMER_OTP' end,
    'payout', v_payout,
    'cash_collected', coalesce(p_cash_collected, 0)
  );
end;
$$;

comment on function public.complete_delivery is
  'Completes a delivery only after OTP verification or an audited manager override. Settles COD and payout.';

create or replace function public.fail_delivery(
  p_assignment_id uuid,
  p_reason text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.delivery_assignments;
  v_partner_id uuid := app.current_delivery_partner_id();
begin
  select * into v_assignment from public.delivery_assignments where id = p_assignment_id for update;

  if not found then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'Delivery not found.');
  end if;

  if v_assignment.delivery_partner_id <> v_partner_id
     and not app.has_permission('delivery.complete') then
    perform app.fail('PERMISSION_DENIED', 'This delivery is not assigned to you.');
  end if;

  update public.delivery_assignments
  set status = 'FAILED', failed_at = now(), failure_reason = p_reason, updated_at = now()
  where id = p_assignment_id;

  insert into public.order_notes (order_id, author_id, note)
  values (v_assignment.order_id, auth.uid(),
          format('Delivery failed: %s. %s', p_reason, coalesce(p_note, '')));

  return app.transition_order(
    v_assignment.order_id, 'DELIVERY_FAILED', p_note, 'USER', auth.uid(),
    jsonb_build_object('reason', p_reason), false, 'RIDER', 'CUSTOMER_UNREACHABLE'
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- LIVE LOCATION
-- Called only while a delivery is active. Writes the mutable current-position
-- row every time, and a breadcrumb row at most once per sample interval.
-- ═══════════════════════════════════════════════════════════════════════════
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
declare
  v_partner_id uuid := app.current_delivery_partner_id();
  v_assignment public.delivery_assignments;
  v_order public.orders;
  v_dest_lat numeric;
  v_dest_lng numeric;
  v_distance numeric;
  v_eta int;
  v_last_event timestamptz;
  v_sample_seconds int;
  v_speed numeric;
begin
  if v_partner_id is null then
    perform app.fail('NOT_A_DELIVERY_PARTNER', 'This account is not a delivery partner.');
  end if;

  -- The most advanced live assignment defines the destination.
  select * into v_assignment
  from public.delivery_assignments
  where delivery_partner_id = v_partner_id
    and status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
  order by
    case status
      when 'AT_CUSTOMER' then 1
      when 'PICKED_UP' then 2
      when 'AT_STORE' then 3
      else 4
    end
  limit 1;

  if found then
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
      -- Assume a realistic urban average when the device reports no speed.
      v_speed := greatest(coalesce(nullif(p_speed_kmph, 0), 18), 8);
      v_eta := greatest(ceil(v_distance / v_speed * 60)::int, 1);
    end if;
  end if;

  insert into public.delivery_partner_locations as l (
    delivery_partner_id, order_id, assignment_id, latitude, longitude,
    accuracy_meters, heading_degrees, speed_kmph, battery_level, is_moving,
    distance_to_destination_km, eta_minutes, recorded_at
  )
  values (
    v_partner_id, v_assignment.order_id, v_assignment.id, p_latitude, p_longitude,
    p_accuracy_meters, p_heading_degrees, p_speed_kmph, p_battery_level,
    coalesce(p_is_moving, true), v_distance, v_eta, now()
  )
  on conflict (delivery_partner_id) do update
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
        recorded_at = now(),
        updated_at = now();

  -- Throttled breadcrumb trail: one row per sample interval, active trips only.
  if v_assignment.id is not null then
    v_sample_seconds := app.setting_int('delivery.location_sample_seconds', 20);

    select max(recorded_at) into v_last_event
    from public.delivery_location_events
    where assignment_id = v_assignment.id;

    if v_last_event is null or v_last_event < now() - make_interval(secs => v_sample_seconds) then
      insert into public.delivery_location_events (
        delivery_partner_id, order_id, assignment_id, latitude, longitude,
        accuracy_meters, speed_kmph
      )
      values (
        v_partner_id, v_assignment.order_id, v_assignment.id, p_latitude, p_longitude,
        p_accuracy_meters, p_speed_kmph
      );
    end if;
  end if;

  -- Auto-notify the customer once the rider is genuinely close.
  if v_assignment.status = 'PICKED_UP'
     and v_distance is not null
     and v_distance <= app.setting_numeric('delivery.nearby_radius_km', 0.5) then
    perform app.enqueue_notification(
      v_order.user_id, 'RIDER_NEARBY',
      jsonb_build_object('order_number', v_order.order_number, 'order_id', v_order.id::text),
      array['PUSH', 'IN_APP']::public.notification_channel[],
      v_order.id,
      'rider_nearby:' || v_order.id::text
    );
  end if;

  return jsonb_build_object(
    'recorded', true,
    'order_id', v_assignment.order_id,
    'assignment_id', v_assignment.id,
    'distance_to_destination_km', v_distance,
    'eta_minutes', v_eta,
    -- Lets the app back off GPS sampling when there is nothing to track.
    'should_keep_publishing', v_assignment.id is not null
  );
end;
$$;

comment on function public.publish_rider_location is
  'Rider GPS ingress. Updates one mutable row plus a throttled breadcrumb trail.';

-- ═══════════════════════════════════════════════════════════════════════════
-- RIDER READ SURFACES
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.my_deliveries(p_include_history boolean default false)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_partner_id uuid := app.current_delivery_partner_id();
begin
  if v_partner_id is null then
    perform app.fail('NOT_A_DELIVERY_PARTNER', 'This account is not a delivery partner.');
  end if;

  return jsonb_build_object(
    'partner', (
      select jsonb_build_object(
        'id', dp.id,
        'full_name', dp.full_name,
        'photo_path', dp.photo_path,
        'phone', dp.phone,
        'vehicle_type', dp.vehicle_type,
        'vehicle_number', dp.vehicle_number,
        'onboarding_status', dp.onboarding_status,
        'duty_state', dp.duty_state,
        'rating_average', dp.rating_average,
        'total_deliveries', dp.total_deliveries,
        'cash_in_hand', dp.cash_in_hand,
        'max_concurrent_orders', dp.max_concurrent_orders,
        'active_load', app.rider_active_load(dp.id)
      )
      from public.delivery_partners dp where dp.id = v_partner_id
    ),
    'active', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'assignment_id', da.id,
          'status', da.status,
          'offered_at', da.offered_at,
          'expires_at', da.expires_at,
          'accepted_at', da.accepted_at,
          'arrived_store_at', da.arrived_store_at,
          'picked_up_at', da.picked_up_at,
          'total_payout', da.total_payout,
          'order', jsonb_build_object(
            'id', o.id,
            'order_number', o.order_number,
            'status', o.status,
            'item_count', o.item_count,
            'unit_count', o.unit_count,
            'payment_mode', o.payment_mode,
            'cod_amount', case when o.payment_mode in ('COD', 'SPLIT_WALLET_COD')
                               then o.payable_amount else 0 end,
            'grand_total', o.grand_total,
            'customer_name', o.delivery_contact_name,
            'customer_phone', o.delivery_contact_phone,
            'address', concat_ws(', ', o.delivery_address_line1, o.delivery_address_line2,
                                 o.delivery_landmark, o.delivery_area, o.delivery_city),
            'latitude', o.delivery_latitude,
            'longitude', o.delivery_longitude,
            'instructions', o.delivery_instructions,
            'distance_km', o.distance_km,
            'promised_at', o.promised_at,
            'placed_at', o.placed_at,
            'ready_at', o.ready_at,
            'items', (
              select jsonb_agg(jsonb_build_object(
                'name', oi.product_name,
                'variant', oi.variant_name,
                'quantity', oi.quantity
              ) order by oi.display_order)
              from public.order_items oi
              where oi.order_id = o.id and not oi.is_cancelled
            )
          ),
          'branch', jsonb_build_object(
            'id', b.id, 'name', b.name, 'phone', b.phone,
            'address', concat_ws(', ', b.address_line1, b.city),
            'latitude', b.latitude, 'longitude', b.longitude
          )
        ) order by da.offered_at
      )
      from public.delivery_assignments da
      join public.orders o on o.id = da.order_id
      join public.branches b on b.id = da.branch_id
      where da.delivery_partner_id = v_partner_id
        and da.status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
    ), '[]'::jsonb),
    'history', case when not p_include_history then '[]'::jsonb else coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'assignment_id', da.id,
          'status', da.status,
          'order_number', o.order_number,
          'completed_at', da.completed_at,
          'total_payout', da.total_payout,
          'cash_collected', da.cash_collected,
          'distance_km', o.distance_km,
          'area', o.delivery_area
        ) order by coalesce(da.completed_at, da.updated_at) desc
      )
      from public.delivery_assignments da
      join public.orders o on o.id = da.order_id
      where da.delivery_partner_id = v_partner_id
        and da.status in ('COMPLETED', 'FAILED')
      limit 50
    ), '[]'::jsonb) end
  );
end;
$$;

create or replace function public.my_earnings(
  p_from date default null,
  p_to date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_partner_id uuid := app.current_delivery_partner_id();
  v_from date := coalesce(p_from, current_date - 29);
  v_to date := coalesce(p_to, current_date);
begin
  if v_partner_id is null then
    perform app.fail('NOT_A_DELIVERY_PARTNER', 'This account is not a delivery partner.');
  end if;

  return jsonb_build_object(
    'today', coalesce((
      select sum(amount) from public.delivery_earnings
      where delivery_partner_id = v_partner_id and earned_on = current_date
    ), 0),
    'this_week', coalesce((
      select sum(amount) from public.delivery_earnings
      where delivery_partner_id = v_partner_id
        and earned_on >= date_trunc('week', current_date)::date
    ), 0),
    'this_month', coalesce((
      select sum(amount) from public.delivery_earnings
      where delivery_partner_id = v_partner_id
        and earned_on >= date_trunc('month', current_date)::date
    ), 0),
    'lifetime', coalesce((
      select sum(amount) from public.delivery_earnings
      where delivery_partner_id = v_partner_id
    ), 0),
    'cash_in_hand', coalesce((
      select cash_in_hand from public.delivery_partners where id = v_partner_id
    ), 0),
    'unsettled_cash', coalesce((
      select sum(cc.collected_amount)
      from public.cod_collections cc
      where cc.delivery_partner_id = v_partner_id
        and cc.status = 'COD_COLLECTED'
        and cc.settled_at is null
    ), 0),
    'deliveries_today', coalesce((
      select count(*) from public.delivery_assignments
      where delivery_partner_id = v_partner_id
        and status = 'COMPLETED'
        and completed_at::date = current_date
    ), 0),
    'daily', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'date', d.day,
          'amount', coalesce(e.total, 0),
          'deliveries', coalesce(e.deliveries, 0)
        ) order by d.day desc
      )
      from generate_series(v_from, v_to, interval '1 day') d(day)
      left join (
        select earned_on,
               sum(amount) as total,
               count(*) filter (where entry_type = 'DELIVERY_PAYOUT') as deliveries
        from public.delivery_earnings
        where delivery_partner_id = v_partner_id
          and earned_on between v_from and v_to
        group by earned_on
      ) e on e.earned_on = d.day::date
    ), '[]'::jsonb),
    'entries', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', de.id,
          'entry_type', de.entry_type,
          'amount', de.amount,
          'description', de.description,
          'earned_on', de.earned_on,
          'created_at', de.created_at
        ) order by de.created_at desc
      )
      from public.delivery_earnings de
      where de.delivery_partner_id = v_partner_id
        and de.earned_on between v_from and v_to
      limit 200
    ), '[]'::jsonb)
  );
end;
$$;

-- ─── COD settlement (rider hands cash to the branch) ───────────────────────
create or replace function public.settle_cod(
  p_delivery_partner_id uuid,
  p_order_ids uuid[] default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total numeric;
  v_count int;
  v_branch uuid;
begin
  select branch_id into v_branch from public.delivery_partners where id = p_delivery_partner_id;

  perform app.require_permission('payment.reconcile', v_branch);

  with settled as (
    update public.cod_collections
    set settled_at = now(), settled_by = auth.uid(), settlement_note = p_note, updated_at = now()
    where delivery_partner_id = p_delivery_partner_id
      and status = 'COD_COLLECTED'
      and settled_at is null
      and (p_order_ids is null or order_id = any (p_order_ids))
    returning collected_amount
  )
  select coalesce(sum(collected_amount), 0), count(*) into v_total, v_count from settled;

  update public.delivery_partners
  set cash_in_hand = greatest(cash_in_hand - v_total, 0), updated_at = now()
  where id = p_delivery_partner_id;

  perform app.audit(
    'UPDATE', 'cod_settlement', p_delivery_partner_id::text, null,
    jsonb_build_object('amount', v_total, 'orders', v_count),
    p_note, null, v_branch
  );

  return jsonb_build_object('settled_amount', v_total, 'order_count', v_count);
end;
$$;
