-- ═══════════════════════════════════════════════════════════════════════════
-- 0034 · TWO FUNCTIONS THAT THREW ON EVERY CALL
--
-- Found by `supabase db lint --level warning`, which reports these at *error*
-- level. Both were verified to fail at runtime, not merely to look suspicious:
--
--   public.search_suggestions  →  42803  column "p.order_count" must appear in
--                                 the GROUP BY clause
--   public.svc_audit           →  42804  column "actor_kind" is of type
--                                 public.actor_kind but expression is of type text
--
-- Neither was covered by a test, and both sit on paths that are easy to miss:
-- `search_suggestions` is called by the customer search screen
-- (menu_repository.suggestions), so search was broken for every user including
-- guests; `svc_audit` is how an Edge Function attributes an action to the human
-- who requested it, so the audit trail for service-role writes was unreachable.
--
-- The lesson worth keeping: `supabase db lint` is in CI, but reporting is not
-- gating. A plpgsql body is only parsed when it runs, so a query that cannot
-- possibly execute still installs cleanly. The linter is the only thing that looks
-- inside a function body before a user does.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 1 · search_suggestions ─────────────────────────────────────────────────
--
-- `popular_products` read:
--
--     select jsonb_agg(jsonb_build_object(...) order by p.order_count desc)
--     from public.products p
--     where p.is_active and p.deleted_at is null
--     order by p.order_count desc
--     limit 8
--
-- Once an aggregate appears, the query collapses to a single group, so the outer
-- `order by p.order_count` references a column that is neither grouped nor
-- aggregated — hence 42803. The `limit 8` was also not doing what it looks like:
-- it would have limited the one aggregate row, not the products.
--
-- The `trending` branch immediately above already had the right shape — order and
-- limit in a subquery, aggregate outside it — so this brings the two into line.
create or replace function public.search_suggestions(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  return jsonb_build_object(
    'recent', case when auth.uid() is null then '[]'::jsonb else coalesce((
      select jsonb_agg(distinct q.query)
      from (
        select query from public.search_queries
        where user_id = auth.uid() and result_count > 0
        order by created_at desc
        limit 8
      ) q
    ), '[]'::jsonb) end,
    'trending', coalesce((
      select jsonb_agg(t.query order by t.hits desc)
      from (
        select query, count(*) as hits
        from public.search_queries
        where created_at > now() - interval '7 days' and result_count > 0
        group by query
        order by hits desc
        limit 8
      ) t
    ), '[]'::jsonb),
    'popular_products', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', top.id,
          'name', top.name,
          'thumbnail_path', top.thumbnail_path,
          'base_price', top.base_price,
          'food_type', top.food_type,
          -- Availability is per branch and per moment, so it is resolved here
          -- rather than stored: a paused item must disappear from suggestions
          -- immediately, not at the next cache expiry.
          'is_available', app.product_orderable(top.id, v_branch)
        )
        order by top.order_count desc
      )
      from (
        select p.id, p.name, p.thumbnail_path, p.base_price, p.food_type, p.order_count
        from public.products p
        where p.is_active and p.deleted_at is null
        order by p.order_count desc, p.name
        limit 8
      ) top
    ), '[]'::jsonb)
  );
end;
$$;

comment on function public.search_suggestions is
  'Recent, trending and popular search entry points. Availability is resolved live per branch.';

-- ─── 2 · svc_audit ──────────────────────────────────────────────────────────
--
-- `case when p_actor_id is null then 'SYSTEM' else 'USER' end` is an untyped
-- expression, and Postgres will not implicitly assign text to an enum column in an
-- INSERT — so every call raised 42804.
--
-- This is the third time this exact shape has bitten in this schema. The rule:
-- a CASE that feeds an enum column must cast at least one branch, because the
-- branch type is what gives the whole expression its type.
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
  v_actor_kind public.actor_kind;
begin
  perform app.assert_service_role();

  -- Resolved into a typed variable rather than cast inline, so the intent is
  -- readable and the type is enforced at assignment.
  v_actor_kind := case
    when p_actor_id is null then 'SYSTEM'::public.actor_kind
    else 'USER'::public.actor_kind
  end;

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
    v_actor_kind,
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

comment on function public.svc_audit is
  'Service-role audit writer. Attributes the action to the human who requested it, so an Edge Function write is never an anonymous SYSTEM entry.';
