-- ═══════════════════════════════════════════════════════════════════════════
-- 0026 · ADMIN OPERATIONS
--
-- Role management and ledger adjustments used by the admin-operation Edge
-- Function, plus the staff-invite flow.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Ledger access for trusted server code ─────────────────────────────────
create or replace function public.svc_post_wallet_entry(
  p_user_id uuid,
  p_kind public.wallet_entry_kind,
  p_amount numeric,
  p_description text,
  p_order_id uuid default null,
  p_refund_id uuid default null,
  p_idempotency_key text default null,
  p_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();

  return app.post_wallet_entry(
    p_user_id, p_kind, p_amount, p_description,
    p_order_id, p_refund_id, p_idempotency_key, p_expires_at
  );
end;
$$;

create or replace function public.svc_post_loyalty_entry(
  p_user_id uuid,
  p_kind public.loyalty_entry_kind,
  p_points int,
  p_description text,
  p_order_id uuid default null,
  p_monetary_value numeric default 0,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_service_role();

  return app.post_loyalty_entry(
    p_user_id, p_kind, p_points, p_description,
    p_order_id, p_monetary_value, p_idempotency_key
  );
end;
$$;

/**
 * Writes an audit entry on behalf of an actor.
 *
 * app.audit() reads auth.uid(), which is null when the service role acts. This
 * wrapper lets an Edge Function attribute the action to the human who requested
 * it, so the trail never shows an anonymous "SYSTEM" for a staff decision.
 */
create or replace function public.svc_audit(
  p_action public.audit_action,
  p_entity_type text,
  p_entity_id text default null,
  p_old_value jsonb default null,
  p_new_value jsonb default null,
  p_reason text default null,
  p_entity_label text default null,
  p_branch_id uuid default null,
  p_actor_id uuid default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id bigint;
  v_actor_name text;
  v_actor_role public.app_role;
begin
  perform app.assert_service_role();

  if p_actor_id is not null then
    select coalesce(pr.full_name, pr.phone::text) into v_actor_name
    from public.profiles pr where pr.id = p_actor_id;

    select r.code into v_actor_role
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = p_actor_id and ur.is_active
    order by ur.is_primary desc, r.rank desc
    limit 1;
  end if;

  insert into public.audit_logs (
    actor_id, actor_kind, actor_role, actor_name, action, entity_type, entity_id,
    entity_label, branch_id, old_value, new_value, reason, ip_address, user_agent
  )
  values (
    p_actor_id,
    case when p_actor_id is null then 'SYSTEM' else 'USER' end,
    v_actor_role,
    v_actor_name,
    p_action,
    p_entity_type,
    p_entity_id,
    p_entity_label,
    p_branch_id,
    p_old_value,
    p_new_value,
    p_reason,
    app.request_ip(),
    app.request_user_agent()
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ROLE MANAGEMENT
-- Runs as the calling user so the privilege-escalation guard on user_roles can
-- compare ranks. A user can therefore only ever grant a role below their own.
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.manage_user_role(
  p_user_id uuid,
  p_role public.app_role,
  p_grant boolean default true,
  p_branch_id uuid default null,
  p_make_primary boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role_id uuid;
  v_branch uuid;
  v_existing public.user_roles;
  v_actor uuid := auth.uid();
begin
  perform app.require_permission('role.assign');

  if p_user_id = v_actor then
    perform app.fail('VALIDATION_FAILED', 'You cannot change your own roles.');
  end if;

  select id into v_role_id from public.roles where code = p_role;

  if v_role_id is null then
    perform app.fail('VALIDATION_FAILED', 'Unknown role.');
  end if;

  -- Organisation-wide roles are branch-agnostic; everything else is scoped.
  v_branch := case
    when p_role in ('OWNER', 'ADMIN') then null
    else coalesce(p_branch_id, app.default_branch_id())
  end;

  if p_grant then
    -- Demote the current primary first so the single-primary index is never violated.
    if p_make_primary then
      update public.user_roles
      set is_primary = false, updated_at = now()
      where user_id = p_user_id and is_primary and is_active;
    end if;

    insert into public.user_roles (user_id, role_id, branch_id, is_primary, assigned_by)
    values (p_user_id, v_role_id, v_branch, p_make_primary, v_actor)
    on conflict (user_id, role_id, coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid))
      where is_active
    do update set is_primary = excluded.is_primary or public.user_roles.is_primary,
                  updated_at = now()
    returning * into v_existing;

    return jsonb_build_object(
      'user_id', p_user_id,
      'role', p_role,
      'branch_id', v_branch,
      'granted', true,
      'is_primary', v_existing.is_primary
    );
  end if;

  -- Revoke
  update public.user_roles
  set is_active = false,
      is_primary = false,
      revoked_at = now(),
      revoked_by = v_actor,
      updated_at = now()
  where user_id = p_user_id
    and role_id = v_role_id
    and is_active
    and (v_branch is null or branch_id is null or branch_id = v_branch);

  -- Never leave an account with no role at all: fall back to CUSTOMER.
  if not exists (
    select 1 from public.user_roles where user_id = p_user_id and is_active
  ) then
    insert into public.user_roles (user_id, role_id, is_primary, assigned_by)
    select p_user_id, r.id, true, v_actor
    from public.roles r where r.is_default
    on conflict do nothing;
  end if;

  -- Guarantee exactly one primary role remains.
  if not exists (
    select 1 from public.user_roles where user_id = p_user_id and is_active and is_primary
  ) then
    update public.user_roles ur
    set is_primary = true, updated_at = now()
    where ur.id = (
      select ur2.id
      from public.user_roles ur2
      join public.roles r on r.id = ur2.role_id
      where ur2.user_id = p_user_id and ur2.is_active
      order by r.rank desc
      limit 1
    );
  end if;

  return jsonb_build_object(
    'user_id', p_user_id,
    'role', p_role,
    'branch_id', v_branch,
    'granted', false
  );
end;
$$;

comment on function public.manage_user_role is
  'Grants or revokes a role. SECURITY INVOKER so the escalation guard can compare actor rank.';

-- ═══════════════════════════════════════════════════════════════════════════
-- STAFF & RIDER DIRECTORY (admin read surfaces)
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.staff_directory(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  perform app.require_permission('staff.view', v_branch);

  return jsonb_build_object(
    'staff', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', p.id,
        'full_name', p.full_name,
        'phone', p.phone,
        'email', p.email,
        'avatar_url', p.avatar_url,
        'status', p.status,
        'last_seen_at', p.last_seen_at,
        'employee', (
          select jsonb_build_object(
            'employee_code', sm.employee_code,
            'designation', sm.designation,
            'department', sm.department,
            'joined_on', sm.joined_on,
            'shift_start', sm.shift_start,
            'shift_end', sm.shift_end,
            'is_active', sm.is_active
          )
          from public.staff_members sm
          where sm.user_id = p.id and sm.branch_id = v_branch and sm.deleted_at is null
          limit 1
        ),
        'roles', (
          select jsonb_agg(jsonb_build_object(
            'role', r.code, 'label', r.label, 'branch_id', ur.branch_id,
            'is_primary', ur.is_primary, 'assigned_at', ur.assigned_at
          ) order by r.rank desc)
          from public.user_roles ur
          join public.roles r on r.id = ur.role_id
          where ur.user_id = p.id and ur.is_active
        )
      ) order by p.full_name)
      from public.profiles p
      where p.deleted_at is null
        and exists (
          select 1 from public.user_roles ur
          join public.roles r on r.id = ur.role_id
          where ur.user_id = p.id
            and ur.is_active
            and r.code <> 'CUSTOMER'
            and (ur.branch_id is null or ur.branch_id = v_branch)
        )
    ), '[]'::jsonb),
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', r.code, 'label', r.label, 'description', r.description,
        'rank', r.rank, 'surfaces', r.surfaces,
        'permission_count', (
          select count(*) from public.role_permissions rp where rp.role_id = r.id
        )
      ) order by r.rank desc)
      from public.roles r
    ), '[]'::jsonb),
    'permissions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', pm.code, 'resource', pm.resource, 'action', pm.action,
        'label', pm.label, 'description', pm.description, 'is_sensitive', pm.is_sensitive,
        'roles', (
          select jsonb_agg(r2.code order by r2.rank desc)
          from public.role_permissions rp2
          join public.roles r2 on r2.id = rp2.role_id
          where rp2.permission_id = pm.id
        )
      ) order by pm.resource, pm.action)
      from public.permissions pm
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.rider_directory(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  perform app.require_permission('rider.view', v_branch);

  return jsonb_build_object(
    'riders', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', dp.id,
        'user_id', dp.user_id,
        'partner_code', dp.partner_code,
        'full_name', dp.full_name,
        'phone', dp.phone,
        'photo_path', dp.photo_path,
        'vehicle_type', dp.vehicle_type,
        'vehicle_number', dp.vehicle_number,
        'onboarding_status', dp.onboarding_status,
        'duty_state', dp.duty_state,
        'is_salaried', dp.is_salaried,
        'active_load', app.rider_active_load(dp.id),
        'max_concurrent_orders', dp.max_concurrent_orders,
        'total_deliveries', dp.total_deliveries,
        'successful_deliveries', dp.successful_deliveries,
        'failed_deliveries', dp.failed_deliveries,
        'rejected_assignments', dp.rejected_assignments,
        'rating_average', dp.rating_average,
        'rating_count', dp.rating_count,
        'cash_in_hand', dp.cash_in_hand,
        'unsettled_cash', coalesce((
          select sum(cc.collected_amount) from public.cod_collections cc
          where cc.delivery_partner_id = dp.id
            and cc.status = 'COD_COLLECTED' and cc.settled_at is null
        ), 0),
        'last_online_at', dp.last_online_at,
        'last_delivery_at', dp.last_delivery_at,
        'earnings_today', coalesce((
          select sum(de.amount) from public.delivery_earnings de
          where de.delivery_partner_id = dp.id and de.earned_on = current_date
        ), 0),
        'live_location', (
          select jsonb_build_object(
            'latitude', l.latitude, 'longitude', l.longitude,
            'recorded_at', l.recorded_at,
            'is_fresh', l.recorded_at > now() - interval '2 minutes',
            'order_id', l.order_id
          )
          from public.delivery_partner_locations l where l.delivery_partner_id = dp.id
        ),
        'documents', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', d.id, 'document_type', d.document_type, 'status', d.status,
            'storage_path', d.storage_path, 'document_number', d.document_number,
            'expires_on', d.expires_on, 'rejection_reason', d.rejection_reason
          ) order by d.document_type)
          from public.delivery_partner_documents d
          where d.delivery_partner_id = dp.id
        ), '[]'::jsonb)
      ) order by
        case dp.onboarding_status
          when 'DOCUMENTS_SUBMITTED' then 0
          when 'PENDING' then 1
          when 'ACTIVE' then 2
          else 3
        end,
        dp.full_name)
      from public.delivery_partners dp
      where dp.branch_id = v_branch and dp.deleted_at is null
    ), '[]'::jsonb),
    'counts', (
      select jsonb_build_object(
        'total', count(*),
        'active', count(*) filter (where onboarding_status = 'ACTIVE'),
        'pending_approval', count(*) filter (where onboarding_status in ('PENDING', 'DOCUMENTS_SUBMITTED')),
        'suspended', count(*) filter (where onboarding_status = 'SUSPENDED'),
        'online', count(*) filter (where duty_state <> 'OFFLINE' and onboarding_status = 'ACTIVE'),
        'available', count(*) filter (where duty_state = 'AVAILABLE' and onboarding_status = 'ACTIVE')
      )
      from public.delivery_partners
      where branch_id = v_branch and deleted_at is null
    )
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ADMIN LIST QUERIES (server-side pagination + filters)
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.admin_orders(
  p_branch_id uuid default null,
  p_search text default null,
  p_statuses public.order_status[] default null,
  p_payment_modes public.payment_mode[] default null,
  p_fulfilment public.fulfilment_type default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_delayed_only boolean default false,
  p_limit int default 50,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_rows jsonb;
  v_total bigint;
begin
  perform app.require_permission('order.view', v_branch);

  with filtered as (
    select o.*
    from public.orders o
    where o.branch_id = v_branch
      and (p_statuses is null or o.status = any (p_statuses))
      and (p_payment_modes is null or o.payment_mode = any (p_payment_modes))
      and (p_fulfilment is null or o.fulfilment_type = p_fulfilment)
      and (p_from is null or o.created_at >= p_from)
      and (p_to is null or o.created_at <= p_to)
      and (not p_delayed_only or (o.promised_at < now() and app.is_active_status(o.status)))
      and (
        v_search is null
        or o.order_number ilike '%' || v_search || '%'
        or o.customer_name ilike '%' || v_search || '%'
        or o.customer_phone::text ilike '%' || v_search || '%'
        or o.delivery_area ilike '%' || v_search || '%'
      )
  ),
  counted as (select count(*) as total from filtered),
  page as (
    select f.*
    from filtered f
    order by f.created_at desc
    limit least(coalesce(p_limit, 50), 200)
    offset greatest(coalesce(p_offset, 0), 0)
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id,
      'order_number', p.order_number,
      'status', p.status,
      'is_active', app.is_active_status(p.status),
      'fulfilment_type', p.fulfilment_type,
      'timing', p.timing,
      'scheduled_for', p.scheduled_for,
      'customer_name', p.customer_name,
      'customer_phone', p.customer_phone,
      'user_id', p.user_id,
      'area', coalesce(p.delivery_area, p.delivery_city),
      'item_count', p.item_count,
      'unit_count', p.unit_count,
      'grand_total', p.grand_total,
      'refunded_amount', p.refunded_amount,
      'payment_mode', p.payment_mode,
      'payment_status', p.payment_status,
      'cod_status', p.cod_status,
      'created_at', p.created_at,
      'placed_at', p.placed_at,
      'promised_at', p.promised_at,
      'delivered_at', p.delivered_at,
      'is_delayed', p.promised_at is not null and p.promised_at < now()
                    and app.is_active_status(p.status),
      'coupon_code', p.coupon_code,
      'rider_name', (
        select dp.full_name from public.delivery_assignments da
        join public.delivery_partners dp on dp.id = da.delivery_partner_id
        where da.order_id = p.id
          and da.status in ('OFFERED','ACCEPTED','AT_STORE','PICKED_UP','AT_CUSTOMER','COMPLETED')
        order by da.attempt_number desc limit 1
      )
    ) order by p.created_at desc), '[]'::jsonb),
    (select total from counted)
  into v_rows, v_total
  from page p;

  return jsonb_build_object(
    'orders', v_rows,
    'total', coalesce(v_total, 0),
    'limit', least(coalesce(p_limit, 50), 200),
    'offset', greatest(coalesce(p_offset, 0), 0)
  );
end;
$$;

create or replace function public.admin_customers(
  p_search text default null,
  p_segment text default null,
  p_limit int default 50,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_high_value numeric := app.setting_numeric('segment.high_value_ltv', 5000);
  v_inactive_days int := app.setting_int('segment.inactive_days', 30);
  v_rows jsonb;
  v_total bigint;
begin
  perform app.require_permission('customer.view');

  with filtered as (
    select p.*
    from public.profiles p
    where p.deleted_at is null
      and (
        v_search is null
        or p.full_name ilike '%' || v_search || '%'
        or p.phone::text ilike '%' || v_search || '%'
        or p.email::text ilike '%' || v_search || '%'
      )
      and case upper(coalesce(p_segment, 'ALL'))
        when 'NEW' then p.completed_orders = 0
        when 'REPEAT' then p.completed_orders > 1
        when 'HIGH_VALUE' then p.lifetime_value >= v_high_value
        when 'INACTIVE' then p.completed_orders > 0
          and (p.last_order_at is null
               or p.last_order_at < now() - make_interval(days => v_inactive_days))
        when 'BLOCKED' then p.status = 'BLOCKED'
        else true
      end
  ),
  counted as (select count(*) as total from filtered),
  page as (
    select f.* from filtered f
    order by f.lifetime_value desc, f.created_at desc
    limit least(coalesce(p_limit, 50), 200)
    offset greatest(coalesce(p_offset, 0), 0)
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id,
      'full_name', c.full_name,
      'phone', c.phone,
      'email', c.email,
      'status', c.status,
      'total_orders', c.total_orders,
      'completed_orders', c.completed_orders,
      'cancelled_orders', c.cancelled_orders,
      'lifetime_value', c.lifetime_value,
      'average_order_value', c.average_order_value,
      'last_order_at', c.last_order_at,
      'created_at', c.created_at,
      'marketing_opt_in', c.marketing_opt_in,
      'wallet_balance', coalesce((
        select w.balance from public.wallet_accounts w where w.user_id = c.id
      ), 0)
    ) order by c.lifetime_value desc), '[]'::jsonb),
    (select total from counted)
  into v_rows, v_total
  from page c;

  return jsonb_build_object(
    'customers', v_rows,
    'total', coalesce(v_total, 0),
    'limit', least(coalesce(p_limit, 50), 200),
    'offset', greatest(coalesce(p_offset, 0), 0)
  );
end;
$$;

create or replace function public.admin_refund_queue(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  perform app.require_permission('refund.view', v_branch);

  return jsonb_build_object(
    'refunds', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id,
        'order_id', r.order_id,
        'order_number', o.order_number,
        'customer_name', o.customer_name,
        'customer_phone', o.customer_phone,
        'kind', r.kind,
        'status', r.status,
        'reason', r.reason,
        'reason_note', r.reason_note,
        'destination', r.destination,
        'amount', r.amount,
        'amount_processed', r.amount_processed,
        'order_total', o.grand_total,
        'refundable_amount', app.refundable_amount(r.order_id),
        'requested_at', r.requested_at,
        'requested_by_name', (
          select coalesce(pr.full_name, pr.phone::text)
          from public.profiles pr where pr.id = r.requested_by
        ),
        'approved_at', r.approved_at,
        'completed_at', r.completed_at,
        'failure_reason', r.failure_reason,
        'provider_refund_id', r.provider_refund_id,
        'support_ticket_id', r.support_ticket_id,
        'can_approve', app.has_permission('refund.approve', o.branch_id)
                       and r.status in ('REQUESTED', 'APPROVAL_PENDING')
      ) order by
        case r.status
          when 'APPROVAL_PENDING' then 0
          when 'REQUESTED' then 1
          when 'PROCESSING' then 2
          when 'FAILED' then 3
          else 4
        end,
        r.requested_at desc)
      from public.refunds r
      join public.orders o on o.id = r.order_id
      where o.branch_id = v_branch
        and (r.status in ('REQUESTED', 'APPROVAL_PENDING', 'APPROVED', 'PROCESSING', 'FAILED')
             or r.created_at > now() - interval '7 days')
    ), '[]'::jsonb),
    'counts', (
      select jsonb_build_object(
        'pending_approval', count(*) filter (where r.status in ('REQUESTED', 'APPROVAL_PENDING')),
        'processing', count(*) filter (where r.status in ('APPROVED', 'PROCESSING')),
        'failed', count(*) filter (where r.status = 'FAILED'),
        'pending_value', coalesce(sum(r.amount) filter (
          where r.status in ('REQUESTED', 'APPROVAL_PENDING')), 0)
      )
      from public.refunds r
      join public.orders o on o.id = r.order_id
      where o.branch_id = v_branch
    )
  );
end;
$$;

create or replace function public.admin_support_inbox(
  p_branch_id uuid default null,
  p_statuses public.ticket_status[] default null,
  p_limit int default 50
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
  perform app.require_permission('support.view', v_branch);

  return jsonb_build_object(
    'tickets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id,
        'ticket_number', t.ticket_number,
        'category', t.category,
        'subject', t.subject,
        'status', t.status,
        'priority', t.priority,
        'customer_name', pr.full_name,
        'customer_phone', pr.phone,
        'user_id', t.user_id,
        'order_id', t.order_id,
        'order_number', o.order_number,
        'assigned_to', t.assigned_to,
        'assigned_to_name', (
          select coalesce(a.full_name, a.phone::text) from public.profiles a where a.id = t.assigned_to
        ),
        'created_at', t.created_at,
        'last_message_at', t.last_message_at,
        'first_response_due_at', t.first_response_due_at,
        'first_response_at', t.first_response_at,
        -- Drives the red SLA badge in the support inbox.
        'sla_breached', t.first_response_at is null
                        and t.first_response_due_at < now()
                        and t.status in ('OPEN', 'IN_PROGRESS', 'ESCALATED'),
        'message_count', (
          select count(*) from public.support_messages m where m.ticket_id = t.id
        ),
        'unread_from_customer', (
          select count(*) from public.support_messages m
          where m.ticket_id = t.id
            and m.author_kind = 'CUSTOMER'
            and m.read_by_agent_at is null
        ),
        'refund_id', t.refund_id
      ) order by
        case t.priority when 'URGENT' then 0 when 'HIGH' then 1 when 'NORMAL' then 2 else 3 end,
        t.last_message_at desc)
      from public.support_tickets t
      join public.profiles pr on pr.id = t.user_id
      left join public.orders o on o.id = t.order_id
      where (t.branch_id = v_branch or t.branch_id is null)
        and (p_statuses is null or t.status = any (p_statuses))
      limit least(coalesce(p_limit, 50), 200)
    ), '[]'::jsonb),
    'counts', (
      select jsonb_build_object(
        'open', count(*) filter (where status = 'OPEN'),
        'in_progress', count(*) filter (where status = 'IN_PROGRESS'),
        'waiting_on_customer', count(*) filter (where status = 'WAITING_ON_CUSTOMER'),
        'escalated', count(*) filter (where status = 'ESCALATED'),
        'urgent', count(*) filter (where priority = 'URGENT'
                                   and status in ('OPEN', 'IN_PROGRESS', 'ESCALATED')),
        'sla_breached', count(*) filter (
          where first_response_at is null
            and first_response_due_at < now()
            and status in ('OPEN', 'IN_PROGRESS', 'ESCALATED')
        )
      )
      from public.support_tickets
      where branch_id = v_branch or branch_id is null
    )
  );
end;
$$;

create or replace function public.support_ticket_detail(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ticket public.support_tickets;
  v_is_agent boolean;
begin
  select * into v_ticket from public.support_tickets where id = p_ticket_id;

  if not found then
    perform app.fail('TICKET_NOT_FOUND', 'That conversation no longer exists.');
  end if;

  v_is_agent := app.has_permission('support.view', v_ticket.branch_id);

  if v_ticket.user_id <> auth.uid() and not v_is_agent then
    perform app.fail('PERMISSION_DENIED', 'You cannot view this ticket.');
  end if;

  return jsonb_build_object(
    'ticket', jsonb_build_object(
      'id', v_ticket.id,
      'ticket_number', v_ticket.ticket_number,
      'category', v_ticket.category,
      'subject', v_ticket.subject,
      'description', v_ticket.description,
      'status', v_ticket.status,
      'priority', v_ticket.priority,
      'order_id', v_ticket.order_id,
      'created_at', v_ticket.created_at,
      'resolved_at', v_ticket.resolved_at,
      'resolution_note', v_ticket.resolution_note,
      'satisfaction_rating', v_ticket.satisfaction_rating,
      'refund_id', v_ticket.refund_id,
      'wallet_credit_amount', v_ticket.wallet_credit_amount,
      'assigned_to', case when v_is_agent then v_ticket.assigned_to else null end,
      'first_response_due_at', case when v_is_agent then v_ticket.first_response_due_at else null end
    ),
    'customer', (
      select jsonb_build_object(
        'id', p.id, 'full_name', p.full_name,
        'phone', case when v_is_agent then p.phone else null end,
        'total_orders', case when v_is_agent then p.total_orders else null end,
        'lifetime_value', case when v_is_agent then p.lifetime_value else null end
      )
      from public.profiles p where p.id = v_ticket.user_id
    ),
    'order', case when v_ticket.order_id is null then null
      else app.order_payload(v_ticket.order_id, v_is_agent) end,
    'messages', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id,
        'author_kind', m.author_kind,
        'author_name', (
          select coalesce(a.full_name, 'Bites Box') from public.profiles a where a.id = m.author_id
        ),
        'body', m.body,
        'is_internal', m.is_internal,
        'attachments', m.attachments,
        'created_at', m.created_at
      ) order by m.created_at)
      from public.support_messages m
      where m.ticket_id = p_ticket_id
        -- Internal notes stay invisible to the customer.
        and (v_is_agent or not m.is_internal)
    ), '[]'::jsonb)
  );
end;
$$;

-- ─── Grants ────────────────────────────────────────────────────────────────
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'svc\_%'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', fn.sig);
    execute format('grant execute on function %s to service_role', fn.sig);
  end loop;
end;
$$;

grant execute on function public.manage_user_role(uuid, public.app_role, boolean, uuid, boolean) to authenticated;
grant execute on function public.staff_directory(uuid) to authenticated;
grant execute on function public.rider_directory(uuid) to authenticated;
grant execute on function public.admin_orders(uuid, text, public.order_status[], public.payment_mode[], public.fulfilment_type, timestamptz, timestamptz, boolean, int, int) to authenticated;
grant execute on function public.admin_customers(text, text, int, int) to authenticated;
grant execute on function public.admin_refund_queue(uuid) to authenticated;
grant execute on function public.admin_support_inbox(uuid, public.ticket_status[], int) to authenticated;
grant execute on function public.support_ticket_detail(uuid) to authenticated;
