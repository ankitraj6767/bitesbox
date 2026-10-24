-- Taste preferences belong to the signed-in customer. Direct writes are
-- deliberately unavailable; the owner-only RPC below validates every value.
create table public.customer_taste_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  food_types public.food_type[] not null default '{}',
  max_spice public.spice_level,
  price_ceiling app.money,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_taste_price_positive check (
    price_ceiling is null or price_ceiling > 0
  )
);
select app.attach_updated_at('public.customer_taste_profiles');
alter table public.customer_taste_profiles enable row level security;
create policy customer_taste_profiles_owner_read on public.customer_taste_profiles
  for select to authenticated using (user_id = auth.uid());
revoke all on public.customer_taste_profiles from public, anon, authenticated;
grant select on public.customer_taste_profiles to authenticated;

create table public.customer_taste_categories (
  user_id uuid not null references public.customer_taste_profiles (user_id) on delete cascade,
  category_id uuid not null references public.categories (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, category_id)
);
create index customer_taste_categories_category_idx
  on public.customer_taste_categories (category_id, user_id);
alter table public.customer_taste_categories enable row level security;
create policy customer_taste_categories_owner_read on public.customer_taste_categories
  for select to authenticated using (user_id = auth.uid());
revoke all on public.customer_taste_categories from public, anon, authenticated;
grant select on public.customer_taste_categories to authenticated;

comment on table public.customer_taste_profiles is
  'Private optional customer taste constraints. Read and write only through owner-scoped RPCs.';
comment on table public.customer_taste_categories is
  'Categories chosen by the owning customer as taste preferences.';

insert into public.feature_flags (key, label, description, is_enabled, rollout_percentage)
values (
  'taste_match',
  'Taste Match recommendations',
  'Customer taste preferences and personalized menu recommendations. Keep disabled until the English and Hindi customer copy has been reviewed.',
  false,
  100
)
on conflict (key) do nothing;

-- The section is CMS managed like the other home rails. It remains invisible
-- until the separately controlled feature flag is enabled. The Hindi strings
-- are simple UI copy and still require the normal language review before rollout.
insert into public.cms_sections (
  id, kind, section_key, title, title_hi, subtitle, subtitle_hi,
  layout, item_limit, display_order, is_active, requires_auth
)
select
  '77777777-0000-0000-0000-000000000010'::uuid,
  'TASTE_MATCH',
  'taste-match',
  'For your taste',
  'आपकी पसंद के लिए',
  'A few picks based on your choices and past orders.',
  'आपकी पसंद और पिछले ऑर्डर के आधार पर कुछ सुझाव।',
  'CAROUSEL', 10, 16, true, true
where not exists (
  select 1 from public.cms_sections s
  where s.branch_id is null and s.section_key = 'taste-match' and s.deleted_at is null
);

create or replace function public.my_taste_profile()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_profile public.customer_taste_profiles;
begin
  if v_user is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to view your taste preferences.');
  end if;
  if not exists (
    select 1 from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = v_user and ur.is_active and r.code = 'CUSTOMER'
  ) then
    perform app.fail('PERMISSION_DENIED', 'Taste preferences are available to customer accounts.');
  end if;

  select * into v_profile
  from public.customer_taste_profiles p where p.user_id = v_user;

  return jsonb_build_object(
    'food_types', coalesce(to_jsonb(v_profile.food_types), '[]'::jsonb),
    'max_spice', v_profile.max_spice,
    'category_ids', coalesce((
      select jsonb_agg(tc.category_id order by tc.category_id)
      from public.customer_taste_categories tc
      join public.categories c on c.id = tc.category_id
      where tc.user_id = v_user and c.is_active and c.deleted_at is null
    ), '[]'::jsonb),
    'price_ceiling', v_profile.price_ceiling,
    'has_profile', v_profile.user_id is not null
      and (cardinality(v_profile.food_types) > 0 or v_profile.max_spice is not null
        or v_profile.price_ceiling is not null or exists (
          select 1 from public.customer_taste_categories tc
          join public.categories c on c.id = tc.category_id
          where tc.user_id = v_user and c.is_active and c.deleted_at is null
        ))
  );
end;
$$;

create or replace function public.save_my_taste_profile(
  p_food_types text[] default '{}',
  p_max_spice text default null,
  p_category_ids uuid[] default '{}',
  p_price_ceiling numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_food_types public.food_type[] := '{}';
  v_max_spice public.spice_level;
  v_category_ids uuid[] := coalesce(p_category_ids, '{}');
  v_food text;
begin
  if v_user is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to save your taste preferences.');
  end if;
  if not exists (
    select 1 from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = v_user and ur.is_active and r.code = 'CUSTOMER'
  ) then
    perform app.fail('PERMISSION_DENIED', 'Taste preferences are available to customer accounts.');
  end if;
  if coalesce(cardinality(p_food_types), 0) > 4
     or cardinality(coalesce(p_food_types, '{}')) <>
        cardinality(array(select distinct unnest(coalesce(p_food_types, '{}')))) then
    perform app.fail('INVALID_TASTE_PREFERENCES', 'Choose valid food types.');
  end if;
  foreach v_food in array coalesce(p_food_types, '{}') loop
    if v_food is null or v_food not in ('VEG', 'NON_VEG', 'EGG', 'VEGAN') then
      perform app.fail('INVALID_TASTE_PREFERENCES', 'Choose a food type from the menu.');
    end if;
    v_food_types := array_append(v_food_types, v_food::public.food_type);
  end loop;

  if p_max_spice is not null and p_max_spice not in ('NONE', 'MILD', 'MEDIUM', 'HOT', 'EXTRA_HOT') then
    perform app.fail('INVALID_TASTE_PREFERENCES', 'Choose a spice level from the menu.');
  end if;
  if p_max_spice is not null then v_max_spice := p_max_spice::public.spice_level; end if;

  if cardinality(v_category_ids) > 20
     or cardinality(v_category_ids) <>
        cardinality(array(select distinct unnest(v_category_ids))) then
    perform app.fail('INVALID_TASTE_PREFERENCES', 'Choose up to 20 menu categories.');
  end if;
  if exists (
    select 1
    from unnest(v_category_ids) selected(category_id)
    left join public.categories c on c.id = selected.category_id
    where c.id is null or not c.is_active or c.deleted_at is not null
  ) then
    perform app.fail('INVALID_TASTE_PREFERENCES', 'Choose active categories from the menu.');
  end if;
  if p_price_ceiling is not null and (p_price_ceiling < 1 or p_price_ceiling > 100000) then
    perform app.fail('INVALID_TASTE_PREFERENCES', 'Enter an item price between ₹1 and ₹100,000.');
  end if;

  insert into public.customer_taste_profiles (user_id, food_types, max_spice, price_ceiling)
  values (v_user, v_food_types, v_max_spice, p_price_ceiling)
  on conflict (user_id) do update set
    food_types = excluded.food_types,
    max_spice = excluded.max_spice,
    price_ceiling = excluded.price_ceiling,
    updated_at = now();

  delete from public.customer_taste_categories tc where tc.user_id = v_user;
  insert into public.customer_taste_categories (user_id, category_id)
  select v_user, selected.category_id from unnest(v_category_ids) selected(category_id);

  return public.my_taste_profile();
end;
$$;

create or replace function app.taste_match_state(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when (
    exists (
      select 1 from public.customer_taste_profiles p
      where p.user_id = p_user_id and (
        cardinality(p.food_types) > 0 or p.max_spice is not null or p.price_ceiling is not null
      )
    )
    or exists (
      select 1 from public.customer_taste_categories tc
      join public.categories c on c.id = tc.category_id
      where tc.user_id = p_user_id and c.is_active and c.deleted_at is null
    )
    or exists (select 1 from public.customer_favorites f where f.user_id = p_user_id)
    or exists (
      select 1 from public.review_items ri
      join public.reviews r on r.id = ri.review_id
      where r.user_id = p_user_id and r.status = 'PUBLISHED' and ri.rating >= 4
    )
    or exists (
      select 1 from public.orders o
      join public.order_items oi on oi.order_id = o.id
      where o.user_id = p_user_id and o.status in ('DELIVERED', 'COMPLETED')
        and not oi.is_cancelled and oi.product_id is not null
    )
  ) then 'MATCHED' else 'SETUP' end;
$$;

create or replace function app.taste_match_products(
  p_user_id uuid,
  p_branch_id uuid,
  p_limit int
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_state text;
  v_result jsonb;
begin
  if v_user is null or p_user_id is distinct from v_user
     or not app.has_role('CUSTOMER') then return '[]'::jsonb; end if;
  if not public.feature_enabled('taste_match', v_user) then return '[]'::jsonb; end if;
  if not exists (
    select 1 from public.branches b
    where b.id = v_branch and b.is_active and b.deleted_at is null
  ) then return '[]'::jsonb; end if;
  v_state := app.taste_match_state(v_user);

  with preference as (
    select
      coalesce(p.food_types, '{}'::public.food_type[]) as food_types,
      p.max_spice,
      p.price_ceiling,
      coalesce((select array_agg(tc.category_id) from public.customer_taste_categories tc
                join public.categories c on c.id = tc.category_id
                where tc.user_id = v_user and c.is_active and c.deleted_at is null),
               '{}'::uuid[]) as category_ids
    from (select 1) one
    left join public.customer_taste_profiles p on p.user_id = v_user
  ), candidates as (
    select
      p.id, p.name, p.slug, p.short_description, p.thumbnail_path, p.hero_image_path,
      p.food_type, p.spice_level, p.base_price, p.compare_price, p.preparation_minutes,
      p.rating_average, p.rating_count, p.is_best_seller, p.is_new, p.is_featured,
      p.is_combo, p.is_recommended, p.category_id, c.name as category_name,
      p.display_order, p.order_count,
      (variant_data.variant_count > 0) as has_variants,
      case when variant_data.variant_count > 0 then variant_data.min_price else p.base_price end as current_price,
      exists (
        select 1 from public.customer_favorites f
        where f.user_id = v_user and f.product_id = p.id
      ) as is_favorite,
      exists (
        select 1 from public.review_items ri
        join public.reviews r on r.id = ri.review_id
        where ri.product_id = p.id and ri.rating >= 4
          and r.user_id = v_user and r.status = 'PUBLISHED'
      ) as positive_review,
      exists (
        select 1 from public.order_items oi
        join public.orders o on o.id = oi.order_id
        where oi.product_id = p.id and o.user_id = v_user
          and o.status in ('DELIVERED', 'COMPLETED') and not oi.is_cancelled
      ) as ordered_before,
      p.category_id = any(pref.category_ids) as favorite_category,
      p.food_type = any(pref.food_types) as food_type_match,
      pref.food_types,
      pref.max_spice,
      pref.price_ceiling,
      pref.category_ids,
      branch_popularity.order_count as outlet_order_count
    from public.products p
    join public.categories c on c.id = p.category_id
    cross join preference pref
    cross join lateral (
      select count(*)::int as variant_count, min(v.price) as min_price
      from public.product_variants v
      where v.product_id = p.id and v.is_active and v.deleted_at is null
        and app.variant_orderable(v.id)
    ) variant_data
    cross join lateral (
      select coalesce(sum(oi.quantity), 0)::int as order_count
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where oi.product_id = p.id and o.branch_id = v_branch
        and o.status in ('DELIVERED', 'COMPLETED') and not oi.is_cancelled
    ) branch_popularity
    where p.is_active and p.deleted_at is null
      and c.is_active and c.deleted_at is null
      and (p.branch_id is null or p.branch_id = v_branch)
      and (c.branch_id is null or c.branch_id = v_branch)
      and app.product_orderable(p.id, v_branch)
      and (not exists (
            select 1 from public.product_variants v
            where v.product_id = p.id and v.is_active and v.deleted_at is null
          ) or variant_data.variant_count > 0)
      and (cardinality(pref.food_types) = 0 or p.food_type = any(pref.food_types))
      and (pref.max_spice is null or array_position(enum_range(null::public.spice_level), p.spice_level)
           <= array_position(enum_range(null::public.spice_level), pref.max_spice))
      and (pref.price_ceiling is null or
           (case when variant_data.variant_count > 0 then variant_data.min_price else p.base_price end)
             <= pref.price_ceiling)
      and (v_state <> 'SETUP' or branch_popularity.order_count > 0
        or p.order_count > 0 or p.is_best_seller or p.is_new or p.is_featured
        or p.is_recommended or p.is_combo or p.rating_count > 0)
  ), scored as (
    select candidate.*,
      case when v_state = 'SETUP' then
          least(coalesce(nullif(outlet_order_count, 0), order_count), 40) * 0.75
        + rating_average * 0.5
        + (case when is_best_seller or is_new or is_featured or is_recommended or is_combo then 1 else 0 end)
      else
          (case when favorite_category then 50 else 0 end)
        + (case when is_favorite then 40 else 0 end)
        + (case when positive_review then 25 else 0 end)
        + (case when ordered_before then 18 else 0 end)
        + (case when food_type_match then 5 else 0 end)
        + least(outlet_order_count, 40) * 0.75
        + least(order_count, 40) * 0.25
        + rating_average * 0.5
        + (case when is_best_seller or is_featured or is_recommended or is_combo then 1 else 0 end)
      end as score,
      row_number() over (
        partition by category_id
        order by
          case when v_state = 'SETUP' then coalesce(nullif(outlet_order_count, 0), order_count) else
            (case when favorite_category then 50 else 0 end)
            + (case when is_favorite then 40 else 0 end)
            + (case when positive_review then 25 else 0 end)
            + (case when ordered_before then 18 else 0 end)
            + (case when food_type_match then 5 else 0 end)
            + least(outlet_order_count, 40) * 0.75 + rating_average * 0.5
          end desc,
          outlet_order_count desc, rating_average desc, display_order asc, id asc
      ) as category_position
    from candidates candidate
  ), explained as (
    select scored.*,
      case
        when v_state = 'SETUP' and outlet_order_count > 0 then 'POPULAR_AT_OUTLET'
        when v_state = 'SETUP' and order_count > 0 then 'POPULAR_MENU_PICK'
        when v_state = 'SETUP' and (is_best_seller or is_new or is_featured or is_recommended or is_combo)
          then 'CURATED_MENU_PICK'
        when v_state = 'SETUP' then 'CUSTOMER_RATED_MENU_PICK'
        when favorite_category then 'FAVORITE_CATEGORY'
        when is_favorite then 'SAVED_FAVORITE'
        when positive_review then 'POSITIVE_REVIEW'
        when ordered_before then 'ORDERED_BEFORE'
        when spice_level = 'MILD' then 'MILD_SPICE'
        when food_type_match then 'FOOD_TYPE_MATCH'
        when outlet_order_count > 0 then 'POPULAR_AT_OUTLET'
        when order_count > 0 then 'POPULAR_MENU_PICK'
        when is_best_seller or is_new or is_featured or is_recommended or is_combo then 'CURATED_MENU_PICK'
        else 'TASTE_PROFILE_MATCH'
      end as reason_code
    from scored
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', item.id,
      'name', item.name,
      'slug', item.slug,
      'short_description', item.short_description,
      'thumbnail_path', item.thumbnail_path,
      'hero_image_path', item.hero_image_path,
      'food_type', item.food_type,
      'spice_level', item.spice_level,
      'base_price', item.base_price,
      'compare_price', item.compare_price,
      'preparation_minutes', item.preparation_minutes,
      'rating_average', item.rating_average,
      'rating_count', item.rating_count,
      'is_best_seller', item.is_best_seller,
      'is_new', item.is_new,
      'is_featured', item.is_featured,
      'is_combo', item.is_combo,
      'is_recommended', item.is_recommended,
      'category_id', item.category_id,
      'category_name', item.category_name,
      'is_available', true,
      'availability_state', 'AVAILABLE',
      'display_order', item.display_order,
      'order_count', item.order_count,
      'has_variants', item.has_variants,
      'min_price', case when item.has_variants then item.current_price else null end,
      'reason_code', item.reason_code,
      'taste_state', v_state
    ) order by item.category_position, item.score desc,
      item.outlet_order_count desc, item.rating_average desc, item.display_order, item.id
  ), '[]'::jsonb)
  into v_result
  from (
    select * from explained
    where category_position <= 3
    order by category_position, score desc, outlet_order_count desc,
      rating_average desc, display_order, id
    limit least(greatest(coalesce(p_limit, 10), 1), 50)
  ) item;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

-- These helpers are called from the owner-scoped home-feed RPC. They are not
-- client RPCs; keeping EXECUTE private also prevents profile-state probing.
revoke all on function app.taste_match_state(uuid) from public, anon, authenticated;
revoke all on function app.taste_match_products(uuid, uuid, int) from public, anon, authenticated;

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
  if p_section.kind = 'TASTE_MATCH' then
    return app.taste_match_products(p_user_id, p_branch_id, p_section.item_limit);
  end if;

  v_max_price := nullif(p_section.rule ->> 'max_price', '')::numeric;

  with base as (
    select
      p.id, p.name, p.slug, p.short_description, p.thumbnail_path, p.hero_image_path,
      p.food_type, p.spice_level, p.base_price, p.compare_price, p.preparation_minutes,
      p.rating_average, p.rating_count, p.is_best_seller, p.is_new, p.is_featured,
      p.category_id, c.name as category_name,
      app.product_orderable(p.id, p_branch_id) as is_available,
      p.display_order, p.order_count,
      (select min(v.price) from public.product_variants v
       where v.product_id = p.id and v.is_active and v.deleted_at is null) as min_variant_price,
      (select count(*) from public.product_variants v
       where v.product_id = p.id and v.is_active and v.deleted_at is null) as variant_count
    from public.products p
    join public.categories c on c.id = p.category_id
    where p.is_active and p.deleted_at is null and c.is_active and c.deleted_at is null
      and (p.branch_id is null or p.branch_id = p_branch_id)
      and case p_section.kind
        when 'BEST_SELLERS' then p.is_best_seller
        when 'NEW_ARRIVALS' then p.is_new
        when 'RECOMMENDED_COMBOS' then p.is_combo or p.is_recommended
        when 'CUSTOMER_FAVOURITES' then p.rating_count > 0
        when 'PRICE_BUCKET' then v_max_price is null or p.base_price <= v_max_price
        when 'POPULAR_NOW' then true
        when 'PRODUCT_CAROUSEL' then
          (cardinality(p_section.product_ids) = 0 or p.id = any (p_section.product_ids))
          and (p_section.category_id is null or p.category_id = p_section.category_id)
        when 'BUY_AGAIN' then p_user_id is not null and exists (
          select 1 from public.order_items oi join public.orders o on o.id = oi.order_id
          where oi.product_id = p.id and o.user_id = p_user_id
            and o.status in ('DELIVERED', 'COMPLETED')
        )
        when 'RECENTLY_ORDERED' then p_user_id is not null and exists (
          select 1 from public.order_items oi join public.orders o on o.id = oi.order_id
          where oi.product_id = p.id and o.user_id = p_user_id
            and o.created_at > now() - interval '60 days'
        )
        else true
      end
      and (p_section.collection_id is null or exists (
        select 1 from public.collection_products cp
        where cp.collection_id = p_section.collection_id and cp.product_id = p.id
      ))
  )
  select jsonb_agg(to_jsonb(ordered) order by ordered.sort_key)
  into v_result
  from (
    select base.*,
      case p_section.kind
        when 'POPULAR_NOW' then -base.order_count
        when 'BEST_SELLERS' then -base.order_count
        when 'CUSTOMER_FAVOURITES' then -(base.rating_average * 100)::int
        else base.display_order
      end as sort_key
    from base
    order by base.is_available desc,
      case p_section.kind
        when 'POPULAR_NOW' then -base.order_count
        when 'BEST_SELLERS' then -base.order_count
        when 'CUSTOMER_FAVOURITES' then -(base.rating_average * 100)::int
        else base.display_order
      end
    limit p_section.item_limit
  ) ordered;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

create or replace function public.home_feed(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_user uuid := auth.uid();
  v_tz text;
  v_now timestamptz := now();
  v_section public.cms_sections;
  v_sections jsonb := '[]'::jsonb;
  v_payload jsonb;
begin
  select timezone into v_tz from public.branches where id = v_branch;
  v_tz := coalesce(v_tz, 'Asia/Kolkata');

  for v_section in
    select * from public.cms_sections
    where (branch_id is null or branch_id = v_branch)
    order by display_order, created_at
  loop
    if not app.section_is_live(v_section, v_now, v_tz) then continue; end if;
    if v_section.requires_auth and v_user is null then continue; end if;
    if v_section.kind = 'TASTE_MATCH' and
       (v_user is null or not app.has_role('CUSTOMER')
        or not public.feature_enabled('taste_match', v_user)) then
      continue;
    end if;

    v_payload := jsonb_build_object(
      'id', v_section.id,
      'key', v_section.section_key,
      'kind', v_section.kind,
      'title', v_section.title,
      'subtitle', v_section.subtitle,
      'action_label', v_section.action_label,
      'action_route', v_section.action_route,
      'layout', v_section.layout,
      'background_color', v_section.background_color,
      'text_color', v_section.text_color,
      'image_path', v_section.image_path,
      'rich_text', v_section.rich_text,
      'display_order', v_section.display_order
    );

    if v_section.kind in ('HERO_CAROUSEL', 'CAMPAIGN_BANNER') then
      v_payload := v_payload || jsonb_build_object('banners', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', b.id, 'title', b.title, 'subtitle', b.subtitle, 'badge_text', b.badge_text,
          'image_path', b.image_path, 'image_path_wide', b.image_path_wide,
          'alt_text', b.alt_text, 'background_color', b.background_color,
          'link_kind', b.link_kind, 'link_category_id', b.link_category_id,
          'link_product_id', b.link_product_id, 'link_coupon_id', b.link_coupon_id,
          'link_collection_id', b.link_collection_id, 'link_url', b.link_url,
          'link_route', b.link_route
        ) order by b.display_order)
        from public.cms_banners b
        where b.section_id = v_section.id and b.is_active and b.deleted_at is null
          and (b.starts_at is null or b.starts_at <= v_now)
          and (b.ends_at is null or b.ends_at > v_now)
      ), '[]'::jsonb));
    elsif v_section.kind in ('CATEGORY_GRID', 'CATEGORY_CAROUSEL') then
      v_payload := v_payload || jsonb_build_object('categories', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', c.id, 'name', c.name, 'slug', c.slug, 'image_path', c.image_path,
          'thumbnail_path', c.thumbnail_path, 'icon_name', c.icon_name,
          'accent_color', c.accent_color,
          'product_count', (select count(*) from public.products p
            where p.category_id = c.id and p.is_active and p.deleted_at is null)
        ) order by c.display_order)
        from public.categories c
        where c.is_active and c.deleted_at is null
          and (c.branch_id is null or c.branch_id = v_branch)
          and (c.day_part = 'ALL_DAY' or v_section.rule ->> 'day_part' is null
               or c.day_part = (v_section.rule ->> 'day_part')::public.day_part)
        limit v_section.item_limit
      ), '[]'::jsonb));
    elsif v_section.kind in ('TODAYS_OFFERS', 'COUPON_STRIP') then
      v_payload := v_payload || jsonb_build_object('coupons', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', cp.id, 'code', cp.code, 'title', cp.title, 'description', cp.description,
          'discount_kind', cp.discount_kind, 'discount_value', cp.discount_value,
          'min_order_amount', cp.min_order_amount, 'max_discount_amount', cp.max_discount_amount,
          'banner_path', cp.banner_path, 'ends_at', cp.ends_at
        ) order by cp.created_at desc)
        from public.coupons cp
        where cp.is_active and cp.is_visible and cp.deleted_at is null
          and cp.starts_at <= v_now and (cp.ends_at is null or cp.ends_at > v_now)
          and (cp.branch_id is null or cp.branch_id = v_branch)
        limit v_section.item_limit
      ), '[]'::jsonb));
    elsif v_section.kind = 'RICH_TEXT' then
      null;
    else
      v_payload := v_payload || jsonb_build_object(
        'products', app.section_products(v_section, v_branch, v_user)
      );
      if v_section.kind = 'TASTE_MATCH' then
        v_payload := v_payload || jsonb_build_object('taste_state', app.taste_match_state(v_user));
      end if;
    end if;

    if v_section.kind not in ('RICH_TEXT', 'TASTE_MATCH')
       and coalesce(jsonb_array_length(
         coalesce(v_payload -> 'products', v_payload -> 'banners',
                  v_payload -> 'categories', v_payload -> 'coupons', '[]'::jsonb)
       ), 0) = 0 then
      continue;
    end if;
    v_sections := v_sections || jsonb_build_array(v_payload);
  end loop;

  return jsonb_build_object(
    'branch', public.branch_ordering_state(v_branch),
    'sections', v_sections,
    'generated_at', v_now
  );
end;
$$;

revoke all on function public.my_taste_profile() from public, anon;
revoke all on function public.save_my_taste_profile(text[], text, uuid[], numeric) from public, anon;
grant execute on function public.my_taste_profile() to authenticated, service_role;
grant execute on function public.save_my_taste_profile(text[], text, uuid[], numeric) to authenticated, service_role;

-- Keep customer preference tables out of the default operator-visible CRUD
-- grants. Only the owner-scoped profile RPC and personalized home feed read them.
revoke all on public.customer_taste_profiles, public.customer_taste_categories from anon, authenticated;
grant select on public.customer_taste_profiles, public.customer_taste_categories to authenticated;

alter publication supabase_realtime add table
  public.customer_favorites,
  public.customer_taste_profiles;
alter table public.customer_favorites replica identity full;
alter table public.customer_taste_profiles replica identity full;
