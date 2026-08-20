-- ═══════════════════════════════════════════════════════════════════════════
-- 0019 · REFUND OPERATIONS
--
-- request → permission check → amount validation → approval (policy driven) →
-- gateway call (Edge Function) → webhook → completion → notification → audit.
--
-- Postgres owns eligibility, amount limits, approval routing and idempotency.
-- The Edge Function only talks to Razorpay.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.refund_eligibility(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_refundable numeric;
  v_payment public.payments;
begin
  select * into v_order from public.orders where id = p_order_id;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'Order not found.');
  end if;

  if v_order.user_id <> auth.uid() and not app.has_permission('refund.view', v_order.branch_id) then
    perform app.fail('PERMISSION_DENIED', 'You cannot view refunds for this order.');
  end if;

  v_refundable := app.refundable_amount(p_order_id);

  select * into v_payment
  from public.payments
  where order_id = p_order_id and status in ('CAPTURED', 'PARTIALLY_REFUNDED')
  order by captured_at desc nulls last
  limit 1;

  return jsonb_build_object(
    'order_id', p_order_id,
    'grand_total', v_order.grand_total,
    'already_refunded', v_order.refunded_amount,
    'refundable_amount', v_refundable,
    'payment_id', v_payment.id,
    'payment_mode', v_order.payment_mode,
    -- COD money never reached the gateway, so it can only go back as wallet credit.
    'gateway_refund_possible', v_payment.id is not null
                               and v_order.payment_mode not in ('COD', 'SPLIT_WALLET_COD'),
    'wallet_credit_possible', true,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'order_item_id', oi.id,
        'product_name', oi.product_name,
        'variant_name', oi.variant_name,
        'quantity', oi.quantity,
        'refunded_quantity', oi.refunded_quantity,
        'refundable_quantity', oi.quantity - oi.refunded_quantity,
        'net_amount', oi.net_amount,
        'unit_refund_value', case
          when oi.quantity > 0 then app.money_round(oi.net_amount / oi.quantity)
          else 0
        end,
        'is_cancelled', oi.is_cancelled
      ) order by oi.display_order)
      from public.order_items oi where oi.order_id = p_order_id
    ), '[]'::jsonb),
    'existing_refunds', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'kind', r.kind, 'status', r.status, 'amount', r.amount,
        'amount_processed', r.amount_processed, 'reason', r.reason,
        'destination', r.destination, 'created_at', r.created_at,
        'completed_at', r.completed_at
      ) order by r.created_at desc)
      from public.refunds r where r.order_id = p_order_id
    ), '[]'::jsonb)
  );
end;
$$;

-- ─── Refund request ────────────────────────────────────────────────────────
-- Validates permission, amount and item quantities, then either auto-approves
-- (within the requester's policy limit) or parks the refund for approval.
create or replace function public.request_refund(
  p_order_id uuid,
  p_kind public.refund_kind,
  p_reason public.refund_reason,
  p_amount numeric default null,
  p_destination public.refund_destination default 'ORIGINAL_PAYMENT_METHOD',
  p_reason_note text default null,
  p_items jsonb default '[]'::jsonb,
  p_idempotency_key text default null,
  p_support_ticket_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_payment public.payments;
  v_refundable numeric;
  v_amount numeric := 0;
  v_refund public.refunds;
  v_existing public.refunds;
  v_policy public.refund_policies;
  v_role public.app_role;
  v_auto_approve boolean := false;
  v_key text;
  v_item jsonb;
  v_order_item public.order_items;
  v_item_total numeric := 0;
  v_destination public.refund_destination := p_destination;
begin
  perform app.require_permission('refund.create');

  select * into v_order from public.orders where id = p_order_id for update;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'Order not found.');
  end if;

  perform app.require_permission('refund.create', v_order.branch_id);

  v_key := coalesce(
    p_idempotency_key,
    'refund:' || p_order_id::text || ':' || p_kind::text || ':' || coalesce(p_amount::text, 'auto')
  );

  -- Idempotent replay.
  select * into v_existing from public.refunds where idempotency_key = v_key;
  if found then
    return jsonb_build_object(
      'refund_id', v_existing.id,
      'status', v_existing.status,
      'amount', v_existing.amount,
      'replayed', true
    );
  end if;

  if v_order.payment_status not in ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUND_PENDING') then
    perform app.fail(
      'REFUND_NOT_ALLOWED',
      'This order has no captured payment to refund.',
      jsonb_build_object('payment_status', v_order.payment_status)
    );
  end if;

  v_refundable := app.refundable_amount(p_order_id);

  if v_refundable <= 0 then
    perform app.fail(
      'REFUND_NOT_ALLOWED',
      'This order has already been fully refunded or has a refund in progress.',
      jsonb_build_object('refunded_amount', v_order.refunded_amount)
    );
  end if;

  -- ── Determine the amount ──
  if p_kind = 'FULL_REFUND' then
    v_amount := v_refundable;

  elsif p_kind = 'ITEM_REFUND' then
    if coalesce(jsonb_array_length(p_items), 0) = 0 then
      perform app.fail('REFUND_ITEMS_REQUIRED', 'Select the items to refund.');
    end if;

    for v_item in select * from jsonb_array_elements(p_items) loop
      select * into v_order_item
      from public.order_items
      where id = (v_item ->> 'order_item_id')::uuid and order_id = p_order_id;

      if not found then
        perform app.fail('ORDER_ITEM_NOT_FOUND', 'One of the selected items is not on this order.');
      end if;

      if coalesce((v_item ->> 'quantity')::smallint, v_order_item.quantity)
         > v_order_item.quantity - v_order_item.refunded_quantity then
        perform app.fail(
          'REFUND_QUANTITY_EXCEEDED',
          format('You can refund at most %s × %s.',
                 v_order_item.quantity - v_order_item.refunded_quantity,
                 v_order_item.product_name)
        );
      end if;

      v_item_total := v_item_total + app.money_round(
        v_order_item.net_amount / greatest(v_order_item.quantity, 1)
        * coalesce((v_item ->> 'quantity')::smallint, v_order_item.quantity)
      );
    end loop;

    v_amount := v_item_total;

  else -- PARTIAL_REFUND
    if p_amount is null or p_amount <= 0 then
      perform app.fail('REFUND_AMOUNT_REQUIRED', 'Enter the refund amount.');
    end if;
    v_amount := app.money_round(p_amount);
  end if;

  if v_amount <= 0 then
    perform app.fail('INVALID_REFUND_AMOUNT', 'The refund amount must be greater than zero.');
  end if;

  if v_amount > v_refundable then
    perform app.fail(
      'REFUND_AMOUNT_EXCEEDS_REFUNDABLE',
      format('Only ₹%s can still be refunded on this order.', to_char(v_refundable, 'FM999999990.00')),
      jsonb_build_object('refundable_amount', v_refundable, 'requested', v_amount)
    );
  end if;

  -- ── Destination sanity ──
  select * into v_payment
  from public.payments
  where order_id = p_order_id and status in ('CAPTURED', 'PARTIALLY_REFUNDED')
  order by captured_at desc nulls last
  limit 1;

  if v_destination = 'ORIGINAL_PAYMENT_METHOD' then
    if v_order.payment_mode in ('COD', 'SPLIT_WALLET_COD') or v_payment.id is null then
      -- Cash cannot be returned through the gateway; use store credit instead.
      v_destination := 'WALLET_CREDIT';
    end if;
  end if;

  -- ── Approval routing ──
  v_role := app.primary_role();

  select * into v_policy from public.refund_policies
  where role_code = v_role and is_active;

  if app.has_permission('refund.approve', v_order.branch_id) then
    v_auto_approve := true;
  elsif found and v_amount <= v_policy.auto_approve_limit then
    v_auto_approve := true;
  end if;

  if found and v_policy.max_request_amount is not null and v_amount > v_policy.max_request_amount then
    perform app.fail(
      'REFUND_EXCEEDS_ROLE_LIMIT',
      format('Your role can request refunds up to ₹%s. Escalate this to a manager.',
             to_char(v_policy.max_request_amount, 'FM999999990.00')),
      jsonb_build_object('limit', v_policy.max_request_amount)
    );
  end if;

  -- Abuse guard on the customer account, not the agent.
  if not app.consume_rate_limit('refund_request', v_order.user_id::text, 10, 86400) then
    perform app.fail('RATE_LIMITED', 'This account has an unusual number of refund requests. Escalate manually.');
  end if;

  insert into public.refunds (
    order_id, payment_id, user_id, kind, destination, status, reason, reason_note,
    amount, requested_by, idempotency_key, support_ticket_id,
    approved_by, approved_at
  )
  values (
    p_order_id, v_payment.id, v_order.user_id, p_kind, v_destination,
    case when v_auto_approve then 'APPROVED'::public.refund_status
         else 'APPROVAL_PENDING'::public.refund_status end,
    p_reason, p_reason_note, v_amount, auth.uid(), v_key, p_support_ticket_id,
    case when v_auto_approve then auth.uid() else null end,
    case when v_auto_approve then now() else null end
  )
  returning * into v_refund;

  -- Item lines for exact invoicing and per-item refund history.
  if p_kind = 'ITEM_REFUND' then
    for v_item in select * from jsonb_array_elements(p_items) loop
      select * into v_order_item
      from public.order_items where id = (v_item ->> 'order_item_id')::uuid;

      insert into public.refund_items (refund_id, order_item_id, quantity, amount)
      values (
        v_refund.id,
        v_order_item.id,
        coalesce((v_item ->> 'quantity')::smallint, v_order_item.quantity),
        app.money_round(
          v_order_item.net_amount / greatest(v_order_item.quantity, 1)
          * coalesce((v_item ->> 'quantity')::smallint, v_order_item.quantity)
        )
      )
      on conflict (refund_id, order_item_id) do nothing;
    end loop;
  end if;

  -- Reflect the money-back lifecycle on the order.
  if v_order.status in ('DELIVERED', 'COMPLETED', 'CUSTOMER_CANCELLED', 'ADMIN_CANCELLED',
                        'STORE_REJECTED', 'DELIVERY_FAILED') then
    perform app.transition_order(
      p_order_id, 'REFUND_PENDING',
      format('Refund of ₹%s requested', to_char(v_amount, 'FM999999990.00')),
      'USER', auth.uid(), jsonb_build_object('refund_id', v_refund.id)
    );
  end if;

  perform app.audit(
    'REFUND_REQUEST', 'refund', v_refund.id::text, null,
    jsonb_build_object(
      'order_id', p_order_id, 'amount', v_amount, 'kind', p_kind,
      'reason', p_reason, 'destination', v_destination, 'auto_approved', v_auto_approve
    ),
    p_reason_note, v_order.order_number, v_order.branch_id
  );

  return jsonb_build_object(
    'refund_id', v_refund.id,
    'order_id', p_order_id,
    'status', v_refund.status,
    'amount', v_amount,
    'destination', v_destination,
    'auto_approved', v_auto_approve,
    -- The Edge Function reads this to decide whether to call Razorpay now.
    'requires_gateway_call', v_auto_approve and v_destination = 'ORIGINAL_PAYMENT_METHOD',
    'payment_id', v_payment.id,
    'provider_payment_id', v_payment.provider_payment_id,
    'replayed', false
  );
end;
$$;

comment on function public.request_refund is
  'Validated, idempotent refund request with policy-driven auto-approval.';

-- ─── Approval / rejection ──────────────────────────────────────────────────
create or replace function public.approve_refund(
  p_refund_id uuid,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_refund public.refunds;
  v_order public.orders;
  v_payment public.payments;
begin
  -- Coarse check first: an unauthorised caller must not learn whether a refund
  -- id exists. The branch-scoped check follows once we have the order.
  perform app.require_permission('refund.approve');

  select * into v_refund from public.refunds where id = p_refund_id for update;

  if not found then
    perform app.fail('REFUND_NOT_FOUND', 'Refund not found.');
  end if;

  select * into v_order from public.orders where id = v_refund.order_id;

  perform app.require_permission('refund.approve', v_order.branch_id);

  if v_refund.status not in ('REQUESTED', 'APPROVAL_PENDING') then
    return jsonb_build_object(
      'refund_id', p_refund_id, 'status', v_refund.status, 'changed', false
    );
  end if;

  -- Four-eyes: the requester cannot approve their own large refund.
  if v_refund.requested_by = auth.uid()
     and v_refund.amount > app.setting_numeric('refund.self_approval_limit', 500)
     and not app.has_role('OWNER') then
    perform app.fail(
      'SELF_APPROVAL_NOT_ALLOWED',
      'A refund of this size must be approved by someone other than the requester.'
    );
  end if;

  update public.refunds
  set status = 'APPROVED', approved_by = auth.uid(), approved_at = now(),
      reason_note = coalesce(reason_note || E'\n' || p_note, reason_note, p_note),
      updated_at = now()
  where id = p_refund_id
  returning * into v_refund;

  select * into v_payment from public.payments where id = v_refund.payment_id;

  perform app.audit(
    'REFUND_APPROVE', 'refund', p_refund_id::text,
    jsonb_build_object('status', 'APPROVAL_PENDING'),
    jsonb_build_object('status', 'APPROVED', 'amount', v_refund.amount),
    p_note, v_order.order_number, v_order.branch_id
  );

  return jsonb_build_object(
    'refund_id', p_refund_id,
    'status', 'APPROVED',
    'amount', v_refund.amount,
    'destination', v_refund.destination,
    'requires_gateway_call', v_refund.destination = 'ORIGINAL_PAYMENT_METHOD' and v_payment.id is not null,
    'payment_id', v_payment.id,
    'provider_payment_id', v_payment.provider_payment_id,
    'changed', true
  );
end;
$$;

create or replace function public.reject_refund(
  p_refund_id uuid,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_refund public.refunds;
  v_order public.orders;
begin
  perform app.require_permission('refund.reject');

  select * into v_refund from public.refunds where id = p_refund_id for update;

  if not found then
    perform app.fail('REFUND_NOT_FOUND', 'Refund not found.');
  end if;

  select * into v_order from public.orders where id = v_refund.order_id;

  perform app.require_permission('refund.reject', v_order.branch_id);

  if v_refund.status not in ('REQUESTED', 'APPROVAL_PENDING') then
    perform app.fail('REFUND_NOT_PENDING', 'This refund is no longer awaiting a decision.');
  end if;

  update public.refunds
  set status = 'REJECTED', rejected_by = auth.uid(), rejected_at = now(),
      rejection_note = p_note, updated_at = now()
  where id = p_refund_id;

  perform app.audit(
    'REFUND_REJECT', 'refund', p_refund_id::text,
    jsonb_build_object('status', v_refund.status),
    jsonb_build_object('status', 'REJECTED'),
    p_note, v_order.order_number, v_order.branch_id
  );

  return jsonb_build_object('refund_id', p_refund_id, 'status', 'REJECTED', 'changed', true);
end;
$$;

-- ─── Completion (wallet path is synchronous; gateway path awaits the webhook) ─
create or replace function app.complete_refund(
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
declare
  v_refund public.refunds;
  v_order public.orders;
  v_amount numeric;
begin
  select * into v_refund from public.refunds where id = p_refund_id for update;

  if not found then
    perform app.fail('REFUND_NOT_FOUND', 'Refund not found.');
  end if;

  if v_refund.status = 'COMPLETED' then
    return jsonb_build_object(
      'refund_id', p_refund_id, 'status', 'COMPLETED', 'changed', false,
      'amount_processed', v_refund.amount_processed
    );
  end if;

  select * into v_order from public.orders where id = v_refund.order_id;
  v_amount := coalesce(p_amount_processed, v_refund.amount);

  -- Store credit is settled straight into the wallet ledger.
  if v_refund.destination = 'WALLET_CREDIT' then
    perform app.post_wallet_entry(
      v_refund.user_id, 'REFUND', v_amount,
      format('Refund for order %s', v_order.order_number),
      v_refund.order_id, v_refund.id,
      'refund_wallet:' || v_refund.id::text
    );
  end if;

  update public.refunds
  set status = 'COMPLETED',
      amount_processed = v_amount,
      provider_refund_id = coalesce(p_provider_refund_id, provider_refund_id),
      provider_status = coalesce(p_provider_status, provider_status),
      processed_at = coalesce(processed_at, now()),
      completed_at = now(),
      updated_at = now()
  where id = p_refund_id;

  -- Trigger app.sync_order_refund_state() recomputes order + payment state.

  perform app.enqueue_notification(
    v_refund.user_id, 'REFUND_COMPLETED',
    jsonb_build_object(
      'order_number', v_order.order_number,
      'order_id', v_order.id::text,
      'refund_amount', to_char(v_amount, 'FM999999990.00'),
      'destination', case v_refund.destination
        when 'WALLET_CREDIT' then 'your Bites Box wallet'
        else 'your original payment method'
      end
    ),
    array['PUSH', 'IN_APP', 'SMS']::public.notification_channel[],
    v_refund.order_id,
    'refund_done:' || v_refund.id::text
  );

  perform app.audit(
    'UPDATE', 'refund', p_refund_id::text,
    jsonb_build_object('status', v_refund.status),
    jsonb_build_object('status', 'COMPLETED', 'amount_processed', v_amount),
    null, v_order.order_number, v_order.branch_id
  );

  return jsonb_build_object(
    'refund_id', p_refund_id,
    'status', 'COMPLETED',
    'amount_processed', v_amount,
    'changed', true
  );
end;
$$;

create or replace function app.fail_refund(
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
  update public.refunds
  set status = 'FAILED',
      failure_code = p_failure_code,
      failure_reason = p_failure_reason,
      failed_at = now(),
      updated_at = now()
  where id = p_refund_id and status <> 'COMPLETED';

  return jsonb_build_object('refund_id', p_refund_id, 'status', 'FAILED');
end;
$$;

-- ─── Customer-initiated refund request via support ─────────────────────────
-- Customers never call request_refund directly; they raise a ticket and support
-- decides. This keeps refund authority entirely inside the back office.
create or replace function public.request_order_help(
  p_order_id uuid,
  p_category public.ticket_category,
  p_description text,
  p_item_ids uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_ticket jsonb;
begin
  select * into v_order from public.orders
  where id = p_order_id and user_id = auth.uid();

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'We could not find that order on your account.');
  end if;

  v_ticket := public.create_support_ticket(
    p_category,
    format('%s — Order %s', replace(p_category::text, '_', ' '), v_order.order_number),
    p_description,
    p_order_id
  );

  if p_item_ids is not null and cardinality(p_item_ids) > 0 then
    update public.support_tickets
    set metadata = metadata || jsonb_build_object('reported_item_ids', to_jsonb(p_item_ids))
    where id = (v_ticket ->> 'ticket_id')::uuid;
  end if;

  return v_ticket;
end;
$$;

comment on function public.request_order_help is
  'Customer-facing entry point for order problems. Creates a ticket; support decides on refunds.';
