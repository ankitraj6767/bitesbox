-- ═══════════════════════════════════════════════════════════════════════════
-- 0001 · FOUNDATION
-- Extensions, internal schemas, shared domains, conventions and helpers.
--
-- Conventions used across every Bites Box migration:
--   · UUID primary keys (gen_random_uuid())
--   · created_at / updated_at timestamptz not null default now()
--   · created_by / updated_by uuid references auth.users on privileged tables
--   · deleted_at timestamptz for soft deletion (partial unique indexes exclude it)
--   · money  -> numeric(12,2)   NEVER float
--   · rates  -> numeric(6,4)
--   · All business writes go through SECURITY DEFINER functions or Edge Functions
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Extensions ────────────────────────────────────────────────────────────
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;
create extension if not exists btree_gist with schema extensions;
create extension if not exists pg_stat_statements with schema extensions;

-- ─── Internal schemas ──────────────────────────────────────────────────────
-- `app`        : private business logic + helpers. NOT exposed through the Data API.
-- `auth_hooks` : Supabase Auth hook surface, callable only by supabase_auth_admin.
-- `analytics`  : reporting views/materialised views consumed by the admin dashboard.
create schema if not exists app;
create schema if not exists auth_hooks;
create schema if not exists analytics;

comment on schema app is 'Private Bites Box business logic. Never added to api.schemas.';
comment on schema auth_hooks is 'Supabase Auth hook functions. Executable only by supabase_auth_admin.';
comment on schema analytics is 'Reporting views for the admin dashboard.';

revoke all on schema app from anon, authenticated;
revoke all on schema auth_hooks from anon, authenticated;
grant usage on schema analytics to authenticated;

-- ─── Money & rate domains ──────────────────────────────────────────────────
-- Enforced non-negative money. Financial values are always exact numerics.
create domain app.money as numeric(12, 2)
  constraint money_non_negative check (value >= 0);

-- Signed money for ledger entries and adjustments.
create domain app.money_signed as numeric(12, 2);

create domain app.rate as numeric(6, 4)
  constraint rate_range check (value >= 0 and value <= 1);

create domain app.percent as numeric(6, 3)
  constraint percent_range check (value >= 0 and value <= 100);

-- Indian mobile number in E.164 (+91XXXXXXXXXX). Normalised before insert.
create domain app.phone as text
  constraint phone_e164 check (value ~ '^\+[1-9][0-9]{7,14}$');

create domain app.email as text
  constraint email_shape check (value ~* '^[^@\s]+@[^@\s]+\.[a-z]{2,}$');

create domain app.slug as text
  constraint slug_shape check (value ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$');

create domain app.latitude as numeric(10, 7)
  constraint latitude_range check (value >= -90 and value <= 90);

create domain app.longitude as numeric(10, 7)
  constraint longitude_range check (value >= -180 and value <= 180);

-- ─── updated_at maintenance ────────────────────────────────────────────────
create or replace function app.tg_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function app.tg_set_updated_at is 'BEFORE UPDATE trigger: stamps updated_at.';

-- Attaches the updated_at trigger to a table. Keeps migrations terse and uniform.
create or replace function app.attach_updated_at(p_table regclass)
returns void
language plpgsql
as $$
declare
  v_name text := 'set_updated_at';
begin
  execute format(
    'drop trigger if exists %I on %s',
    v_name, p_table::text
  );
  execute format(
    'create trigger %I before update on %s for each row execute function app.tg_set_updated_at()',
    v_name, p_table::text
  );
end;
$$;

-- ─── Immutability guard ────────────────────────────────────────────────────
-- Used on ledger / event / history tables that must never be rewritten.
create or replace function app.tg_block_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Table %.% is append-only; % is not permitted.',
    tg_table_schema, tg_table_name, tg_op
    using errcode = 'restrict_violation';
end;
$$;

create or replace function app.make_append_only(p_table regclass)
returns void
language plpgsql
as $$
begin
  execute format('drop trigger if exists block_mutation on %s', p_table::text);
  execute format(
    'create trigger block_mutation before update or delete on %s for each row execute function app.tg_block_mutation()',
    p_table::text
  );
end;
$$;

-- ─── Text utilities ────────────────────────────────────────────────────────
create or replace function app.slugify(p_input text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select trim(both '-' from
    regexp_replace(
      regexp_replace(lower(extensions.unaccent(p_input)), '[^a-z0-9]+', '-', 'g'),
      '-{2,}', '-', 'g'
    )
  );
$$;

comment on function app.slugify is 'URL-safe slug: unaccented, lowercased, hyphen separated.';

-- Normalises an Indian-first phone number to E.164.
create or replace function app.normalize_phone(p_input text, p_default_cc text default '91')
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_digits text;
begin
  if p_input is null then
    return null;
  end if;

  v_digits := regexp_replace(p_input, '[^0-9]', '', 'g');

  if v_digits = '' then
    return null;
  end if;

  -- Strip Indian trunk prefix (0XXXXXXXXXX)
  if length(v_digits) = 11 and left(v_digits, 1) = '0' then
    v_digits := right(v_digits, 10);
  end if;

  if length(v_digits) = 10 then
    v_digits := p_default_cc || v_digits;
  end if;

  return '+' || v_digits;
end;
$$;

-- ─── Geo utilities ─────────────────────────────────────────────────────────
-- Great-circle distance in kilometres. Pure SQL keeps PostGIS optional; delivery
-- zone polygons use the point-in-polygon helper below.
create or replace function app.haversine_km(
  p_lat1 numeric, p_lng1 numeric,
  p_lat2 numeric, p_lng2 numeric
)
returns numeric
language sql
immutable
strict
set search_path = ''
as $$
  select round(
    (6371 * 2 * asin(
      sqrt(
        power(sin(radians(p_lat2 - p_lat1) / 2), 2) +
        cos(radians(p_lat1)) * cos(radians(p_lat2)) *
        power(sin(radians(p_lng2 - p_lng1) / 2), 2)
      )
    ))::numeric,
    3
  );
$$;

comment on function app.haversine_km is 'Great-circle distance between two WGS84 points, in km.';

-- Ray-casting point-in-polygon over a GeoJSON-style ring: [[lng,lat],[lng,lat],...]
create or replace function app.point_in_ring(
  p_lat numeric,
  p_lng numeric,
  p_ring jsonb
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_count int;
  v_inside boolean := false;
  i int;
  j int;
  xi numeric; yi numeric;
  xj numeric; yj numeric;
begin
  if p_ring is null or jsonb_typeof(p_ring) <> 'array' then
    return false;
  end if;

  v_count := jsonb_array_length(p_ring);
  if v_count < 3 then
    return false;
  end if;

  j := v_count - 1;
  for i in 0 .. v_count - 1 loop
    xi := (p_ring -> i -> 0)::numeric;  -- longitude
    yi := (p_ring -> i -> 1)::numeric;  -- latitude
    xj := (p_ring -> j -> 0)::numeric;
    yj := (p_ring -> j -> 1)::numeric;

    if ((yi > p_lat) <> (yj > p_lat))
       and (p_lng < (xj - xi) * (p_lat - yi) / nullif(yj - yi, 0) + xi) then
      v_inside := not v_inside;
    end if;

    j := i;
  end loop;

  return v_inside;
end;
$$;

-- ─── Money helpers ─────────────────────────────────────────────────────────
-- Rupee amounts are stored as numeric(12,2); Razorpay works in paise (integer).
create or replace function app.to_paise(p_amount numeric)
returns bigint
language sql
immutable
strict
set search_path = ''
as $$
  select round(p_amount * 100)::bigint;
$$;

create or replace function app.from_paise(p_paise bigint)
returns numeric
language sql
immutable
strict
set search_path = ''
as $$
  select round(p_paise::numeric / 100, 2);
$$;

-- Banker-safe rupee rounding used by the pricing engine.
create or replace function app.money_round(p_amount numeric)
returns numeric
language sql
immutable
strict
set search_path = ''
as $$
  select round(p_amount, 2);
$$;

-- ─── Random codes (OTP, referral, pickup) ──────────────────────────────────
create or replace function app.random_numeric_code(p_length int default 4)
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_code text := '';
  i int;
begin
  for i in 1 .. p_length loop
    -- gen_random_bytes gives us CSPRNG material rather than predictable random()
    v_code := v_code || (get_byte(extensions.gen_random_bytes(1), 0) % 10)::text;
  end loop;
  return v_code;
end;
$$;

create or replace function app.random_alnum_code(p_length int default 8)
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  -- Crockford-ish alphabet: no I, L, O, U, 0, 1 to avoid human transcription errors
  v_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTVWXYZ';
  v_code text := '';
  i int;
begin
  for i in 1 .. p_length loop
    v_code := v_code || substr(
      v_alphabet,
      (get_byte(extensions.gen_random_bytes(1), 0) % length(v_alphabet)) + 1,
      1
    );
  end loop;
  return v_code;
end;
$$;

-- OTPs are stored only as salted hashes; the plaintext exists solely in transit.
create or replace function app.hash_code(p_code text, p_salt text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  -- `digest` comes from pgcrypto (extensions schema); `encode` is a builtin.
  select pg_catalog.encode(
    extensions.digest(p_salt || ':' || p_code, 'sha256'),
    'hex'
  );
$$;

-- ─── Standard error raising ────────────────────────────────────────────────
-- Every business failure surfaces a stable machine code the clients map to
-- localised, customer-friendly copy. See docs/errors.md.
create or replace function app.fail(
  p_code text,
  p_message text default null,
  p_detail jsonb default null
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception '%', coalesce(p_message, p_code)
    using
      errcode = 'P0001',
      detail  = coalesce(p_detail, '{}'::jsonb)::text,
      hint    = p_code;
end;
$$;

comment on function app.fail is
  'Raises a business error. HINT carries the stable error code (e.g. COUPON_EXPIRED).';

-- ─── Request context ───────────────────────────────────────────────────────
-- Edge Functions forward client metadata via `set_config`, letting audit rows
-- capture IP/device without trusting them for authorisation.
create or replace function app.request_ip()
returns inet
language plpgsql
stable
set search_path = ''
as $$
declare
  v_headers json;
  v_ip text;
begin
  begin
    v_headers := current_setting('request.headers', true)::json;
  exception when others then
    return null;
  end;

  if v_headers is null then
    return null;
  end if;

  v_ip := coalesce(
    split_part(v_headers ->> 'x-forwarded-for', ',', 1),
    v_headers ->> 'cf-connecting-ip',
    v_headers ->> 'x-real-ip'
  );

  if v_ip is null or btrim(v_ip) = '' then
    return null;
  end if;

  return btrim(v_ip)::inet;
exception when others then
  return null;
end;
$$;

create or replace function app.request_user_agent()
returns text
language sql
stable
set search_path = ''
as $$
  select nullif(
    (nullif(current_setting('request.headers', true), '')::json) ->> 'user-agent',
    ''
  );
$$;

-- Reads a JWT claim without assuming the claim exists.
create or replace function app.jwt_claim(p_key text)
returns text
language sql
stable
set search_path = ''
as $$
  select nullif(
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb) ->> p_key,
    ''
  );
$$;

create or replace function app.is_service_role()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(app.jwt_claim('role') = 'service_role', false);
$$;

comment on function app.is_service_role is
  'True when the request uses the service key (Edge Functions / trusted server code).';
