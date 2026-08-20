-- `row_to_jsonb(record)` is not a PostgreSQL function. Keep this composed
-- customer rail on the supported `to_jsonb(record)` form.
create or replace function app.section_products(
  p_section public.cms_sections,
  p_branch_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_max_price numeric;
  v_result jsonb;
begin
  v_max_price := nullif(p_section.rule ->> 'max_price', '')::numeric;

  with base as (
    select
      p.id,
      p.name,
      p.slug,
      p.short_description,
      p.thumbnail_path,
      p.hero_image_path,
      p.food_type,
      p.spice_level,
      p.base_price,
      p.compare_price,
      p.preparation_minutes,
      p.rating_average,
      p.rating_count,
      p.is_best_seller,
      p.is_new,
      p.is_featured,
      p.category_id,
      c.name as category_name,
      app.product_orderable(p.id, p_branch_id) as is_available,
      p.display_order,
      p.order_count,
      (
        select min(v.price) from public.product_variants v
        where v.product_id = p.id and v.is_active and v.deleted_at is null
      ) as min_variant_price,
      (
        select count(*) from public.product_variants v
        where v.product_id = p.id and v.is_active and v.deleted_at is null
      ) as variant_count
    from public.products p
    join public.categories c on c.id = p.category_id
    where p.is_active
      and p.deleted_at is null
      and c.is_active
      and c.deleted_at is null
      and (p.branch_id is null or p.branch_id = p_branch_id)
      and case p_section.kind
        when 'BEST_SELLERS'        then p.is_best_seller
        when 'NEW_ARRIVALS'        then p.is_new
        when 'RECOMMENDED_COMBOS'  then p.is_combo or p.is_recommended
        when 'CUSTOMER_FAVOURITES' then p.rating_count > 0
        when 'PRICE_BUCKET'        then v_max_price is null or p.base_price <= v_max_price
        when 'POPULAR_NOW'         then true
        when 'PRODUCT_CAROUSEL'    then
          (cardinality(p_section.product_ids) = 0 or p.id = any (p_section.product_ids))
          and (p_section.category_id is null or p.category_id = p_section.category_id)
        when 'BUY_AGAIN'           then p_user_id is not null and exists (
          select 1 from public.order_items oi
          join public.orders o on o.id = oi.order_id
          where oi.product_id = p.id
            and o.user_id = p_user_id
            and o.status in ('DELIVERED', 'COMPLETED')
        )
        when 'RECENTLY_ORDERED'    then p_user_id is not null and exists (
          select 1 from public.order_items oi
          join public.orders o on o.id = oi.order_id
          where oi.product_id = p.id
            and o.user_id = p_user_id
            and o.created_at > now() - interval '60 days'
        )
        else true
      end
      and (
        p_section.collection_id is null
        or exists (
          select 1 from public.collection_products cp
          where cp.collection_id = p_section.collection_id and cp.product_id = p.id
        )
      )
  )
  select jsonb_agg(to_jsonb(ordered) order by ordered.sort_key)
  into v_result
  from (
    select
      base.*,
      case p_section.kind
        when 'POPULAR_NOW'         then -base.order_count
        when 'BEST_SELLERS'        then -base.order_count
        when 'CUSTOMER_FAVOURITES' then -(base.rating_average * 100)::int
        else base.display_order
      end as sort_key
    from base
    order by
      base.is_available desc,
      case p_section.kind
        when 'POPULAR_NOW'         then -base.order_count
        when 'BEST_SELLERS'        then -base.order_count
        when 'CUSTOMER_FAVOURITES' then -(base.rating_average * 100)::int
        else base.display_order
      end
    limit p_section.item_limit
  ) ordered;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;
