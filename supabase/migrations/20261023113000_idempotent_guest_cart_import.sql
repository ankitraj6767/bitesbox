-- Move a browser guest cart to its verified customer account as one atomic,
-- retryable operation. Prices and availability are never accepted from a client.
create table public.guest_cart_imports (
  user_id uuid not null references auth.users (id) on delete cascade,
  idempotency_key uuid not null,
  branch_id uuid not null references public.branches (id) on delete restrict,
  payload_hash text not null,
  result jsonb,
  created_at timestamptz not null default now(),
  primary key (user_id, idempotency_key)
);

alter table public.guest_cart_imports enable row level security;
revoke all on public.guest_cart_imports from public, anon, authenticated;

create or replace function public.import_guest_cart(
  p_idempotency_key uuid,
  p_branch_id uuid,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_line jsonb;
  v_existing public.guest_cart_imports;
  v_count int := 0;
  v_hash text;
  v_result jsonb;
  v_product_id uuid;
  v_variant_id uuid;
  v_quantity smallint;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in before importing a saved cart.');
  end if;
  if not app.account_is_active() or not exists (
    select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id
    where ur.user_id = v_uid and ur.is_active and r.code = 'CUSTOMER'
  ) then
    perform app.fail('PERMISSION_DENIED', 'This account cannot import a customer cart.');
  end if;
  if p_idempotency_key is null or p_branch_id is null or p_lines is null then
    perform app.fail('INVALID_GUEST_CART', 'The saved cart is invalid. Review its items and try again.');
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' then
    perform app.fail('INVALID_GUEST_CART', 'The saved cart is invalid. Review its items and try again.');
  end if;
  if jsonb_array_length(p_lines) < 1 or jsonb_array_length(p_lines) > 50 then
    perform app.fail('INVALID_GUEST_CART', 'The saved cart is invalid. Review its items and try again.');
  end if;
  if not exists (
    select 1 from public.branches b
    where b.id = p_branch_id and b.is_active and b.deleted_at is null
  ) then
    perform app.fail('BRANCH_UNAVAILABLE', 'This outlet is no longer available.');
  end if;

  -- Serialize retries for the same account/key. If the response was lost after
  -- commit, the same payload returns its recorded result without adding again.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_uid::text || ':' || p_idempotency_key::text, 0)
  );
  v_hash := pg_catalog.md5(p_lines::text);
  select * into v_existing from public.guest_cart_imports
  where user_id = v_uid and idempotency_key = p_idempotency_key for update;
  if found then
    if v_existing.branch_id <> p_branch_id or v_existing.payload_hash <> v_hash then
      perform app.fail('IDEMPOTENCY_KEY_REUSED', 'This saved cart was already imported with different contents.');
    end if;
    return coalesce(v_existing.result, jsonb_build_object(
      'imported', true, 'line_count', 0, 'branch_id', p_branch_id, 'replayed', true
    ));
  end if;

  insert into public.guest_cart_imports (user_id, idempotency_key, branch_id, payload_hash)
  values (v_uid, p_idempotency_key, p_branch_id, v_hash);

  for v_line in select value from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(v_line) <> 'object'
       or jsonb_typeof(v_line -> 'product_id') <> 'string'
       or jsonb_typeof(v_line -> 'quantity') <> 'number'
       or (v_line ? 'modifiers' and jsonb_typeof(v_line -> 'modifiers') <> 'array')
       or coalesce(length(v_line ->> 'special_instructions'), 0) > 240
       or coalesce((v_line ->> 'quantity') !~ '^[1-9][0-9]*$', true) then
      perform app.fail('INVALID_GUEST_CART', 'The saved cart contains an invalid item.');
    end if;
    v_product_id := (v_line ->> 'product_id')::uuid;
    v_variant_id := nullif(v_line ->> 'variant_id', '')::uuid;
    v_quantity := (v_line ->> 'quantity')::smallint;
    if v_quantity < 1 or v_quantity > 100 then
      perform app.fail('INVALID_GUEST_CART', 'The saved cart contains an invalid quantity.');
    end if;

    -- cart_add_item rechecks product, variant, modifier, quantity and outlet
    -- eligibility. It also computes prices using the server's current catalogue.
    perform public.cart_add_item(
      p_product_id => v_product_id,
      p_variant_id => v_variant_id,
      p_quantity => v_quantity,
      p_modifiers => coalesce(v_line -> 'modifiers', '[]'::jsonb),
      p_special_instructions => nullif(v_line ->> 'special_instructions', ''),
      p_branch_id => p_branch_id,
      p_replace_quantity => false
    );
    v_count := v_count + 1;
  end loop;

  v_result := jsonb_build_object(
    'imported', true, 'line_count', v_count, 'branch_id', p_branch_id, 'replayed', false
  );
  update public.guest_cart_imports set result = v_result
  where user_id = v_uid and idempotency_key = p_idempotency_key;
  return v_result;
end;
$$;

revoke all on function public.import_guest_cart(uuid, uuid, jsonb) from public, anon;
grant execute on function public.import_guest_cart(uuid, uuid, jsonb) to authenticated;
