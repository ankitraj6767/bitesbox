-- Issue a fresh pickup code only at an active, ready delivery handoff. The code
-- remains one-time plaintext: return it to the authorized kitchen client once,
-- while persisting only the salted hash used by rider verification.
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

  v_code := app.random_numeric_code(4);
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

  -- Record the disclosure without placing the secret code in the audit trail.
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
  'Issues a one-time pickup code to authorized kitchen staff for the active rider on a ready delivery.';

revoke all on function public.issue_pickup_handoff_code(uuid) from public, anon, authenticated;
grant execute on function public.issue_pickup_handoff_code(uuid) to authenticated;

-- A rider whose assignment was cancelled or replaced must not be able to use an
-- older still-valid order code to collect the parcel.
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
  v_order_id uuid;
  v_partner_id uuid := app.current_delivery_partner_id();
  v_verification public.verification_codes;
  v_required boolean;
begin
  -- Keep lock order consistent with dispatch and code issuance (order first,
  -- then assignment) so a pickup racing a reassignment cannot deadlock.
  select * into v_assignment
  from public.delivery_assignments
  where id = p_assignment_id;

  if not found
     or (v_assignment.delivery_partner_id <> v_partner_id and not app.is_staff()) then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is not assigned to you.');
  end if;

  v_order_id := v_assignment.order_id;

  select * into v_order
  from public.orders
  where id = v_order_id
  for update;

  if not found then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is no longer available.');
  end if;

  select * into v_assignment
  from public.delivery_assignments
  where id = p_assignment_id
  for update;

  if not found
     or v_assignment.order_id <> v_order.id
     or (v_assignment.delivery_partner_id <> v_partner_id and not app.is_staff()) then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is not assigned to you.');
  end if;

  if v_assignment.status = 'PICKED_UP' then
    return jsonb_build_object('assignment_id', p_assignment_id, 'verified', true, 'changed', false);
  end if;

  if v_assignment.status not in ('ACCEPTED', 'AT_STORE') then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This delivery is no longer active.');
  end if;

  if v_order.status not in ('READY_FOR_PICKUP', 'RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE') then
    perform app.fail('ASSIGNMENT_NOT_FOUND', 'This order is no longer ready for pickup.');
  end if;

  v_required := app.setting_bool('delivery.require_pickup_verification', true);

  if v_required then
    if not app.consume_rate_limit('pickup_code', p_assignment_id::text, 6, 600, 300) then
      perform app.fail('TOO_MANY_ATTEMPTS', 'Too many incorrect codes. Ask the kitchen for help.');
    end if;

    select * into v_verification
    from public.verification_codes
    where purpose = 'PICKUP_CODE'
      and order_id = v_assignment.order_id
      and (
        subject = 'PICKUP_CODE:' || v_assignment.id::text
        -- Codes generated before this migration are order-scoped. Allow them
        -- only for the first assignment; a reassigned order needs a fresh,
        -- rider-bound code from the kitchen.
        or (v_assignment.attempt_number = 1 and subject = v_assignment.order_id::text)
      )
      and consumed_at is null
      and expires_at > now()
    order by created_at desc
    limit 1;

    if not found then
      perform app.fail('PICKUP_CODE_UNAVAILABLE', 'No pickup code is active for this order.');
    end if;

    if v_verification.attempts >= v_verification.max_attempts then
      perform app.fail('TOO_MANY_ATTEMPTS', 'Too many incorrect codes. Ask the kitchen for help.');
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

comment on function public.verify_pickup(uuid, text) is
  'Pickup code verification; only the active assigned rider can collect a ready delivery.';

revoke all on function public.verify_pickup(uuid, text) from public, anon, authenticated;
grant execute on function public.verify_pickup(uuid, text) to authenticated;
