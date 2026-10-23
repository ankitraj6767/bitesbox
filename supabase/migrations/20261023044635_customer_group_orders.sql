-- Collaborative ordering for a single Bites Box outlet. Each participant keeps
-- an ordinary server-priced cart; the host merges those lines through the same
-- cart RPC used by the customer app immediately before checkout.

create table public.group_orders (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  host_user_id uuid not null references auth.users (id) on delete cascade,
  host_cart_id uuid not null references public.carts (id) on delete cascade,
  invite_code text not null unique,
  status text not null default 'OPEN'
    check (status in ('OPEN', 'MERGED', 'CANCELLED')),
  expires_at timestamptz not null default (now() + interval '2 hours'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index group_orders_open_expiry_idx
  on public.group_orders (expires_at) where status = 'OPEN';

create table public.group_order_members (
  group_order_id uuid not null references public.group_orders (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  cart_id uuid not null references public.carts (id) on delete cascade,
  is_host boolean not null default false,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (group_order_id, user_id)
);

create index group_order_members_group_idx
  on public.group_order_members (group_order_id, joined_at)
  where left_at is null;

create unique index group_order_members_one_active_per_user
  on public.group_order_members (user_id) where left_at is null;

-- cart RPCs update the parent cart after touching its lines. Lock it before the
-- line mutation so a group merge can take a consistent snapshot while holding
-- the same parent-row lock.
create or replace function app.tg_lock_cart_for_item_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_cart_id uuid;
begin
  if tg_op = 'DELETE' then
    v_cart_id := old.cart_id;
  else
    v_cart_id := new.cart_id;
  end if;

  perform 1 from public.carts c where c.id = v_cart_id for update;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger cart_items_lock_parent_before_write
before insert or update or delete on public.cart_items
for each row execute function app.tg_lock_cart_for_item_mutation();

select app.attach_updated_at('public.group_orders');

comment on table public.group_orders is
  'Time-limited collaborative food orders. Participants add items to their own carts; the host controls checkout.';
comment on table public.group_order_members is
  'Membership and private cart binding for an open collaborative food order.';

alter table public.group_orders enable row level security;
alter table public.group_order_members enable row level security;
revoke all on table public.group_orders, public.group_order_members
  from anon, authenticated;

create or replace function public.group_order_create(p_branch_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_cart public.carts;
  v_group public.group_orders;
  v_expired_code text;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to start a group order.');
  end if;

  if not app.account_is_active() then
    perform app.fail('ACCOUNT_BLOCKED', 'This account cannot place orders. Please contact support.');
  end if;

  update public.group_order_members m
  set left_at = now()
  from public.group_orders g
  where m.group_order_id = g.id and m.user_id = v_uid and m.left_at is null
    and (g.status <> 'OPEN' or g.expires_at <= now());

  if exists (
    select 1 from public.group_order_members m
    join public.group_orders g on g.id = m.group_order_id
    where m.user_id = v_uid and m.left_at is null and g.status = 'OPEN'
      and g.expires_at > now()
  ) then
    perform app.fail('GROUP_ALREADY_ACTIVE', 'You already have an active group order.');
  end if;

  if not exists (
    select 1 from public.branches b
    where b.id = v_branch and b.is_active and b.deleted_at is null
  ) then
    perform app.fail('BRANCH_NOT_FOUND', 'This outlet is not available.');
  end if;

  v_cart := app.get_or_create_cart(v_uid, v_branch);

  loop
    v_expired_code := upper(pg_catalog.encode(extensions.gen_random_bytes(16), 'hex'));
    exit when not exists (
      select 1 from public.group_orders where invite_code = v_expired_code
    );
  end loop;

  insert into public.group_orders (branch_id, host_user_id, host_cart_id, invite_code)
  values (v_branch, v_uid, v_cart.id, v_expired_code)
  returning * into v_group;

  insert into public.group_order_members (group_order_id, user_id, cart_id, is_host)
  values (v_group.id, v_uid, v_cart.id, true);

  return jsonb_build_object('group_order_id', v_group.id, 'invite_code', v_group.invite_code);
end;
$$;

create or replace function public.group_order_join(p_invite_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_group public.group_orders;
  v_cart public.carts;
  v_existing public.group_order_members;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to join a group order.');
  end if;

  if not app.account_is_active() then
    perform app.fail('ACCOUNT_BLOCKED', 'This account cannot place orders. Please contact support.');
  end if;

  if p_invite_code is null or length(trim(p_invite_code)) < 24 then
    perform app.fail('GROUP_CODE_INVALID', 'Enter a valid group order code.');
  end if;

  select * into v_group
  from public.group_orders
  where invite_code = upper(trim(p_invite_code))
    and status = 'OPEN' and expires_at > now()
  for update;

  if not found then
    perform app.fail('GROUP_NOT_FOUND', 'That group order is closed or the code is incorrect.');
  end if;

  update public.group_order_members m
  set left_at = now()
  from public.group_orders g
  where m.group_order_id = g.id and m.user_id = v_uid and m.left_at is null
    and (g.status <> 'OPEN' or g.expires_at <= now());

  select * into v_existing
  from public.group_order_members
  where group_order_id = v_group.id and user_id = v_uid;
  if found then
    if v_existing.left_at is not null then
      perform app.fail('GROUP_ALREADY_LEFT', 'You have already left this group order.');
    end if;
    return jsonb_build_object('group_order_id', v_group.id);
  end if;

  if exists (
    select 1 from public.group_order_members m
    join public.group_orders g on g.id = m.group_order_id
    where m.user_id = v_uid and m.left_at is null and g.status = 'OPEN'
      and g.expires_at > now()
  ) then
    perform app.fail('GROUP_ALREADY_ACTIVE', 'Leave your current group order before joining another.');
  end if;

  v_cart := app.get_or_create_cart(v_uid, v_group.branch_id);

  if exists (select 1 from public.cart_items where cart_id = v_cart.id) then
    perform app.fail('GROUP_CART_NOT_EMPTY', 'Finish or clear your current cart before joining a group order.');
  end if;

  insert into public.group_order_members (group_order_id, user_id, cart_id)
  values (v_group.id, v_uid, v_cart.id);

  return jsonb_build_object('group_order_id', v_group.id);
end;
$$;

create or replace function public.group_order_detail(p_group_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_group public.group_orders;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to view a group order.');
  end if;

  select g.* into v_group
  from public.group_orders g
  join public.group_order_members m on m.group_order_id = g.id
  where g.id = p_group_order_id and m.user_id = v_uid and m.left_at is null;

  if not found then
    perform app.fail('GROUP_NOT_FOUND', 'This group order is no longer available to you.');
  end if;

  return jsonb_build_object(
    'id', v_group.id,
    'branch_id', v_group.branch_id,
    'status', case when v_group.status = 'OPEN' and v_group.expires_at <= now()
      then 'EXPIRED' else v_group.status end,
    'is_host', v_group.host_user_id = v_uid,
    'invite_code', case when v_group.host_user_id = v_uid then v_group.invite_code else null end,
    'expires_at', v_group.expires_at,
    'members', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', m.user_id,
        'name', coalesce(nullif(trim(p.display_name), ''), nullif(trim(p.full_name), ''), 'Guest'),
        'is_host', m.is_host,
        'item_count', coalesce((select sum(ci.quantity) from public.cart_items ci where ci.cart_id = m.cart_id), 0),
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', pr.name,
            'quantity', ci.quantity,
            'variant_name', pv.name,
            'modifiers', coalesce((
              select jsonb_agg(mod.name order by mod.name)
              from public.cart_item_modifiers cim
              join public.modifiers mod on mod.id = cim.modifier_id
              where cim.cart_item_id = ci.id
            ), '[]'::jsonb)
          ) order by ci.created_at, ci.id)
          from public.cart_items ci
          join public.products pr on pr.id = ci.product_id
          left join public.product_variants pv on pv.id = ci.variant_id
          where ci.cart_id = m.cart_id
        ), '[]'::jsonb)
      ) order by m.is_host desc, m.joined_at)
      from public.group_order_members m
      join public.profiles p on p.id = m.user_id
      where m.group_order_id = v_group.id and m.left_at is null
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.group_order_current()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_group_id uuid;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to view your group order.');
  end if;

  update public.group_order_members m
  set left_at = now()
  from public.group_orders g
  where m.group_order_id = g.id and m.user_id = v_uid and m.left_at is null
    and (g.status <> 'OPEN' or g.expires_at <= now());

  select m.group_order_id into v_group_id
  from public.group_order_members m
  join public.group_orders g on g.id = m.group_order_id
  where m.user_id = v_uid and m.left_at is null and g.status = 'OPEN'
    and g.expires_at > now()
  order by m.joined_at desc limit 1;

  if v_group_id is null then return null; end if;
  return public.group_order_detail(v_group_id);
end;
$$;

create or replace function public.group_order_leave(p_group_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_member public.group_order_members;
  v_group public.group_orders;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to leave a group order.');
  end if;

  select * into v_group
  from public.group_orders
  where id = p_group_order_id
  for update;

  if not found or v_group.status <> 'OPEN' or v_group.expires_at <= now() then
    perform app.fail('GROUP_NOT_FOUND', 'This group order is no longer available.');
  end if;

  select m.* into v_member
  from public.group_order_members m
  join public.group_orders g on g.id = m.group_order_id
  where m.group_order_id = p_group_order_id and m.user_id = v_uid
    and m.left_at is null and g.status = 'OPEN' and g.expires_at > now();

  if not found then
    perform app.fail('GROUP_NOT_FOUND', 'This group order is no longer available.');
  end if;
  if v_member.is_host then
    perform app.fail('GROUP_HOST_CANNOT_LEAVE', 'The host must close this group order.');
  end if;

  update public.group_order_members
  set left_at = now()
  where group_order_id = p_group_order_id and user_id = v_uid and left_at is null;

  return jsonb_build_object('left', true);
end;
$$;

create or replace function public.group_order_close(p_group_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_group public.group_orders;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to close a group order.');
  end if;

  select * into v_group
  from public.group_orders
  where id = p_group_order_id
  for update;

  if not found or v_group.host_user_id <> v_uid then
    perform app.fail('PERMISSION_DENIED', 'Only the host can close this group order.');
  end if;
  if v_group.status <> 'OPEN' then
    perform app.fail('GROUP_CLOSED', 'This group order is already closed.');
  end if;

  update public.group_orders set status = 'CANCELLED' where id = v_group.id;
  update public.group_order_members set left_at = now()
    where group_order_id = v_group.id and left_at is null;

  return jsonb_build_object('closed', true);
end;
$$;

create or replace function public.group_order_merge(p_group_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_group public.group_orders;
  v_member record;
  v_item record;
  v_modifiers jsonb;
  v_imported int := 0;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to check out a group order.');
  end if;

  select * into v_group
  from public.group_orders
  where id = p_group_order_id
  for update;

  if not found or v_group.host_user_id <> v_uid then
    perform app.fail('PERMISSION_DENIED', 'Only the group host can prepare checkout.');
  end if;
  if v_group.status <> 'OPEN' or v_group.expires_at <= now() then
    perform app.fail('GROUP_CLOSED', 'This group order has expired or is already closed.');
  end if;
  if not exists (
    select 1 from public.carts c
    where c.id = v_group.host_cart_id and c.user_id = v_uid and c.branch_id = v_group.branch_id
      and c.is_active and c.converted_order_id is null
  ) then
    perform app.fail('GROUP_HOST_CART_CLOSED', 'Start a new group order from your active cart.');
  end if;

  -- Cart mutations and group joins acquire these same row locks, so the merge
  -- includes a consistent snapshot of every participant's latest contribution.
  perform 1 from public.carts c
  join public.group_order_members m on m.cart_id = c.id
  where m.group_order_id = v_group.id and m.left_at is null
  order by c.id
  for update of c;

  for v_member in
    select m.cart_id
    from public.group_order_members m
    where m.group_order_id = v_group.id and m.left_at is null and not m.is_host
    order by m.joined_at
  loop
    for v_item in
      select ci.id, ci.product_id, ci.variant_id, ci.quantity, ci.special_instructions
      from public.cart_items ci where ci.cart_id = v_member.cart_id
      order by ci.created_at, ci.id
      for update
    loop
      select coalesce(jsonb_agg(jsonb_build_object(
        'modifier_id', cim.modifier_id, 'quantity', cim.quantity
      ) order by cim.modifier_id), '[]'::jsonb)
      into v_modifiers
      from public.cart_item_modifiers cim where cim.cart_item_id = v_item.id;

      perform public.cart_add_item(
        v_item.product_id,
        v_item.variant_id,
        v_item.quantity,
        v_modifiers,
        v_item.special_instructions,
        v_group.branch_id,
        false
      );
      v_imported := v_imported + 1;
    end loop;

    delete from public.cart_items where cart_id = v_member.cart_id;
    update public.carts
    set coupon_id = null, coupon_code = null, use_wallet = false, updated_at = now()
    where id = v_member.cart_id;
  end loop;

  update public.group_orders set status = 'MERGED' where id = v_group.id;
  update public.group_order_members set left_at = now()
    where group_order_id = v_group.id and left_at is null;

  return jsonb_build_object('merged', true, 'imported_lines', v_imported);
end;
$$;

revoke all on function public.group_order_create(uuid) from public, anon, authenticated;
revoke all on function public.group_order_join(text) from public, anon, authenticated;
revoke all on function public.group_order_detail(uuid) from public, anon, authenticated;
revoke all on function public.group_order_current() from public, anon, authenticated;
revoke all on function public.group_order_leave(uuid) from public, anon, authenticated;
revoke all on function public.group_order_close(uuid) from public, anon, authenticated;
revoke all on function public.group_order_merge(uuid) from public, anon, authenticated;

grant execute on function public.group_order_create(uuid) to authenticated;
grant execute on function public.group_order_join(text) to authenticated;
grant execute on function public.group_order_detail(uuid) to authenticated;
grant execute on function public.group_order_current() to authenticated;
grant execute on function public.group_order_leave(uuid) to authenticated;
grant execute on function public.group_order_close(uuid) to authenticated;
grant execute on function public.group_order_merge(uuid) to authenticated;

-- Shift the default storefront from the former chilli-red palette to a modern
-- orange and slate food-commerce palette. Keep any operator-customised values.
update public.settings s
set value = v.new_value
from (values
  ('brand.color_primary', '"#C1121F"'::jsonb, '"#FC8019"'::jsonb),
  ('brand.color_primary_dark', '"#8E0D17"'::jsonb, '"#E86C0A"'::jsonb),
  ('brand.color_secondary', '"#1B4332"'::jsonb, '"#3D4152"'::jsonb),
  ('brand.color_accent', '"#F0A202"'::jsonb, '"#F7A552"'::jsonb),
  ('brand.color_background', '"#FFFBF6"'::jsonb, '"#F3F3F5"'::jsonb),
  ('brand.color_success', '"#1B7F4B"'::jsonb, '"#1BA672"'::jsonb),
  ('brand.color_warning', '"#B45309"'::jsonb, '"#CF8700"'::jsonb),
  ('brand.color_error', '"#B3261E"'::jsonb, '"#E85D5D"'::jsonb),
  ('brand.color_text_primary', '"#1A1614"'::jsonb, '"#282C3F"'::jsonb),
  ('brand.color_text_secondary', '"#6B625C"'::jsonb, '"#686B78"'::jsonb)
) as v(key, old_value, new_value)
where s.key = v.key and s.value = v.old_value;
