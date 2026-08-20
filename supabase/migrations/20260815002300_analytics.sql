-- ═══════════════════════════════════════════════════════════════════════════
-- 0023 · ANALYTICS & REPORTS
--
-- Every function checks analytics.view / report.view before returning data.
-- Aggregates are computed in Postgres so the dashboard ships numbers, not rows.
-- ═══════════════════════════════════════════════════════════════════════════

-- Revenue only counts orders the restaurant actually fulfilled, net of refunds.
create or replace function analytics.net_revenue_expr()
returns text
language sql
immutable
as $$
  select 'coalesce(sum(o.grand_total - o.refunded_amount), 0)';
$$;

-- ─── Overview KPIs ─────────────────────────────────────────────────────────
create or replace function public.dashboard_overview(
  p_branch_id uuid default null,
  p_from timestamptz default null,
  p_to timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_tz text;
  v_from timestamptz;
  v_to timestamptz;
  v_prev_from timestamptz;
  v_prev_to timestamptz;
  v_span interval;
  v_current jsonb;
  v_previous jsonb;
begin
  perform app.require_permission('analytics.view', v_branch);

  select timezone into v_tz from public.branches where id = v_branch;
  v_tz := coalesce(v_tz, 'Asia/Kolkata');

  -- Default window: today in the branch's own timezone.
  v_from := coalesce(p_from, date_trunc('day', now() at time zone v_tz) at time zone v_tz);
  v_to := coalesce(p_to, now());
  v_span := v_to - v_from;
  v_prev_from := v_from - v_span;
  v_prev_to := v_from;

  select jsonb_build_object(
    'orders', count(*),
    'delivered_orders', count(*) filter (where o.status in ('DELIVERED', 'COMPLETED')),
    'cancelled_orders', count(*) filter (where app.is_cancelled_status(o.status)),
    'active_orders', count(*) filter (where app.is_active_status(o.status)),
    'gross_sales', coalesce(sum(o.grand_total) filter (where o.status in ('DELIVERED', 'COMPLETED')), 0),
    'net_sales', coalesce(sum(o.grand_total - o.refunded_amount)
                          filter (where o.status in ('DELIVERED', 'COMPLETED')), 0),
    'refunds', coalesce(sum(o.refunded_amount), 0),
    'discounts', coalesce(sum(o.total_discount), 0),
    'tax_collected', coalesce(sum(o.tax_amount) filter (where o.status in ('DELIVERED', 'COMPLETED')), 0),
    'delivery_fees', coalesce(sum(o.delivery_fee) filter (where o.status in ('DELIVERED', 'COMPLETED')), 0),
    'packaging_charges', coalesce(sum(o.packaging_charge) filter (where o.status in ('DELIVERED', 'COMPLETED')), 0),
    'tips', coalesce(sum(o.tip_amount) filter (where o.status in ('DELIVERED', 'COMPLETED')), 0),
    'average_order_value', case
      when count(*) filter (where o.status in ('DELIVERED', 'COMPLETED')) > 0
      then round(coalesce(sum(o.grand_total) filter (where o.status in ('DELIVERED', 'COMPLETED')), 0)
                 / count(*) filter (where o.status in ('DELIVERED', 'COMPLETED')), 2)
      else 0
    end,
    'units_sold', coalesce(sum(o.unit_count) filter (where o.status in ('DELIVERED', 'COMPLETED')), 0),
    'new_customers', count(distinct o.user_id) filter (where o.is_first_order),
    'returning_customers', count(distinct o.user_id) filter (where not o.is_first_order),
    'payment_failures', count(*) filter (where o.payment_status = 'FAILED'),
    'cod_orders', count(*) filter (where o.payment_mode in ('COD', 'SPLIT_WALLET_COD')),
    'online_orders', count(*) filter (where o.payment_mode = 'ONLINE'),
    'pickup_orders', count(*) filter (where o.fulfilment_type = 'PICKUP'),
    'scheduled_orders', count(*) filter (where o.timing = 'SCHEDULED'),
    'avg_prep_minutes', round(coalesce(avg(
      extract(epoch from (o.ready_at - o.accepted_at)) / 60
    ) filter (where o.ready_at is not null and o.accepted_at is not null), 0), 1),
    'avg_delivery_minutes', round(coalesce(avg(
      extract(epoch from (o.delivered_at - o.picked_up_at)) / 60
    ) filter (where o.delivered_at is not null and o.picked_up_at is not null), 0), 1),
    'avg_total_minutes', round(coalesce(avg(
      extract(epoch from (o.delivered_at - o.placed_at)) / 60
    ) filter (where o.delivered_at is not null and o.placed_at is not null), 0), 1),
    'on_time_rate', case
      when count(*) filter (where o.delivered_at is not null and o.promised_at is not null) > 0
      then round(
        count(*) filter (where o.delivered_at <= o.promised_at)::numeric
        / count(*) filter (where o.delivered_at is not null and o.promised_at is not null) * 100, 1)
      else null
    end,
    'cancellation_rate', case
      when count(*) > 0
      then round(count(*) filter (where app.is_cancelled_status(o.status))::numeric / count(*) * 100, 1)
      else 0
    end,
    'refund_rate', case
      when count(*) > 0
      then round(count(*) filter (where o.refunded_amount > 0)::numeric / count(*) * 100, 1)
      else 0
    end
  )
  into v_current
  from public.orders o
  where o.branch_id = v_branch
    and o.created_at >= v_from
    and o.created_at <= v_to
    and o.status <> 'PENDING_PAYMENT';

  select jsonb_build_object(
    'orders', count(*),
    'net_sales', coalesce(sum(o.grand_total - o.refunded_amount)
                          filter (where o.status in ('DELIVERED', 'COMPLETED')), 0),
    'average_order_value', case
      when count(*) filter (where o.status in ('DELIVERED', 'COMPLETED')) > 0
      then round(coalesce(sum(o.grand_total) filter (where o.status in ('DELIVERED', 'COMPLETED')), 0)
                 / count(*) filter (where o.status in ('DELIVERED', 'COMPLETED')), 2)
      else 0
    end,
    'new_customers', count(distinct o.user_id) filter (where o.is_first_order)
  )
  into v_previous
  from public.orders o
  where o.branch_id = v_branch
    and o.created_at >= v_prev_from
    and o.created_at < v_prev_to
    and o.status <> 'PENDING_PAYMENT';

  return jsonb_build_object(
    'range', jsonb_build_object('from', v_from, 'to', v_to, 'timezone', v_tz),
    'current', v_current,
    'previous', v_previous,
    -- Period-over-period deltas so the dashboard can render trend chips.
    'deltas', jsonb_build_object(
      'orders', case when (v_previous ->> 'orders')::numeric > 0
        then round(((v_current ->> 'orders')::numeric - (v_previous ->> 'orders')::numeric)
                   / (v_previous ->> 'orders')::numeric * 100, 1) else null end,
      'net_sales', case when (v_previous ->> 'net_sales')::numeric > 0
        then round(((v_current ->> 'net_sales')::numeric - (v_previous ->> 'net_sales')::numeric)
                   / (v_previous ->> 'net_sales')::numeric * 100, 1) else null end,
      'average_order_value', case when (v_previous ->> 'average_order_value')::numeric > 0
        then round(((v_current ->> 'average_order_value')::numeric - (v_previous ->> 'average_order_value')::numeric)
                   / (v_previous ->> 'average_order_value')::numeric * 100, 1) else null end
    ),
    'live', jsonb_build_object(
      'preparing', (select count(*) from public.orders
                    where branch_id = v_branch and status in ('STORE_ACCEPTED', 'PREPARING')),
      'ready', (select count(*) from public.orders
                where branch_id = v_branch and status = 'READY_FOR_PICKUP'),
      'out_for_delivery', (select count(*) from public.orders
                           where branch_id = v_branch
                             and status in ('RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE', 'PICKED_UP',
                                            'OUT_FOR_DELIVERY', 'RIDER_ARRIVED_CUSTOMER')),
      'online_riders', (select count(*) from public.delivery_partners
                        where branch_id = v_branch and onboarding_status = 'ACTIVE'
                          and duty_state in ('AVAILABLE', 'BUSY')),
      'available_riders', (select count(*) from public.delivery_partners
                           where branch_id = v_branch and onboarding_status = 'ACTIVE'
                             and duty_state = 'AVAILABLE'),
      'out_of_stock_items', (select count(*) from public.product_availability pa
                             join public.products p on p.id = pa.product_id
                             where pa.branch_id = v_branch and pa.state <> 'AVAILABLE'
                               and p.is_active and p.deleted_at is null),
      'open_tickets', (select count(*) from public.support_tickets
                       where branch_id = v_branch and status in ('OPEN', 'IN_PROGRESS', 'ESCALATED')),
      'pending_refunds', (select count(*) from public.refunds r
                          join public.orders o on o.id = r.order_id
                          where o.branch_id = v_branch
                            and r.status in ('REQUESTED', 'APPROVAL_PENDING'))
    )
  );
end;
$$;

comment on function public.dashboard_overview is
  'Admin overview KPIs with period-over-period deltas and live operational counters.';

-- ─── Charts ────────────────────────────────────────────────────────────────
create or replace function public.dashboard_charts(
  p_branch_id uuid default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_granularity text default 'day'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_tz text;
  v_from timestamptz;
  v_to timestamptz;
  v_trunc text;
begin
  perform app.require_permission('analytics.view', v_branch);

  select timezone into v_tz from public.branches where id = v_branch;
  v_tz := coalesce(v_tz, 'Asia/Kolkata');
  v_from := coalesce(p_from, now() - interval '30 days');
  v_to := coalesce(p_to, now());
  v_trunc := case when p_granularity in ('hour', 'day', 'week', 'month') then p_granularity else 'day' end;

  return jsonb_build_object(
    'revenue_trend', coalesce((
      select jsonb_agg(jsonb_build_object(
        'bucket', b.bucket,
        'orders', coalesce(d.orders, 0),
        'gross_sales', coalesce(d.gross_sales, 0),
        'net_sales', coalesce(d.net_sales, 0),
        'average_order_value', coalesce(d.aov, 0)
      ) order by b.bucket)
      from generate_series(
        date_trunc(v_trunc, v_from at time zone v_tz),
        date_trunc(v_trunc, v_to at time zone v_tz),
        ('1 ' || v_trunc)::interval
      ) b(bucket)
      left join (
        select
          date_trunc(v_trunc, o.created_at at time zone v_tz) as bucket,
          count(*) as orders,
          coalesce(sum(o.grand_total), 0) as gross_sales,
          coalesce(sum(o.grand_total - o.refunded_amount), 0) as net_sales,
          round(coalesce(avg(o.grand_total), 0), 2) as aov
        from public.orders o
        where o.branch_id = v_branch
          and o.created_at between v_from and v_to
          and o.status in ('DELIVERED', 'COMPLETED', 'PARTIALLY_REFUNDED')
        group by 1
      ) d on d.bucket = b.bucket
    ), '[]'::jsonb),

    'orders_by_hour', coalesce((
      select jsonb_agg(jsonb_build_object('hour', h.hour, 'orders', coalesce(d.orders, 0),
                                          'revenue', coalesce(d.revenue, 0)) order by h.hour)
      from generate_series(0, 23) h(hour)
      left join (
        select extract(hour from o.created_at at time zone v_tz)::int as hour,
               count(*) as orders,
               coalesce(sum(o.grand_total), 0) as revenue
        from public.orders o
        where o.branch_id = v_branch
          and o.created_at between v_from and v_to
          and o.status <> 'PENDING_PAYMENT'
        group by 1
      ) d on d.hour = h.hour
    ), '[]'::jsonb),

    'order_status_breakdown', coalesce((
      select jsonb_agg(jsonb_build_object('status', status, 'count', cnt) order by cnt desc)
      from (
        select o.status::text as status, count(*) as cnt
        from public.orders o
        where o.branch_id = v_branch and o.created_at between v_from and v_to
        group by o.status
      ) s
    ), '[]'::jsonb),

    'payment_methods', coalesce((
      select jsonb_agg(jsonb_build_object(
        'method', method, 'count', cnt, 'revenue', revenue
      ) order by cnt desc)
      from (
        select
          coalesce(
            (select p.method::text from public.payments p
             where p.order_id = o.id and p.status in ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED')
             order by p.captured_at desc nulls last limit 1),
            case when o.payment_mode in ('COD', 'SPLIT_WALLET_COD') then 'CASH' else 'OTHER' end
          ) as method,
          count(*) as cnt,
          coalesce(sum(o.grand_total), 0) as revenue
        from public.orders o
        where o.branch_id = v_branch
          and o.created_at between v_from and v_to
          and o.status in ('DELIVERED', 'COMPLETED')
        group by 1
      ) m
    ), '[]'::jsonb),

    'top_products', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_id', product_id, 'product_name', product_name,
        'units', units, 'revenue', revenue, 'orders', orders
      ) order by units desc)
      from (
        select oi.product_id, oi.product_name,
               sum(oi.quantity)::int as units,
               coalesce(sum(oi.net_amount), 0) as revenue,
               count(distinct oi.order_id) as orders
        from public.order_items oi
        join public.orders o on o.id = oi.order_id
        where o.branch_id = v_branch
          and o.created_at between v_from and v_to
          and o.status in ('DELIVERED', 'COMPLETED')
          and not oi.is_cancelled
        group by oi.product_id, oi.product_name
        order by units desc
        limit 15
      ) t
    ), '[]'::jsonb),

    'top_categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'category_id', category_id, 'category_name', category_name,
        'units', units, 'revenue', revenue
      ) order by revenue desc)
      from (
        select oi.category_id, oi.category_name,
               sum(oi.quantity)::int as units,
               coalesce(sum(oi.net_amount), 0) as revenue
        from public.order_items oi
        join public.orders o on o.id = oi.order_id
        where o.branch_id = v_branch
          and o.created_at between v_from and v_to
          and o.status in ('DELIVERED', 'COMPLETED')
          and not oi.is_cancelled
        group by oi.category_id, oi.category_name
        order by revenue desc
        limit 10
      ) t
    ), '[]'::jsonb),

    'customer_mix', (
      select jsonb_build_object(
        'new', count(distinct o.user_id) filter (where o.is_first_order),
        'returning', count(distinct o.user_id) filter (where not o.is_first_order)
      )
      from public.orders o
      where o.branch_id = v_branch
        and o.created_at between v_from and v_to
        and o.status in ('DELIVERED', 'COMPLETED')
    ),

    'cancellation_reasons', coalesce((
      select jsonb_agg(jsonb_build_object('reason', reason, 'count', cnt) order by cnt desc)
      from (
        select coalesce(o.cancellation_reason::text, 'UNKNOWN') as reason, count(*) as cnt
        from public.orders o
        where o.branch_id = v_branch
          and o.created_at between v_from and v_to
          and app.is_cancelled_status(o.status)
        group by 1
      ) c
    ), '[]'::jsonb),

    'coupon_usage', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', code, 'uses', uses, 'discount_given', discount, 'revenue_influenced', revenue
      ) order by uses desc)
      from (
        select cr.code, count(*) as uses,
               coalesce(sum(cr.discount_amount), 0) as discount,
               coalesce(sum(cr.order_amount), 0) as revenue
        from public.coupon_redemptions cr
        join public.orders o on o.id = cr.order_id
        where o.branch_id = v_branch and cr.created_at between v_from and v_to
        group by cr.code
        order by uses desc
        limit 15
      ) c
    ), '[]'::jsonb),

    'delivery_performance', coalesce((
      select jsonb_agg(jsonb_build_object(
        'delivery_partner_id', delivery_partner_id, 'name', full_name,
        'deliveries', deliveries, 'avg_minutes', avg_minutes,
        'on_time_rate', on_time_rate, 'rating', rating
      ) order by deliveries desc)
      from (
        select dp.id as delivery_partner_id, dp.full_name,
               count(*) as deliveries,
               round(coalesce(avg(da.delivery_duration_seconds) / 60.0, 0), 1) as avg_minutes,
               round(
                 count(*) filter (where o.delivered_at <= o.promised_at)::numeric
                 / greatest(count(*) filter (where o.promised_at is not null), 1) * 100, 1
               ) as on_time_rate,
               dp.rating_average as rating
        from public.delivery_assignments da
        join public.delivery_partners dp on dp.id = da.delivery_partner_id
        join public.orders o on o.id = da.order_id
        where da.branch_id = v_branch
          and da.status = 'COMPLETED'
          and da.completed_at between v_from and v_to
        group by dp.id, dp.full_name, dp.rating_average
        order by deliveries desc
        limit 15
      ) d
    ), '[]'::jsonb),

    'zero_result_searches', coalesce((
      select jsonb_agg(jsonb_build_object('query', query, 'count', cnt) order by cnt desc)
      from (
        select sq.query, count(*) as cnt
        from public.search_queries sq
        where sq.created_at between v_from and v_to and sq.result_count = 0
        group by sq.query
        order by cnt desc
        limit 20
      ) s
    ), '[]'::jsonb)
  );
end;
$$;

comment on function public.dashboard_charts is
  'All admin dashboard charts in one call, bucketed in the branch timezone.';

-- ─── Report: sales register (per-order, exportable) ────────────────────────
create or replace function public.report_sales(
  p_branch_id uuid default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_limit int default 500,
  p_offset int default 0
)
returns table (
  order_id uuid,
  order_number text,
  placed_at timestamptz,
  status public.order_status,
  fulfilment_type public.fulfilment_type,
  customer_name text,
  customer_phone text,
  item_count int,
  unit_count int,
  items_subtotal numeric,
  total_discount numeric,
  coupon_code text,
  taxable_amount numeric,
  cgst_amount numeric,
  sgst_amount numeric,
  tax_amount numeric,
  packaging_charge numeric,
  delivery_fee numeric,
  tip_amount numeric,
  grand_total numeric,
  refunded_amount numeric,
  net_amount numeric,
  payment_mode public.payment_mode,
  payment_method public.payment_method,
  zone_name text,
  rider_name text,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  perform app.require_permission('report.view', v_branch);

  return query
  with filtered as (
    select o.*
    from public.orders o
    where o.branch_id = v_branch
      and (p_from is null or o.created_at >= p_from)
      and (p_to is null or o.created_at <= p_to)
      and o.status <> 'PENDING_PAYMENT'
  )
  select
    f.id, f.order_number, coalesce(f.placed_at, f.created_at), f.status, f.fulfilment_type,
    f.customer_name, f.customer_phone::text,
    f.item_count, f.unit_count,
    f.items_subtotal::numeric, f.total_discount::numeric, f.coupon_code,
    f.taxable_amount::numeric, f.cgst_amount::numeric, f.sgst_amount::numeric, f.tax_amount::numeric,
    f.packaging_charge::numeric, f.delivery_fee::numeric, f.tip_amount::numeric,
    f.grand_total::numeric, f.refunded_amount::numeric,
    (f.grand_total - f.refunded_amount)::numeric,
    f.payment_mode,
    (select p.method from public.payments p
     where p.order_id = f.id and p.status in ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED')
     order by p.captured_at desc nulls last limit 1),
    f.delivery_zone_name,
    (select dp.full_name from public.delivery_assignments da
     join public.delivery_partners dp on dp.id = da.delivery_partner_id
     where da.order_id = f.id and da.status = 'COMPLETED' limit 1),
    count(*) over () as total_count
  from filtered f
  order by coalesce(f.placed_at, f.created_at) desc
  limit least(coalesce(p_limit, 500), 5000)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

-- ─── Report: GST summary ───────────────────────────────────────────────────
create or replace function public.report_tax_summary(
  p_branch_id uuid default null,
  p_from timestamptz default null,
  p_to timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  perform app.require_permission('finance.view', v_branch);

  return jsonb_build_object(
    'totals', (
      select jsonb_build_object(
        'orders', count(*),
        'taxable_amount', coalesce(sum(o.taxable_amount), 0),
        'cgst', coalesce(sum(o.cgst_amount), 0),
        'sgst', coalesce(sum(o.sgst_amount), 0),
        'igst', coalesce(sum(o.igst_amount), 0),
        'cess', coalesce(sum(o.cess_amount), 0),
        'total_tax', coalesce(sum(o.tax_amount), 0),
        'gross_sales', coalesce(sum(o.grand_total), 0),
        'refunds', coalesce(sum(o.refunded_amount), 0)
      )
      from public.orders o
      where o.branch_id = v_branch
        and o.status in ('DELIVERED', 'COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED')
        and (p_from is null or o.created_at >= p_from)
        and (p_to is null or o.created_at <= p_to)
    ),
    'by_rate', coalesce((
      select jsonb_agg(jsonb_build_object(
        'tax_rate', tax_rate, 'hsn_sac_code', hsn_sac_code,
        'taxable_amount', taxable, 'cgst', cgst, 'sgst', sgst, 'total_tax', total_tax
      ) order by tax_rate)
      from (
        select oi.tax_rate::numeric as tax_rate, oi.hsn_sac_code,
               coalesce(sum(oi.taxable_amount), 0) as taxable,
               coalesce(sum(oi.cgst_amount), 0) as cgst,
               coalesce(sum(oi.sgst_amount), 0) as sgst,
               coalesce(sum(oi.tax_amount), 0) as total_tax
        from public.order_items oi
        join public.orders o on o.id = oi.order_id
        where o.branch_id = v_branch
          and o.status in ('DELIVERED', 'COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED')
          and not oi.is_cancelled
          and (p_from is null or o.created_at >= p_from)
          and (p_to is null or o.created_at <= p_to)
        group by oi.tax_rate, oi.hsn_sac_code
      ) r
    ), '[]'::jsonb),
    'branch', (
      select jsonb_build_object('name', b.name, 'gstin', b.gstin, 'address',
        concat_ws(', ', b.address_line1, b.city, b.state, b.postal_code))
      from public.branches b where b.id = v_branch
    )
  );
end;
$$;

-- ─── Report: payments & settlement ─────────────────────────────────────────
create or replace function public.report_payments(
  p_branch_id uuid default null,
  p_from timestamptz default null,
  p_to timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  perform app.require_permission('payment.view', v_branch);

  return jsonb_build_object(
    'summary', (
      select jsonb_build_object(
        'attempts', count(*),
        'captured', count(*) filter (where p.status in ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED')),
        'failed', count(*) filter (where p.status = 'FAILED'),
        'pending', count(*) filter (where p.status in ('CREATED', 'PENDING', 'AUTHORIZED')),
        'unreconciled', count(*) filter (where p.status = 'CAPTURED' and p.reconciled_at is null),
        'amount_captured', coalesce(sum(p.amount_captured), 0),
        'amount_refunded', coalesce(sum(p.amount_refunded), 0),
        'gateway_fees', coalesce(sum(p.gateway_fee + p.gateway_tax), 0),
        'net_settlement', coalesce(sum(p.amount_captured - p.amount_refunded - p.gateway_fee - p.gateway_tax), 0),
        'failure_rate', case when count(*) > 0
          then round(count(*) filter (where p.status = 'FAILED')::numeric / count(*) * 100, 1)
          else 0 end
      )
      from public.payments p
      where p.branch_id = v_branch
        and (p_from is null or p.created_at >= p_from)
        and (p_to is null or p.created_at <= p_to)
    ),
    'cod', (
      select jsonb_build_object(
        'orders', count(*),
        'expected', coalesce(sum(cc.expected_amount), 0),
        'collected', coalesce(sum(cc.collected_amount), 0),
        'pending', coalesce(sum(cc.expected_amount) filter (where cc.status = 'COD_PENDING'), 0),
        'unsettled', coalesce(sum(cc.collected_amount)
                              filter (where cc.status = 'COD_COLLECTED' and cc.settled_at is null), 0),
        'discrepancies', coalesce(sum(cc.discrepancy_amount), 0)
      )
      from public.cod_collections cc
      join public.orders o on o.id = cc.order_id
      where o.branch_id = v_branch
        and (p_from is null or cc.created_at >= p_from)
        and (p_to is null or cc.created_at <= p_to)
    ),
    'failure_reasons', coalesce((
      select jsonb_agg(jsonb_build_object('code', failure_code, 'count', cnt) order by cnt desc)
      from (
        select coalesce(p.failure_code, 'UNKNOWN') as failure_code, count(*) as cnt
        from public.payments p
        where p.branch_id = v_branch and p.status = 'FAILED'
          and (p_from is null or p.created_at >= p_from)
          and (p_to is null or p.created_at <= p_to)
        group by 1 order by cnt desc limit 15
      ) f
    ), '[]'::jsonb),
    'refunds', (
      select jsonb_build_object(
        'count', count(*),
        'requested', coalesce(sum(r.amount), 0),
        'completed', coalesce(sum(r.amount_processed) filter (where r.status = 'COMPLETED'), 0),
        'pending_approval', count(*) filter (where r.status in ('REQUESTED', 'APPROVAL_PENDING')),
        'processing', count(*) filter (where r.status in ('APPROVED', 'PROCESSING')),
        'failed', count(*) filter (where r.status = 'FAILED'),
        'by_reason', coalesce((
          select jsonb_agg(jsonb_build_object('reason', reason, 'count', cnt, 'amount', amt) order by amt desc)
          from (
            select r2.reason::text as reason, count(*) as cnt, coalesce(sum(r2.amount), 0) as amt
            from public.refunds r2
            join public.orders o2 on o2.id = r2.order_id
            where o2.branch_id = v_branch
              and (p_from is null or r2.created_at >= p_from)
              and (p_to is null or r2.created_at <= p_to)
            group by 1
          ) rr
        ), '[]'::jsonb)
      )
      from public.refunds r
      join public.orders o on o.id = r.order_id
      where o.branch_id = v_branch
        and (p_from is null or r.created_at >= p_from)
        and (p_to is null or r.created_at <= p_to)
    )
  );
end;
$$;

-- ─── Report: product performance ───────────────────────────────────────────
create or replace function public.report_products(
  p_branch_id uuid default null,
  p_from timestamptz default null,
  p_to timestamptz default null
)
returns table (
  product_id uuid,
  product_name text,
  category_name text,
  units_sold int,
  orders_count bigint,
  gross_revenue numeric,
  discount_given numeric,
  net_revenue numeric,
  refunded_units int,
  average_rating numeric,
  is_available boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  perform app.require_permission('report.view', v_branch);

  return query
  select
    p.id,
    p.name,
    c.name,
    coalesce(sum(oi.quantity) filter (where not oi.is_cancelled), 0)::int,
    count(distinct oi.order_id),
    coalesce(sum(oi.gross_amount) filter (where not oi.is_cancelled), 0)::numeric,
    coalesce(sum(oi.allocated_discount) filter (where not oi.is_cancelled), 0)::numeric,
    coalesce(sum(oi.net_amount) filter (where not oi.is_cancelled), 0)::numeric,
    coalesce(sum(oi.refunded_quantity), 0)::int,
    p.rating_average::numeric,
    app.product_orderable(p.id, v_branch)
  from public.products p
  join public.categories c on c.id = p.category_id
  left join public.order_items oi on oi.product_id = p.id
  left join public.orders o on o.id = oi.order_id
    and o.branch_id = v_branch
    and o.status in ('DELIVERED', 'COMPLETED', 'PARTIALLY_REFUNDED')
    and (p_from is null or o.created_at >= p_from)
    and (p_to is null or o.created_at <= p_to)
  where p.deleted_at is null
  group by p.id, p.name, c.name, p.rating_average
  order by 4 desc, p.name;
end;
$$;

-- ─── Report: customer cohort / retention ───────────────────────────────────
create or replace function public.report_customers(
  p_branch_id uuid default null,
  p_from timestamptz default null,
  p_to timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_high_value numeric := app.setting_numeric('segment.high_value_ltv', 5000);
  v_inactive_days int := app.setting_int('segment.inactive_days', 30);
begin
  perform app.require_permission('report.view', v_branch);

  return jsonb_build_object(
    'segments', jsonb_build_object(
      'total', (select count(*) from public.profiles where deleted_at is null),
      'ordered_at_least_once', (select count(*) from public.profiles where completed_orders > 0),
      'repeat_customers', (select count(*) from public.profiles where completed_orders > 1),
      'high_value', (select count(*) from public.profiles where lifetime_value >= v_high_value),
      'inactive', (select count(*) from public.profiles
                   where completed_orders > 0
                     and (last_order_at is null
                          or last_order_at < now() - make_interval(days => v_inactive_days))),
      'blocked', (select count(*) from public.profiles where status = 'BLOCKED')
    ),
    'repeat_rate', (
      select case when count(*) filter (where completed_orders > 0) > 0
        then round(count(*) filter (where completed_orders > 1)::numeric
                   / count(*) filter (where completed_orders > 0) * 100, 1)
        else 0 end
      from public.profiles
    ),
    'signups_trend', coalesce((
      select jsonb_agg(jsonb_build_object('date', d.day, 'signups', coalesce(s.cnt, 0)) order by d.day)
      from generate_series(
        coalesce(p_from, now() - interval '30 days')::date,
        coalesce(p_to, now())::date,
        interval '1 day'
      ) d(day)
      left join (
        select created_at::date as day, count(*) as cnt
        from public.profiles
        where created_at between coalesce(p_from, now() - interval '30 days') and coalesce(p_to, now())
        group by 1
      ) s on s.day = d.day::date
    ), '[]'::jsonb),
    'top_customers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', id, 'name', full_name, 'phone', phone,
        'orders', completed_orders, 'lifetime_value', lifetime_value,
        'average_order_value', average_order_value, 'last_order_at', last_order_at
      ) order by lifetime_value desc)
      from (
        select id, full_name, phone, completed_orders, lifetime_value,
               average_order_value, last_order_at
        from public.profiles
        where completed_orders > 0
        order by lifetime_value desc
        limit 25
      ) t
    ), '[]'::jsonb),
    'abandoned_carts', (
      select jsonb_build_object(
        'count', count(*),
        'value', coalesce(sum((c.last_totals #>> '{totals,grand_total}')::numeric), 0)
      )
      from public.carts c
      where c.is_active
        and c.converted_order_id is null
        and c.updated_at < now() - interval '1 hour'
        and exists (select 1 from public.cart_items ci where ci.cart_id = c.id)
    )
  );
end;
$$;

grant execute on function public.dashboard_overview(uuid, timestamptz, timestamptz) to authenticated;
grant execute on function public.dashboard_charts(uuid, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.report_sales(uuid, timestamptz, timestamptz, int, int) to authenticated;
grant execute on function public.report_tax_summary(uuid, timestamptz, timestamptz) to authenticated;
grant execute on function public.report_payments(uuid, timestamptz, timestamptz) to authenticated;
grant execute on function public.report_products(uuid, timestamptz, timestamptz) to authenticated;
grant execute on function public.report_customers(uuid, timestamptz, timestamptz) to authenticated;

-- ─── Invoice payload (rendered to PDF by the admin app / Edge Function) ─────
create or replace function public.order_invoice(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_branch public.branches;
begin
  select * into v_order from public.orders where id = p_order_id;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'Order not found.');
  end if;

  if v_order.user_id <> auth.uid() and not app.has_permission('order.view', v_order.branch_id) then
    perform app.fail('PERMISSION_DENIED', 'You cannot view this invoice.');
  end if;

  if v_order.status not in ('DELIVERED', 'COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED') then
    perform app.fail('INVOICE_NOT_AVAILABLE', 'The invoice is available once the order is delivered.');
  end if;

  select * into v_branch from public.branches where id = v_order.branch_id;

  return jsonb_build_object(
    'invoice_number', 'INV-' || v_order.order_number,
    'order_number', v_order.order_number,
    'invoice_date', coalesce(v_order.delivered_at, v_order.created_at),
    'restaurant', jsonb_build_object(
      'name', v_branch.name,
      'legal_name', coalesce(v_branch.legal_name, v_branch.name),
      'address', concat_ws(', ', v_branch.address_line1, v_branch.address_line2,
                           v_branch.city, v_branch.state, v_branch.postal_code),
      'phone', v_branch.phone,
      'email', v_branch.email,
      'gstin', v_branch.gstin,
      'fssai', v_branch.fssai_licence_no
    ),
    'customer', jsonb_build_object(
      'name', v_order.customer_name,
      'phone', v_order.customer_phone,
      'address', case when v_order.fulfilment_type = 'DELIVERY'
        then concat_ws(', ', v_order.delivery_address_line1, v_order.delivery_address_line2,
                       v_order.delivery_landmark, v_order.delivery_area,
                       v_order.delivery_city, v_order.delivery_postal_code)
        else 'Self pickup' end
    ),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', oi.product_name || coalesce(' (' || oi.variant_name || ')', ''),
        'hsn_sac_code', oi.hsn_sac_code,
        'quantity', oi.quantity,
        'unit_price', oi.unit_price,
        'modifiers', coalesce((
          select jsonb_agg(oim.modifier_name || case when oim.unit_price > 0
            then ' (+₹' || to_char(oim.total_price, 'FM999990.00') || ')' else '' end)
          from public.order_item_modifiers oim where oim.order_item_id = oi.id
        ), '[]'::jsonb),
        'gross_amount', oi.gross_amount,
        'discount', oi.allocated_discount,
        'taxable_amount', oi.taxable_amount,
        'tax_rate', oi.tax_rate,
        'cgst', oi.cgst_amount,
        'sgst', oi.sgst_amount,
        'tax_amount', oi.tax_amount,
        'net_amount', oi.net_amount,
        'is_cancelled', oi.is_cancelled
      ) order by oi.display_order)
      from public.order_items oi where oi.order_id = p_order_id
    ), '[]'::jsonb),
    'totals', jsonb_build_object(
      'items_subtotal', v_order.items_subtotal,
      'discount', v_order.total_discount,
      'coupon_code', v_order.coupon_code,
      'taxable_amount', v_order.taxable_amount,
      'cgst', v_order.cgst_amount,
      'sgst', v_order.sgst_amount,
      'igst', v_order.igst_amount,
      'cess', v_order.cess_amount,
      'tax_total', v_order.tax_amount,
      'packaging_charge', v_order.packaging_charge,
      'delivery_fee', v_order.delivery_fee,
      'service_fee', v_order.service_fee,
      'tip', v_order.tip_amount,
      'round_off', v_order.round_off,
      'grand_total', v_order.grand_total,
      'wallet_applied', v_order.wallet_applied,
      'amount_paid', v_order.grand_total,
      'refunded', v_order.refunded_amount
    ),
    'payment', jsonb_build_object(
      'mode', v_order.payment_mode,
      'status', v_order.payment_status,
      'paid_at', v_order.paid_at,
      'reference', (
        select p.provider_payment_id from public.payments p
        where p.order_id = p_order_id and p.status in ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED')
        order by p.captured_at desc nulls last limit 1
      )
    ),
    'tax_note', case when app.setting_bool('tax.inclusive_note', true)
      then 'All prices are inclusive of GST.' else null end,
    'footer_note', app.setting_text('invoice.footer_note', 'Thank you for ordering from Bites Box.')
  );
end;
$$;

grant execute on function public.order_invoice(uuid) to authenticated;

comment on function public.order_invoice is
  'GST-compliant invoice payload for an order. Rendered to PDF by the client.';
