-- ═══════════════════════════════════════════════════════════════════════════
-- 0035 · THREE MORE FUNCTIONS THAT THREW ON EVERY CALL
--
-- Found by the read-surface smoke suite added alongside this migration.
--
-- `authenticated` and `anon` have EXECUTE on many `app.*` helpers — migration 0028
-- granted the RLS helpers deliberately, because an RLS qual is evaluated with the
-- caller's privileges. But neither role has USAGE on schema `app`, and USAGE is
-- what you need in order to *name* something in a schema.
--
-- That does not matter for a SECURITY DEFINER function: its body runs as the
-- owner, who has USAGE. Every read surface in this schema is defined that way —
-- except these three, which were invoker-rights and referenced `app.`:
--
--   public.branch_ordering_state   permission denied for schema app  (anon + authenticated)
--   public.has_permission          permission denied for schema app  (authenticated)
--   public.manage_user_role        permission denied for schema app  (owner)
--
-- So "is the restaurant open?", the client-side permission check, and all role
-- management were broken outright. None had a test, and a plpgsql body is only
-- resolved when it runs, so `supabase db reset` installed all three happily.
--
-- ─── Why not grant USAGE on schema app instead ──────────────────────────────
--
-- Because schema USAGE is currently the only thing making 54 individual EXECUTE
-- grants on `app` unreachable — among them `app.run_job`, `app.dispatch_campaign`,
-- `app.next_partner_code` and every `app.job_*`. Those grants exist so RLS quals
-- and older code paths resolve; they were never meant to be callable directly.
-- Granting USAGE would turn a latent tidiness problem into a live privilege
-- escalation, letting any signed-in user run the job scheduler. The boundary stays.
--
-- ─── Why SECURITY DEFINER is safe for all three ────────────────────────────
--
-- The instinct to worry is right, so each one is justified separately.
--
-- `has_permission` delegates to `app.has_permission`, which resolves the caller's
-- own grants through `auth.uid()`. `auth.uid()` reads a request setting, not a
-- database role, so it is unchanged by definer. The answer is still about the
-- caller.
--
-- `branch_ordering_state` is a pure read of one branch row plus two settings. It
-- takes no user input beyond a branch id and returns the same answer to everyone.
--
-- `manage_user_role` is the one that needed checking. Its original comment said it
-- ran as the caller "so the privilege-escalation guard on user_roles can compare
-- ranks". The guard is real, but it is `app.tg_guard_role_assignment` — a
-- SECURITY DEFINER *trigger*. A trigger fires for whoever writes the row, and it
-- reads `auth.uid()`, so it is entirely unaffected by the caller's rights. The
-- only thing invoker-rights actually bought was the `user_roles_write` RLS policy,
-- which checks `app.has_permission('role.assign')` — precisely what the function's
-- own first statement already checks. Nothing is lost.
--
-- The rank guard is asserted directly in suite 010 after this change, rather than
-- being assumed.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 1 · branch_ordering_state ──────────────────────────────────────────────
-- Body unchanged; only the security context. Re-stated in full because
-- `create or replace` cannot alter SECURITY DEFINER on its own.
create or replace function public.branch_ordering_state(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch public.branches;
  v_in_hours boolean;
  v_maintenance boolean;
  v_accepting boolean;
  v_reason text;
begin
  select * into v_branch
  from public.branches
  where id = coalesce(p_branch_id, app.default_branch_id())
    and deleted_at is null;

  if not found then
    return jsonb_build_object(
      'accepting_orders', false,
      'reason_code', 'BRANCH_NOT_FOUND',
      'message', 'We could not find a Bites Box outlet for this location.'
    );
  end if;

  v_maintenance := coalesce(app.setting_bool('maintenance.enabled', false), false);
  v_in_hours := app.is_within_trading_hours(v_branch.id);

  if v_maintenance then
    v_accepting := false;
    v_reason := 'MAINTENANCE_MODE';
  elsif not v_branch.is_active then
    v_accepting := false;
    v_reason := 'BRANCH_INACTIVE';
  elsif v_branch.status = 'CLOSED' or not v_branch.accepting_orders then
    v_accepting := false;
    v_reason := coalesce(v_branch.status_reason::text, 'RESTAURANT_CLOSED');
  elsif v_branch.status = 'PAUSED' then
    v_accepting := false;
    v_reason := 'ORDERING_PAUSED';
  elsif not v_in_hours then
    v_accepting := false;
    v_reason := 'OUTSIDE_TRADING_HOURS';
  else
    v_accepting := true;
    v_reason := null;
  end if;

  return jsonb_build_object(
    'branch_id',        v_branch.id,
    'branch_name',      v_branch.name,
    'status',           v_branch.status,
    'accepting_orders', v_accepting,
    'is_busy',          v_branch.status = 'BUSY',
    'within_hours',     v_in_hours,
    'maintenance',      v_maintenance,
    'reason_code',      v_reason,
    'status_note',      v_branch.status_note,
    'service_mode',     v_branch.service_mode,
    'prep_minutes',     v_branch.default_prep_minutes + v_branch.rush_buffer_minutes,
    'auto_resume_at',   v_branch.auto_resume_at,
    'next_opens_at',    null::timestamptz
  );
end;
$$;

comment on function public.branch_ordering_state is
  'Whether this outlet is taking orders right now, and if not, why. SECURITY DEFINER: the body reads app.* helpers and the caller has no USAGE on that schema.';

-- ─── 2 · has_permission ─────────────────────────────────────────────────────
-- The client-facing wrapper. `auth.uid()` is a request setting rather than a
-- database role, so running as the owner does not change whose permissions are
-- being reported.
create or replace function public.has_permission(
  p_permission text,
  p_branch_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app.has_permission(p_permission, p_branch_id);
$$;

comment on function public.has_permission is
  'Does the caller hold this permission? Reports on auth.uid(), so SECURITY DEFINER does not widen the answer.';

-- ─── 3 · manage_user_role ───────────────────────────────────────────────────
-- Body unchanged. `app.tg_guard_role_assignment` still fires on the write and
-- still refuses to grant a role at or above the actor's own rank.
create or replace function public.manage_user_role(
  p_user_id uuid,
  p_role public.app_role,
  p_grant boolean default true,
  p_branch_id uuid default null,
  p_make_primary boolean default false
)
returns jsonb
language plpgsql
security definer
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
  'Grant or revoke a role. SECURITY DEFINER; the rank guard is the SECURITY DEFINER trigger app.tg_guard_role_assignment, which fires on the write regardless and reads auth.uid().';
