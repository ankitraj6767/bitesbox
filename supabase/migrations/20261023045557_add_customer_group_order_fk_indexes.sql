-- Cover every new group-order foreign key so joins and cascading cleanup stay
-- efficient as a single outlet accumulates group-order history.
create index group_orders_branch_idx
  on public.group_orders (branch_id);

create index group_orders_host_user_idx
  on public.group_orders (host_user_id);

create index group_orders_host_cart_idx
  on public.group_orders (host_cart_id);

create index group_order_members_cart_idx
  on public.group_order_members (cart_id);
