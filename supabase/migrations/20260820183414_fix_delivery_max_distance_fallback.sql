-- The global delivery.max_distance_km setting must be able to extend the
-- widest active radius zone. Previously resolve_delivery_zone stopped at the
-- zone's own max (8 km), so setting the global limit to 20 km had no effect for
-- addresses between 8 km and 20 km.
create or replace function app.resolve_delivery_zone(
  p_latitude numeric,
  p_longitude numeric,
  p_branch_id uuid default null
)
returns table (
  zone_id uuid,
  branch_id uuid,
  distance_km numeric,
  zone_name text,
  delivery_fee numeric,
  min_order_amount numeric,
  free_delivery_threshold numeric,
  base_eta_minutes int,
  extra_eta_minutes int,
  cod_enabled boolean,
  max_cod_amount numeric,
  is_serviceable boolean,
  per_km_surcharge numeric,
  surcharge_after_km numeric,
  peak_surcharge numeric,
  peak_starts_at time,
  peak_ends_at time,
  dynamic_surcharge numeric
)
language sql
stable
set search_path = ''
as $$
  with target_branches as (
    select b.id, b.latitude, b.longitude
    from public.branches b
    where b.deleted_at is null
      and b.is_active
      and (p_branch_id is null or b.id = p_branch_id)
  ),
  candidates as (
    select
      z.id                as zone_id,
      z.branch_id         as branch_id,
      app.haversine_km(tb.latitude, tb.longitude, p_latitude, p_longitude) as distance_km,
      z.name              as zone_name,
      z.delivery_fee,
      z.min_order_amount,
      z.free_delivery_threshold,
      z.base_eta_minutes,
      z.extra_eta_minutes,
      z.cod_enabled,
      z.max_cod_amount,
      z.is_serviceable,
      z.per_km_surcharge,
      z.surcharge_after_km,
      z.peak_surcharge,
      z.peak_starts_at,
      z.peak_ends_at,
      z.dynamic_surcharge,
      z.priority,
      z.kind,
      z.min_distance_km,
      z.max_distance_km,
      z.polygon
    from public.delivery_zones z
    join target_branches tb on tb.id = z.branch_id
    where z.is_active and z.deleted_at is null
  ),
  matched as (
    select c.*
    from candidates c
    where
      (c.kind = 'RADIUS'
        and c.distance_km >= c.min_distance_km
        and c.distance_km <= c.max_distance_km)
      or
      (c.kind = 'POLYGON'
        and app.point_in_ring(p_latitude, p_longitude, c.polygon -> 0))
  ),
  fallback as (
    select c.*
    from candidates c
    where c.kind = 'RADIUS'
      and c.is_serviceable
      and c.distance_km <= app.setting_numeric('delivery.max_distance_km', 12)
      and c.max_distance_km = (
        select max(widest.max_distance_km)
        from candidates widest
        where widest.kind = 'RADIUS'
          and widest.is_serviceable
      )
      and not exists (select 1 from matched)
    order by c.priority, c.distance_km
    limit 1
  ),
  selected as (
    select * from matched
    union all
    select * from fallback
  )
  select
    c.zone_id, c.branch_id, c.distance_km, c.zone_name,
    c.delivery_fee, c.min_order_amount, c.free_delivery_threshold,
    c.base_eta_minutes, c.extra_eta_minutes,
    c.cod_enabled, c.max_cod_amount, c.is_serviceable,
    c.per_km_surcharge, c.surcharge_after_km,
    c.peak_surcharge, c.peak_starts_at, c.peak_ends_at, c.dynamic_surcharge
  from selected c
  order by c.priority, c.distance_km
  limit 1;
$$;
