-- ═══════════════════════════════════════════════════════════════════════════
-- 0004 · IDENTITY & ROLE-BASED ACCESS CONTROL
--
-- Authorisation model
--   auth.users ── profiles (1:1 app identity)
--       │
--       └── user_roles ──► roles ──► role_permissions ──► permissions
--
-- Rules
--   · Roles NEVER carry hard-coded behaviour. Every check asks for a permission.
--   · Authorisation is evaluated against the database (app.has_permission), so
--     revoking a permission takes effect on the next statement — not the next
--     token refresh. JWT claims are a UI hint only.
--   · Staff membership is branch-scoped so a manager of one outlet cannot act on
--     another once more branches exist.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Profiles ──────────────────────────────────────────────────────────────
create table public.profiles (
  id                    uuid primary key references auth.users (id) on delete cascade,
  phone                 app.phone,
  email                 app.email,
  full_name             text,
  display_name          text,
  avatar_url            text,
  date_of_birth         date,
  gender                text,

  -- Preferences
  preferred_language    text not null default 'en',
  marketing_opt_in      boolean not null default true,
  push_enabled          boolean not null default true,
  sms_enabled           boolean not null default true,
  email_enabled         boolean not null default true,
  whatsapp_enabled      boolean not null default false,

  -- Lifecycle
  status                public.account_status not null default 'ACTIVE',
  blocked_reason        text,
  blocked_at            timestamptz,
  blocked_by            uuid references auth.users (id) on delete set null,
  onboarding_completed  boolean not null default false,
  profile_completed_at  timestamptz,

  -- Denormalised customer stats, maintained by triggers on orders. Read-only to clients.
  total_orders          int not null default 0,
  completed_orders      int not null default 0,
  cancelled_orders      int not null default 0,
  lifetime_value        app.money not null default 0,
  average_order_value   app.money not null default 0,
  first_order_at        timestamptz,
  last_order_at         timestamptz,

  -- Growth
  referral_code         text,
  referred_by           uuid references public.profiles (id) on delete set null,

  -- Attribution / diagnostics
  signup_channel        text,
  last_seen_at          timestamptz,
  last_app_version      text,

  internal_notes        text,
  metadata              jsonb not null default '{}'::jsonb,

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz,

  constraint profiles_gender check (gender is null or gender in ('MALE', 'FEMALE', 'OTHER', 'UNDISCLOSED')),
  constraint profiles_language check (preferred_language in ('en', 'hi')),
  constraint profiles_blocked_shape check (status <> 'BLOCKED' or blocked_at is not null)
);

create unique index profiles_phone_key on public.profiles (phone) where deleted_at is null;
create unique index profiles_referral_code_key on public.profiles (referral_code)
  where referral_code is not null;
create index profiles_status_idx on public.profiles (status) where deleted_at is null;
create index profiles_last_order_idx on public.profiles (last_order_at desc nulls last);
create index profiles_ltv_idx on public.profiles (lifetime_value desc);
create index profiles_name_trgm_idx on public.profiles
  using gin (full_name extensions.gin_trgm_ops);
create index profiles_referred_by_idx on public.profiles (referred_by)
  where referred_by is not null;

select app.attach_updated_at('public.profiles');

comment on table public.profiles is 'Application identity for every auth user, whatever their role.';
comment on column public.profiles.lifetime_value is
  'Maintained by trigger from delivered orders. Clients must never write this.';

-- ─── Permissions catalogue ─────────────────────────────────────────────────
create table public.permissions (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  resource      text not null,
  action        text not null,
  label         text not null,
  description   text,
  -- Permissions flagged sensitive always land in the audit log when exercised.
  is_sensitive  boolean not null default false,
  created_at    timestamptz not null default now(),

  constraint permissions_code_shape check (code ~ '^[a-z_]+\.[a-z_]+$')
);

create index permissions_resource_idx on public.permissions (resource);

comment on table public.permissions is 'Atomic capabilities, e.g. order.accept, refund.approve.';

-- ─── Roles ─────────────────────────────────────────────────────────────────
create table public.roles (
  id              uuid primary key default gen_random_uuid(),
  code            public.app_role not null unique,
  label           text not null,
  description     text,
  surfaces        public.role_surface[] not null default '{}',
  -- System roles cannot be deleted and their code cannot change.
  is_system       boolean not null default true,
  -- Role granted automatically to every new signup.
  is_default      boolean not null default false,
  -- Higher rank can manage lower ranks (prevents privilege escalation sideways).
  rank            int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create unique index roles_single_default on public.roles (is_default) where is_default;
select app.attach_updated_at('public.roles');

-- ─── Role ⇄ Permission ─────────────────────────────────────────────────────
create table public.role_permissions (
  role_id       uuid not null references public.roles (id) on delete cascade,
  permission_id uuid not null references public.permissions (id) on delete cascade,
  granted_at    timestamptz not null default now(),
  granted_by    uuid references auth.users (id) on delete set null,
  primary key (role_id, permission_id)
);

create index role_permissions_permission_idx on public.role_permissions (permission_id);

-- ─── User ⇄ Role ───────────────────────────────────────────────────────────
create table public.user_roles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  role_id     uuid not null references public.roles (id) on delete restrict,
  -- null = role applies to every branch (owner/admin). Otherwise branch-scoped.
  branch_id   uuid references public.branches (id) on delete cascade,
  is_active   boolean not null default true,
  is_primary  boolean not null default false,
  expires_at  timestamptz,
  assigned_at timestamptz not null default now(),
  assigned_by uuid references auth.users (id) on delete set null,
  revoked_at  timestamptz,
  revoked_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint user_roles_revoked_shape check (is_active or revoked_at is not null)
);

-- One live grant per (user, role, branch). NULL branch treated as its own slot.
create unique index user_roles_unique_grant
  on public.user_roles (user_id, role_id, coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where is_active;
create index user_roles_user_idx on public.user_roles (user_id) where is_active;
create index user_roles_role_idx on public.user_roles (role_id) where is_active;
create index user_roles_branch_idx on public.user_roles (branch_id) where is_active;
-- Exactly one primary role per user drives which app shell loads.
create unique index user_roles_single_primary on public.user_roles (user_id)
  where is_primary and is_active;

select app.attach_updated_at('public.user_roles');

comment on table public.user_roles is
  'Role grants. branch_id NULL = organisation-wide. is_primary selects the app shell.';

-- ─── Staff records ─────────────────────────────────────────────────────────
create table public.staff_members (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  branch_id         uuid not null references public.branches (id) on delete cascade,
  employee_code     text,
  designation       text,
  department        text,
  photo_path        text,
  joined_on         date not null default current_date,
  exited_on         date,
  shift_start       time,
  shift_end         time,
  emergency_contact_name  text,
  emergency_contact_phone app.phone,
  is_active         boolean not null default true,
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid references auth.users (id) on delete set null,
  deleted_at        timestamptz,

  constraint staff_members_exit_after_join check (exited_on is null or exited_on >= joined_on)
);

create unique index staff_members_user_branch_key
  on public.staff_members (user_id, branch_id) where deleted_at is null;
create unique index staff_members_employee_code_key
  on public.staff_members (employee_code) where employee_code is not null and deleted_at is null;
create index staff_members_branch_idx on public.staff_members (branch_id) where is_active;

select app.attach_updated_at('public.staff_members');

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTHORISATION HELPERS
-- All are STABLE + SECURITY DEFINER with a pinned empty search_path so they are
-- safe to call from RLS policies without recursion.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function app.current_user_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select auth.uid();
$$;

-- Authoritative permission check. Reads live grants, never the JWT.
create or replace function app.has_permission(p_permission text, p_branch_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    app.is_service_role()
    or exists (
      select 1
      from public.user_roles ur
      join public.role_permissions rp on rp.role_id = ur.role_id
      join public.permissions p on p.id = rp.permission_id
      where ur.user_id = auth.uid()
        and ur.is_active
        and (ur.expires_at is null or ur.expires_at > now())
        and p.code = p_permission
        -- Organisation-wide grants (branch_id null) satisfy any branch scope.
        and (ur.branch_id is null or p_branch_id is null or ur.branch_id = p_branch_id)
    );
$$;

comment on function app.has_permission is
  'Authoritative RBAC check against live grants. Service role always passes.';

-- Convenience wrapper exposed to clients so the UI can ask what it may render.
create or replace function public.has_permission(p_permission text, p_branch_id uuid default null)
returns boolean
language sql
stable
set search_path = ''
as $$
  select app.has_permission(p_permission, p_branch_id);
$$;

create or replace function app.has_any_permission(p_permissions text[], p_branch_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    app.is_service_role()
    or exists (
      select 1
      from public.user_roles ur
      join public.role_permissions rp on rp.role_id = ur.role_id
      join public.permissions p on p.id = rp.permission_id
      where ur.user_id = auth.uid()
        and ur.is_active
        and (ur.expires_at is null or ur.expires_at > now())
        and p.code = any (p_permissions)
        and (ur.branch_id is null or p_branch_id is null or ur.branch_id = p_branch_id)
    );
$$;

create or replace function app.has_role(p_role public.app_role, p_branch_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = auth.uid()
      and ur.is_active
      and (ur.expires_at is null or ur.expires_at > now())
      and r.code = p_role
      and (ur.branch_id is null or p_branch_id is null or ur.branch_id = p_branch_id)
  );
$$;

-- True for any back-office / operations role. Used to widen read scopes.
create or replace function app.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    app.is_service_role()
    or exists (
      select 1
      from public.user_roles ur
      join public.roles r on r.id = ur.role_id
      where ur.user_id = auth.uid()
        and ur.is_active
        and (ur.expires_at is null or ur.expires_at > now())
        and r.code <> 'CUSTOMER'
        and r.code <> 'DELIVERY_PARTNER'
    );
$$;

create or replace function app.is_rider()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app.has_role('DELIVERY_PARTNER');
$$;

-- Branches this user may operate on. Empty array = organisation-wide access.
create or replace function app.accessible_branch_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(distinct ur.branch_id) filter (where ur.branch_id is not null), '{}')
  from public.user_roles ur
  where ur.user_id = auth.uid()
    and ur.is_active
    and (ur.expires_at is null or ur.expires_at > now());
$$;

create or replace function app.can_access_branch(p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    app.is_service_role()
    or exists (
      select 1
      from public.user_roles ur
      where ur.user_id = auth.uid()
        and ur.is_active
        and (ur.expires_at is null or ur.expires_at > now())
        and (ur.branch_id is null or ur.branch_id = p_branch_id)
    );
$$;

create or replace function app.primary_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select r.code
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where ur.user_id = auth.uid()
    and ur.is_active
    and (ur.expires_at is null or ur.expires_at > now())
  order by ur.is_primary desc, r.rank desc
  limit 1;
$$;

create or replace function app.account_is_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select p.status = 'ACTIVE' and p.deleted_at is null
     from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

-- Raises a standard error instead of silently returning false. For RPC bodies.
create or replace function app.require_permission(p_permission text, p_branch_id uuid default null)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app.has_permission(p_permission, p_branch_id) then
    perform app.fail(
      'PERMISSION_DENIED',
      format('You do not have permission to perform this action (%s).', p_permission),
      jsonb_build_object('permission', p_permission, 'branch_id', p_branch_id)
    );
  end if;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- SESSION CONTEXT — one round trip that tells a client who it is talking to
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.my_session()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
  v_roles jsonb;
  v_permissions text[];
  v_primary public.app_role;
  v_branches jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('authenticated', false);
  end if;

  select * into v_profile from public.profiles where id = v_uid;

  -- Roles and permissions are aggregated separately: joining through
  -- role_permissions in one pass would repeat each role once per permission.
  select jsonb_agg(grant_row order by grant_row.is_primary desc, grant_row.rank desc)
  into v_roles
  from (
    select distinct
      r.code,
      r.label,
      ur.branch_id,
      ur.is_primary,
      r.surfaces,
      r.rank
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = v_uid
      and ur.is_active
      and (ur.expires_at is null or ur.expires_at > now())
  ) grant_row;

  -- Re-shape without the internal `rank` column used only for ordering.
  select jsonb_agg(
    jsonb_build_object(
      'role', entry ->> 'code',
      'label', entry ->> 'label',
      'branch_id', entry -> 'branch_id',
      'is_primary', entry -> 'is_primary',
      'surfaces', entry -> 'surfaces'
    )
  )
  into v_roles
  from jsonb_array_elements(coalesce(v_roles, '[]'::jsonb)) entry;

  select coalesce(array_agg(distinct p.code), '{}')
  into v_permissions
  from public.user_roles ur
  join public.role_permissions rp on rp.role_id = ur.role_id
  join public.permissions p on p.id = rp.permission_id
  where ur.user_id = v_uid
    and ur.is_active
    and (ur.expires_at is null or ur.expires_at > now());

  v_primary := app.primary_role();

  select jsonb_agg(
    jsonb_build_object('id', b.id, 'code', b.code, 'name', b.name, 'status', b.status)
    order by b.display_order
  )
  into v_branches
  from public.branches b
  where b.deleted_at is null
    and b.is_active
    and app.can_access_branch(b.id);

  return jsonb_build_object(
    'authenticated', true,
    'user_id', v_uid,
    'profile', case
      when v_profile.id is null then null
      else jsonb_build_object(
        'id', v_profile.id,
        'phone', v_profile.phone,
        'email', v_profile.email,
        'full_name', v_profile.full_name,
        'avatar_url', v_profile.avatar_url,
        'status', v_profile.status,
        'preferred_language', v_profile.preferred_language,
        'onboarding_completed', v_profile.onboarding_completed,
        'total_orders', v_profile.total_orders,
        'marketing_opt_in', v_profile.marketing_opt_in
      )
    end,
    'primary_role', v_primary,
    'roles', coalesce(v_roles, '[]'::jsonb),
    'permissions', to_jsonb(coalesce(v_permissions, '{}')),
    'branches', coalesce(v_branches, '[]'::jsonb),
    'account_active', coalesce(v_profile.status = 'ACTIVE', false)
  );
end;
$$;

comment on function public.my_session is
  'Single call returning identity, primary role, live permissions and branch scope.';

-- ═══════════════════════════════════════════════════════════════════════════
-- SIGNUP PIPELINE — auth.users → profiles + default role
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.tg_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_default_role uuid;
  v_referral text;
begin
  -- Unique, human-friendly referral code with a bounded retry loop.
  for i in 1 .. 5 loop
    v_referral := 'BB' || app.random_alnum_code(6);
    exit when not exists (select 1 from public.profiles where referral_code = v_referral);
    v_referral := null;
  end loop;

  insert into public.profiles (
    id, phone, email, full_name, referral_code, signup_channel
  )
  values (
    new.id,
    app.normalize_phone(coalesce(new.phone, new.raw_user_meta_data ->> 'phone')),
    nullif(new.email, ''),
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    v_referral,
    coalesce(new.raw_user_meta_data ->> 'signup_channel', 'mobile_app')
  )
  on conflict (id) do nothing;

  -- Every new account starts as a CUSTOMER. Staff roles are granted explicitly
  -- by an authorised operator; self-signup can never yield privilege.
  select id into v_default_role from public.roles where is_default limit 1;

  if v_default_role is not null then
    insert into public.user_roles (user_id, role_id, is_primary, assigned_by)
    values (new.id, v_default_role, true, new.id)
    on conflict do nothing;
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function app.tg_handle_new_user();

-- Keep profile contact details aligned when auth records change.
create or replace function app.tg_sync_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set phone = coalesce(app.normalize_phone(new.phone), phone),
      email = coalesce(nullif(new.email, ''), email),
      updated_at = now()
  where id = new.id;

  return new;
end;
$$;

create trigger on_auth_user_updated
  after update of phone, email on auth.users
  for each row execute function app.tg_sync_auth_user();

-- ═══════════════════════════════════════════════════════════════════════════
-- CUSTOM ACCESS TOKEN HOOK
-- Adds role/permission/branch claims so the admin UI and Flutter shells can
-- render instantly. Claims are advisory: RLS still verifies against the DB.
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function auth_hooks.custom_access_token(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_claims jsonb;
  v_roles text[];
  v_permissions text[];
  v_primary text;
  v_branches uuid[];
  v_status text;
begin
  v_user_id := (event ->> 'user_id')::uuid;
  v_claims := coalesce(event -> 'claims', '{}'::jsonb);

  select
    coalesce(array_agg(distinct r.code::text), '{}'),
    coalesce(array_remove(array_agg(distinct ur.branch_id), null), '{}')
  into v_roles, v_branches
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where ur.user_id = v_user_id
    and ur.is_active
    and (ur.expires_at is null or ur.expires_at > now());

  select coalesce(array_agg(distinct p.code), '{}')
  into v_permissions
  from public.user_roles ur
  join public.role_permissions rp on rp.role_id = ur.role_id
  join public.permissions p on p.id = rp.permission_id
  where ur.user_id = v_user_id
    and ur.is_active
    and (ur.expires_at is null or ur.expires_at > now());

  select r.code::text
  into v_primary
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where ur.user_id = v_user_id
    and ur.is_active
    and (ur.expires_at is null or ur.expires_at > now())
  order by ur.is_primary desc, r.rank desc
  limit 1;

  select status::text into v_status from public.profiles where id = v_user_id;

  v_claims := jsonb_set(v_claims, '{app_roles}', to_jsonb(coalesce(v_roles, '{}')));
  v_claims := jsonb_set(v_claims, '{app_permissions}', to_jsonb(coalesce(v_permissions, '{}')));
  v_claims := jsonb_set(v_claims, '{app_primary_role}', to_jsonb(coalesce(v_primary, 'CUSTOMER')));
  v_claims := jsonb_set(v_claims, '{app_branch_ids}', to_jsonb(coalesce(v_branches, '{}')));
  v_claims := jsonb_set(v_claims, '{app_account_status}', to_jsonb(coalesce(v_status, 'ACTIVE')));

  return jsonb_set(event, '{claims}', v_claims);
end;
$$;

grant usage on schema auth_hooks to supabase_auth_admin;
grant execute on function auth_hooks.custom_access_token(jsonb) to supabase_auth_admin;
revoke execute on function auth_hooks.custom_access_token(jsonb) from authenticated, anon, public;

grant select on public.user_roles, public.roles, public.role_permissions,
  public.permissions, public.profiles to supabase_auth_admin;

-- ═══════════════════════════════════════════════════════════════════════════
-- PRIVILEGE-ESCALATION GUARD
-- A user may only grant a role that ranks strictly below their own highest rank,
-- and only if they hold staff.create / staff.update.
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.tg_guard_role_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_actor_rank int;
  v_target_rank int;
begin
  -- Trusted server paths (Edge Functions, seeds, migrations) bypass the guard.
  if v_actor is null or app.is_service_role() then
    return new;
  end if;

  -- The signup trigger self-assigns the default CUSTOMER role.
  if new.user_id = v_actor and exists (
    select 1 from public.roles r where r.id = new.role_id and r.is_default
  ) then
    return new;
  end if;

  if not app.has_any_permission(array['staff.create', 'staff.update', 'role.assign']) then
    perform app.fail('PERMISSION_DENIED', 'You cannot assign roles.');
  end if;

  select coalesce(max(r.rank), -1) into v_actor_rank
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where ur.user_id = v_actor and ur.is_active;

  select rank into v_target_rank from public.roles where id = new.role_id;

  if v_target_rank >= v_actor_rank then
    perform app.fail(
      'PRIVILEGE_ESCALATION_BLOCKED',
      'You cannot grant a role at or above your own level.',
      jsonb_build_object('actor_rank', v_actor_rank, 'target_rank', v_target_rank)
    );
  end if;

  new.assigned_by := v_actor;
  return new;
end;
$$;

create trigger guard_role_assignment
  before insert or update on public.user_roles
  for each row execute function app.tg_guard_role_assignment();

-- ═══════════════════════════════════════════════════════════════════════════
-- SEED: permissions, roles and their mappings
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.permissions (code, resource, action, label, description, is_sensitive) values
  -- Menu
  ('menu.view',            'menu',      'view',    'View menu',                'Read categories, products, variants and modifiers.', false),
  ('menu.create',          'menu',      'create',  'Create menu items',        'Add categories, products, variants, modifiers.', false),
  ('menu.update',          'menu',      'update',  'Update menu items',        'Edit menu content and ordering.', false),
  ('menu.delete',          'menu',      'delete',  'Delete menu items',        'Soft-delete menu entities.', true),
  ('menu.price_update',    'menu',      'price',   'Change prices',            'Modify product or variant pricing.', true),
  ('menu.availability',    'menu',      'toggle',  'Toggle availability',      'Mark items available or out of stock.', false),
  -- Orders
  ('order.view',           'order',     'view',    'View orders',              'Read orders across the branch.', false),
  ('order.create',         'order',     'create',  'Create orders',            'Place an order (customer or manual).', false),
  ('order.accept',         'order',     'accept',  'Accept orders',            'Store acceptance of an incoming order.', false),
  ('order.reject',         'order',     'reject',  'Reject orders',            'Store rejection with a reason.', true),
  ('order.prepare',        'order',     'prepare', 'Start preparing',          'Move an order into preparation.', false),
  ('order.ready',          'order',     'ready',   'Mark ready',               'Mark an order ready for pickup.', false),
  ('order.cancel',         'order',     'cancel',  'Cancel orders',            'Cancel an order on behalf of the store.', true),
  ('order.override',       'order',     'override','Override order state',     'Force a status transition. Always audited.', true),
  ('order.note',           'order',     'note',    'Add internal notes',       'Attach internal notes to an order.', false),
  -- Delivery
  ('delivery.view',        'delivery',  'view',    'View deliveries',          'Read delivery assignments.', false),
  ('delivery.assign',      'delivery',  'assign',  'Assign riders',            'Assign or reassign a delivery partner.', false),
  ('delivery.pickup',      'delivery',  'pickup',  'Confirm pickup',           'Verify and confirm order pickup.', false),
  ('delivery.complete',    'delivery',  'complete','Complete delivery',        'Complete a delivery with OTP verification.', false),
  ('delivery.override',    'delivery',  'override','Override delivery',        'Complete delivery without OTP. Audited.', true),
  ('delivery.track',       'delivery',  'track',   'Track riders live',        'View live rider locations.', false),
  -- Riders
  ('rider.view',           'rider',     'view',    'View delivery partners',   'Read rider profiles and documents.', false),
  ('rider.create',         'rider',     'create',  'Onboard delivery partner', 'Create a rider record.', false),
  ('rider.update',         'rider',     'update',  'Update delivery partner',  'Edit rider details.', false),
  ('rider.approve',        'rider',     'approve', 'Approve delivery partner', 'Verify documents and activate a rider.', true),
  ('rider.suspend',        'rider',     'suspend', 'Suspend delivery partner', 'Suspend or reject a rider.', true),
  -- Payments & refunds
  ('payment.view',         'payment',   'view',    'View payments',            'Read payment records and gateway events.', false),
  ('payment.reconcile',    'payment',   'reconcile','Reconcile payments',      'Resolve mismatched gateway state.', true),
  ('payment.settings',     'payment',   'settings','Configure payments',       'Change gateway and COD configuration.', true),
  ('refund.view',          'refund',    'view',    'View refunds',             'Read refund records.', false),
  ('refund.create',        'refund',    'create',  'Request refunds',          'Raise a refund request.', true),
  ('refund.approve',       'refund',    'approve', 'Approve refunds',          'Approve and execute refunds.', true),
  ('refund.reject',        'refund',    'reject',  'Reject refunds',           'Decline a refund request.', true),
  -- Coupons & promotions
  ('coupon.view',          'coupon',    'view',    'View coupons',             'Read coupons and redemptions.', false),
  ('coupon.create',        'coupon',    'create',  'Create coupons',           'Create coupon codes.', false),
  ('coupon.update',        'coupon',    'update',  'Update coupons',           'Edit coupon rules.', true),
  ('coupon.delete',        'coupon',    'delete',  'Delete coupons',           'Deactivate or delete coupons.', true),
  ('promotion.manage',     'promotion', 'manage',  'Manage promotions',        'Create and edit automatic promotions.', false),
  -- Customers
  ('customer.view',        'customer',  'view',    'View customers',           'Read customer profiles and history.', false),
  ('customer.update',      'customer',  'update',  'Update customers',         'Edit customer details and notes.', false),
  ('customer.block',       'customer',  'block',   'Block customers',          'Block or unblock a customer.', true),
  ('customer.credit',      'customer',  'credit',  'Issue credit',             'Grant wallet credit or loyalty points.', true),
  -- Staff & roles
  ('staff.view',           'staff',     'view',    'View staff',               'Read staff records.', false),
  ('staff.create',         'staff',     'create',  'Create staff',             'Invite and create staff accounts.', true),
  ('staff.update',         'staff',     'update',  'Update staff',             'Edit staff records.', true),
  ('role.assign',          'role',      'assign',  'Assign roles',             'Grant or revoke user roles.', true),
  ('role.manage',          'role',      'manage',  'Manage roles',             'Edit role/permission mappings.', true),
  -- Support
  ('support.view',         'support',   'view',    'View support tickets',     'Read support tickets and messages.', false),
  ('support.respond',      'support',   'respond', 'Respond to tickets',       'Reply to and update tickets.', false),
  ('support.close',        'support',   'close',   'Close tickets',            'Resolve or close tickets.', false),
  -- Reviews
  ('review.view',          'review',    'view',    'View reviews',             'Read customer reviews.', false),
  ('review.moderate',      'review',    'moderate','Moderate reviews',         'Hide, flag or respond to reviews.', false),
  -- Notifications
  ('notification.send',    'notification','send',  'Send notifications',       'Send ad-hoc notifications.', false),
  ('notification.template','notification','template','Manage templates',       'Edit notification templates.', false),
  ('campaign.manage',      'campaign',  'manage',  'Manage campaigns',         'Create and run notification campaigns.', false),
  -- Analytics & reports
  ('analytics.view',       'analytics', 'view',    'View analytics',           'Read dashboards and KPIs.', false),
  ('report.view',          'report',    'view',    'View reports',             'Read operational and financial reports.', false),
  ('report.export',        'report',    'export',  'Export reports',           'Download report data.', true),
  ('finance.view',         'finance',   'view',    'View finance',             'Read revenue, settlement and tax data.', false),
  -- CMS
  ('cms.view',             'cms',       'view',    'View CMS',                 'Read homepage and content configuration.', false),
  ('cms.update',           'cms',       'update',  'Update CMS',               'Edit homepage sections, banners and policies.', false),
  -- Settings
  ('settings.view',        'settings',  'view',    'View settings',            'Read platform configuration.', false),
  ('settings.update',      'settings',  'update',  'Update settings',          'Change platform configuration.', true),
  ('branch.manage',        'branch',    'manage',  'Manage branch',            'Open/close branch, edit hours and zones.', true),
  ('feature_flag.update',  'feature_flag','update','Toggle feature flags',     'Enable or disable features.', true),
  -- Inventory
  ('inventory.view',       'inventory', 'view',    'View inventory',           'Read stock levels.', false),
  ('inventory.update',     'inventory', 'update',  'Update inventory',         'Adjust stock and thresholds.', false),
  -- Audit
  ('audit.view',           'audit',     'view',    'View audit log',           'Read the audit trail.', true),
  -- Kitchen
  ('kitchen.view',         'kitchen',   'view',    'View kitchen queue',       'Read the kitchen order queue.', false),
  ('kitchen.operate',      'kitchen',   'operate', 'Operate kitchen',          'Accept, prepare and complete orders.', false);

insert into public.roles (code, label, description, surfaces, is_default, rank) values
  ('CUSTOMER',         'Customer',         'Places orders through the mobile app.',                array['MOBILE_CUSTOMER']::public.role_surface[], true,  0),
  ('DELIVERY_PARTNER', 'Delivery Partner', 'Picks up and delivers orders.',                        array['MOBILE_DELIVERY']::public.role_surface[], false, 10),
  ('KITCHEN_STAFF',    'Kitchen Staff',    'Runs the kitchen queue and item availability.',        array['MOBILE_KITCHEN']::public.role_surface[],  false, 20),
  ('SUPPORT',          'Support Agent',    'Handles customer tickets and small goodwill refunds.', array['ADMIN_WEB']::public.role_surface[],       false, 30),
  ('MARKETING',        'Marketing',        'Runs coupons, promotions and campaigns.',              array['ADMIN_WEB']::public.role_surface[],       false, 30),
  ('FINANCE',          'Finance',          'Owns payments, refunds and financial reporting.',      array['ADMIN_WEB']::public.role_surface[],       false, 40),
  ('OPERATIONS',       'Operations',       'Runs live operations and rider dispatch.',             array['ADMIN_WEB']::public.role_surface[],       false, 40),
  ('MANAGER',          'Branch Manager',   'Full operational control of a branch.',                array['ADMIN_WEB', 'MOBILE_KITCHEN']::public.role_surface[], false, 60),
  ('ADMIN',            'Administrator',    'Platform administration except ownership transfer.',   array['ADMIN_WEB']::public.role_surface[],       false, 80),
  ('OWNER',            'Owner',            'Unrestricted access.',                                 array['ADMIN_WEB']::public.role_surface[],       false, 100);

-- OWNER holds every permission, now and in future.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r cross join public.permissions p where r.code = 'OWNER';

-- ADMIN: everything except role.manage (reserved for the owner).
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.code = 'ADMIN' and p.code <> 'role.manage';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.code = 'MANAGER'
  and p.code in (
    'menu.view','menu.create','menu.update','menu.availability','menu.price_update',
    'order.view','order.create','order.accept','order.reject','order.prepare','order.ready',
    'order.cancel','order.note',
    'delivery.view','delivery.assign','delivery.pickup','delivery.complete','delivery.track',
    'rider.view','rider.update',
    'payment.view','refund.view','refund.create',
    'coupon.view','promotion.manage',
    'customer.view','customer.update',
    'staff.view',
    'support.view','support.respond',
    'review.view','review.moderate',
    'notification.send',
    'analytics.view','report.view',
    'cms.view',
    'settings.view','branch.manage',
    'inventory.view','inventory.update',
    'kitchen.view','kitchen.operate'
  );

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.code = 'OPERATIONS'
  and p.code in (
    'menu.view','menu.availability',
    'order.view','order.create','order.accept','order.reject','order.prepare','order.ready',
    'order.cancel','order.note',
    'delivery.view','delivery.assign','delivery.pickup','delivery.complete','delivery.track',
    'rider.view','rider.update',
    'payment.view','refund.view','refund.create',
    'customer.view',
    'support.view','support.respond',
    'analytics.view','report.view',
    'kitchen.view','kitchen.operate',
    'inventory.view','inventory.update',
    'notification.send'
  );

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.code = 'FINANCE'
  and p.code in (
    'order.view',
    'payment.view','payment.reconcile',
    'refund.view','refund.create','refund.approve','refund.reject',
    'customer.view','customer.credit',
    'analytics.view','report.view','report.export','finance.view',
    'audit.view',
    'settings.view'
  );

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.code = 'SUPPORT'
  and p.code in (
    'menu.view',
    'order.view','order.note','order.cancel',
    'delivery.view','delivery.track',
    'payment.view','refund.view','refund.create',
    'customer.view','customer.update',
    'support.view','support.respond','support.close',
    'review.view',
    'notification.send'
  );

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.code = 'MARKETING'
  and p.code in (
    'menu.view',
    'coupon.view','coupon.create','coupon.update','coupon.delete',
    'promotion.manage',
    'customer.view',
    'campaign.manage','notification.send','notification.template',
    'cms.view','cms.update',
    'analytics.view','report.view',
    'review.view'
  );

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.code = 'KITCHEN_STAFF'
  and p.code in (
    'menu.view','menu.availability',
    'order.view','order.accept','order.reject','order.prepare','order.ready',
    'kitchen.view','kitchen.operate',
    'inventory.view','inventory.update'
  );

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.code = 'DELIVERY_PARTNER'
  and p.code in (
    'delivery.view','delivery.pickup','delivery.complete'
  );

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.code = 'CUSTOMER'
  and p.code in ('menu.view', 'order.create');
