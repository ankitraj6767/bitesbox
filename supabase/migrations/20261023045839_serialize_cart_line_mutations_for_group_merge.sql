-- Group merges lock participant cart rows before reading or clearing lines.
-- Ordinary cart mutations must acquire the same parent lock before touching a
-- cart_items row, so concurrent quantity edits cannot invert lock order.
create or replace function app.get_or_create_cart(
  p_user_id uuid,
  p_branch_id uuid default null
)
returns public.carts
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_cart public.carts;
begin
  select * into v_cart
  from public.carts
  where user_id = p_user_id and branch_id = v_branch and is_active
  for update;

  if found then
    return v_cart;
  end if;

  insert into public.carts (user_id, branch_id)
  values (p_user_id, v_branch)
  on conflict (user_id, branch_id) where is_active do update
    set updated_at = now()
  returning * into v_cart;

  return v_cart;
end;
$$;

create or replace function public.cart_update_item(
  p_cart_item_id uuid,
  p_quantity smallint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cart_id uuid;
  v_max smallint;
  v_name text;
begin
  select c.id, p.max_quantity_per_order, p.name
  into v_cart_id, v_max, v_name
  from public.cart_items ci
  join public.carts c on c.id = ci.cart_id
  join public.products p on p.id = ci.product_id
  where ci.id = p_cart_item_id and c.user_id = v_uid and c.is_active
  for update of c;

  if v_cart_id is null then
    perform app.fail('CART_ITEM_NOT_FOUND', 'That item is no longer in your cart.');
  end if;

  if p_quantity <= 0 then
    delete from public.cart_items where id = p_cart_item_id;
  else
    if v_max is not null and p_quantity > v_max then
      perform app.fail(
        'QUANTITY_LIMIT_EXCEEDED',
        format('You can order up to %s of %s.', v_max, v_name)
      );
    end if;

    update public.cart_items
    set quantity = p_quantity, updated_at = now()
    where id = p_cart_item_id;
  end if;

  update public.carts set updated_at = now() where id = v_cart_id;

  return app.calculate_checkout(v_uid, v_cart_id);
end;
$$;
