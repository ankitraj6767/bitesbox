-- A self-pickup handover is a completed delivery from the store's perspective.
-- Keep the original function name so the admin action gets the repaired behavior.
-- Confirm a customer-collected pickup order at the counter. For pay-at-store
-- orders this records the cash/manual payment before moving the order to the
-- picked-up state, so the customer and finance screens agree.
create or replace function public.confirm_pickup_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_now timestamptz := now();
  v_transition jsonb;
  v_payment_captured boolean := false;
begin
  perform app.require_permission('delivery.pickup');

  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'Order not found.');
  end if;

  perform app.require_permission('delivery.pickup', v_order.branch_id);

  if v_order.fulfilment_type <> 'PICKUP' then
    perform app.fail('NOT_A_PICKUP_ORDER', 'Only self-pickup orders can be collected at the counter.');
  end if;

  if v_order.status in ('DELIVERED', 'COMPLETED') then
    return jsonb_build_object(
      'order_id', v_order.id,
      'status', v_order.status,
      'payment_captured', v_order.payment_status = 'CAPTURED',
      'changed', false
    );
  end if;

  if v_order.status <> 'READY_FOR_PICKUP' then
    perform app.fail(
      'ORDER_NOT_READY',
      'This pickup order must be marked ready before the customer collects it.'
    );
  end if;

  if v_order.payment_mode = 'PAY_AT_STORE' and v_order.payment_status <> 'CAPTURED' then
    insert into public.payments (
      order_id, user_id, branch_id, gateway, mode, method, status,
      currency_code, amount, amount_captured, provider_reference_id,
      idempotency_key, captured_at, notes
    )
    values (
      v_order.id, v_order.user_id, v_order.branch_id, 'MANUAL', v_order.payment_mode,
      'CASH', 'CAPTURED', v_order.currency_code, v_order.payable_amount,
      v_order.payable_amount, 'pickup:' || v_order.id::text,
      'manual-pickup:' || v_order.id::text, v_now,
      jsonb_build_object('source', 'COUNTER_PICKUP', 'confirmed_by', auth.uid())
    )
    on conflict (idempotency_key) do update
      set status = 'CAPTURED',
          amount_captured = excluded.amount_captured,
          captured_at = coalesce(public.payments.captured_at, excluded.captured_at),
          updated_at = now();

    update public.orders
    set payment_status = 'CAPTURED',
        paid_at = coalesce(paid_at, v_now),
        updated_at = v_now
    where id = v_order.id;

    v_payment_captured := true;
  end if;

  perform app.require_permission('delivery.complete', v_order.branch_id);

  v_transition := app.transition_order(
    p_order_id,
    'DELIVERED',
    'Payment confirmed and customer collected pickup order',
    'USER'
  );

  return v_transition || jsonb_build_object(
    'payment_captured', v_payment_captured,
    'changed', true
  );
end;
$$;

grant execute on function public.confirm_pickup_order(uuid) to authenticated;
