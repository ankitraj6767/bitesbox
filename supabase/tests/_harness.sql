-- ═══════════════════════════════════════════════════════════════════════════
-- TEST HARNESS
--
-- A deliberately small, dependency-free assertion library.
--
-- pgTAP is available in the local image but is not installed on the hosted
-- project, and these tests need to run against both — a policy that passes
-- locally and fails in production is exactly the bug worth catching. Sixty lines
-- of plpgsql travels everywhere and needs no extension.
--
-- Style is fail-fast: an assertion raises, psql runs with ON_ERROR_STOP=1, and
-- the runner reports the file that broke. Suites are therefore kept small and
-- focused so the first failure still tells you where to look.
--
-- Impersonation matters more than assertion sugar here. Most of what needs
-- testing is "can this role see this row", so `tap.as_user` sets both the
-- Postgres role and the JWT claim that `auth.uid()` reads, which is what RLS
-- actually evaluates against.
-- ═══════════════════════════════════════════════════════════════════════════

create schema if not exists tap;

-- ─── Identity ───────────────────────────────────────────────────────────────

-- Become a signed-in user: Postgres role `authenticated` plus the JWT claim that
-- auth.uid() reads. Transaction-scoped, so a rollback restores the session.
create or replace function tap.as_user(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id::text, 'role', 'authenticated')::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

-- An anonymous visitor browsing the menu before sign-in.
create or replace function tap.as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  execute 'set local role anon';
end;
$$;

-- The service role, which bypasses RLS. Used to arrange fixtures, never to assert.
create or replace function tap.as_service()
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('role', 'service_role')::text,
    true
  );
  execute 'set local role service_role';
end;
$$;

-- Back to the migration owner, for arranging fixtures.
--
-- Deliberately NOT called as_owner: this is the database owner, which bypasses RLS
-- but carries no JWT, so app.has_permission is false for everything. Anything that
-- needs OWNER-role permissions must use tap.as_user(tap.seed('owner')).
create or replace function tap.reset()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- ─── Assertions ─────────────────────────────────────────────────────────────

create or replace function tap.ok(p_condition boolean, p_label text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'FAILED: %', p_label using errcode = 'triggered_action_exception';
  end if;

  raise notice '  ok  %', p_label;
end;
$$;

create or replace function tap.eq(p_actual anyelement, p_expected anyelement, p_label text)
returns void
language plpgsql
as $$
begin
  if p_actual is distinct from p_expected then
    raise exception 'FAILED: % — expected %, got %',
      p_label, coalesce(p_expected::text, 'null'), coalesce(p_actual::text, 'null')
      using errcode = 'triggered_action_exception';
  end if;

  raise notice '  ok  % (%)', p_label, coalesce(p_actual::text, 'null');
end;
$$;

-- Asserts that a statement fails with a specific business error code.
--
-- Every guard rail in this schema reports through `app.fail`, which puts the
-- stable machine code in the exception HINT. Matching on that rather than the
-- message means these tests do not break when customer-facing copy is reworded.
create or replace function tap.throws(
  p_sql text,
  p_expected_code text,
  p_label text
)
returns void
language plpgsql
as $$
declare
  v_hint text;
  v_message text;
begin
  begin
    execute p_sql;
  exception
    when others then
      get stacked diagnostics
        v_hint = pg_exception_hint,
        v_message = message_text;

      -- Privilege and RLS rejections arrive as SQLSTATE, not as app.fail.
      if p_expected_code = 'PERMISSION_DENIED'
         and (sqlstate in ('42501', '42P01') or v_hint = 'PERMISSION_DENIED') then
        raise notice '  ok  % (denied)', p_label;
        return;
      end if;

      if v_hint is distinct from p_expected_code then
        raise exception 'FAILED: % — expected code %, got % (%)',
          p_label, p_expected_code, coalesce(v_hint, sqlstate), v_message
          using errcode = 'triggered_action_exception';
      end if;

      raise notice '  ok  % (%)', p_label, p_expected_code;
      return;
  end;

  raise exception 'FAILED: % — expected % but the statement succeeded',
    p_label, p_expected_code
    using errcode = 'triggered_action_exception';
end;
$$;

-- Asserts that a statement is permitted. Re-raises the original error, because
-- "it should have worked" is only useful alongside the reason it did not.
create or replace function tap.no_throw(p_sql text, p_label text)
returns void
language plpgsql
as $$
declare
  v_message text;
  v_hint text;
begin
  begin
    execute p_sql;
  exception
    when others then
      get stacked diagnostics
        v_message = message_text,
        v_hint = pg_exception_hint;

      raise exception 'FAILED: % — unexpected % (%)',
        p_label, coalesce(v_hint, sqlstate), v_message
        using errcode = 'triggered_action_exception';
  end;

  raise notice '  ok  %', p_label;
end;
$$;

-- Row visibility under the current role. The workhorse of the RLS suite.
create or replace function tap.visible_count(p_sql text)
returns bigint
language plpgsql
as $$
declare
  v_count bigint;
begin
  execute format('select count(*) from (%s) as q', p_sql) into v_count;
  return v_count;
end;
$$;

-- ─── Scratch values ────────────────────────────────────────────────────────
--
-- Suites need to carry an id from one step to the next, but a temporary table
-- created by the owner is not readable once the suite switches to
-- `authenticated`, and granting on a per-session temp schema is fragile.
-- Transaction-scoped GUCs are visible to every role and vanish on rollback.
create or replace function tap.remember(p_key text, p_value text)
returns void
language sql
as $$
  select set_config('tap.' || p_key, coalesce(p_value, ''), true);
$$;

create or replace function tap.recall(p_key text)
returns text
language sql
stable
as $$
  select nullif(current_setting('tap.' || p_key, true), '');
$$;

create or replace function tap.recall_uuid(p_key text)
returns uuid
language sql
stable
as $$
  select tap.recall(p_key)::uuid;
$$;

create or replace function tap.recall_numeric(p_key text)
returns numeric
language sql
stable
as $$
  select tap.recall(p_key)::numeric;
$$;

-- ─── Seed identities ────────────────────────────────────────────────────────
--
-- A function rather than a temp table: the tests switch Postgres role constantly,
-- and a temp table created by the owner is not readable as `authenticated`.
-- These ids are fixed by supabase/seeds/40_users.sql.
create or replace function tap.seed(p_key text)
returns uuid
language sql
immutable
as $$
  select (case p_key
    -- Customers
    when 'customer_a'   then '91000000-0000-0000-0000-000000000001'
    when 'customer_b'   then '91000000-0000-0000-0000-000000000002'
    when 'customer_c'   then '91000000-0000-0000-0000-000000000003'
    when 'customer_d'   then '91000000-0000-0000-0000-000000000004'
    when 'customer_e'   then '91000000-0000-0000-0000-000000000005'
    -- Staff
    when 'owner'        then '90000000-0000-0000-0000-000000000001'
    when 'manager'      then '90000000-0000-0000-0000-000000000002'
    when 'operations'   then '90000000-0000-0000-0000-000000000003'
    when 'finance'      then '90000000-0000-0000-0000-000000000004'
    when 'support'      then '90000000-0000-0000-0000-000000000005'
    when 'marketing'    then '90000000-0000-0000-0000-000000000006'
    when 'kitchen'      then '90000000-0000-0000-0000-000000000201'
    when 'headchef'     then '90000000-0000-0000-0000-000000000301'
    -- Riders (auth user ids)
    when 'rider_rahul'  then '90000000-0000-0000-0000-000000000101'
    when 'rider_amit'   then '90000000-0000-0000-0000-000000000102'
    when 'rider_rohit'  then '90000000-0000-0000-0000-000000000103'
    when 'rider_suraj'  then '90000000-0000-0000-0000-000000000104'
    -- Delivery partner rows
    when 'dp_rahul'     then 'a1000000-0000-0000-0000-000000000001'
    when 'dp_amit'      then 'a1000000-0000-0000-0000-000000000002'
    when 'dp_rohit'     then 'a1000000-0000-0000-0000-000000000003'
    when 'dp_suraj'     then 'a1000000-0000-0000-0000-000000000004'
    -- Organisation
    when 'branch'       then '11111111-1111-1111-1111-111111111111'
    else null
  end)::uuid;
$$;

-- ─── Seed orders ────────────────────────────────────────────────────────────
--
-- Order numbers are generated by the sequence at seed time and embed the date:
-- `BB-BKP01-260820-00003`. Matching on the full string meant every suite broke the
-- day after it was written, which is exactly the kind of failure that teaches a
-- team to ignore a red build.
--
-- The trailing sequence is stable — seed order 3 is always `…-00003` — so that is
-- what these resolve on. The comments name what each one is for, matching
-- supabase/seeds/50_orders.sql.
--
--   1  DELIVERED, paid 566, reviewed
--   2  OUT_FOR_DELIVERY
--   3  ORDER_PLACED, COD, awaiting kitchen acceptance
--   4  PREPARING
--   5  READY_FOR_PICKUP, no rider
--   6  COMPLETED, self-pickup
--   7  REFUNDED (store rejected)
--   8  CUSTOMER_CANCELLED
--   9  PARTIALLY_REFUNDED (item refund to wallet)
--  10  PENDING_PAYMENT
create or replace function tap.seed_order(p_index int)
returns uuid
language sql
stable
as $$
  select o.id
  from public.orders o
  where o.order_number like '%-' || lpad(p_index::text, 5, '0')
  order by o.created_at
  limit 1;
$$;

comment on function tap.seed_order is
  'The nth seeded order, resolved by its sequence suffix so suites survive a date change.';

create or replace function tap.suite(p_name text)
returns void
language plpgsql
as $$
begin
  raise notice '';
  raise notice '── % ──', p_name;
end;
$$;

create or replace function tap.note(p_message text)
returns void
language plpgsql
as $$
begin
  raise notice '      %', p_message;
end;
$$;

create or replace function tap.done(p_name text)
returns void
language plpgsql
as $$
begin
  raise notice '── % passed ──', p_name;
end;
$$;

-- The harness is called while impersonating, so every role needs to reach it.
grant usage on schema tap to anon, authenticated, service_role;
grant execute on all functions in schema tap to anon, authenticated, service_role;
