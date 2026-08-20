-- ═══════════════════════════════════════════════════════════════════════════
-- 0020 · READ SURFACES
--
-- Purpose-built, single-round-trip reads for each screen. Keeping composition in
-- Postgres means the mobile app on a weak Bihar mobile network makes one call
-- instead of six, and availability logic can never drift between clients.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Menu ──────────────────────────────────────────────────────────────────
create or replace function public.menu_catalog(
  p_branch_id uuid default null,
  p_category_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  return jsonb_build_object(
    'branch', public.branch_ordering_state(v_branch),
    'categories', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'name', c.name,
          'slug', c.slug,
          'short_description', c.short_description,
          'image_path', c.image_path,
          'thumbnail_path', c.thumbnail_path,
          'icon_name', c.icon_name,
          'accent_color', c.accent_color,
          'day_part', c.day_part,
          'display_order', c.display_order,
          'subcategories', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', sc.id, 'name', sc.name, 'slug', sc.slug,
              'image_path', sc.image_path, 'display_order', sc.display_order
            ) order by sc.display_order)
            from public.subcategories sc
            where sc.category_id = c.id and sc.is_active and sc.deleted_at is null
          ), '[]'::jsonb),
          'product_count', (
            select count(*) from public.products p
            where p.category_id = c.id and p.is_active and p.deleted_at is null
              and (p.branch_id is null or p.branch_id = v_branch)
          )
        ) order by c.display_order, c.name
      )
      from public.categories c
      where c.is_active and c.deleted_at is null
        and (c.branch_id is null or c.branch_id = v_branch)
        and (p_category_id is null or c.id = p_category_id)
    ), '[]'::jsonb),
    'products', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'category_id', p.category_id,
          'subcategory_id', p.subcategory_id,
          'name', p.name,
          'slug', p.slug,
          'short_description', p.short_description,
          'description', p.description,
          'thumbnail_path', p.thumbnail_path,
          'hero_image_path', p.hero_image_path,
          'food_type', p.food_type,
          'spice_level', p.spice_level,
          'allergens', p.allergens,
          'dietary_tags', p.dietary_tags,
          'base_price', p.base_price,
          'compare_price', p.compare_price,
          'packaging_charge', p.packaging_charge,
          'preparation_minutes', p.preparation_minutes,
          'serves_count', p.serves_count,
          'calories', p.calories,
          'is_featured', p.is_featured,
          'is_best_seller', p.is_best_seller,
          'is_new', p.is_new,
          'is_recommended', p.is_recommended,
          'is_combo', p.is_combo,
          'rating_average', p.rating_average,
          'rating_count', p.rating_count,
          'display_order', p.display_order,
          'min_quantity_per_order', p.min_quantity_per_order,
          'max_quantity_per_order', p.max_quantity_per_order,
          'allows_special_instructions', p.allows_special_instructions,
          'is_available', app.product_orderable(p.id, v_branch),
          'availability_state', coalesce(pa.state, 'AVAILABLE'),
          'out_of_stock_until', pa.out_of_stock_until,
          'has_variants', exists (
            select 1 from public.product_variants v
            where v.product_id = p.id and v.is_active and v.deleted_at is null
          ),
          'min_price', coalesce((
            select min(v.price) from public.product_variants v
            where v.product_id = p.id and v.is_active and v.deleted_at is null
          ), p.base_price),
          'images', coalesce((
            select jsonb_agg(jsonb_build_object(
              'storage_path', pi.storage_path, 'alt_text', pi.alt_text,
              'variants', pi.variants, 'is_primary', pi.is_primary
            ) order by pi.display_order)
            from public.product_images pi where pi.product_id = p.id
          ), '[]'::jsonb)
        ) order by p.display_order, p.name
      )
      from public.products p
      left join public.product_availability pa
        on pa.product_id = p.id and pa.branch_id = v_branch
      join public.categories c on c.id = p.category_id
      where p.is_active and p.deleted_at is null
        and c.is_active and c.deleted_at is null
        and (p.branch_id is null or p.branch_id = v_branch)
        and (p_category_id is null or p.category_id = p_category_id)
    ), '[]'::jsonb),
    'generated_at', now()
  );
end;
$$;

comment on function public.menu_catalog is
  'Whole menu with per-branch availability in one call. Safe to cache client-side by generated_at.';

-- ─── Product detail (variants + modifier groups) ───────────────────────────
create or replace function public.product_detail(
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
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_product public.products;
begin
  select * into v_product from public.products
  where (p_product_id is not null and id = p_product_id
         or p_slug is not null and slug = p_slug)
    and is_active and deleted_at is null;

  if not found then
    perform app.fail('ITEM_NOT_FOUND', 'This dish is no longer on the menu.');
  end if;

  return jsonb_build_object(
    'id', v_product.id,
    'category_id', v_product.category_id,
    'category_name', (select name from public.categories where id = v_product.category_id),
    'name', v_product.name,
    'slug', v_product.slug,
    'short_description', v_product.short_description,
    'description', v_product.description,
    'thumbnail_path', v_product.thumbnail_path,
    'hero_image_path', v_product.hero_image_path,
    'food_type', v_product.food_type,
    'spice_level', v_product.spice_level,
    'allergens', v_product.allergens,
    'dietary_tags', v_product.dietary_tags,
    'base_price', v_product.base_price,
    'compare_price', v_product.compare_price,
    'packaging_charge', v_product.packaging_charge,
    'preparation_minutes', v_product.preparation_minutes,
    'serves_count', v_product.serves_count,
    'calories', v_product.calories,
    'weight_grams', v_product.weight_grams,
    'rating_average', v_product.rating_average,
    'rating_count', v_product.rating_count,
    'is_best_seller', v_product.is_best_seller,
    'is_new', v_product.is_new,
    'is_combo', v_product.is_combo,
    'min_quantity_per_order', v_product.min_quantity_per_order,
    'max_quantity_per_order', v_product.max_quantity_per_order,
    'allows_special_instructions', v_product.allows_special_instructions,
    'is_available', app.product_orderable(v_product.id, v_branch),
    'meta_title', v_product.meta_title,
    'meta_description', v_product.meta_description,
    'images', coalesce((
      select jsonb_agg(jsonb_build_object(
        'storage_path', pi.storage_path, 'alt_text', pi.alt_text,
        'variants', pi.variants, 'is_primary', pi.is_primary
      ) order by pi.display_order)
      from public.product_images pi where pi.product_id = v_product.id
    ), '[]'::jsonb),
    'variants', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id,
        'name', v.name,
        'option_group', v.option_group,
        'price', v.price,
        'compare_price', v.compare_price,
        'packaging_charge', v.packaging_charge,
        'calories', v.calories,
        'serves_count', v.serves_count,
        'is_default', v.is_default,
        'is_available', app.variant_orderable(v.id),
        'availability_state', v.availability,
        'display_order', v.display_order
      ) order by v.display_order, v.price)
      from public.product_variants v
      where v.product_id = v_product.id and v.is_active and v.deleted_at is null
    ), '[]'::jsonb),
    'modifier_groups', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', mg.id,
        'name', mg.name,
        'description', mg.description,
        'selection', mg.selection,
        'is_required', coalesce(pmg.is_required, mg.is_required),
        'min_select', coalesce(pmg.min_select, mg.min_select),
        'max_select', coalesce(pmg.max_select, mg.max_select),
        'free_selections', mg.free_selections,
        'display_order', pmg.display_order,
        'modifiers', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', m.id,
            'name', m.name,
            'description', m.description,
            'image_path', m.image_path,
            'price', m.price,
            'food_type', m.food_type,
            'calories', m.calories,
            'max_quantity', m.max_quantity,
            'is_default', m.is_default,
            'is_available', app.modifier_orderable(m.id),
            'display_order', m.display_order
          ) order by m.display_order, m.price)
          from public.modifiers m
          where m.modifier_group_id = mg.id and m.is_active and m.deleted_at is null
        ), '[]'::jsonb)
      ) order by pmg.display_order, mg.display_order)
      from public.product_modifier_groups pmg
      join public.modifier_groups mg on mg.id = pmg.modifier_group_id
      where pmg.product_id = v_product.id and mg.is_active and mg.deleted_at is null
    ), '[]'::jsonb),
    'reviews', coalesce((
      select jsonb_agg(jsonb_build_object(
        'rating', ri.rating,
        'comment', ri.comment,
        'customer_name', coalesce(split_part(pr.full_name, ' ', 1), 'Customer'),
        'created_at', ri.created_at
      ) order by ri.created_at desc)
      from (
        select ri.* from public.review_items ri
        join public.reviews r on r.id = ri.review_id
        where ri.product_id = v_product.id
          and r.status = 'PUBLISHED'
          and ri.comment is not null
        order by ri.created_at desc
        limit 10
      ) ri
      join public.reviews r on r.id = ri.review_id
      join public.profiles pr on pr.id = r.user_id
    ), '[]'::jsonb),
    'similar_products', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p2.id, 'name', p2.name, 'thumbnail_path', p2.thumbnail_path,
        'base_price', p2.base_price, 'food_type', p2.food_type,
        'rating_average', p2.rating_average,
        'is_available', app.product_orderable(p2.id, v_branch)
      ) order by p2.order_count desc)
      from public.products p2
      where p2.category_id = v_product.category_id
        and p2.id <> v_product.id
        and p2.is_active and p2.deleted_at is null
      limit 8
    ), '[]'::jsonb)
  );
end;
$$;

-- ─── Search ────────────────────────────────────────────────────────────────
create or replace function public.search_menu(
  p_query text,
  p_branch_id uuid default null,
  p_limit int default 30
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_normalized text := lower(btrim(coalesce(p_query, '')));
  v_results jsonb;
  v_count int;
begin
  if length(v_normalized) < 2 then
    return jsonb_build_object('query', p_query, 'products', '[]'::jsonb, 'categories', '[]'::jsonb, 'count', 0);
  end if;

  select
    coalesce(jsonb_agg(r order by (r ->> 'rank')::numeric desc, (r ->> 'name')), '[]'::jsonb),
    count(*)::int
  into v_results, v_count
  from (
    select jsonb_build_object(
      'id', p.id,
      'name', p.name,
      'slug', p.slug,
      'short_description', p.short_description,
      'thumbnail_path', p.thumbnail_path,
      'category_id', p.category_id,
      'category_name', c.name,
      'food_type', p.food_type,
      'base_price', p.base_price,
      'compare_price', p.compare_price,
      'rating_average', p.rating_average,
      'rating_count', p.rating_count,
      'is_best_seller', p.is_best_seller,
      'is_available', app.product_orderable(p.id, v_branch),
      'min_price', coalesce((
        select min(v.price) from public.product_variants v
        where v.product_id = p.id and v.is_active and v.deleted_at is null
      ), p.base_price),
      'has_variants', exists (
        select 1 from public.product_variants v
        where v.product_id = p.id and v.is_active and v.deleted_at is null
      ),
      -- Blend exact full-text relevance with trigram similarity so common
      -- misspellings ("biriyani", "chiken") still find the dish.
      'rank', greatest(
        ts_rank(p.search_vector, websearch_to_tsquery('simple', v_normalized)) * 4,
        extensions.similarity(lower(p.name), v_normalized) * 3,
        case when lower(p.name) like v_normalized || '%' then 5 else 0 end,
        case when lower(p.name) like '%' || v_normalized || '%' then 2 else 0 end,
        coalesce((
          select max(extensions.similarity(lower(kw), v_normalized))
          from unnest(p.search_keywords) kw
        ), 0) * 2
      )
    ) as r
    from public.products p
    join public.categories c on c.id = p.category_id
    where p.is_active and p.deleted_at is null
      and c.is_active and c.deleted_at is null
      and (p.branch_id is null or p.branch_id = v_branch)
      and (
        p.search_vector @@ websearch_to_tsquery('simple', v_normalized)
        or lower(p.name) like '%' || v_normalized || '%'
        or extensions.similarity(lower(p.name), v_normalized) > 0.25
        or exists (
          select 1 from unnest(p.search_keywords) kw
          where lower(kw) like '%' || v_normalized || '%'
             or extensions.similarity(lower(kw), v_normalized) > 0.3
        )
        or lower(c.name) like '%' || v_normalized || '%'
      )
    limit least(coalesce(p_limit, 30), 60)
  ) matches
  where (r ->> 'rank')::numeric > 0;

  -- Telemetry: powers recent searches, trending queries and zero-result reports.
  if auth.uid() is not null then
    insert into public.search_queries (user_id, query, normalized, result_count)
    values (auth.uid(), p_query, v_normalized, v_count);
  end if;

  return jsonb_build_object(
    'query', p_query,
    'count', v_count,
    'products', v_results,
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'name', c.name, 'slug', c.slug, 'thumbnail_path', c.thumbnail_path
      ) order by c.display_order)
      from public.categories c
      where c.is_active and c.deleted_at is null
        and lower(c.name) like '%' || v_normalized || '%'
      limit 5
    ), '[]'::jsonb)
  );
end;
$$;

comment on function public.search_menu is
  'Typo-tolerant menu search blending full-text rank with trigram similarity.';

create or replace function public.search_suggestions(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  return jsonb_build_object(
    'recent', case when auth.uid() is null then '[]'::jsonb else coalesce((
      select jsonb_agg(distinct q.query)
      from (
        select query from public.search_queries
        where user_id = auth.uid() and result_count > 0
        order by created_at desc
        limit 8
      ) q
    ), '[]'::jsonb) end,
    'trending', coalesce((
      select jsonb_agg(t.query order by t.hits desc)
      from (
        select query, count(*) as hits
        from public.search_queries
        where created_at > now() - interval '7 days' and result_count > 0
        group by query
        order by hits desc
        limit 8
      ) t
    ), '[]'::jsonb),
    'popular_products', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.name, 'thumbnail_path', p.thumbnail_path,
        'base_price', p.base_price, 'food_type', p.food_type,
        'is_available', app.product_orderable(p.id, v_branch)
      ) order by p.order_count desc)
      from public.products p
      where p.is_active and p.deleted_at is null
      order by p.order_count desc
      limit 8
    ), '[]'::jsonb)
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ORDERS
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.order_payload(p_order_id uuid, p_for_staff boolean default false)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_assignment public.delivery_assignments;
begin
  select * into v_order from public.orders where id = p_order_id;

  if not found then
    return null;
  end if;

  select * into v_assignment
  from public.delivery_assignments
  where order_id = p_order_id
    and status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER', 'COMPLETED')
  order by attempt_number desc
  limit 1;

  return jsonb_build_object(
    'id', v_order.id,
    'order_number', v_order.order_number,
    'branch_id', v_order.branch_id,
    'status', v_order.status,
    'status_changed_at', v_order.status_changed_at,
    'is_active', app.is_active_status(v_order.status),
    'fulfilment_type', v_order.fulfilment_type,
    'timing', v_order.timing,
    'scheduled_for', v_order.scheduled_for,
    'channel', v_order.channel,
    'item_count', v_order.item_count,
    'unit_count', v_order.unit_count,
    'customer_note', v_order.customer_note,

    'customer', jsonb_build_object(
      'user_id', v_order.user_id,
      'name', v_order.customer_name,
      'phone', case when p_for_staff then v_order.customer_phone::text else null end,
      'email', case when p_for_staff then v_order.customer_email::text else null end,
      'is_first_order', v_order.is_first_order
    ),

    'delivery', jsonb_build_object(
      'address_line1', v_order.delivery_address_line1,
      'address_line2', v_order.delivery_address_line2,
      'landmark', v_order.delivery_landmark,
      'area', v_order.delivery_area,
      'city', v_order.delivery_city,
      'state', v_order.delivery_state,
      'postal_code', v_order.delivery_postal_code,
      'latitude', v_order.delivery_latitude,
      'longitude', v_order.delivery_longitude,
      'instructions', v_order.delivery_instructions,
      'contact_name', v_order.delivery_contact_name,
      'contact_phone', v_order.delivery_contact_phone,
      'zone_name', v_order.delivery_zone_name,
      'distance_km', v_order.distance_km
    ),

    'totals', jsonb_build_object(
      'currency_code', v_order.currency_code,
      'items_subtotal', v_order.items_subtotal,
      'items_discount', v_order.items_discount,
      'coupon_code', v_order.coupon_code,
      'coupon_discount', v_order.coupon_discount,
      'promotion_discount', v_order.promotion_discount,
      'total_discount', v_order.total_discount,
      'taxable_amount', v_order.taxable_amount,
      'tax_amount', v_order.tax_amount,
      'cgst_amount', v_order.cgst_amount,
      'sgst_amount', v_order.sgst_amount,
      'igst_amount', v_order.igst_amount,
      'cess_amount', v_order.cess_amount,
      'packaging_charge', v_order.packaging_charge,
      'delivery_fee', v_order.delivery_fee,
      'delivery_fee_waived', v_order.delivery_fee_waived,
      'service_fee', v_order.service_fee,
      'tip_amount', v_order.tip_amount,
      'round_off', v_order.round_off,
      'wallet_applied', v_order.wallet_applied,
      'loyalty_discount', v_order.loyalty_discount,
      'loyalty_points_redeemed', v_order.loyalty_points_redeemed,
      'grand_total', v_order.grand_total,
      'payable_amount', v_order.payable_amount,
      'refunded_amount', v_order.refunded_amount,
      'cancellation_fee', v_order.cancellation_fee
    ),

    'payment', jsonb_build_object(
      'mode', v_order.payment_mode,
      'status', v_order.payment_status,
      'cod_status', v_order.cod_status,
      'paid_at', v_order.paid_at,
      'method', (
        select p.method from public.payments p
        where p.order_id = v_order.id and p.status in ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED')
        order by p.captured_at desc nulls last limit 1
      ),
      'provider_payment_id', case when p_for_staff then (
        select p.provider_payment_id from public.payments p
        where p.order_id = v_order.id order by p.created_at desc limit 1
      ) else null end
    ),

    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', oi.id,
        'product_id', oi.product_id,
        'product_name', oi.product_name,
        'variant_name', oi.variant_name,
        'variant_option_group', oi.variant_option_group,
        'category_name', oi.category_name,
        'food_type', oi.food_type,
        'image_path', oi.image_path,
        'quantity', oi.quantity,
        'unit_price', oi.unit_price,
        'modifiers_price', oi.modifiers_price,
        'gross_amount', oi.gross_amount,
        'allocated_discount', oi.allocated_discount,
        'net_amount', oi.net_amount,
        'tax_amount', oi.tax_amount,
        'special_instructions', oi.special_instructions,
        'is_cancelled', oi.is_cancelled,
        'refunded_quantity', oi.refunded_quantity,
        'modifiers', coalesce((
          select jsonb_agg(jsonb_build_object(
            'group_name', oim.group_name,
            'modifier_name', oim.modifier_name,
            'unit_price', oim.unit_price,
            'quantity', oim.quantity,
            'total_price', oim.total_price
          ) order by oim.group_name, oim.modifier_name)
          from public.order_item_modifiers oim where oim.order_item_id = oi.id
        ), '[]'::jsonb)
      ) order by oi.display_order)
      from public.order_items oi where oi.order_id = v_order.id
    ), '[]'::jsonb),

    'timeline', coalesce((
      select jsonb_agg(jsonb_build_object(
        'to_status', h.to_status,
        'from_status', h.from_status,
        'label', case when p_for_staff then h.label else coalesce(t.customer_label, h.label) end,
        'note', case when p_for_staff then h.note else null end,
        'is_override', h.is_override,
        'actor_kind', h.actor_kind,
        'actor_role', case when p_for_staff then h.actor_role else null end,
        'created_at', h.created_at
      ) order by h.created_at)
      from public.order_status_history h
      left join public.order_status_transitions t
        on t.from_status = h.from_status and t.to_status = h.to_status
      where h.order_id = v_order.id
    ), '[]'::jsonb),

    'timing', jsonb_build_object(
      'placed_at', v_order.placed_at,
      'accepted_at', v_order.accepted_at,
      'preparing_at', v_order.preparing_at,
      'ready_at', v_order.ready_at,
      'assigned_at', v_order.assigned_at,
      'picked_up_at', v_order.picked_up_at,
      'delivered_at', v_order.delivered_at,
      'cancelled_at', v_order.cancelled_at,
      'promised_at', v_order.promised_at,
      'prep_minutes_estimate', v_order.prep_minutes_estimate,
      'delivery_minutes_estimate', v_order.delivery_minutes_estimate,
      'is_delayed', v_order.is_delayed,
      'created_at', v_order.created_at
    ),

    'rider', case when v_assignment.id is null then null else (
      select jsonb_build_object(
        'assignment_id', v_assignment.id,
        'assignment_status', v_assignment.status,
        'delivery_partner_id', dp.id,
        'name', dp.full_name,
        'photo_path', dp.photo_path,
        'phone', dp.phone,
        'vehicle_type', dp.vehicle_type,
        'vehicle_number', dp.vehicle_number,
        'rating_average', dp.rating_average,
        'total_deliveries', case when p_for_staff then dp.total_deliveries else null end,
        'live_location', (
          select jsonb_build_object(
            'latitude', l.latitude,
            'longitude', l.longitude,
            'heading_degrees', l.heading_degrees,
            'eta_minutes', l.eta_minutes,
            'distance_to_destination_km', l.distance_to_destination_km,
            'recorded_at', l.recorded_at,
            -- Stale fixes must not be drawn as a live marker.
            'is_fresh', l.recorded_at > now() - interval '2 minutes'
          )
          from public.delivery_partner_locations l
          where l.delivery_partner_id = dp.id and l.order_id = v_order.id
        )
      )
      from public.delivery_partners dp where dp.id = v_assignment.delivery_partner_id
    ) end,

    'cancellation', case when v_order.cancelled_at is null then null else jsonb_build_object(
      'actor', v_order.cancellation_actor,
      'reason', v_order.cancellation_reason,
      'note', v_order.cancellation_note,
      'cancelled_at', v_order.cancelled_at,
      'fee', v_order.cancellation_fee
    ) end,

    'refunds', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'kind', r.kind, 'status', r.status, 'amount', r.amount,
        'amount_processed', r.amount_processed, 'destination', r.destination,
        'reason', r.reason, 'created_at', r.created_at, 'completed_at', r.completed_at
      ) order by r.created_at desc)
      from public.refunds r where r.order_id = v_order.id
    ), '[]'::jsonb),

    'review', (
      select jsonb_build_object(
        'id', rv.id, 'food_rating', rv.food_rating, 'delivery_rating', rv.delivery_rating,
        'overall_rating', rv.overall_rating, 'comment', rv.comment, 'created_at', rv.created_at
      )
      from public.reviews rv where rv.order_id = v_order.id
    ),

    'support_tickets', case when not p_for_staff then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', st.id, 'ticket_number', st.ticket_number, 'category', st.category,
        'status', st.status, 'priority', st.priority, 'created_at', st.created_at
      ) order by st.created_at desc)
      from public.support_tickets st where st.order_id = v_order.id
    ), '[]'::jsonb) end,

    'internal_notes', case when not p_for_staff then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', n.id, 'note', n.note, 'created_at', n.created_at,
        'author', (select coalesce(pr.full_name, pr.phone::text) from public.profiles pr where pr.id = n.author_id)
      ) order by n.created_at desc)
      from public.order_notes n where n.order_id = v_order.id
    ), '[]'::jsonb) end,

    'can_cancel', case
      when p_for_staff then app.is_active_status(v_order.status)
      else coalesce((public.cancellation_options(v_order.id) ->> 'can_cancel')::boolean, false)
    end,
    'can_review', v_order.status in ('DELIVERED', 'COMPLETED')
                  and not exists (select 1 from public.reviews where order_id = v_order.id),
    'can_reorder', v_order.status in ('DELIVERED', 'COMPLETED', 'CUSTOMER_CANCELLED',
                                      'ADMIN_CANCELLED', 'STORE_REJECTED')
  );
end;
$$;

create or replace function public.order_detail(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_for_staff boolean;
  v_is_rider boolean;
begin
  select * into v_order from public.orders where id = p_order_id;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'Order not found.');
  end if;

  v_is_rider := exists (
    select 1 from public.delivery_assignments da
    join public.delivery_partners dp on dp.id = da.delivery_partner_id
    where da.order_id = p_order_id and dp.user_id = auth.uid()
  );

  v_for_staff := app.has_permission('order.view', v_order.branch_id);

  if v_order.user_id <> auth.uid() and not v_for_staff and not v_is_rider then
    perform app.fail('PERMISSION_DENIED', 'You cannot view this order.');
  end if;

  return app.order_payload(p_order_id, v_for_staff);
end;
$$;

create or replace function public.my_orders(
  p_scope text default 'ALL',
  p_limit int default 20,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to see your orders.');
  end if;

  return jsonb_build_object(
    'orders', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', o.id,
          'order_number', o.order_number,
          'status', o.status,
          'is_active', app.is_active_status(o.status),
          'fulfilment_type', o.fulfilment_type,
          'grand_total', o.grand_total,
          'item_count', o.item_count,
          'unit_count', o.unit_count,
          'payment_mode', o.payment_mode,
          'payment_status', o.payment_status,
          'created_at', o.created_at,
          'placed_at', o.placed_at,
          'delivered_at', o.delivered_at,
          'promised_at', o.promised_at,
          'refunded_amount', o.refunded_amount,
          'has_review', exists (select 1 from public.reviews rv where rv.order_id = o.id),
          'items_preview', coalesce((
            select jsonb_agg(jsonb_build_object(
              'product_name', oi.product_name,
              'variant_name', oi.variant_name,
              'quantity', oi.quantity,
              'image_path', oi.image_path
            ) order by oi.display_order)
            from (
              select * from public.order_items
              where order_id = o.id order by display_order limit 3
            ) oi
          ), '[]'::jsonb)
        ) order by o.created_at desc
      )
      from public.orders o
      where o.user_id = v_uid
        and case upper(coalesce(p_scope, 'ALL'))
          when 'CURRENT' then app.is_active_status(o.status)
          when 'PAST' then o.status in ('DELIVERED', 'COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED')
          when 'CANCELLED' then app.is_cancelled_status(o.status)
          else true
        end
      limit least(coalesce(p_limit, 20), 50)
      offset greatest(coalesce(p_offset, 0), 0)
    ), '[]'::jsonb),
    'counts', jsonb_build_object(
      'current', (select count(*) from public.orders where user_id = v_uid and app.is_active_status(status)),
      'past', (select count(*) from public.orders where user_id = v_uid
               and status in ('DELIVERED', 'COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED')),
      'cancelled', (select count(*) from public.orders where user_id = v_uid and app.is_cancelled_status(status))
    )
  );
end;
$$;

-- ─── Reorder ───────────────────────────────────────────────────────────────
-- Rebuilds a cart from a past order, skipping anything no longer orderable and
-- telling the customer exactly what changed.
create or replace function public.reorder(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders;
  v_cart public.carts;
  v_item public.order_items;
  v_mods jsonb;
  v_skipped jsonb := '[]'::jsonb;
  v_added int := 0;
begin
  select * into v_order from public.orders
  where id = p_order_id and user_id = v_uid;

  if not found then
    perform app.fail('ORDER_NOT_FOUND', 'We could not find that order on your account.');
  end if;

  v_cart := app.get_or_create_cart(v_uid, v_order.branch_id);

  -- Start from a clean cart so the reorder matches the original intent.
  delete from public.cart_items where cart_id = v_cart.id;

  for v_item in
    select * from public.order_items
    where order_id = p_order_id and not is_cancelled
    order by display_order
  loop
    if v_item.product_id is null
       or not app.product_orderable(v_item.product_id, v_order.branch_id)
       or (v_item.variant_id is not null and not app.variant_orderable(v_item.variant_id)) then
      v_skipped := v_skipped || jsonb_build_array(jsonb_build_object(
        'product_name', v_item.product_name,
        'variant_name', v_item.variant_name,
        'reason', 'Currently unavailable'
      ));
      continue;
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
      'modifier_id', oim.modifier_id, 'quantity', oim.quantity
    )), '[]'::jsonb)
    into v_mods
    from public.order_item_modifiers oim
    where oim.order_item_id = v_item.id
      and oim.modifier_id is not null
      and app.modifier_orderable(oim.modifier_id);

    begin
      perform public.cart_add_item(
        v_item.product_id, v_item.variant_id, v_item.quantity, v_mods,
        v_item.special_instructions, v_order.branch_id, true
      );
      v_added := v_added + 1;
    exception when others then
      -- One bad line must not abort the whole reorder.
      v_skipped := v_skipped || jsonb_build_array(jsonb_build_object(
        'product_name', v_item.product_name,
        'variant_name', v_item.variant_name,
        'reason', 'Could not be added'
      ));
    end;
  end loop;

  if v_added = 0 then
    perform app.fail(
      'REORDER_UNAVAILABLE',
      'None of the items from that order are available right now.',
      jsonb_build_object('skipped', v_skipped)
    );
  end if;

  return app.calculate_checkout(v_uid, v_cart.id)
         || jsonb_build_object('skipped_items', v_skipped, 'added_count', v_added);
end;
$$;

comment on function public.reorder is
  'Rebuilds a cart from a past order and reports exactly which lines were dropped.';

-- ═══════════════════════════════════════════════════════════════════════════
-- KITCHEN QUEUE
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.kitchen_queue(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_late_seconds int;
begin
  perform app.require_permission('kitchen.view', v_branch);
  v_late_seconds := app.setting_int('kitchen.delay_threshold_seconds', 900);

  return jsonb_build_object(
    'branch', public.branch_ordering_state(v_branch),
    'orders', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', o.id,
          'order_number', o.order_number,
          'status', o.status,
          'fulfilment_type', o.fulfilment_type,
          'timing', o.timing,
          'scheduled_for', o.scheduled_for,
          'payment_mode', o.payment_mode,
          'payment_status', o.payment_status,
          'is_paid', o.payment_status = 'CAPTURED',
          'customer_note', o.customer_note,
          'item_count', o.item_count,
          'unit_count', o.unit_count,
          'grand_total', o.grand_total,
          'placed_at', o.placed_at,
          'accepted_at', o.accepted_at,
          'preparing_at', o.preparing_at,
          'ready_at', o.ready_at,
          'promised_at', o.promised_at,
          'prep_minutes_estimate', o.prep_minutes_estimate,
          -- Drives the large countdown timer on the kitchen tablet.
          'elapsed_seconds', extract(epoch from (now() - coalesce(o.placed_at, o.created_at)))::int,
          'is_delayed', o.promised_at is not null and o.promised_at < now(),
          'is_late_in_stage', extract(epoch from (now() - o.status_changed_at))::int > v_late_seconds,
          'is_first_order', o.is_first_order,
          'items', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', oi.id,
              'product_name', oi.product_name,
              'variant_name', oi.variant_name,
              'quantity', oi.quantity,
              'food_type', oi.food_type,
              'special_instructions', oi.special_instructions,
              'is_cancelled', oi.is_cancelled,
              'modifiers', coalesce((
                select jsonb_agg(jsonb_build_object(
                  'group_name', oim.group_name, 'modifier_name', oim.modifier_name,
                  'quantity', oim.quantity
                ) order by oim.group_name)
                from public.order_item_modifiers oim where oim.order_item_id = oi.id
              ), '[]'::jsonb)
            ) order by oi.display_order)
            from public.order_items oi where oi.order_id = o.id
          ), '[]'::jsonb),
          'rider', (
            select jsonb_build_object(
              'name', dp.full_name, 'phone', dp.phone,
              'assignment_status', da.status, 'arrived_store_at', da.arrived_store_at
            )
            from public.delivery_assignments da
            join public.delivery_partners dp on dp.id = da.delivery_partner_id
            where da.order_id = o.id
              and da.status in ('ACCEPTED', 'AT_STORE', 'PICKED_UP')
            order by da.attempt_number desc limit 1
          )
        ) order by
          -- New orders first, then by promise time so the kitchen paces itself.
          case o.status
            when 'ORDER_PLACED' then 0
            when 'STORE_ACCEPTED' then 1
            when 'PREPARING' then 2
            when 'READY_FOR_PICKUP' then 3
            else 4
          end,
          coalesce(o.promised_at, o.created_at)
      )
      from public.orders o
      where o.branch_id = v_branch
        and o.status in ('ORDER_PLACED', 'STORE_ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP')
    ), '[]'::jsonb),
    'recently_completed', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id, 'order_number', o.order_number, 'status', o.status,
        'unit_count', o.unit_count, 'picked_up_at', o.picked_up_at,
        'delivered_at', o.delivered_at
      ) order by coalesce(o.delivered_at, o.picked_up_at, o.updated_at) desc)
      from public.orders o
      where o.branch_id = v_branch
        and o.status in ('PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED', 'COMPLETED')
        and o.updated_at > now() - interval '4 hours'
      limit 25
    ), '[]'::jsonb),
    'counts', (
      select jsonb_build_object(
        'new', count(*) filter (where status = 'ORDER_PLACED'),
        'accepted', count(*) filter (where status = 'STORE_ACCEPTED'),
        'preparing', count(*) filter (where status = 'PREPARING'),
        'ready', count(*) filter (where status = 'READY_FOR_PICKUP'),
        'delayed', count(*) filter (where promised_at is not null and promised_at < now()
                                    and status in ('ORDER_PLACED', 'STORE_ACCEPTED', 'PREPARING'))
      )
      from public.orders where branch_id = v_branch
        and status in ('ORDER_PLACED', 'STORE_ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP')
    ),
    'generated_at', now()
  );
end;
$$;

comment on function public.kitchen_queue is
  'Kitchen tablet payload: live queue with elapsed timers, delay flags and counts.';

-- Items the kitchen can toggle, with their current state.
create or replace function public.kitchen_availability(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  perform app.require_permission('menu.availability', v_branch);

  return jsonb_build_object(
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'products', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', p.id,
            'name', p.name,
            'thumbnail_path', p.thumbnail_path,
            'food_type', p.food_type,
            'base_price', p.base_price,
            'state', coalesce(pa.state, 'AVAILABLE'),
            'remaining_quantity', pa.remaining_quantity,
            'out_of_stock_until', pa.out_of_stock_until,
            'out_of_stock_reason', pa.out_of_stock_reason,
            'changed_at', pa.changed_at,
            'is_orderable', app.product_orderable(p.id, v_branch),
            'variants', coalesce((
              select jsonb_agg(jsonb_build_object(
                'id', v.id, 'name', v.name, 'option_group', v.option_group,
                'price', v.price, 'availability', v.availability
              ) order by v.display_order)
              from public.product_variants v
              where v.product_id = p.id and v.is_active and v.deleted_at is null
            ), '[]'::jsonb)
          ) order by p.display_order, p.name)
          from public.products p
          left join public.product_availability pa
            on pa.product_id = p.id and pa.branch_id = v_branch
          where p.category_id = c.id and p.is_active and p.deleted_at is null
        ), '[]'::jsonb)
      ) order by c.display_order)
      from public.categories c
      where c.is_active and c.deleted_at is null
    ), '[]'::jsonb),
    'out_of_stock_count', (
      select count(*) from public.product_availability pa
      join public.products p on p.id = pa.product_id
      where pa.branch_id = v_branch
        and pa.state <> 'AVAILABLE'
        and p.is_active and p.deleted_at is null
    )
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- LIVE OPERATIONS (admin command centre)
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.live_operations(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  perform app.require_permission('order.view', v_branch);

  return jsonb_build_object(
    'branch', public.branch_ordering_state(v_branch),
    'columns', (
      select jsonb_object_agg(bucket, orders)
      from (
        select
          case o.status
            when 'ORDER_PLACED' then 'NEW'
            when 'STORE_ACCEPTED' then 'ACCEPTED'
            when 'PREPARING' then 'PREPARING'
            when 'READY_FOR_PICKUP' then 'READY'
            when 'RIDER_ASSIGNED' then 'RIDER_ASSIGNED'
            when 'RIDER_ARRIVED_STORE' then 'RIDER_ASSIGNED'
            when 'PICKED_UP' then 'OUT_FOR_DELIVERY'
            when 'OUT_FOR_DELIVERY' then 'OUT_FOR_DELIVERY'
            when 'RIDER_ARRIVED_CUSTOMER' then 'OUT_FOR_DELIVERY'
            else 'DELIVERED'
          end as bucket,
          jsonb_agg(
            jsonb_build_object(
              'id', o.id,
              'order_number', o.order_number,
              'status', o.status,
              'fulfilment_type', o.fulfilment_type,
              'customer_name', o.customer_name,
              'customer_phone', o.customer_phone,
              'area', coalesce(o.delivery_area, o.delivery_city),
              'unit_count', o.unit_count,
              'grand_total', o.grand_total,
              'payment_mode', o.payment_mode,
              'payment_status', o.payment_status,
              'placed_at', o.placed_at,
              'promised_at', o.promised_at,
              'status_changed_at', o.status_changed_at,
              'elapsed_seconds', extract(epoch from (now() - coalesce(o.placed_at, o.created_at)))::int,
              'is_delayed', o.promised_at is not null and o.promised_at < now(),
              'distance_km', o.distance_km,
              'rider_name', (
                select dp.full_name from public.delivery_assignments da
                join public.delivery_partners dp on dp.id = da.delivery_partner_id
                where da.order_id = o.id
                  and da.status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
                order by da.attempt_number desc limit 1
              )
            ) order by coalesce(o.promised_at, o.created_at)
          ) as orders
        from public.orders o
        where o.branch_id = v_branch
          and (
            app.is_active_status(o.status) and o.status <> 'PENDING_PAYMENT'
            or (o.status in ('DELIVERED', 'COMPLETED') and o.updated_at > now() - interval '2 hours')
          )
        group by bucket
      ) buckets
    ),
    'alerts', coalesce((
      select jsonb_agg(alert order by (alert ->> 'severity'))
      from (
        -- Orders past their promise time
        select jsonb_build_object(
          'type', 'ORDER_DELAYED', 'severity', '1',
          'order_id', o.id, 'order_number', o.order_number,
          'message', format('Order %s is %s min past its promise time.',
                            o.order_number,
                            ceil(extract(epoch from (now() - o.promised_at)) / 60)::int)
        ) as alert
        from public.orders o
        where o.branch_id = v_branch
          and o.promised_at < now()
          and o.status in ('ORDER_PLACED', 'STORE_ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP',
                           'RIDER_ASSIGNED', 'PICKED_UP', 'OUT_FOR_DELIVERY')

        union all

        -- Ready orders with nobody to carry them
        select jsonb_build_object(
          'type', 'NO_RIDER_AVAILABLE', 'severity', '1',
          'order_id', o.id, 'order_number', o.order_number,
          'message', format('Order %s is ready with no delivery partner assigned.', o.order_number)
        )
        from public.orders o
        where o.branch_id = v_branch
          and o.status = 'READY_FOR_PICKUP'
          and o.fulfilment_type = 'DELIVERY'
          and o.ready_at < now() - interval '5 minutes'
          and not exists (
            select 1 from public.delivery_assignments da
            where da.order_id = o.id
              and da.status in ('OFFERED', 'ACCEPTED', 'AT_STORE', 'PICKED_UP', 'AT_CUSTOMER')
          )

        union all

        -- Payments that never reconciled
        select jsonb_build_object(
          'type', 'PAYMENT_UNRECONCILED', 'severity', '2',
          'order_id', o.id, 'order_number', o.order_number,
          'message', format('Order %s payment is not fully reconciled.', o.order_number)
        )
        from public.orders o
        join public.payments p on p.order_id = o.id
        where o.branch_id = v_branch
          and p.status = 'CAPTURED'
          and p.reconciled_at is null
          and p.captured_at < now() - interval '15 minutes'

        union all

        -- Orders stuck awaiting kitchen acceptance
        select jsonb_build_object(
          'type', 'AWAITING_ACCEPTANCE', 'severity', '1',
          'order_id', o.id, 'order_number', o.order_number,
          'message', format('Order %s has been waiting %s min for kitchen acceptance.',
                            o.order_number,
                            ceil(extract(epoch from (now() - o.placed_at)) / 60)::int)
        )
        from public.orders o
        where o.branch_id = v_branch
          and o.status = 'ORDER_PLACED'
          and o.placed_at < now() - make_interval(secs => app.setting_int('kitchen.accept_sla_seconds', 180))

        union all

        -- Open urgent support tickets
        select jsonb_build_object(
          'type', 'SUPPORT_ESCALATION', 'severity', '2',
          'order_id', st.order_id, 'ticket_number', st.ticket_number,
          'message', format('Urgent ticket %s: %s', st.ticket_number,
                            replace(st.category::text, '_', ' '))
        )
        from public.support_tickets st
        where st.branch_id = v_branch
          and st.priority in ('URGENT', 'HIGH')
          and st.status in ('OPEN', 'IN_PROGRESS', 'ESCALATED')
      ) alerts
    ), '[]'::jsonb),
    'riders', coalesce((
      select jsonb_agg(jsonb_build_object(
        'delivery_partner_id', r.delivery_partner_id,
        'full_name', r.full_name,
        'phone', r.phone,
        'photo_path', r.photo_path,
        'vehicle_type', r.vehicle_type,
        'duty_state', r.duty_state,
        'active_load', r.active_load,
        'max_concurrent_orders', r.max_concurrent_orders,
        'distance_to_store_km', r.distance_to_store_km,
        'last_location_at', r.last_location_at,
        'rating_average', r.rating_average,
        'score', r.score
      ) order by r.score)
      from public.available_riders(v_branch) r
    ), '[]'::jsonb),
    'stats', (
      select jsonb_build_object(
        'active_orders', count(*) filter (where app.is_active_status(status) and status <> 'PENDING_PAYMENT'),
        'delayed_orders', count(*) filter (where promised_at < now() and app.is_active_status(status)),
        'unpaid_orders', count(*) filter (where status = 'PENDING_PAYMENT'),
        'online_riders', (
          select count(*) from public.delivery_partners
          where branch_id = v_branch and onboarding_status = 'ACTIVE' and duty_state <> 'OFFLINE'
        )
      )
      from public.orders where branch_id = v_branch and created_at > now() - interval '1 day'
    ),
    'generated_at', now()
  );
end;
$$;

comment on function public.live_operations is
  'Operations command centre: kanban columns, actionable alerts, rider roster and live stats.';

-- ─── Customer 360 (admin) ──────────────────────────────────────────────────
create or replace function public.customer_detail(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles;
begin
  perform app.require_permission('customer.view');

  select * into v_profile from public.profiles where id = p_user_id;

  if not found then
    perform app.fail('CUSTOMER_NOT_FOUND', 'Customer not found.');
  end if;

  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', v_profile.id,
      'full_name', v_profile.full_name,
      'phone', v_profile.phone,
      'email', v_profile.email,
      'avatar_url', v_profile.avatar_url,
      'status', v_profile.status,
      'blocked_reason', v_profile.blocked_reason,
      'preferred_language', v_profile.preferred_language,
      'marketing_opt_in', v_profile.marketing_opt_in,
      'referral_code', v_profile.referral_code,
      'created_at', v_profile.created_at,
      'last_seen_at', v_profile.last_seen_at,
      'internal_notes', v_profile.internal_notes
    ),
    'metrics', jsonb_build_object(
      'total_orders', v_profile.total_orders,
      'completed_orders', v_profile.completed_orders,
      'cancelled_orders', v_profile.cancelled_orders,
      'lifetime_value', v_profile.lifetime_value,
      'average_order_value', v_profile.average_order_value,
      'first_order_at', v_profile.first_order_at,
      'last_order_at', v_profile.last_order_at,
      'days_since_last_order', case
        when v_profile.last_order_at is null then null
        else extract(day from (now() - v_profile.last_order_at))::int
      end,
      'total_refunded', coalesce((
        select sum(r.amount_processed) from public.refunds r
        where r.user_id = p_user_id and r.status = 'COMPLETED'
      ), 0),
      'cancellation_rate', case
        when v_profile.total_orders > 0
        then round(v_profile.cancelled_orders::numeric / v_profile.total_orders * 100, 1)
        else 0
      end
    ),
    'wallet', jsonb_build_object(
      'balance', coalesce((select balance from public.wallet_accounts where user_id = p_user_id), 0),
      'is_frozen', coalesce((select is_frozen from public.wallet_accounts where user_id = p_user_id), false)
    ),
    'loyalty', jsonb_build_object(
      'points_balance', coalesce((select points_balance from public.loyalty_accounts where user_id = p_user_id), 0),
      'tier', coalesce((select tier from public.loyalty_accounts where user_id = p_user_id), 'BRONZE')
    ),
    'addresses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'label', a.label, 'address_line1', a.address_line1,
        'address_line2', a.address_line2, 'landmark', a.landmark, 'area', a.area,
        'city', a.city, 'postal_code', a.postal_code, 'is_default', a.is_default,
        'is_serviceable', a.is_serviceable, 'distance_km', a.distance_km
      ) order by a.is_default desc, a.created_at desc)
      from public.addresses a where a.user_id = p_user_id and a.deleted_at is null
    ), '[]'::jsonb),
    'recent_orders', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id, 'order_number', o.order_number, 'status', o.status,
        'grand_total', o.grand_total, 'unit_count', o.unit_count,
        'payment_mode', o.payment_mode, 'created_at', o.created_at,
        'refunded_amount', o.refunded_amount
      ) order by o.created_at desc)
      from (
        select * from public.orders where user_id = p_user_id
        order by created_at desc limit 20
      ) o
    ), '[]'::jsonb),
    'favourite_products', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_id', t.product_id, 'product_name', t.product_name, 'times_ordered', t.cnt
      ) order by t.cnt desc)
      from (
        select oi.product_id, oi.product_name, count(*) as cnt
        from public.order_items oi
        join public.orders o on o.id = oi.order_id
        where o.user_id = p_user_id and o.status in ('DELIVERED', 'COMPLETED')
        group by oi.product_id, oi.product_name
        order by cnt desc limit 5
      ) t
    ), '[]'::jsonb),
    'support_tickets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', st.id, 'ticket_number', st.ticket_number, 'category', st.category,
        'status', st.status, 'priority', st.priority, 'created_at', st.created_at
      ) order by st.created_at desc)
      from public.support_tickets st where st.user_id = p_user_id limit 20
    ), '[]'::jsonb),
    'reviews', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', rv.id, 'overall_rating', rv.overall_rating, 'food_rating', rv.food_rating,
        'delivery_rating', rv.delivery_rating, 'comment', rv.comment, 'created_at', rv.created_at
      ) order by rv.created_at desc)
      from public.reviews rv where rv.user_id = p_user_id limit 20
    ), '[]'::jsonb),
    'coupon_usage', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', cr.code, 'discount_amount', cr.discount_amount, 'created_at', cr.created_at
      ) order by cr.created_at desc)
      from public.coupon_redemptions cr where cr.user_id = p_user_id limit 20
    ), '[]'::jsonb)
  );
end;
$$;

-- ─── Customer profile mutations ────────────────────────────────────────────
create or replace function public.update_my_profile(
  p_full_name text default null,
  p_email text default null,
  p_date_of_birth date default null,
  p_gender text default null,
  p_preferred_language text default null,
  p_marketing_opt_in boolean default null,
  p_avatar_url text default null,
  p_push_enabled boolean default null,
  p_sms_enabled boolean default null,
  p_email_enabled boolean default null,
  p_whatsapp_enabled boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to continue.');
  end if;

  update public.profiles
  set full_name = coalesce(nullif(btrim(p_full_name), ''), full_name),
      email = coalesce(nullif(btrim(lower(p_email)), '')::app.email, email),
      date_of_birth = coalesce(p_date_of_birth, date_of_birth),
      gender = coalesce(p_gender, gender),
      preferred_language = coalesce(p_preferred_language, preferred_language),
      marketing_opt_in = coalesce(p_marketing_opt_in, marketing_opt_in),
      avatar_url = coalesce(p_avatar_url, avatar_url),
      push_enabled = coalesce(p_push_enabled, push_enabled),
      sms_enabled = coalesce(p_sms_enabled, sms_enabled),
      email_enabled = coalesce(p_email_enabled, email_enabled),
      whatsapp_enabled = coalesce(p_whatsapp_enabled, whatsapp_enabled),
      onboarding_completed = true,
      profile_completed_at = coalesce(profile_completed_at, now()),
      updated_at = now()
  where id = v_uid
  returning * into v_profile;

  return jsonb_build_object(
    'id', v_profile.id,
    'full_name', v_profile.full_name,
    'email', v_profile.email,
    'phone', v_profile.phone,
    'preferred_language', v_profile.preferred_language,
    'onboarding_completed', v_profile.onboarding_completed
  );
end;
$$;

create or replace function public.upsert_address(
  p_address_line1 text,
  p_city text,
  p_state text,
  p_latitude numeric,
  p_longitude numeric,
  p_id uuid default null,
  p_label text default 'HOME',
  p_address_line2 text default null,
  p_landmark text default null,
  p_area text default null,
  p_postal_code text default null,
  p_contact_name text default null,
  p_contact_phone text default null,
  p_delivery_instructions text default null,
  p_formatted_address text default null,
  p_google_place_id text default null,
  p_location_source text default 'GPS',
  p_is_default boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_address public.addresses;
  v_service jsonb;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to save an address.');
  end if;

  v_service := public.check_serviceability(p_latitude, p_longitude);

  if p_id is not null then
    update public.addresses
    set label = p_label,
        address_line1 = p_address_line1,
        address_line2 = p_address_line2,
        landmark = p_landmark,
        area = p_area,
        city = p_city,
        state = p_state,
        postal_code = p_postal_code,
        latitude = p_latitude,
        longitude = p_longitude,
        contact_name = p_contact_name,
        contact_phone = app.normalize_phone(p_contact_phone)::app.phone,
        delivery_instructions = p_delivery_instructions,
        formatted_address = p_formatted_address,
        google_place_id = p_google_place_id,
        location_source = p_location_source,
        is_default = p_is_default or is_default,
        resolved_zone_id = nullif(v_service ->> 'zone_id', '')::uuid,
        resolved_branch_id = nullif(v_service ->> 'branch_id', '')::uuid,
        distance_km = nullif(v_service ->> 'distance_km', '')::numeric,
        is_serviceable = (v_service ->> 'serviceable')::boolean,
        serviceability_checked_at = now(),
        updated_at = now()
    where id = p_id and user_id = v_uid and deleted_at is null
    returning * into v_address;

    if not found then
      perform app.fail('ADDRESS_NOT_FOUND', 'That address could not be updated.');
    end if;
  else
    insert into public.addresses (
      user_id, label, address_line1, address_line2, landmark, area, city, state,
      postal_code, latitude, longitude, contact_name, contact_phone,
      delivery_instructions, formatted_address, google_place_id, location_source,
      is_default, resolved_zone_id, resolved_branch_id, distance_km,
      is_serviceable, serviceability_checked_at
    )
    values (
      v_uid, p_label, p_address_line1, p_address_line2, p_landmark, p_area, p_city, p_state,
      p_postal_code, p_latitude, p_longitude, p_contact_name,
      app.normalize_phone(p_contact_phone)::app.phone,
      p_delivery_instructions, p_formatted_address, p_google_place_id, p_location_source,
      p_is_default, nullif(v_service ->> 'zone_id', '')::uuid,
      nullif(v_service ->> 'branch_id', '')::uuid,
      nullif(v_service ->> 'distance_km', '')::numeric,
      (v_service ->> 'serviceable')::boolean, now()
    )
    returning * into v_address;
  end if;

  return jsonb_build_object(
    'address', jsonb_build_object(
      'id', v_address.id,
      'label', v_address.label,
      'address_line1', v_address.address_line1,
      'address_line2', v_address.address_line2,
      'landmark', v_address.landmark,
      'area', v_address.area,
      'city', v_address.city,
      'state', v_address.state,
      'postal_code', v_address.postal_code,
      'latitude', v_address.latitude,
      'longitude', v_address.longitude,
      'is_default', v_address.is_default,
      'is_serviceable', v_address.is_serviceable,
      'distance_km', v_address.distance_km,
      'delivery_instructions', v_address.delivery_instructions
    ),
    'serviceability', v_service
  );
end;
$$;

create or replace function public.delete_address(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.addresses
  set deleted_at = now(), is_default = false, updated_at = now()
  where id = p_id and user_id = auth.uid() and deleted_at is null;

  if not found then
    perform app.fail('ADDRESS_NOT_FOUND', 'That address could not be found.');
  end if;

  -- Promote the most recent remaining address so checkout always has a default.
  update public.addresses
  set is_default = true, updated_at = now()
  where id = (
    select id from public.addresses
    where user_id = auth.uid() and deleted_at is null
    order by created_at desc limit 1
  )
  and not exists (
    select 1 from public.addresses
    where user_id = auth.uid() and deleted_at is null and is_default
  );

  return true;
end;
$$;
