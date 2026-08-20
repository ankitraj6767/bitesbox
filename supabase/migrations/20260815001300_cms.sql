-- ═══════════════════════════════════════════════════════════════════════════
-- 0013 · CMS
--
-- Everything the customer sees on the home screen is data: sections, their
-- order, their titles, their scheduling and their linked content. No release is
-- required to run a campaign or reshuffle the homepage.
-- ═══════════════════════════════════════════════════════════════════════════

create table public.cms_sections (
  id                  uuid primary key default gen_random_uuid(),
  branch_id           uuid references public.branches (id) on delete cascade,
  kind                public.home_section_kind not null,
  -- Stable machine key so the Flutter app can special-case a renderer.
  section_key         text not null,
  title               text,
  subtitle            text,
  -- Optional CTA rendered on the section header, e.g. "See all".
  action_label        text,
  action_route        text,

  -- Content binding (only the relevant column is used per kind)
  category_id         uuid references public.categories (id) on delete cascade,
  collection_id       uuid references public.collections (id) on delete cascade,
  coupon_id           uuid references public.coupons (id) on delete set null,
  product_ids         uuid[] not null default '{}',
  -- Rule-driven rails, e.g. {"max_price": 199} or {"limit": 10}
  rule                jsonb not null default '{}'::jsonb,

  -- Presentation
  layout              text not null default 'CAROUSEL',
  item_limit          smallint not null default 10,
  background_color    text,
  text_color          text,
  image_path          text,
  rich_text           text,

  display_order       int not null default 0,
  is_active           boolean not null default true,
  -- Scheduling: a section can appear only during a window and/or day part.
  starts_at           timestamptz,
  ends_at             timestamptz,
  valid_days_of_week  smallint[] not null default '{0,1,2,3,4,5,6}',
  valid_from_time     time,
  valid_to_time       time,
  -- Restrict a rail to signed-in customers (e.g. "Buy Again").
  requires_auth       boolean not null default false,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  updated_by          uuid references auth.users (id) on delete set null,
  deleted_at          timestamptz,

  constraint cms_sections_layout check (layout in ('CAROUSEL', 'GRID', 'LIST', 'BANNER', 'STRIP')),
  constraint cms_sections_window check (ends_at is null or starts_at is null or ends_at > starts_at),
  constraint cms_sections_limit check (item_limit between 1 and 50),
  constraint cms_sections_colors check (
    (background_color is null or background_color ~ '^#[0-9A-Fa-f]{6}$')
    and (text_color is null or text_color ~ '^#[0-9A-Fa-f]{6}$')
  )
);

create unique index cms_sections_key
  on public.cms_sections (coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid), section_key)
  where deleted_at is null;
create index cms_sections_active_idx on public.cms_sections (display_order)
  where is_active and deleted_at is null;

select app.attach_updated_at('public.cms_sections');

comment on table public.cms_sections is
  'Admin-composed homepage blocks. Order, visibility, titles and scheduling are all data.';

-- ─── Banners ───────────────────────────────────────────────────────────────
create table public.cms_banners (
  id                uuid primary key default gen_random_uuid(),
  section_id        uuid references public.cms_sections (id) on delete cascade,
  branch_id         uuid references public.branches (id) on delete cascade,
  title             text,
  subtitle          text,
  badge_text        text,
  image_path        text not null,
  -- Separate artwork for tall phones vs. tablets.
  image_path_wide   text,
  alt_text          text,
  background_color  text,

  link_kind         public.banner_link_kind not null default 'NONE',
  link_category_id  uuid references public.categories (id) on delete set null,
  link_product_id   uuid references public.products (id) on delete set null,
  link_coupon_id    uuid references public.coupons (id) on delete set null,
  link_collection_id uuid references public.collections (id) on delete set null,
  link_url          text,
  link_route        text,

  display_order     int not null default 0,
  is_active         boolean not null default true,
  starts_at         timestamptz,
  ends_at           timestamptz,

  -- Engagement counters for campaign reporting.
  impression_count  int not null default 0,
  click_count       int not null default 0,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,

  constraint cms_banners_window check (ends_at is null or starts_at is null or ends_at > starts_at),
  constraint cms_banners_link_shape check (
    case link_kind
      when 'CATEGORY' then link_category_id is not null
      when 'PRODUCT' then link_product_id is not null
      when 'COUPON' then link_coupon_id is not null
      when 'COLLECTION' then link_collection_id is not null
      when 'EXTERNAL_URL' then link_url is not null
      when 'IN_APP_ROUTE' then link_route is not null
      else true
    end
  )
);

create index cms_banners_section_idx on public.cms_banners (section_id, display_order)
  where is_active and deleted_at is null;

select app.attach_updated_at('public.cms_banners');

-- ─── Legal / informational documents ───────────────────────────────────────
create table public.cms_documents (
  id            uuid primary key default gen_random_uuid(),
  kind          public.legal_document_kind not null,
  locale        text not null default 'en',
  title         text not null,
  body          text not null,
  version       text not null default '1.0',
  effective_from date not null default current_date,
  is_published  boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  updated_by    uuid references auth.users (id) on delete set null,

  constraint cms_documents_locale check (locale in ('en', 'hi'))
);

create unique index cms_documents_key on public.cms_documents (kind, locale, version);
create index cms_documents_published_idx on public.cms_documents (kind, locale)
  where is_published;

select app.attach_updated_at('public.cms_documents');

-- ─── FAQs ──────────────────────────────────────────────────────────────────
create table public.cms_faqs (
  id            uuid primary key default gen_random_uuid(),
  category      text not null default 'GENERAL',
  question      text not null,
  answer        text not null,
  locale        text not null default 'en',
  display_order int not null default 0,
  is_published  boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index cms_faqs_published_idx on public.cms_faqs (category, display_order)
  where is_published;

select app.attach_updated_at('public.cms_faqs');

-- ═══════════════════════════════════════════════════════════════════════════
-- HOME FEED — one call returns the entire composed home screen
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function app.section_is_live(
  p_section public.cms_sections,
  p_at timestamptz,
  p_timezone text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    p_section.is_active
    and p_section.deleted_at is null
    and (p_section.starts_at is null or p_section.starts_at <= p_at)
    and (p_section.ends_at is null or p_section.ends_at > p_at)
    and extract(dow from (p_at at time zone p_timezone))::smallint = any (p_section.valid_days_of_week)
    and (
      p_section.valid_from_time is null
      or (p_at at time zone p_timezone)::time between p_section.valid_from_time and p_section.valid_to_time
    );
$$;

-- Resolves the product list backing a single section.
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
      -- Cheapest variant price so cards show "from ₹X" correctly.
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
      -- Unavailable items sink to the end of every rail.
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
    if not app.section_is_live(v_section, v_now, v_tz) then
      continue;
    end if;

    if v_section.requires_auth and v_user is null then
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
        select jsonb_agg(
          jsonb_build_object(
            'id', b.id,
            'title', b.title,
            'subtitle', b.subtitle,
            'badge_text', b.badge_text,
            'image_path', b.image_path,
            'image_path_wide', b.image_path_wide,
            'alt_text', b.alt_text,
            'background_color', b.background_color,
            'link_kind', b.link_kind,
            'link_category_id', b.link_category_id,
            'link_product_id', b.link_product_id,
            'link_coupon_id', b.link_coupon_id,
            'link_collection_id', b.link_collection_id,
            'link_url', b.link_url,
            'link_route', b.link_route
          ) order by b.display_order
        )
        from public.cms_banners b
        where b.section_id = v_section.id
          and b.is_active
          and b.deleted_at is null
          and (b.starts_at is null or b.starts_at <= v_now)
          and (b.ends_at is null or b.ends_at > v_now)
      ), '[]'::jsonb));

    elsif v_section.kind in ('CATEGORY_GRID', 'CATEGORY_CAROUSEL') then
      v_payload := v_payload || jsonb_build_object('categories', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'id', c.id,
            'name', c.name,
            'slug', c.slug,
            'image_path', c.image_path,
            'thumbnail_path', c.thumbnail_path,
            'icon_name', c.icon_name,
            'accent_color', c.accent_color,
            'product_count', (
              select count(*) from public.products p
              where p.category_id = c.id and p.is_active and p.deleted_at is null
            )
          ) order by c.display_order
        )
        from public.categories c
        where c.is_active
          and c.deleted_at is null
          and (c.branch_id is null or c.branch_id = v_branch)
          -- The rule holds text; cast it so the enum comparison is valid. A rule
          -- without a day_part means "no day-part filter".
          and (
            c.day_part = 'ALL_DAY'
            or v_section.rule ->> 'day_part' is null
            or c.day_part = (v_section.rule ->> 'day_part')::public.day_part
          )
        limit v_section.item_limit
      ), '[]'::jsonb));

    elsif v_section.kind in ('TODAYS_OFFERS', 'COUPON_STRIP') then
      v_payload := v_payload || jsonb_build_object('coupons', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'id', cp.id,
            'code', cp.code,
            'title', cp.title,
            'description', cp.description,
            'discount_kind', cp.discount_kind,
            'discount_value', cp.discount_value,
            'min_order_amount', cp.min_order_amount,
            'max_discount_amount', cp.max_discount_amount,
            'banner_path', cp.banner_path,
            'ends_at', cp.ends_at
          ) order by cp.created_at desc
        )
        from public.coupons cp
        where cp.is_active
          and cp.is_visible
          and cp.deleted_at is null
          and cp.starts_at <= v_now
          and (cp.ends_at is null or cp.ends_at > v_now)
          and (cp.branch_id is null or cp.branch_id = v_branch)
        limit v_section.item_limit
      ), '[]'::jsonb));

    elsif v_section.kind = 'RICH_TEXT' then
      null; -- rich_text already included

    else
      v_payload := v_payload || jsonb_build_object(
        'products', app.section_products(v_section, v_branch, v_user)
      );
    end if;

    -- Skip empty content rails so the customer never sees a blank header.
    if v_section.kind not in ('RICH_TEXT')
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

comment on function public.home_feed is
  'Fully composed, admin-configured home screen in a single round trip.';

-- ─── Public branding / config bundle ───────────────────────────────────────
create or replace function public.app_config(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
  v_branch_row public.branches;
begin
  select * into v_branch_row from public.branches where id = v_branch;

  return jsonb_build_object(
    'branch', case when v_branch_row.id is null then null else jsonb_build_object(
      'id', v_branch_row.id,
      'code', v_branch_row.code,
      'name', v_branch_row.name,
      'phone', v_branch_row.phone,
      'whatsapp_phone', v_branch_row.whatsapp_phone,
      'email', v_branch_row.email,
      'address_line1', v_branch_row.address_line1,
      'address_line2', v_branch_row.address_line2,
      'city', v_branch_row.city,
      'state', v_branch_row.state,
      'postal_code', v_branch_row.postal_code,
      'latitude', v_branch_row.latitude,
      'longitude', v_branch_row.longitude,
      'google_maps_url', v_branch_row.google_maps_url,
      'timezone', v_branch_row.timezone,
      'currency_code', v_branch_row.currency_code,
      'service_mode', v_branch_row.service_mode,
      'gstin', v_branch_row.gstin,
      'fssai_licence_no', v_branch_row.fssai_licence_no
    ) end,
    'ordering_state', public.branch_ordering_state(v_branch),
    'settings', coalesce((
      select jsonb_object_agg(s.key, s.value)
      from public.settings s
      where s.is_public and (s.branch_id is null or s.branch_id = v_branch)
    ), '{}'::jsonb),
    'feature_flags', coalesce((
      select jsonb_object_agg(f.key, public.feature_enabled(f.key))
      from public.feature_flags f
      where f.branch_id is null or f.branch_id = v_branch
    ), '{}'::jsonb),
    'hours', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'day_of_week', h.day_of_week,
          'opens_at', h.opens_at,
          'closes_at', h.closes_at,
          'closes_next_day', h.closes_next_day,
          'day_part', h.day_part,
          'is_closed', h.is_closed
        ) order by h.day_of_week, h.opens_at
      )
      from public.branch_hours h where h.branch_id = v_branch
    ), '[]'::jsonb)
  );
end;
$$;

comment on function public.app_config is
  'Branding, contact details, public settings, feature flags and trading hours in one call.';
