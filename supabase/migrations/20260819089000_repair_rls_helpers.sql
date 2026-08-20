-- ═══════════════════════════════════════════════════════════════════════════
-- 0028a · REPAIR: RLS helper functions missing on the hosted project
--
-- `supabase db push` failed on the first pending migration:
--
--   Applying migration 20260819090000_security_and_storage_hardening.sql...
--   ERROR: function app.owns_order(uuid) does not exist (SQLSTATE 42883)
--   At statement: grant execute on function app.owns_order(uuid) to anon
--
-- `app.owns_order` is created in `20260815002100_rls.sql`, which the remote
-- records as applied. Comparing a `supabase db dump -s app` of the remote against
-- the local schema showed three functions from that file genuinely absent:
--
--   app.is_rider_for_order   app.owns_order   app.order_branch
--
-- (121 app functions locally, 108 remotely. The other ten are created by the
-- pending migrations, so their absence is expected.)
--
-- The cause is an already-applied migration file having been edited afterwards.
-- Migration history records a filename and a checksum-free version marker, so a
-- later edit is invisible to `migration list` — local and remote both report
-- `20260815002100` and look identical, while the remote is running whatever the
-- file said the day it was pushed.
--
-- Editing `20260815002100_rls.sql` again would not help: it will never re-run on a
-- database that has already recorded it. The only forward path is a new migration,
-- which is what this is.
--
-- It is timestamped `…089000`, one step before `…090000`, because `db push` applies
-- pending migrations in filename order and the failing GRANT is in `090000`.
--
-- Definitions are copied verbatim from `20260815002100_rls.sql`. `create or
-- replace` makes this a no-op on any database that already has them, including
-- every local stack — so it is safe to keep in the history permanently rather than
-- being a one-off script that has to be remembered.
--
-- Why these three matter: they are what stops RLS recursing. `orders` and
-- `delivery_assignments` each have a policy that needs to ask about the other, and
-- a plain subquery would trigger "infinite recursion detected in policy". Reading
-- through a SECURITY DEFINER helper bypasses RLS for that one question. Without
-- them, the policies in `20260815002100` that reference them cannot have been
-- created either — see the note at the end.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function app.is_rider_for_order(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.delivery_assignments da
    join public.delivery_partners dp on dp.id = da.delivery_partner_id
    where da.order_id = p_order_id
      and dp.user_id = auth.uid()
      and da.status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER', 'COMPLETED')
  );
$$;

comment on function app.is_rider_for_order is
  'True when the caller is the delivery partner on this order. SECURITY DEFINER to break RLS recursion.';

create or replace function app.owns_order(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.orders o
    where o.id = p_order_id and o.user_id = auth.uid()
  );
$$;

comment on function app.owns_order is
  'True when the caller placed this order.';

create or replace function app.order_branch(p_order_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select o.branch_id from public.orders o where o.id = p_order_id;
$$;

comment on function app.order_branch is
  'The branch an order belongs to, read past RLS so a policy can scope on it.';

-- The grants that `20260815002200_grants_realtime.sql` makes. Repeated here for the
-- same reason as the functions: that migration is recorded as applied, so its
-- grants for these three never ran on the remote and never will.
grant execute on function app.is_rider_for_order(uuid) to authenticated;
grant execute on function app.owns_order(uuid) to authenticated;
grant execute on function app.order_branch(uuid) to authenticated;

-- ─── Policies from 20260815002100 that depend on these helpers ──────────────
--
-- A policy body is resolved when the policy is created, so any policy in that
-- migration referencing a then-nonexistent function would have failed outright —
-- meaning the remote's copy of that file predates the helpers entirely and is
-- missing those policies too.
--
-- Rather than guess which ones, this migration deliberately stops at the
-- functions. Restoring policies is not idempotent in the way `create or replace
-- function` is, and inventing `drop policy if exists` / `create policy` pairs for a
-- set I cannot see would risk widening access on a live database.
--
-- The check is mechanical: after this migration and the rest of the pending batch
-- land, compare policy counts. Local is 143 in `public` and 15 in `storage`.
--
--   select count(*) from pg_policies where schemaname = 'public';
--
-- A shortfall means the remote also lost policies to the same edited-migration
-- problem, and the honest remedy at that point is `supabase db reset --linked`,
-- which rebuilds the remote from the migration history so that local and remote
-- are provably identical. That is destructive and belongs to whoever owns the data.
