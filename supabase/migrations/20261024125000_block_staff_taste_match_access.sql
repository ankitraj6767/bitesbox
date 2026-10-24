-- Staff accounts can retain the CUSTOMER role after staff-role grants. Keep the
-- customer Taste Match rail and private taste profile RPCs unavailable to them.

create or replace function app.section_is_live(
  p_section public.cms_sections,
  p_at timestamptz,
  p_timezone text
)
returns boolean
language sql
stable
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
    )
    and (p_section.kind <> 'TASTE_MATCH' or not app.is_staff());
$$;

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
  if app.is_staff() or not exists (
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

create or replace function app.reject_staff_taste_profile_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if app.is_staff() then
    perform app.fail('PERMISSION_DENIED', 'Taste preferences are available to customer accounts.');
  end if;
  return new;
end;
$$;

revoke all on function app.reject_staff_taste_profile_write() from public, anon, authenticated;
drop trigger if exists customer_taste_profiles_customer_only on public.customer_taste_profiles;
create trigger customer_taste_profiles_customer_only
  before insert or update on public.customer_taste_profiles
  for each row execute function app.reject_staff_taste_profile_write();
