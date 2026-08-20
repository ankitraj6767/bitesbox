-- ═══════════════════════════════════════════════════════════════════════════
-- 0015 · AUDIT LOG
--
-- Every sensitive action is recorded with actor, role, before/after values,
-- request metadata and a timestamp. The table is append-only at the database
-- level: not even an owner can rewrite history through the API.
-- ═══════════════════════════════════════════════════════════════════════════

create table public.audit_logs (
  id            bigserial primary key,
  actor_id      uuid references auth.users (id) on delete set null,
  actor_kind    public.actor_kind not null default 'USER',
  actor_role    public.app_role,
  actor_name    text,
  action        public.audit_action not null,
  entity_type   text not null,
  entity_id     text,
  entity_label  text,
  branch_id     uuid references public.branches (id) on delete set null,
  old_value     jsonb,
  new_value     jsonb,
  -- Only the fields that actually changed, for compact review in the admin UI.
  changed_fields text[],
  reason        text,
  ip_address    inet,
  user_agent    text,
  request_id    text,
  created_at    timestamptz not null default now()
);

create index audit_logs_entity_idx on public.audit_logs (entity_type, entity_id, created_at desc);
create index audit_logs_actor_idx on public.audit_logs (actor_id, created_at desc);
create index audit_logs_action_idx on public.audit_logs (action, created_at desc);
create index audit_logs_created_idx on public.audit_logs (created_at desc);
create index audit_logs_branch_idx on public.audit_logs (branch_id, created_at desc);

select app.make_append_only('public.audit_logs');

comment on table public.audit_logs is
  'Append-only audit trail. Writable only through app.audit(); never updated or deleted.';

-- ─── Audit writer ──────────────────────────────────────────────────────────
create or replace function app.audit(
  p_action public.audit_action,
  p_entity_type text,
  p_entity_id text default null,
  p_old_value jsonb default null,
  p_new_value jsonb default null,
  p_reason text default null,
  p_entity_label text default null,
  p_branch_id uuid default null,
  p_actor_kind public.actor_kind default 'USER'
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id bigint;
  v_changed text[];
  v_actor_name text;
  v_actor_role public.app_role;
  v_actor uuid := auth.uid();
begin
  -- Compute the changed-field list so reviewers see the diff, not two blobs.
  if p_old_value is not null and p_new_value is not null then
    select coalesce(array_agg(k), '{}')
    into v_changed
    from (
      select key as k from jsonb_each(p_new_value)
      where p_old_value -> key is distinct from p_new_value -> key
    ) diff;
  end if;

  if v_actor is not null then
    select coalesce(pr.full_name, pr.phone::text) into v_actor_name
    from public.profiles pr where pr.id = v_actor;
    v_actor_role := app.primary_role();
  end if;

  insert into public.audit_logs (
    actor_id, actor_kind, actor_role, actor_name, action, entity_type, entity_id,
    entity_label, branch_id, old_value, new_value, changed_fields, reason,
    ip_address, user_agent, request_id
  )
  values (
    v_actor,
    case when v_actor is null and p_actor_kind = 'USER' then 'SYSTEM' else p_actor_kind end,
    v_actor_role,
    v_actor_name,
    p_action,
    p_entity_type,
    p_entity_id,
    p_entity_label,
    p_branch_id,
    p_old_value,
    p_new_value,
    v_changed,
    p_reason,
    app.request_ip(),
    app.request_user_agent(),
    app.jwt_claim('session_id')
  )
  returning id into v_id;

  return v_id;
end;
$$;

comment on function app.audit is
  'Single entry point for audit records. Captures actor, diff and request metadata.';

-- ─── Generic table auditor ─────────────────────────────────────────────────
-- Attached to tables whose every mutation must be recorded. Trigger arguments:
--   TG_ARGV[0] = entity_type label
--   TG_ARGV[1] = column holding a human label (optional)
create or replace function app.tg_audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entity text := coalesce(tg_argv[0], tg_table_name);
  v_label_col text := tg_argv[1];
  v_old jsonb;
  v_new jsonb;
  v_id text;
  v_label text;
  v_action public.audit_action;
begin
  if tg_op = 'INSERT' then
    v_new := to_jsonb(new);
    v_action := 'CREATE';
    v_id := v_new ->> 'id';
  elsif tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
    v_action := 'UPDATE';
    v_id := v_new ->> 'id';
  else
    v_old := to_jsonb(old);
    v_action := 'DELETE';
    v_id := v_old ->> 'id';
  end if;

  if v_label_col is not null then
    v_label := coalesce(v_new ->> v_label_col, v_old ->> v_label_col);
  end if;

  -- Skip no-op updates (e.g. touch-only writes).
  if tg_op = 'UPDATE' and v_old - 'updated_at' = v_new - 'updated_at' then
    return coalesce(new, old);
  end if;

  perform app.audit(
    v_action, v_entity, v_id, v_old, v_new, null, v_label,
    coalesce((v_new ->> 'branch_id')::uuid, (v_old ->> 'branch_id')::uuid)
  );

  return coalesce(new, old);
end;
$$;

-- Attach to the tables where a silent change would be unacceptable.
create trigger audit_settings
  after insert or update or delete on public.settings
  for each row execute function app.tg_audit_row('settings', 'key');

create trigger audit_feature_flags
  after insert or update or delete on public.feature_flags
  for each row execute function app.tg_audit_row('feature_flag', 'key');

create trigger audit_coupons
  after insert or update or delete on public.coupons
  for each row execute function app.tg_audit_row('coupon', 'code');

create trigger audit_promotions
  after insert or update or delete on public.promotions
  for each row execute function app.tg_audit_row('promotion', 'name');

create trigger audit_delivery_zones
  after insert or update or delete on public.delivery_zones
  for each row execute function app.tg_audit_row('delivery_zone', 'name');

create trigger audit_user_roles
  after insert or update or delete on public.user_roles
  for each row execute function app.tg_audit_row('user_role', null);

create trigger audit_role_permissions
  after insert or delete on public.role_permissions
  for each row execute function app.tg_audit_row('role_permission', null);

create trigger audit_refunds
  after insert or update on public.refunds
  for each row execute function app.tg_audit_row('refund', null);

create trigger audit_branches
  after update on public.branches
  for each row execute function app.tg_audit_row('branch', 'name');

create trigger audit_cancellation_policies
  after insert or update or delete on public.cancellation_policies
  for each row execute function app.tg_audit_row('cancellation_policy', null);

create trigger audit_tax_categories
  after insert or update or delete on public.tax_categories
  for each row execute function app.tg_audit_row('tax_category', 'code');

-- ─── Price-change auditing (targeted, not whole-row) ───────────────────────
create or replace function app.tg_audit_price_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'products' then
    if new.base_price is distinct from old.base_price
       or new.compare_price is distinct from old.compare_price
       or new.packaging_charge is distinct from old.packaging_charge then
      perform app.audit(
        'PRICE_CHANGE', 'product', new.id::text,
        jsonb_build_object('base_price', old.base_price, 'compare_price', old.compare_price,
                           'packaging_charge', old.packaging_charge),
        jsonb_build_object('base_price', new.base_price, 'compare_price', new.compare_price,
                           'packaging_charge', new.packaging_charge),
        null, new.name, new.branch_id
      );
    end if;
  elsif tg_table_name = 'product_variants' then
    if new.price is distinct from old.price or new.compare_price is distinct from old.compare_price then
      perform app.audit(
        'PRICE_CHANGE', 'product_variant', new.id::text,
        jsonb_build_object('price', old.price, 'compare_price', old.compare_price),
        jsonb_build_object('price', new.price, 'compare_price', new.compare_price),
        null, new.name
      );
    end if;
  end if;

  return new;
end;
$$;

create trigger audit_product_price
  after update of base_price, compare_price, packaging_charge on public.products
  for each row execute function app.tg_audit_price_change();

create trigger audit_variant_price
  after update of price, compare_price on public.product_variants
  for each row execute function app.tg_audit_price_change();

-- ─── Customer block / unblock ──────────────────────────────────────────────
create or replace function app.tg_audit_profile_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    perform app.audit(
      case when new.status = 'BLOCKED' then 'CUSTOMER_BLOCK'::public.audit_action
           else 'CUSTOMER_UNBLOCK'::public.audit_action end,
      'profile', new.id::text,
      jsonb_build_object('status', old.status),
      jsonb_build_object('status', new.status, 'reason', new.blocked_reason),
      new.blocked_reason,
      coalesce(new.full_name, new.phone::text)
    );
  end if;

  return new;
end;
$$;

create trigger audit_profile_status
  after update of status on public.profiles
  for each row execute function app.tg_audit_profile_status();

-- ─── Rider suspension ──────────────────────────────────────────────────────
create or replace function app.tg_audit_rider_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.onboarding_status is distinct from old.onboarding_status then
    perform app.audit(
      case when new.onboarding_status in ('SUSPENDED', 'REJECTED') then 'RIDER_SUSPEND'::public.audit_action
           else 'UPDATE'::public.audit_action end,
      'delivery_partner', new.id::text,
      jsonb_build_object('onboarding_status', old.onboarding_status),
      jsonb_build_object('onboarding_status', new.onboarding_status),
      coalesce(new.suspended_reason, new.rejection_reason),
      new.full_name,
      new.branch_id
    );
  end if;

  return new;
end;
$$;

create trigger audit_rider_status
  after update of onboarding_status on public.delivery_partners
  for each row execute function app.tg_audit_rider_status();

-- ─── Audit query surface for the admin dashboard ───────────────────────────
create or replace function public.audit_trail(
  p_entity_type text default null,
  p_entity_id text default null,
  p_actor_id uuid default null,
  p_action public.audit_action default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_limit int default 100,
  p_offset int default 0
)
returns table (
  id bigint,
  actor_id uuid,
  actor_name text,
  actor_role public.app_role,
  actor_kind public.actor_kind,
  action public.audit_action,
  entity_type text,
  entity_id text,
  entity_label text,
  changed_fields text[],
  old_value jsonb,
  new_value jsonb,
  reason text,
  ip_address inet,
  created_at timestamptz,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform app.require_permission('audit.view');

  return query
  with filtered as (
    select a.*
    from public.audit_logs a
    where (p_entity_type is null or a.entity_type = p_entity_type)
      and (p_entity_id is null or a.entity_id = p_entity_id)
      and (p_actor_id is null or a.actor_id = p_actor_id)
      and (p_action is null or a.action = p_action)
      and (p_from is null or a.created_at >= p_from)
      and (p_to is null or a.created_at <= p_to)
  )
  select
    f.id, f.actor_id, f.actor_name, f.actor_role, f.actor_kind, f.action,
    f.entity_type, f.entity_id, f.entity_label, f.changed_fields,
    f.old_value, f.new_value, f.reason, f.ip_address, f.created_at,
    count(*) over () as total_count
  from filtered f
  order by f.created_at desc
  limit least(coalesce(p_limit, 100), 500)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;
