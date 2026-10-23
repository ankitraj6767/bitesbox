-- Recovery: this migration only adds triggers, publication membership, and
-- guarded RPCs; it does not rewrite existing configuration rows. If application
-- code is rolled back, keep these additive database objects until clients no
-- longer depend on them. Archived branch/tax rows are retained as history and
-- must not be hard-deleted as part of rollback. Any manual schema reversal must
-- first check publication consumers and remove only objects introduced here.

-- Settings CRUD now includes trading hours and holiday exceptions. Capture
-- those changes in the same append-only audit trail used by other live config.
create trigger audit_branch_hours
  after insert or update or delete on public.branch_hours
  for each row execute function app.tg_audit_row('branch_hours', null);

create trigger audit_branch_holidays
  after insert or update or delete on public.branch_holidays
  for each row execute function app.tg_audit_row('branch_holiday', 'label');

-- The customer app reads these values through app_config(). Publish only
-- tables that already have public-read RLS policies; Realtime still evaluates
-- those policies for every event.
alter publication supabase_realtime
  add table public.branch_hours, public.branch_holidays,
             public.settings, public.feature_flags,
             public.delivery_zones, public.tax_categories;

-- A branch is operational identity. Never hard-delete it: historical orders
-- and audit records refer to it. Archive it transactionally only when another
-- active outlet can take over the default selection and no live orders remain.
create or replace function public.archive_branch(p_branch_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch public.branches;
  v_replacement public.branches;
  v_now timestamptz := now();
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  -- Reject unauthorized calls before taking a table lock so the public RPC
  -- cannot be used to stall branch operations by authenticated customers.
  if not app.has_permission('branch.manage', p_branch_id) then
    raise exception using errcode = '42501', message = 'PERMISSION_DENIED';
  end if;

  -- Serialize branch archives with other branch writes, including a second
  -- operator archiving the replacement outlet at the same time.
  lock table public.branches in share row exclusive mode;

  select * into v_branch
  from public.branches
  where id = p_branch_id and deleted_at is null
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'Branch not found.', hint = 'BRANCH_NOT_FOUND';
  end if;
  if not app.has_permission('branch.manage', v_branch.id) then
    raise exception using errcode = '42501', message = 'PERMISSION_DENIED';
  end if;

  if exists (
    select 1
    from public.orders o
    where o.branch_id = v_branch.id
      and not app.is_terminal_status(o.status)
  ) then
    raise exception using errcode = 'P0001', message = 'Active orders must be resolved before archiving this outlet.', hint = 'BRANCH_HAS_ACTIVE_ORDERS';
  end if;

  if v_branch.is_default then
    select b.* into v_replacement
    from public.branches b
    where b.id <> v_branch.id
      and b.is_active
      and b.deleted_at is null
      and app.has_permission('branch.manage', b.id)
    order by b.is_default desc, b.display_order, b.created_at
    limit 1
    for update;
  else
    select b.* into v_replacement
    from public.branches b
    where b.id <> v_branch.id
      and b.is_active
      and b.deleted_at is null
    order by b.is_default desc, b.display_order, b.created_at
    limit 1
    for update;
  end if;

  if v_replacement.id is null then
    if v_branch.is_default and exists (
      select 1 from public.branches b
      where b.id <> v_branch.id and b.is_active and b.deleted_at is null
    ) then
      raise exception using
        errcode = '42501',
        message = 'A replacement outlet must remain the default.',
        hint = 'DEFAULT_BRANCH_REASSIGNMENT_PERMISSION_REQUIRED';
    end if;
    raise exception using errcode = 'P0001', message = 'The last active outlet cannot be archived.', hint = 'LAST_ACTIVE_BRANCH';
  end if;

  if v_branch.is_default then
    update public.branches
      set is_default = false
      where id = v_branch.id;
    update public.branches
      set is_default = true
      where id = v_replacement.id;
  end if;

  update public.branches
  set is_active = false,
      accepting_orders = false,
      status = 'CLOSED',
      status_reason = 'OTHER',
      status_note = 'Outlet archived',
      status_changed_at = v_now,
      status_changed_by = auth.uid(),
      deleted_at = v_now,
      updated_by = auth.uid()
  where id = v_branch.id;

  insert into public.branch_status_log (
    branch_id, previous_status, status, reason, note,
    accepting_orders, changed_by
  ) values (
    v_branch.id, v_branch.status, 'CLOSED', 'OTHER', 'Outlet archived',
    false, auth.uid()
  );

  return v_branch.id;
end;
$$;

comment on function public.archive_branch(uuid) is
  'Soft-archives an outlet without deleting historical orders; requires another active outlet and no live orders.';

revoke all on function public.archive_branch(uuid) from public, anon;
grant execute on function public.archive_branch(uuid) to authenticated;

-- Tax categories are referenced by live catalogue rows and historical orders,
-- so removal is a soft archive. Default changes are serialized with archives.
create or replace function public.set_default_tax_category(p_category_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if not app.has_permission('settings.update') then
    raise exception using errcode = '42501', message = 'PERMISSION_DENIED';
  end if;

  lock table public.tax_categories in share row exclusive mode;
  perform 1
  from public.tax_categories
  where id = p_category_id and deleted_at is null and is_active
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'Tax category not available.', hint = 'TAX_CATEGORY_NOT_AVAILABLE';
  end if;

  update public.tax_categories set is_default = false where is_default;
  update public.tax_categories set is_default = true where id = p_category_id;
  return p_category_id;
end;
$$;

create or replace function public.archive_tax_category(p_category_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_category public.tax_categories;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if not app.has_permission('settings.update') then
    raise exception using errcode = '42501', message = 'PERMISSION_DENIED';
  end if;

  lock table public.tax_categories in share row exclusive mode;
  select * into v_category
  from public.tax_categories
  where id = p_category_id and deleted_at is null
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'Tax category not available.', hint = 'TAX_CATEGORY_NOT_AVAILABLE';
  end if;
  if v_category.is_default then
    raise exception using errcode = 'P0001', message = 'Select another default tax category first.', hint = 'DEFAULT_TAX_CATEGORY_CANNOT_BE_ARCHIVED';
  end if;

  update public.tax_categories
  set is_active = false, deleted_at = now()
  where id = p_category_id;
  return p_category_id;
end;
$$;

comment on function public.set_default_tax_category(uuid) is
  'Atomically switches the default tax category without violating the single-default constraint.';
comment on function public.archive_tax_category(uuid) is
  'Soft-archives a non-default tax category while preserving existing menu and order references.';

revoke all on function public.set_default_tax_category(uuid) from public, anon;
grant execute on function public.set_default_tax_category(uuid) to authenticated;
revoke all on function public.archive_tax_category(uuid) from public, anon;
grant execute on function public.archive_tax_category(uuid) to authenticated;
