-- Manual operator override must be honored by both the branch state and the
-- product-orderability gate. The latest USER OPEN event is the explicit signal;
-- scheduler auto-resume events remain subject to the normal trading schedule.
create or replace function app.manual_open_override(p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select l.status = 'OPEN'::public.branch_status
       and l.accepting_orders
       and l.actor_kind = 'USER'::public.actor_kind
    from public.branch_status_log l
    where l.branch_id = p_branch_id
    order by l.created_at desc, l.id desc
    limit 1
  ), false);
$$;

comment on function app.manual_open_override(uuid) is
  'Whether the latest human OPEN action intentionally overrides scheduled trading hours.';

create or replace function public.branch_ordering_state(p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch public.branches;
  v_in_hours boolean;
  v_manual_override boolean;
  v_maintenance boolean;
  v_accepting boolean;
  v_reason text;
begin
  select * into v_branch
  from public.branches
  where id = coalesce(p_branch_id, app.default_branch_id())
    and deleted_at is null;

  if not found then
    return jsonb_build_object(
      'accepting_orders', false,
      'reason_code', 'BRANCH_NOT_FOUND',
      'message', 'We could not find a Bites Box outlet for this location.'
    );
  end if;

  v_maintenance := coalesce(app.setting_bool('maintenance.enabled', false), false);
  v_in_hours := app.is_within_trading_hours(v_branch.id);
  v_manual_override := app.manual_open_override(v_branch.id);

  if v_maintenance then
    v_accepting := false;
    v_reason := 'MAINTENANCE_MODE';
  elsif not v_branch.is_active then
    v_accepting := false;
    v_reason := 'BRANCH_INACTIVE';
  elsif v_branch.status = 'CLOSED' or not v_branch.accepting_orders then
    v_accepting := false;
    v_reason := coalesce(v_branch.status_reason::text, 'RESTAURANT_CLOSED');
  elsif v_branch.status = 'PAUSED' then
    v_accepting := false;
    v_reason := 'ORDERING_PAUSED';
  elsif v_manual_override then
    v_accepting := true;
    v_reason := null;
  elsif not v_in_hours then
    v_accepting := false;
    v_reason := 'OUTSIDE_TRADING_HOURS';
  else
    v_accepting := true;
    v_reason := null;
  end if;

  return jsonb_build_object(
    'branch_id',        v_branch.id,
    'branch_name',      v_branch.name,
    'status',           v_branch.status,
    'accepting_orders', v_accepting,
    'is_busy',          v_branch.status = 'BUSY',
    'within_hours',     v_in_hours,
    'manual_override',  v_manual_override,
    'maintenance',      v_maintenance,
    'reason_code',      v_reason,
    'status_note',      v_branch.status_note,
    'service_mode',     v_branch.service_mode,
    'prep_minutes',     v_branch.default_prep_minutes + v_branch.rush_buffer_minutes,
    'auto_resume_at',   v_branch.auto_resume_at,
    'next_opens_at',    null::timestamptz
  );
end;
$$;

create or replace function app.product_in_schedule(
  p_product_id uuid,
  p_branch_id uuid,
  p_at timestamptz default now()
)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  v_tz text;
  v_local timestamp;
  v_dow smallint;
  v_time time;
  v_has_windows boolean;
begin
  if app.manual_open_override(p_branch_id) then
    return true;
  end if;

  select timezone into v_tz from public.branches where id = p_branch_id;
  v_tz := coalesce(v_tz, 'Asia/Kolkata');
  v_local := p_at at time zone v_tz;
  v_dow := extract(dow from v_local)::smallint;
  v_time := v_local::time;

  select exists (
    select 1 from public.product_schedules s
    where s.product_id = p_product_id
      and s.is_active
      and (s.branch_id is null or s.branch_id = p_branch_id)
  ) into v_has_windows;

  if not v_has_windows then
    return true;
  end if;

  return exists (
    select 1 from public.product_schedules s
    where s.product_id = p_product_id
      and s.is_active
      and (s.branch_id is null or s.branch_id = p_branch_id)
      and v_dow = any (s.days_of_week)
      and v_time between s.starts_at and s.ends_at
      and (s.valid_from is null or v_local::date >= s.valid_from)
      and (s.valid_until is null or v_local::date <= s.valid_until)
  );
end;
$$;

-- Hosted migration history had a stale copy without the enum cast in this
-- category filter. Keep the enum comparison typed explicitly.
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
      null;

    else
      v_payload := v_payload || jsonb_build_object(
        'products', app.section_products(v_section, v_branch, v_user)
      );
    end if;

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
