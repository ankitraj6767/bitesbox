-- ═══════════════════════════════════════════════════════════════════════════
-- 0017 · ORDER STATE MACHINE & PLACEMENT
--
-- No client may set orders.status. The only sanctioned path is
-- app.transition_order(), which:
--   1. validates the transition against order_status_transitions
--   2. enforces the required permission for the acting user
--   3. stamps lifecycle timestamps
--   4. writes an append-only timeline row
--   5. fires the side effects (OTPs, notifications, refunds, stock, payouts)
--
-- A direct UPDATE on orders.status is blocked by a trigger.
-- ═══════════════════════════════════════════════════════════════════════════

create table public.order_status_transitions (
  from_status         public.order_status not null,
  to_status           public.order_status not null,
  -- Permission a human actor must hold. NULL = system/internal only.
  required_permission text,
  -- True when the customer who owns the order may trigger it themselves.
  customer_allowed    boolean not null default false,
  -- True when the assigned rider may trigger it.
  rider_allowed       boolean not null default false,
  label               text not null,
  customer_label      text not null,
  description         text,
  primary key (from_status, to_status)
);

comment on table public.order_status_transitions is
  'The order state machine as data. Every allowed edge with its authorisation rule.';

insert into public.order_status_transitions
  (from_status, to_status, required_permission, customer_allowed, rider_allowed, label, customer_label) values
  -- Payment
  ('PENDING_PAYMENT',        'PAYMENT_CONFIRMED',      null,               false, false, 'Payment confirmed',        'Payment confirmed'),
  ('PENDING_PAYMENT',        'PAYMENT_FAILED',         null,               false, false, 'Payment failed',           'Payment failed'),
  ('PENDING_PAYMENT',        'CUSTOMER_CANCELLED',     'order.cancel',     true,  false, 'Cancelled before payment', 'Order cancelled'),
  ('PENDING_PAYMENT',        'ADMIN_CANCELLED',        'order.cancel',     false, false, 'Cancelled by store',       'Order cancelled'),
  ('PAYMENT_FAILED',         'PENDING_PAYMENT',        null,               true,  false, 'Retrying payment',         'Retrying payment'),
  ('PAYMENT_FAILED',         'CUSTOMER_CANCELLED',     'order.cancel',     true,  false, 'Cancelled by customer',    'Order cancelled'),
  ('PAYMENT_FAILED',         'ADMIN_CANCELLED',        'order.cancel',     false, false, 'Cancelled by store',       'Order cancelled'),
  -- Placement
  ('PAYMENT_CONFIRMED',      'ORDER_PLACED',           null,               false, false, 'Order placed',             'Order placed'),
  ('PAYMENT_CONFIRMED',      'ADMIN_CANCELLED',        'order.cancel',     false, false, 'Cancelled by store',       'Order cancelled'),
  ('PAYMENT_CONFIRMED',      'CUSTOMER_CANCELLED',     'order.cancel',     true,  false, 'Cancelled by customer',    'Order cancelled'),
  -- Store acceptance
  ('ORDER_PLACED',           'STORE_ACCEPTED',         'order.accept',     false, false, 'Restaurant accepted',      'Restaurant accepted your order'),
  ('ORDER_PLACED',           'STORE_REJECTED',         'order.reject',     false, false, 'Restaurant rejected',      'Restaurant could not accept your order'),
  ('ORDER_PLACED',           'CUSTOMER_CANCELLED',     'order.cancel',     true,  false, 'Cancelled by customer',    'Order cancelled'),
  ('ORDER_PLACED',           'ADMIN_CANCELLED',        'order.cancel',     false, false, 'Cancelled by store',       'Order cancelled'),
  -- Kitchen
  ('STORE_ACCEPTED',         'PREPARING',              'order.prepare',    false, false, 'Preparing',                'Your food is being prepared'),
  ('STORE_ACCEPTED',         'CUSTOMER_CANCELLED',     'order.cancel',     true,  false, 'Cancelled by customer',    'Order cancelled'),
  ('STORE_ACCEPTED',         'ADMIN_CANCELLED',        'order.cancel',     false, false, 'Cancelled by store',       'Order cancelled'),
  ('PREPARING',              'READY_FOR_PICKUP',       'order.ready',      false, false, 'Ready',                    'Your order is ready'),
  ('PREPARING',              'CUSTOMER_CANCELLED',     'order.cancel',     true,  false, 'Cancelled by customer',    'Order cancelled'),
  ('PREPARING',              'ADMIN_CANCELLED',        'order.cancel',     false, false, 'Cancelled by store',       'Order cancelled'),
  -- Dispatch
  ('READY_FOR_PICKUP',       'RIDER_ASSIGNED',         'delivery.assign',  false, false, 'Rider assigned',           'A delivery partner is on the way'),
  ('READY_FOR_PICKUP',       'PICKED_UP',              'delivery.pickup',  false, false, 'Collected by customer',    'Order collected'),
  ('READY_FOR_PICKUP',       'DELIVERED',              'delivery.complete',false, false, 'Handed to customer',       'Order collected'),
  ('READY_FOR_PICKUP',       'ADMIN_CANCELLED',        'order.cancel',     false, false, 'Cancelled by store',       'Order cancelled'),
  ('STORE_ACCEPTED',         'RIDER_ASSIGNED',         'delivery.assign',  false, false, 'Rider assigned early',     'A delivery partner is assigned'),
  ('PREPARING',              'RIDER_ASSIGNED',         'delivery.assign',  false, false, 'Rider assigned early',     'A delivery partner is assigned'),
  -- Rider journey
  ('RIDER_ASSIGNED',         'RIDER_ARRIVED_STORE',    'delivery.view',    false, true,  'Rider at restaurant',      'Delivery partner reached the restaurant'),
  ('RIDER_ASSIGNED',         'READY_FOR_PICKUP',       'delivery.assign',  false, false, 'Rider unassigned',         'Reassigning your delivery partner'),
  ('RIDER_ASSIGNED',         'ADMIN_CANCELLED',        'order.cancel',     false, false, 'Cancelled by store',       'Order cancelled'),
  ('RIDER_ARRIVED_STORE',    'PICKED_UP',              'delivery.pickup',  false, true,  'Picked up',                'Your order has been picked up'),
  ('RIDER_ARRIVED_STORE',    'READY_FOR_PICKUP',       'delivery.assign',  false, false, 'Rider unassigned',         'Reassigning your delivery partner'),
  ('PICKED_UP',              'OUT_FOR_DELIVERY',       'delivery.view',    false, true,  'Out for delivery',         'On the way to you'),
  ('PICKED_UP',              'DELIVERY_FAILED',        'delivery.complete',false, true,  'Delivery failed',          'Delivery could not be completed'),
  ('OUT_FOR_DELIVERY',       'RIDER_ARRIVED_CUSTOMER', 'delivery.view',    false, true,  'Rider arrived',            'Your delivery partner has arrived'),
  ('OUT_FOR_DELIVERY',       'DELIVERED',              'delivery.complete',false, true,  'Delivered',                'Delivered. Enjoy your meal!'),
  ('OUT_FOR_DELIVERY',       'DELIVERY_FAILED',        'delivery.complete',false, true,  'Delivery failed',          'Delivery could not be completed'),
  ('RIDER_ARRIVED_CUSTOMER', 'DELIVERED',              'delivery.complete',false, true,  'Delivered',                'Delivered. Enjoy your meal!'),
  ('RIDER_ARRIVED_CUSTOMER', 'DELIVERY_FAILED',        'delivery.complete',false, true,  'Delivery failed',          'Delivery could not be completed'),
  ('DELIVERY_FAILED',        'OUT_FOR_DELIVERY',       'delivery.assign',  false, false, 'Retrying delivery',        'Retrying your delivery'),
  ('DELIVERY_FAILED',        'ADMIN_CANCELLED',        'order.cancel',     false, false, 'Cancelled after failure',  'Order cancelled'),
  -- Completion & money back
  ('DELIVERED',              'COMPLETED',              null,               false, false, 'Completed',                'Order completed'),
  ('DELIVERED',              'REFUND_PENDING',         'refund.create',    false, false, 'Refund requested',         'Refund initiated'),
  ('COMPLETED',              'REFUND_PENDING',         'refund.create',    false, false, 'Refund requested',         'Refund initiated'),
  ('CUSTOMER_CANCELLED',     'REFUND_PENDING',         'refund.create',    false, false, 'Refund requested',         'Refund initiated'),
  ('ADMIN_CANCELLED',        'REFUND_PENDING',         'refund.create',    false, false, 'Refund requested',         'Refund initiated'),
  ('STORE_REJECTED',         'REFUND_PENDING',         'refund.create',    false, false, 'Refund requested',         'Refund initiated'),
  ('DELIVERY_FAILED',        'REFUND_PENDING',         'refund.create',    false, false, 'Refund requested',         'Refund initiated'),
  ('REFUND_PENDING',         'PARTIALLY_REFUNDED',     null,               false, false, 'Partially refunded',       'Partial refund completed'),
  ('REFUND_PENDING',         'REFUNDED',               null,               false, false, 'Refunded',                 'Refund completed'),
  ('PARTIALLY_REFUNDED',     'REFUNDED',               null,               false, false, 'Fully refunded',           'Refund completed'),
  ('PARTIALLY_REFUNDED',     'REFUND_PENDING',         'refund.create',    false, false, 'Further refund requested', 'Refund initiated');

-- Terminal states cannot be left except through the refund lifecycle.
create or replace function app.is_terminal_status(p_status public.order_status)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_status in ('COMPLETED', 'REFUNDED', 'STORE_REJECTED');
$$;

create or replace function app.is_cancelled_status(p_status public.order_status)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_status in ('CUSTOMER_CANCELLED', 'ADMIN_CANCELLED', 'STORE_REJECTED', 'DELIVERY_FAILED');
$$;

create or replace function app.is_active_status(p_status public.order_status)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_status in (
    'PENDING_PAYMENT', 'PAYMENT_CONFIRMED', 'ORDER_PLACED', 'STORE_ACCEPTED',
    'PREPARING', 'READY_FOR_PICKUP', 'RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE',
    'PICKED_UP', 'OUT_FOR_DELIVERY', 'RIDER_ARRIVED_CUSTOMER'
  );
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- GUARD: block direct status writes
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.tg_orders_guard_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status
     and coalesce(current_setting('bitesbox.transition_ok', true), '') <> 'on' then
    raise exception 'Order status must be changed through app.transition_order().'
      using errcode = 'P0001', hint = 'INVALID_ORDER_TRANSITION';
  end if;

  return new;
end;
$$;

create trigger orders_guard_status
  before update of status on public.orders
  for each row execute function app.tg_orders_guard_status();

comment on function app.tg_orders_guard_status is
  'Prevents any code path other than app.transition_order() from mutating order status.';

-- ═══════════════════════════════════════════════════════════════════════════
-- TRANSITION
-- ═══════════════════════════════════════════════════════════════════════════
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

  v_is_customer := v_actor is not null and v_actor = v_order.user_id;
  v_is_rider := v_actor is not null and exists (
    select 1
    from public.delivery_assignments da
    join public.delivery_partners dp on dp.id = da.delivery_partner_id
    where da.order_id = p_order_id
      and dp.user_id = v_actor
      and da.status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
  );

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

comment on function app.transition_order is
  'The only sanctioned order status mutator. Validates the edge, authorises, stamps, logs and fires side effects.';

-- ═══════════════════════════════════════════════════════════════════════════
-- SIDE EFFECTS
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.on_order_status_changed(
  p_order_id uuid,
  p_from public.order_status,
  p_to public.order_status,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_vars jsonb;
  v_code text;
  v_salt text;
  v_earn_rate numeric;
  v_points int;
begin
  select * into v_order from public.orders where id = p_order_id;

  v_vars := jsonb_build_object(
    'order_number', v_order.order_number,
    'order_id', v_order.id::text,
    'customer_name', coalesce(split_part(v_order.customer_name, ' ', 1), 'there'),
    'grand_total', to_char(v_order.grand_total, 'FM999999990.00'),
    'item_count', v_order.item_count::text,
    'eta_minutes', coalesce(v_order.delivery_minutes_estimate, 0)::text
  );

  -- ── Payment confirmed → place the order (or hold a scheduled one) ──
  if p_to = 'PAYMENT_CONFIRMED' then
    perform app.enqueue_notification(
      v_order.user_id, 'PAYMENT_CONFIRMED', v_vars,
      array['PUSH', 'IN_APP']::public.notification_channel[],
      p_order_id, 'payment_confirmed:' || p_order_id::text
    );

    if v_order.timing = 'NOW' then
      perform app.transition_order(
        p_order_id, 'ORDER_PLACED', 'Auto-placed after payment confirmation', 'SYSTEM'
      );
    end if;

    return;
  end if;

  -- ── Order placed → tell the customer and wake the kitchen ──
  if p_to = 'ORDER_PLACED' then
    perform app.enqueue_notification(
      v_order.user_id, 'ORDER_PLACED', v_vars,
      array['PUSH', 'IN_APP', 'SMS']::public.notification_channel[],
      p_order_id, 'order_placed:' || p_order_id::text
    );

    -- Kitchen staff on duty at this branch.
    perform app.enqueue_notification(
      ur.user_id, 'NEW_ORDER_KITCHEN', v_vars,
      array['PUSH']::public.notification_channel[],
      p_order_id, 'kitchen_new:' || p_order_id::text || ':' || ur.user_id::text
    )
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.is_active
      and r.code in ('KITCHEN_STAFF', 'MANAGER')
      and (ur.branch_id is null or ur.branch_id = v_order.branch_id);

    return;
  end if;

  if p_to = 'STORE_ACCEPTED' then
    perform app.enqueue_notification(
      v_order.user_id, 'ORDER_ACCEPTED', v_vars,
      array['PUSH', 'IN_APP']::public.notification_channel[],
      p_order_id, 'order_accepted:' || p_order_id::text
    );
    return;
  end if;

  if p_to = 'PREPARING' then
    perform app.enqueue_notification(
      v_order.user_id, 'ORDER_PREPARING', v_vars,
      array['PUSH', 'IN_APP']::public.notification_channel[],
      p_order_id, 'order_preparing:' || p_order_id::text
    );
    return;
  end if;

  -- ── Ready → mint the pickup code and (for pickup orders) the collection OTP ──
  if p_to = 'READY_FOR_PICKUP' then
    v_salt := app.random_alnum_code(12);
    v_code := app.random_numeric_code(4);

    update public.orders
    set pickup_code_hash = app.hash_code(v_code, v_salt),
        delivery_code_salt = coalesce(delivery_code_salt, v_salt),
        updated_at = now()
    where id = p_order_id;

    insert into public.verification_codes (
      purpose, subject, code_hash, salt, order_id, user_id, expires_at
    )
    values (
      'PICKUP_CODE', p_order_id::text, app.hash_code(v_code, v_salt), v_salt,
      p_order_id, v_order.user_id, now() + interval '6 hours'
    );

    perform app.enqueue_notification(
      v_order.user_id, 'ORDER_READY',
      v_vars || jsonb_build_object('pickup_code', v_code),
      case
        when v_order.fulfilment_type = 'PICKUP'
        then array['PUSH', 'IN_APP', 'SMS']::public.notification_channel[]
        else array['PUSH', 'IN_APP']::public.notification_channel[]
      end,
      p_order_id, 'order_ready:' || p_order_id::text
    );
    return;
  end if;

  -- ── Rider assigned → mint the delivery OTP for the customer ──
  if p_to = 'RIDER_ASSIGNED' then
    if v_order.delivery_code_hash is null then
      v_salt := app.random_alnum_code(12);
      v_code := app.random_numeric_code(app.setting_int('delivery.otp_length', 4));

      update public.orders
      set delivery_code_hash = app.hash_code(v_code, v_salt),
          delivery_code_salt = v_salt,
          delivery_code_attempts = 0,
          updated_at = now()
      where id = p_order_id;

      insert into public.verification_codes (
        purpose, subject, code_hash, salt, order_id, user_id, expires_at
      )
      values (
        'DELIVERY_OTP', p_order_id::text, app.hash_code(v_code, v_salt), v_salt,
        p_order_id, v_order.user_id, now() + interval '12 hours'
      );

      perform app.enqueue_notification(
        v_order.user_id, 'DELIVERY_OTP',
        v_vars || jsonb_build_object('delivery_otp', v_code),
        array['PUSH', 'IN_APP', 'SMS']::public.notification_channel[],
        p_order_id, 'delivery_otp:' || p_order_id::text
      );
    end if;

    perform app.enqueue_notification(
      v_order.user_id, 'RIDER_ASSIGNED',
      v_vars || jsonb_build_object(
        'rider_name', coalesce((
          select dp.full_name
          from public.delivery_assignments da
          join public.delivery_partners dp on dp.id = da.delivery_partner_id
          where da.order_id = p_order_id
            and da.status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
          order by da.attempt_number desc limit 1
        ), 'Your delivery partner')
      ),
      array['PUSH', 'IN_APP']::public.notification_channel[],
      p_order_id, 'rider_assigned:' || p_order_id::text
    );
    return;
  end if;

  if p_to = 'PICKED_UP' then
    perform app.enqueue_notification(
      v_order.user_id, 'ORDER_PICKED_UP', v_vars,
      array['PUSH', 'IN_APP']::public.notification_channel[],
      p_order_id, 'order_picked_up:' || p_order_id::text
    );
    return;
  end if;

  if p_to = 'RIDER_ARRIVED_CUSTOMER' then
    perform app.enqueue_notification(
      v_order.user_id, 'RIDER_NEARBY', v_vars,
      array['PUSH', 'IN_APP']::public.notification_channel[],
      p_order_id, 'rider_nearby:' || p_order_id::text
    );
    return;
  end if;

  -- ── Delivered → notify, award loyalty, settle COD, ask for a rating ──
  if p_to = 'DELIVERED' then
    perform app.enqueue_notification(
      v_order.user_id, 'ORDER_DELIVERED', v_vars,
      array['PUSH', 'IN_APP']::public.notification_channel[],
      p_order_id, 'order_delivered:' || p_order_id::text
    );

    if public.feature_enabled('loyalty', v_order.user_id) then
      v_earn_rate := app.setting_numeric('loyalty.earn_points_per_100', 5);
      v_points := floor(v_order.grand_total / 100 * v_earn_rate)::int;

      if v_points > 0 then
        perform app.post_loyalty_entry(
          v_order.user_id, 'EARN', v_points,
          format('Points earned on order %s', v_order.order_number),
          p_order_id, v_order.grand_total,
          'loyalty_earn:' || p_order_id::text
        );
      end if;
    end if;

    -- Request a review a little later so the customer has eaten first.
    perform app.enqueue_notification(
      v_order.user_id, 'REVIEW_REQUEST', v_vars,
      array['PUSH', 'IN_APP']::public.notification_channel[],
      p_order_id, 'review_request:' || p_order_id::text,
      now() + interval '45 minutes'
    );
    return;
  end if;

  -- ── Cancellations ──
  if app.is_cancelled_status(p_to) then
    perform app.enqueue_notification(
      v_order.user_id, 'ORDER_CANCELLED',
      v_vars || jsonb_build_object(
        'reason', coalesce(v_order.cancellation_note, v_order.cancellation_reason::text, 'Order cancelled')
      ),
      array['PUSH', 'IN_APP', 'SMS']::public.notification_channel[],
      p_order_id, 'order_cancelled:' || p_order_id::text
    );

    -- Free the coupon use so the customer is not penalised for a store failure.
    delete from public.coupon_redemptions where order_id = p_order_id;

    update public.coupons c
    set total_used = greatest(c.total_used - 1, 0)
    where c.id = v_order.coupon_id;

    -- Release any live rider assignment.
    update public.delivery_assignments
    set status = 'CANCELLED', cancelled_at = now(), updated_at = now()
    where order_id = p_order_id
      and status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER');

    -- Return wallet money immediately; gateway refunds go through process-refund.
    if v_order.wallet_applied > 0 then
      perform app.post_wallet_entry(
        v_order.user_id, 'REFUND', v_order.wallet_applied,
        format('Wallet refund for cancelled order %s', v_order.order_number),
        p_order_id, null, 'wallet_cancel_refund:' || p_order_id::text
      );
    end if;

    -- Give redeemed loyalty points back.
    if v_order.loyalty_points_redeemed > 0 then
      perform app.post_loyalty_entry(
        v_order.user_id, 'REVERSAL', v_order.loyalty_points_redeemed,
        format('Points returned for cancelled order %s', v_order.order_number),
        p_order_id, 0, 'loyalty_reversal:' || p_order_id::text
      );
    end if;

    if v_order.payment_mode in ('COD', 'SPLIT_WALLET_COD') then
      update public.cod_collections
      set status = 'COD_WAIVED', updated_at = now()
      where order_id = p_order_id and status = 'COD_PENDING';
    end if;

    return;
  end if;

  if p_to = 'REFUND_PENDING' then
    perform app.enqueue_notification(
      v_order.user_id, 'REFUND_INITIATED', v_vars,
      array['PUSH', 'IN_APP']::public.notification_channel[],
      p_order_id, 'refund_initiated:' || p_order_id::text
    );
    return;
  end if;

  if p_to in ('REFUNDED', 'PARTIALLY_REFUNDED') then
    perform app.enqueue_notification(
      v_order.user_id, 'REFUND_COMPLETED',
      v_vars || jsonb_build_object(
        'refund_amount', to_char(v_order.refunded_amount, 'FM999999990.00')
      ),
      array['PUSH', 'IN_APP', 'SMS']::public.notification_channel[],
      p_order_id, 'refund_completed:' || p_order_id::text || ':' || v_order.refunded_amount::text
    );
    return;
  end if;

  if p_to = 'PAYMENT_FAILED' then
    perform app.enqueue_notification(
      v_order.user_id, 'PAYMENT_FAILED', v_vars,
      array['PUSH', 'IN_APP']::public.notification_channel[],
      p_order_id, 'payment_failed:' || p_order_id::text
    );
    return;
  end if;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER PLACEMENT
-- Called by the create-order Edge Function inside a single transaction.
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.place_order(
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
declare
  v_cart public.carts;
  v_calc jsonb;
  v_totals jsonb;
  v_order public.orders;
  v_existing public.orders;
  v_address public.addresses;
  v_profile public.profiles;
  v_line jsonb;
  v_item_id uuid;
  v_mod jsonb;
  v_display int := 0;
  v_issues jsonb;
  v_first_issue jsonb;
  v_initial_status public.order_status;
  v_now timestamptz := now();
  v_prep int;
  v_delivery int;
begin
  if p_idempotency_key is null or length(btrim(p_idempotency_key)) < 8 then
    perform app.fail('IDEMPOTENCY_KEY_REQUIRED', 'A valid idempotency key is required.');
  end if;

  -- ── Idempotent replay ──
  select * into v_existing
  from public.orders
  where user_id = p_user_id and idempotency_key = p_idempotency_key;

  if found then
    return jsonb_build_object(
      'order_id', v_existing.id,
      'order_number', v_existing.order_number,
      'status', v_existing.status,
      'payment_mode', v_existing.payment_mode,
      'payable_amount', v_existing.payable_amount,
      'grand_total', v_existing.grand_total,
      'replayed', true
    );
  end if;

  if not app.account_is_active() and not app.is_service_role() then
    perform app.fail('ACCOUNT_BLOCKED', 'This account cannot place orders. Please contact support.');
  end if;

  -- Abuse guard: a burst of orders from one account is almost always a bug or fraud.
  if not app.consume_rate_limit('place_order', p_user_id::text, 10, 600, 900) then
    perform app.fail('RATE_LIMITED', 'Too many order attempts. Please wait a moment.');
  end if;

  select * into v_cart from public.carts
  where (p_cart_id is null or id = p_cart_id)
    and user_id = p_user_id
    and branch_id = coalesce(p_branch_id, app.default_branch_id())
    and is_active
  limit 1;

  if not found then
    perform app.fail('CART_EMPTY', 'Your cart is empty.');
  end if;

  -- Lock the cart so a second concurrent checkout cannot read the same lines.
  perform 1 from public.carts where id = v_cart.id for update;

  -- ── RECALCULATE. The client total is never used. ──
  v_calc := app.calculate_checkout(
    p_user_id, v_cart.id, p_payment_mode, p_tip_amount, p_loyalty_points, v_now
  );

  v_issues := coalesce(v_calc -> 'issues', '[]'::jsonb);

  if not coalesce((v_calc ->> 'is_valid')::boolean, false) then
    select i into v_first_issue
    from jsonb_array_elements(v_issues) i
    where i ->> 'severity' = 'BLOCKING'
    limit 1;

    perform app.fail(
      coalesce(v_first_issue ->> 'code', 'CHECKOUT_INVALID'),
      coalesce(v_first_issue ->> 'message', 'We could not place this order.'),
      jsonb_build_object('issues', v_issues)
    );
  end if;

  v_totals := v_calc -> 'totals';

  select * into v_profile from public.profiles where id = p_user_id;

  if v_cart.fulfilment_type = 'DELIVERY' then
    select * into v_address from public.addresses where id = v_cart.address_id;
  end if;

  -- ── Initial status by payment mode ──
  v_initial_status := case
    when (v_totals ->> 'payable_amount')::numeric <= 0 then 'PAYMENT_CONFIRMED'
    when p_payment_mode in ('COD', 'SPLIT_WALLET_COD') then 'ORDER_PLACED'
    else 'PENDING_PAYMENT'
  end;

  v_prep := coalesce((v_calc #>> '{timing_estimate,prep_minutes}')::int, 20);
  v_delivery := coalesce((v_calc #>> '{timing_estimate,delivery_minutes}')::int, 0);

  insert into public.orders (
    order_number, branch_id, user_id, idempotency_key, channel, fulfilment_type,
    timing, scheduled_for, status,
    customer_name, customer_phone, customer_email,
    address_id, delivery_address_line1, delivery_address_line2, delivery_landmark,
    delivery_area, delivery_city, delivery_state, delivery_postal_code,
    delivery_latitude, delivery_longitude, delivery_instructions,
    delivery_contact_name, delivery_contact_phone,
    delivery_zone_id, delivery_zone_name, distance_km,
    currency_code, items_subtotal, items_discount,
    coupon_id, coupon_code, coupon_discount,
    promotion_id, promotion_discount, total_discount,
    taxable_amount, tax_amount, cgst_amount, sgst_amount, igst_amount, cess_amount,
    packaging_charge, delivery_fee, delivery_fee_waived, service_fee, tip_amount,
    round_off, wallet_applied, loyalty_points_redeemed, loyalty_discount,
    grand_total, payable_amount,
    payment_mode, payment_status, cod_status,
    prep_minutes_estimate, delivery_minutes_estimate, promised_at,
    customer_note, item_count, unit_count, is_first_order,
    app_version, device_platform, created_by
  )
  values (
    app.next_order_number(v_cart.branch_id), v_cart.branch_id, p_user_id,
    p_idempotency_key, p_channel, v_cart.fulfilment_type,
    v_cart.timing, v_cart.scheduled_for, v_initial_status,
    v_profile.full_name, v_profile.phone, v_profile.email,
    v_cart.address_id, v_address.address_line1, v_address.address_line2, v_address.landmark,
    v_address.area, v_address.city, v_address.state, v_address.postal_code,
    v_address.latitude, v_address.longitude,
    coalesce(v_cart.delivery_instructions, v_address.delivery_instructions),
    coalesce(v_address.contact_name, v_profile.full_name),
    coalesce(v_address.contact_phone, v_profile.phone),
    nullif(v_calc #>> '{delivery,zone_id}', '')::uuid,
    v_calc #>> '{delivery,zone_name}',
    nullif(v_calc #>> '{delivery,distance_km}', '')::numeric,
    coalesce(v_calc ->> 'currency_code', 'INR'),
    (v_totals ->> 'items_subtotal')::numeric,
    (v_totals ->> 'items_discount')::numeric,
    v_cart.coupon_id, v_cart.coupon_code, (v_totals ->> 'coupon_discount')::numeric,
    nullif(v_calc #>> '{promotion,promotion_id}', '')::uuid,
    (v_totals ->> 'promotion_discount')::numeric,
    (v_totals ->> 'total_discount')::numeric,
    (v_totals ->> 'taxable_amount')::numeric,
    (v_totals ->> 'tax_amount')::numeric,
    (v_totals ->> 'cgst_amount')::numeric,
    (v_totals ->> 'sgst_amount')::numeric,
    (v_totals ->> 'igst_amount')::numeric,
    (v_totals ->> 'cess_amount')::numeric,
    (v_totals ->> 'packaging_charge')::numeric,
    (v_totals ->> 'delivery_fee')::numeric,
    (v_totals ->> 'delivery_fee_waived')::numeric,
    (v_totals ->> 'service_fee')::numeric,
    (v_totals ->> 'tip_amount')::numeric,
    (v_totals ->> 'round_off')::numeric,
    (v_totals ->> 'wallet_applied')::numeric,
    (v_totals ->> 'loyalty_points_redeemed')::int,
    (v_totals ->> 'loyalty_discount')::numeric,
    (v_totals ->> 'grand_total')::numeric,
    (v_totals ->> 'payable_amount')::numeric,
    p_payment_mode,
    case when (v_totals ->> 'payable_amount')::numeric <= 0
         then 'CAPTURED'::public.payment_status
         else 'CREATED'::public.payment_status end,
    case when p_payment_mode in ('COD', 'SPLIT_WALLET_COD')
         then 'COD_PENDING'::public.cod_status else null end,
    v_prep, v_delivery,
    v_now + make_interval(mins => v_prep + v_delivery),
    v_cart.cooking_instructions,
    (v_calc ->> 'item_count')::int,
    (v_calc ->> 'unit_count')::int,
    coalesce(v_profile.completed_orders, 0) = 0,
    p_app_version, p_device_platform, p_user_id
  )
  returning * into v_order;

  -- ── Line snapshots ──
  for v_line in select * from jsonb_array_elements(v_calc -> 'lines') loop
    v_display := v_display + 1;

    insert into public.order_items (
      order_id, product_id, variant_id, category_id,
      product_name, product_slug, variant_name, variant_option_group, category_name,
      food_type, image_path, short_description,
      quantity, unit_price, modifiers_price, gross_amount,
      discount_amount, allocated_discount, net_amount, packaging_charge,
      tax_category_id, tax_rate, tax_inclusive, taxable_amount, tax_amount,
      cgst_amount, sgst_amount, igst_amount, cess_amount, hsn_sac_code,
      special_instructions, preparation_minutes, display_order
    )
    values (
      v_order.id,
      (v_line ->> 'product_id')::uuid,
      nullif(v_line ->> 'variant_id', '')::uuid,
      (v_line ->> 'category_id')::uuid,
      v_line ->> 'product_name',
      v_line ->> 'product_slug',
      v_line ->> 'variant_name',
      v_line ->> 'variant_option_group',
      v_line ->> 'category_name',
      (v_line ->> 'food_type')::public.food_type,
      v_line ->> 'image_path',
      v_line ->> 'short_description',
      (v_line ->> 'quantity')::smallint,
      (v_line ->> 'unit_price')::numeric,
      (v_line ->> 'modifiers_price')::numeric,
      (v_line ->> 'gross_amount')::numeric,
      0,
      (v_line ->> 'allocated_discount')::numeric,
      (v_line ->> 'net_amount')::numeric,
      (v_line ->> 'packaging_charge')::numeric,
      nullif(v_line ->> 'tax_category_id', '')::uuid,
      (v_line ->> 'tax_rate')::numeric,
      (v_line ->> 'tax_inclusive')::boolean,
      (v_line ->> 'taxable_amount')::numeric,
      (v_line ->> 'tax_amount')::numeric,
      case when (v_line ->> 'tax_rate')::numeric > 0
        then app.money_round((v_line ->> 'tax_amount')::numeric
             * (v_line ->> 'cgst_rate')::numeric / (v_line ->> 'tax_rate')::numeric)
        else 0 end,
      case when (v_line ->> 'tax_rate')::numeric > 0
        then app.money_round((v_line ->> 'tax_amount')::numeric
             * (v_line ->> 'sgst_rate')::numeric / (v_line ->> 'tax_rate')::numeric)
        else 0 end,
      case when (v_line ->> 'tax_rate')::numeric > 0
        then app.money_round((v_line ->> 'tax_amount')::numeric
             * (v_line ->> 'igst_rate')::numeric / (v_line ->> 'tax_rate')::numeric)
        else 0 end,
      app.money_round((v_line ->> 'taxable_amount')::numeric * (v_line ->> 'cess_rate')::numeric),
      v_line ->> 'hsn_sac_code',
      nullif(v_line ->> 'special_instructions', ''),
      (v_line ->> 'preparation_minutes')::int,
      v_display
    )
    returning id into v_item_id;

    for v_mod in select * from jsonb_array_elements(coalesce(v_line -> 'modifiers', '[]'::jsonb)) loop
      insert into public.order_item_modifiers (
        order_item_id, modifier_id, modifier_group_id, group_name, modifier_name,
        unit_price, quantity, total_price, food_type
      )
      values (
        v_item_id,
        (v_mod ->> 'modifier_id')::uuid,
        (v_mod ->> 'modifier_group_id')::uuid,
        v_mod ->> 'group_name',
        v_mod ->> 'modifier_name',
        (v_mod ->> 'unit_price')::numeric,
        (v_mod ->> 'quantity')::smallint,
        (v_mod ->> 'total_price')::numeric,
        (v_mod ->> 'food_type')::public.food_type
      );
    end loop;
  end loop;

  -- ── Coupon redemption (unique on order_id ⇒ never double counted) ──
  if v_order.coupon_id is not null and v_order.coupon_discount >= 0 then
    insert into public.coupon_redemptions (
      coupon_id, user_id, order_id, code, discount_amount, order_amount
    )
    values (
      v_order.coupon_id, p_user_id, v_order.id, v_order.coupon_code,
      v_order.coupon_discount, v_order.items_subtotal
    )
    on conflict (order_id) where order_id is not null do nothing;

    update public.coupons
    set total_used = total_used + 1, updated_at = now()
    where id = v_order.coupon_id;
  end if;

  -- ── Wallet debit ──
  if v_order.wallet_applied > 0 then
    perform app.post_wallet_entry(
      p_user_id, 'DEBIT', -v_order.wallet_applied,
      format('Paid towards order %s', v_order.order_number),
      v_order.id, null, 'wallet_debit:' || v_order.id::text
    );
  end if;

  -- ── Loyalty redemption ──
  if v_order.loyalty_points_redeemed > 0 then
    perform app.post_loyalty_entry(
      p_user_id, 'REDEEM', -v_order.loyalty_points_redeemed,
      format('Redeemed on order %s', v_order.order_number),
      v_order.id, v_order.loyalty_discount,
      'loyalty_redeem:' || v_order.id::text
    );
  end if;

  -- ── COD tracking row ──
  if p_payment_mode in ('COD', 'SPLIT_WALLET_COD') then
    insert into public.cod_collections (order_id, expected_amount)
    values (v_order.id, v_order.payable_amount)
    on conflict (order_id) do nothing;
  end if;

  -- ── Retire the cart ──
  update public.carts
  set is_active = false, converted_order_id = v_order.id, updated_at = now()
  where id = v_cart.id;

  -- ── Opening timeline entry ──
  insert into public.order_status_history (
    order_id, from_status, to_status, label, actor_id, actor_kind, metadata
  )
  values (
    v_order.id, null, v_initial_status,
    case v_initial_status
      when 'PENDING_PAYMENT' then 'Awaiting payment'
      when 'ORDER_PLACED' then 'Order placed'
      else 'Payment confirmed'
    end,
    p_user_id, 'USER',
    jsonb_build_object('channel', p_channel, 'payment_mode', p_payment_mode)
  );

  -- Fire the side effects for orders that skipped the payment step.
  if v_initial_status = 'ORDER_PLACED' then
    perform app.on_order_status_changed(v_order.id, null, 'ORDER_PLACED');
  elsif v_initial_status = 'PAYMENT_CONFIRMED' then
    perform app.on_order_status_changed(v_order.id, null, 'PAYMENT_CONFIRMED');
  end if;

  return jsonb_build_object(
    'order_id', v_order.id,
    'order_number', v_order.order_number,
    'status', v_order.status,
    'payment_mode', v_order.payment_mode,
    'payment_status', v_order.payment_status,
    'grand_total', v_order.grand_total,
    'payable_amount', v_order.payable_amount,
    'currency_code', v_order.currency_code,
    'requires_payment', v_order.status = 'PENDING_PAYMENT',
    'promised_at', v_order.promised_at,
    'replayed', false
  );
end;
$$;

comment on function app.place_order is
  'Transactional order placement. Recalculates money, validates, snapshots lines, and is idempotent.';

-- ═══════════════════════════════════════════════════════════════════════════
-- CANCELLATION ENGINE
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.cancellation_options(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_policy public.cancellation_policies;
  v_elapsed int;
  v_refund numeric;
  v_fee numeric;
begin
  select * into v_order from public.orders where id = p_order_id;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'Order not found.');
  end if;

  if v_order.user_id <> auth.uid() and not app.is_staff() then
    perform app.fail('PERMISSION_DENIED', 'You cannot view this order.');
  end if;

  select * into v_policy
  from public.cancellation_policies
  where status = v_order.status
    and is_active
    and (branch_id is null or branch_id = v_order.branch_id)
  order by branch_id nulls last
  limit 1;

  if not found or not v_policy.customer_can_cancel then
    return jsonb_build_object(
      'can_cancel', false,
      'requires_approval', false,
      'reason_code', 'CANCELLATION_NOT_ALLOWED',
      'message', coalesce(
        v_policy.customer_message,
        case
          when v_order.status in ('PICKED_UP', 'OUT_FOR_DELIVERY', 'RIDER_ARRIVED_CUSTOMER')
            then 'Your order is already on the way and can no longer be cancelled. Contact support if something is wrong.'
          when v_order.status in ('DELIVERED', 'COMPLETED')
            then 'This order has been delivered. Raise a support request if there was a problem.'
          else 'This order can no longer be cancelled. Please contact support.'
        end
      )
    );
  end if;

  v_elapsed := coalesce(extract(epoch from (now() - coalesce(v_order.placed_at, v_order.created_at)))::int, 0);

  -- Inside the grace period the customer gets a full, fee-free refund.
  if v_elapsed <= v_policy.grace_period_seconds then
    v_refund := v_order.grand_total;
    v_fee := 0;
  else
    v_fee := v_policy.cancellation_fee;
    v_refund := app.money_round(
      greatest(v_order.grand_total * v_policy.refund_percentage / 100 - v_fee, 0)
    );
  end if;

  return jsonb_build_object(
    'can_cancel', true,
    'requires_approval', v_policy.requires_approval,
    'refund_amount', v_refund,
    'cancellation_fee', v_fee,
    'refund_percentage', v_policy.refund_percentage,
    'grace_period_seconds', v_policy.grace_period_seconds,
    'within_grace_period', v_elapsed <= v_policy.grace_period_seconds,
    'message', coalesce(
      v_policy.customer_message,
      case
        when v_refund >= v_order.grand_total then 'You will receive a full refund.'
        when v_refund > 0 then format('You will receive ₹%s back. A cancellation fee of ₹%s applies.',
                                      to_char(v_refund, 'FM999999990.00'), to_char(v_fee, 'FM999999990.00'))
        else 'This order is no longer refundable.'
      end
    ),
    'refund_destination', case
      when v_order.payment_mode in ('COD', 'SPLIT_WALLET_COD') then 'NONE'
      else 'ORIGINAL_PAYMENT_METHOD'
    end
  );
end;
$$;

comment on function public.cancellation_options is
  'Policy-driven answer to "can I cancel, and what do I get back?" for a given order.';

create or replace function public.cancel_order(
  p_order_id uuid,
  p_reason public.cancellation_reason default 'CUSTOMER_CHANGED_MIND',
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders;
  v_options jsonb;
  v_is_customer boolean;
  v_target public.order_status;
  v_result jsonb;
begin
  select * into v_order from public.orders where id = p_order_id;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'Order not found.');
  end if;

  v_is_customer := v_order.user_id = v_uid;

  if v_is_customer then
    v_options := public.cancellation_options(p_order_id);

    if not (v_options ->> 'can_cancel')::boolean then
      perform app.fail(
        coalesce(v_options ->> 'reason_code', 'CANCELLATION_NOT_ALLOWED'),
        v_options ->> 'message',
        v_options
      );
    end if;

    -- Repeat-cancellation abuse control.
    if not app.consume_rate_limit('cancel_order', v_uid::text, 3, 86400) then
      perform app.fail(
        'CANCELLATION_LIMIT_REACHED',
        'You have cancelled several orders today. Please contact support to continue.'
      );
    end if;

    v_target := 'CUSTOMER_CANCELLED';
  else
    perform app.require_permission('order.cancel', v_order.branch_id);
    v_target := 'ADMIN_CANCELLED';
    v_options := jsonb_build_object('refund_amount', v_order.grand_total, 'cancellation_fee', 0);
  end if;

  v_result := app.transition_order(
    p_order_id, v_target, p_note, 'USER', v_uid,
    jsonb_build_object('reason', p_reason, 'refund_amount', v_options -> 'refund_amount'),
    false,
    case when v_is_customer then 'CUSTOMER'::public.cancellation_actor
         else 'ADMIN'::public.cancellation_actor end,
    p_reason
  );

  update public.orders
  set cancellation_fee = coalesce((v_options ->> 'cancellation_fee')::numeric, 0),
      updated_at = now()
  where id = p_order_id;

  perform app.audit(
    'ORDER_CANCEL', 'order', p_order_id::text,
    jsonb_build_object('status', v_order.status),
    jsonb_build_object('status', v_target, 'reason', p_reason),
    p_note, v_order.order_number, v_order.branch_id
  );

  return v_result || jsonb_build_object(
    'refund_amount', coalesce((v_options ->> 'refund_amount')::numeric, 0),
    'refund_will_be_processed', v_order.payment_status = 'CAPTURED'
                                and coalesce((v_options ->> 'refund_amount')::numeric, 0) > 0
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- KITCHEN & OPERATIONS ACTIONS
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.accept_order(
  p_order_id uuid,
  p_prep_minutes int default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
begin
  -- Authorise before the lookup so a caller without kitchen rights cannot use
  -- this endpoint to discover which order ids exist.
  perform app.require_permission('order.accept');

  select * into v_order from public.orders where id = p_order_id;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'Order not found.');
  end if;

  perform app.require_permission('order.accept', v_order.branch_id);

  if p_prep_minutes is not null then
    update public.orders
    set prep_minutes_estimate = p_prep_minutes,
        promised_at = now() + make_interval(
          mins => p_prep_minutes + coalesce(delivery_minutes_estimate, 0)
        ),
        updated_at = now()
    where id = p_order_id;
  end if;

  return app.transition_order(p_order_id, 'STORE_ACCEPTED', null, 'USER');
end;
$$;

create or replace function public.reject_order(
  p_order_id uuid,
  p_reason public.cancellation_reason default 'KITCHEN_OVERLOADED',
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_result jsonb;
begin
  perform app.require_permission('order.reject');

  select * into v_order from public.orders where id = p_order_id;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'Order not found.');
  end if;

  perform app.require_permission('order.reject', v_order.branch_id);

  v_result := app.transition_order(
    p_order_id, 'STORE_REJECTED', p_note, 'USER', auth.uid(),
    jsonb_build_object('reason', p_reason), false, 'STORE', p_reason
  );

  return v_result || jsonb_build_object(
    'refund_required', v_order.payment_status = 'CAPTURED' and v_order.grand_total > 0,
    'refund_amount', v_order.grand_total
  );
end;
$$;

create or replace function public.start_preparing(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return app.transition_order(p_order_id, 'PREPARING', null, 'USER');
end;
$$;

create or replace function public.mark_order_ready(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return app.transition_order(p_order_id, 'READY_FOR_PICKUP', null, 'USER');
end;
$$;

-- Kitchen removes a single unavailable line mid-preparation. The order stays
-- alive; the removed value becomes an item refund handled by finance.
create or replace function public.cancel_order_item(
  p_order_item_id uuid,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.order_items;
  v_order public.orders;
begin
  select * into v_item from public.order_items where id = p_order_item_id;

  if not found then
    perform app.fail('ORDER_ITEM_NOT_FOUND', 'That order line was not found.');
  end if;

  select * into v_order from public.orders where id = v_item.order_id;

  perform app.require_permission('order.prepare', v_order.branch_id);

  if v_order.status not in ('ORDER_PLACED', 'STORE_ACCEPTED', 'PREPARING') then
    perform app.fail('ITEM_CANCEL_NOT_ALLOWED', 'Items can only be removed while the order is in the kitchen.');
  end if;

  if (select count(*) from public.order_items where order_id = v_item.order_id and not is_cancelled) <= 1 then
    perform app.fail(
      'LAST_ITEM_CANNOT_BE_CANCELLED',
      'This is the only item left. Reject or cancel the whole order instead.'
    );
  end if;

  update public.order_items
  set is_cancelled = true, cancellation_note = p_note
  where id = p_order_item_id;

  insert into public.order_notes (order_id, author_id, note)
  values (
    v_item.order_id, auth.uid(),
    format('Item removed: %s ×%s. %s', v_item.product_name, v_item.quantity, coalesce(p_note, ''))
  );

  perform app.audit(
    'UPDATE', 'order_item', p_order_item_id::text,
    jsonb_build_object('is_cancelled', false),
    jsonb_build_object('is_cancelled', true, 'note', p_note),
    p_note, v_item.product_name, v_order.branch_id
  );

  return jsonb_build_object(
    'order_item_id', p_order_item_id,
    'refund_suggested', app.money_round(v_item.net_amount),
    'order_id', v_item.order_id
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- BRANCH OPEN / CLOSE / PAUSE
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.set_branch_status(
  p_status public.branch_status,
  p_reason public.branch_closure_reason default null,
  p_note text default null,
  p_branch_id uuid default null,
  p_resume_after_minutes int default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_previous public.branch_status;
  v_accepting boolean;
begin
  perform app.require_permission('branch.manage', v_branch);

  select status into v_previous from public.branches where id = v_branch;

  if p_status <> 'OPEN' and p_reason is null then
    perform app.fail('CLOSURE_REASON_REQUIRED', 'Please select a reason.');
  end if;

  v_accepting := p_status in ('OPEN', 'BUSY');

  update public.branches
  set status = p_status,
      status_reason = case when p_status = 'OPEN' then null else p_reason end,
      status_note = case when p_status = 'OPEN' then null else p_note end,
      accepting_orders = v_accepting,
      status_changed_at = now(),
      status_changed_by = auth.uid(),
      auto_resume_at = case
        when p_resume_after_minutes is null then null
        else now() + make_interval(mins => p_resume_after_minutes)
      end,
      updated_at = now()
  where id = v_branch;

  insert into public.branch_status_log (
    branch_id, previous_status, status, reason, note, accepting_orders, changed_by
  )
  values (v_branch, v_previous, p_status, p_reason, p_note, v_accepting, auth.uid());

  return public.branch_ordering_state(v_branch);
end;
$$;

comment on function public.set_branch_status is
  'Manager/kitchen switch for Open, Close, Pause and Too Busy, with an optional auto-resume timer.';
