-- The kitchen board is keyed by kitchen progress, not only the top-level order
-- status. A rider may be assigned or arrive while the kitchen is still working.
create or replace function public.kitchen_queue(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_late_seconds int;
begin
  perform app.require_permission('kitchen.view', v_branch);
  v_late_seconds := app.setting_int('kitchen.delay_threshold_seconds', 900);

  return jsonb_build_object(
    'branch', public.branch_ordering_state(v_branch),
    'orders', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', o.id,
          'order_number', o.order_number,
          'status', o.status,
          'fulfilment_type', o.fulfilment_type,
          'timing', o.timing,
          'scheduled_for', o.scheduled_for,
          'payment_mode', o.payment_mode,
          'payment_status', o.payment_status,
          'is_paid', o.payment_status = 'CAPTURED',
          'customer_note', o.customer_note,
          'item_count', o.item_count,
          'unit_count', o.unit_count,
          'grand_total', o.grand_total,
          'placed_at', o.placed_at,
          'accepted_at', o.accepted_at,
          'preparing_at', o.preparing_at,
          'ready_at', o.ready_at,
          'promised_at', o.promised_at,
          'prep_minutes_estimate', o.prep_minutes_estimate,
          -- Drives the large countdown timer on the kitchen tablet.
          'elapsed_seconds', extract(epoch from (now() - coalesce(o.placed_at, o.created_at)))::int,
          'is_delayed', o.promised_at is not null and o.promised_at < now(),
          'is_late_in_stage', extract(epoch from (now() - case
            when o.status in ('RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE') then
              case
                when o.ready_at is not null then o.ready_at
                when o.preparing_at is not null then o.preparing_at
                else coalesce(o.accepted_at, o.placed_at, o.created_at)
              end
            else o.status_changed_at
          end))::int > v_late_seconds,
          'is_first_order', o.is_first_order,
          'items', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', oi.id,
              'product_name', oi.product_name,
              'variant_name', oi.variant_name,
              'quantity', oi.quantity,
              'food_type', oi.food_type,
              'special_instructions', oi.special_instructions,
              'is_cancelled', oi.is_cancelled,
              'modifiers', coalesce((
                select jsonb_agg(jsonb_build_object(
                  'group_name', oim.group_name, 'modifier_name', oim.modifier_name,
                  'quantity', oim.quantity
                ) order by oim.group_name)
                from public.order_item_modifiers oim where oim.order_item_id = oi.id
              ), '[]'::jsonb)
            ) order by oi.display_order)
            from public.order_items oi where oi.order_id = o.id
          ), '[]'::jsonb),
          'rider', (
            select jsonb_build_object(
              'name', dp.full_name, 'phone', dp.phone,
              'assignment_status', da.status, 'arrived_store_at', da.arrived_store_at
            )
            from public.delivery_assignments da
            join public.delivery_partners dp on dp.id = da.delivery_partner_id
            where da.order_id = o.id
              and da.status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP')
            order by da.attempt_number desc limit 1
          )
        ) order by
          case
            when o.status = 'ORDER_PLACED' then 0
            when o.status = 'STORE_ACCEPTED' then 1
            when o.status = 'PREPARING' then 2
            when o.status = 'READY_FOR_PICKUP' then 3
            when o.status in ('RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE') and o.ready_at is not null then 3
            when o.status in ('RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE') then 2
            else 1
          end,
          coalesce(o.promised_at, o.created_at)
      )
      from public.orders o
      where o.branch_id = v_branch
        and o.status in (
          'ORDER_PLACED', 'STORE_ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP',
          'RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE'
        )
    ), '[]'::jsonb),
    'recently_completed', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id, 'order_number', o.order_number, 'status', o.status,
        'unit_count', o.unit_count, 'picked_up_at', o.picked_up_at,
        'delivered_at', o.delivered_at
      ) order by coalesce(o.delivered_at, o.picked_up_at, o.updated_at) desc)
      from public.orders o
      where o.branch_id = v_branch
        and o.status in ('PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED', 'COMPLETED')
        and o.updated_at > now() - interval '4 hours'
      limit 25
    ), '[]'::jsonb),
    'counts', (
      select jsonb_build_object(
        'new', count(*) filter (where status = 'ORDER_PLACED'),
        'accepted', count(*) filter (where status = 'STORE_ACCEPTED'),
        'preparing', count(*) filter (where status = 'PREPARING'
          or (status in ('RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE') and ready_at is null)),
        'ready', count(*) filter (where status = 'READY_FOR_PICKUP'
          or (status in ('RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE') and ready_at is not null)),
        'delayed', count(*) filter (where promised_at is not null and promised_at < now()
          and status in ('ORDER_PLACED', 'STORE_ACCEPTED', 'PREPARING', 'RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE')
          and ready_at is null)
      )
      from public.orders where branch_id = v_branch
        and status in (
          'ORDER_PLACED', 'STORE_ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP',
          'RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE'
        )
    ),
    'generated_at', now()
  );
end;
$$;

comment on function public.kitchen_queue is
  'Kitchen tablet payload: active kitchen stages remain visible while delivery is assigned or waiting at the store.';
