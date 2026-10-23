-- Make order-level food ratings visible on the products customers purchased.
-- Explicit per-item ratings supplied by newer clients remain authoritative.

create or replace function app.refresh_product_review_aggregate(p_product_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.products p
  set rating_count = aggregate.rating_count,
      rating_average = aggregate.rating_average,
      updated_at = now()
  from (
    select count(*)::int as rating_count,
           coalesce(round(avg(ri.rating)::numeric, 2), 0) as rating_average
    from public.review_items ri
    join public.reviews r on r.id = ri.review_id
    where ri.product_id = p_product_id
      and r.status = 'PUBLISHED'
  ) aggregate
  where p.id = p_product_id;
$$;

revoke all on function app.refresh_product_review_aggregate(uuid)
  from public, anon, authenticated;

-- Status changes must update product totals as well as rider totals.
create or replace function app.tg_review_aggregates()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product_id uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    if old.delivery_partner_id is not null then
      update public.delivery_partners dp
      set rating_count = aggregate.rating_count,
          rating_average = aggregate.rating_average,
          updated_at = now()
      from (
        select count(*)::int as rating_count,
               coalesce(round(avg(r.delivery_rating)::numeric, 2), 0) as rating_average
        from public.reviews r
        where r.delivery_partner_id = old.delivery_partner_id
          and r.delivery_rating is not null
          and r.status = 'PUBLISHED'
      ) aggregate
      where dp.id = old.delivery_partner_id;
    end if;

    for v_product_id in
      select distinct ri.product_id
      from public.review_items ri
      where ri.review_id = old.id and ri.product_id is not null
    loop
      perform app.refresh_product_review_aggregate(v_product_id);
    end loop;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    if new.delivery_partner_id is not null then
      update public.delivery_partners dp
      set rating_count = aggregate.rating_count,
          rating_average = aggregate.rating_average,
          updated_at = now()
      from (
        select count(*)::int as rating_count,
               coalesce(round(avg(r.delivery_rating)::numeric, 2), 0) as rating_average
        from public.reviews r
        where r.delivery_partner_id = new.delivery_partner_id
          and r.delivery_rating is not null
          and r.status = 'PUBLISHED'
      ) aggregate
      where dp.id = new.delivery_partner_id;
    end if;

    for v_product_id in
      select distinct ri.product_id
      from public.review_items ri
      where ri.review_id = new.id and ri.product_id is not null
    loop
      perform app.refresh_product_review_aggregate(v_product_id);
    end loop;
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists review_aggregates on public.reviews;
create trigger review_aggregates
  after insert or delete on public.reviews
  for each row execute function app.tg_review_aggregates();
create trigger review_aggregates_update
  after update of status, delivery_rating, delivery_partner_id on public.reviews
  for each row execute function app.tg_review_aggregates();

create or replace function app.tg_review_item_aggregates()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') and old.product_id is not null then
    perform app.refresh_product_review_aggregate(old.product_id);
  end if;

  if tg_op in ('INSERT', 'UPDATE') and new.product_id is not null then
    perform app.refresh_product_review_aggregate(new.product_id);
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists review_item_aggregates on public.review_items;
create trigger review_item_aggregates
  after insert or delete on public.review_items
  for each row execute function app.tg_review_item_aggregates();
create trigger review_item_aggregates_update
  after update of rating, product_id, review_id on public.review_items
  for each row execute function app.tg_review_item_aggregates();

-- Preserve explicit scores and fill missing product links for reviews already
-- submitted by the app, which currently sends one food score per order.
insert into public.review_items (review_id, order_item_id, product_id, rating, comment, created_at)
select r.id, oi.id, oi.product_id, r.food_rating, r.comment, r.created_at
from public.reviews r
join public.order_items oi on oi.order_id = r.order_id
where oi.product_id is not null
  and not oi.is_cancelled
  and oi.refunded_quantity < oi.quantity
  and not exists (
    select 1 from public.review_items existing
    where existing.review_id = r.id and existing.order_item_id = oi.id
  )
on conflict (review_id, order_item_id) do nothing;

-- Include legacy item links in the refreshed aggregates, even if their parent
-- review status changed before this trigger was installed.
do $$
declare
  v_product_id uuid;
begin
  for v_product_id in
    select distinct ri.product_id
    from public.review_items ri
    where ri.product_id is not null
  loop
    perform app.refresh_product_review_aggregate(v_product_id);
  end loop;
end;
$$;

-- Keep the established detail JSON contract while removing the comment-only
-- filter. The original body continues to provide variants and modifiers.
alter function public.product_detail(uuid, text, uuid) set schema app;
alter function app.product_detail(uuid, text, uuid) rename to product_detail_base_20261023;
revoke all on function app.product_detail_base_20261023(uuid, text, uuid)
  from public, anon, authenticated;

create function public.product_detail(
  p_product_id uuid default null,
  p_slug text default null,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb := app.product_detail_base_20261023(p_product_id, p_slug, p_branch_id);
begin
  return jsonb_set(
    v_result,
    '{reviews}',
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'rating', ri.rating,
        'comment', ri.comment,
        'customer_name', coalesce(nullif(split_part(pr.full_name, ' ', 1), ''), 'Customer'),
        'created_at', ri.created_at
      ) order by ri.created_at desc)
      from (
        select ri.*
        from public.review_items ri
        join public.reviews r on r.id = ri.review_id
        where ri.product_id = (v_result ->> 'id')::uuid
          and r.status = 'PUBLISHED'
        order by ri.created_at desc
        limit 10
      ) ri
      join public.reviews r on r.id = ri.review_id
      join public.profiles pr on pr.id = r.user_id
    ), '[]'::jsonb),
    true
  );
end;
$$;

revoke all on function public.product_detail(uuid, text, uuid)
  from public, anon, authenticated;
grant execute on function public.product_detail(uuid, text, uuid)
  to anon, authenticated;

comment on function public.product_detail(uuid, text, uuid) is
  'Public product detail with published order ratings, including ratings without text comments.';

-- The single food rating from the mobile order-review flow is attached to each
-- purchased product; supplied per-item scores inserted above take precedence.
create or replace function public.submit_review(
  p_order_id uuid,
  p_food_rating smallint,
  p_overall_rating smallint,
  p_delivery_rating smallint default null,
  p_comment text default null,
  p_tags text[] default '{}',
  p_item_ratings jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders;
  v_review public.reviews;
  v_partner uuid;
  v_item jsonb;
begin
  select * into v_order from public.orders where id = p_order_id;

  if not found or v_order.user_id <> v_uid then
    perform app.fail('ORDER_NOT_FOUND', 'We could not find that order on your account.');
  end if;

  if v_order.status not in ('DELIVERED', 'COMPLETED', 'PARTIALLY_REFUNDED') then
    perform app.fail('REVIEW_NOT_ALLOWED', 'You can rate an order once it has been delivered.');
  end if;

  if exists (select 1 from public.reviews where order_id = p_order_id) then
    perform app.fail('REVIEW_ALREADY_SUBMITTED', 'You have already rated this order.');
  end if;

  select delivery_partner_id into v_partner
  from public.delivery_assignments
  where order_id = p_order_id and status = 'COMPLETED'
  order by attempt_number desc
  limit 1;

  insert into public.reviews (
    order_id, user_id, branch_id, delivery_partner_id,
    food_rating, delivery_rating, overall_rating, comment, tags
  )
  values (
    p_order_id, v_uid, v_order.branch_id, v_partner,
    p_food_rating, p_delivery_rating, p_overall_rating,
    nullif(btrim(coalesce(p_comment, '')), ''), coalesce(p_tags, '{}')
  )
  returning * into v_review;

  -- Explicit dish scores are inserted first. The order score fills every
  -- product the customer did not rate individually.
  for v_item in select * from jsonb_array_elements(coalesce(p_item_ratings, '[]'::jsonb)) loop
    insert into public.review_items (review_id, order_item_id, product_id, rating, comment)
    select
      v_review.id,
      oi.id,
      oi.product_id,
      (v_item ->> 'rating')::smallint,
      nullif(v_item ->> 'comment', '')
    from public.order_items oi
    where oi.id = (v_item ->> 'order_item_id')::uuid
      and oi.order_id = p_order_id
      and oi.product_id is not null
      and not oi.is_cancelled
      and oi.refunded_quantity < oi.quantity
    on conflict (review_id, order_item_id) do nothing;
  end loop;

  insert into public.review_items (review_id, order_item_id, product_id, rating, comment)
  select v_review.id, oi.id, oi.product_id, p_food_rating, v_review.comment
  from public.order_items oi
  where oi.order_id = p_order_id
    and oi.product_id is not null
    and not oi.is_cancelled
    and oi.refunded_quantity < oi.quantity
  on conflict (review_id, order_item_id) do nothing;

  return jsonb_build_object('review_id', v_review.id, 'status', v_review.status);
end;
$$;

comment on function public.submit_review(uuid, smallint, smallint, smallint, text, text[], jsonb) is
  'Submit a delivered-order review and associate its food score with each purchased product.';
