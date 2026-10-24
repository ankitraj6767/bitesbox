-- SEED 24 · Portion/size options and relevant add-on groups for the menu expansion.
-- Keep portions consistent with the original catalog: half/full curries, regular/large
-- Chinese sides, and size choices for drinks. Single-serving dishes remain single size.

with variant_products as (
  select p.id, p.slug, p.base_price, p.calories, p.serves_count, p.preparation_minutes,
         'BIRYANI'::text as kind, 1.75::numeric as price_factor, 5 as prep_extra
  from public.products p
  where p.id::text like '77777777-%'
    and p.category_id = '33333333-0000-0000-0000-000000000001'
    and p.food_type <> 'EGG'

  union all

  select p.id, p.slug, p.base_price, p.calories, p.serves_count, p.preparation_minutes,
         'CURRY'::text, 1.85::numeric, 5
  from public.products p
  where p.id::text like '77777777-%'
    and p.category_id in (
      '33333333-0000-0000-0000-000000000002',
      '33333333-0000-0000-0000-000000000003'
    )

  union all

  select p.id, p.slug, p.base_price, p.calories, p.serves_count, p.preparation_minutes,
         'CHINESE'::text, 1.50::numeric, 3
  from public.products p
  where p.id::text like '77777777-%'
    and p.slug in (
      'chicken-chow-mein', 'veg-garlic-noodles', 'schezwan-veg-noodles',
      'singapore-veg-noodles', 'egg-fried-rice', 'chicken-fried-rice',
      'schezwan-veg-fried-rice', 'schezwan-chicken-fried-rice'
    )

  union all

  select p.id, p.slug, p.base_price, p.calories, p.serves_count, p.preparation_minutes,
         'CURRY'::text, 1.85::numeric, 5
  from public.products p
  where p.id::text like '77777777-%'
    and p.slug in (
      'palak-paneer', 'kadai-paneer', 'shahi-paneer', 'matar-paneer',
      'mushroom-masala', 'chole-masala', 'rajma-masala', 'dal-makhani'
    )

  union all

  select p.id, p.slug, p.base_price, p.calories, p.serves_count, p.preparation_minutes,
         'BEVERAGE'::text, 1.50::numeric, 0
  from public.products p
  where p.id::text like '77777777-%'
    and p.category_id = '33333333-0000-0000-0000-000000000009'
), option_rows as (
  select vp.*,
         option.position,
         case vp.kind
           when 'BIRYANI' then case option.position when 1 then 'Half (Serves 1)' else 'Full (Serves 2)' end
           when 'CURRY' then case option.position when 1 then 'Half (Serves 2)' else 'Full (Serves 4)' end
           when 'CHINESE' then case option.position when 1 then 'Regular' else 'Large' end
           else case option.position when 1 then 'Regular (300 ml)' else 'Large (500 ml)' end
         end as option_name,
         case vp.kind
           when 'BIRYANI' then case option.position when 1 then 'आधा (1 व्यक्ति के लिए)' else 'पूरा (2 लोगों के लिए)' end
           when 'CURRY' then case option.position when 1 then 'आधा (2 लोगों के लिए)' else 'पूरा (4 लोगों के लिए)' end
           when 'CHINESE' then case option.position when 1 then 'रेगुलर' else 'लार्ज' end
           else case option.position when 1 then 'रेगुलर (300 मिली)' else 'लार्ज (500 मिली)' end
         end as option_name_hi,
         case when vp.kind = 'BEVERAGE' then 'Size' when vp.kind = 'CHINESE' then 'Portion' else 'Portion' end as option_group,
         case when vp.kind = 'BEVERAGE' then 'आकार' else 'मात्रा' end as option_group_hi,
         case when option.position = 1 then 1.0::numeric else vp.price_factor end as size_factor,
         option.position = 1 as is_default
  from variant_products vp
  cross join (values (1), (2)) as option(position)
)
insert into public.product_variants (
  product_id, name, name_hi, option_group, option_group_hi, sku,
  price, compare_price, packaging_charge, calories, serves_count,
  preparation_minutes, is_default, is_active, display_order
)
select
  r.id,
  r.option_name,
  r.option_name_hi,
  r.option_group,
  r.option_group_hi,
  'EXP-' || upper(replace(r.slug, '-', '')) || case r.position when 1 then '-S' else '-L' end,
  case when r.position = 1 then r.base_price
       else round(r.base_price * r.size_factor / 10) * 10 end,
  null,
  0,
  case when r.calories is null then null
       when r.position = 1 then r.calories
       else round(r.calories * r.size_factor)::integer end,
  case when r.kind = 'BEVERAGE' then coalesce(r.serves_count, 1)
       when r.position = 1 then r.serves_count
       else coalesce(r.serves_count, 1) * 2 end,
  r.preparation_minutes + case when r.position = 1 then 0 else r.prep_extra end,
  r.is_default,
  true,
  r.position
from option_rows r
on conflict (sku) where sku is not null and deleted_at is null do nothing;

-- Share the established customization patterns from the first 38 products.
with assignments as (
  select p.id, 'spice-level'::text as group_slug, 1 as display_order
  from public.products p
  where p.id::text like '77777777-%'
    and p.category_id in (
      '33333333-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000002',
      '33333333-0000-0000-0000-000000000003', '33333333-0000-0000-0000-000000000004',
      '33333333-0000-0000-0000-000000000005', '33333333-0000-0000-0000-000000000006',
      '33333333-0000-0000-0000-000000000007'
    )
  union all
  select p.id, 'spice-level', 1
  from public.products p
  where p.slug in (
    'aloo-paratha-curd', 'chole-bhature', 'masala-omelette-paratha',
    'anda-bhurji-pav', 'poha-masala'
  )
  union all
  select p.id, 'remove-ingredients', 8
  from public.products p
  where p.id::text like '77777777-%'
    and p.category_id in (
      '33333333-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000002',
      '33333333-0000-0000-0000-000000000003', '33333333-0000-0000-0000-000000000004',
      '33333333-0000-0000-0000-000000000005', '33333333-0000-0000-0000-000000000006',
      '33333333-0000-0000-0000-000000000007'
    )
  union all
  select p.id, 'remove-ingredients', 8
  from public.products p
  where p.slug in (
    'aloo-paratha-curd', 'chole-bhature', 'masala-omelette-paratha',
    'anda-bhurji-pav', 'poha-masala'
  )
  union all
  select p.id, 'biryani-extras', 2
  from public.products p
  where p.id::text like '77777777-%'
    and p.category_id = '33333333-0000-0000-0000-000000000001'
  union all
  select p.id, 'roll-fillings', 2
  from public.products p
  where p.id::text like '77777777-%'
    and p.category_id = '33333333-0000-0000-0000-000000000004'
  union all
  select p.id, 'add-ons', 5
  from public.products p
  where p.id::text like '77777777-%'
    and (
      p.category_id in (
        '33333333-0000-0000-0000-000000000002',
        '33333333-0000-0000-0000-000000000003'
      )
      or (p.category_id = '33333333-0000-0000-0000-000000000001' and p.food_type <> 'EGG')
      or p.slug in (
        'palak-paneer', 'kadai-paneer', 'shahi-paneer', 'matar-paneer',
        'mushroom-masala', 'chole-masala', 'rajma-masala', 'dal-makhani',
        'butter-chicken-naan-meal', 'paneer-makhani-meal', 'kebab-platter-for-two',
        'mutton-feast-box', 'biryani-kebab-duo', 'bihari-veg-thali-deluxe'
      )
    )
  union all
  select p.id, 'toppings', 6
  from public.products p
  where p.id::text like '77777777-%'
    and p.category_id = '33333333-0000-0000-0000-000000000001'
    and p.food_type <> 'EGG'
  union all
  select p.id, 'bread-choice', 2
  from public.products p
  where p.slug = 'mutton-feast-box'
)
insert into public.product_modifier_groups (
  product_id, modifier_group_id, is_required, min_select, max_select, display_order
)
select
  a.id,
  mg.id,
  case when a.group_slug = 'bread-choice' then true else null end,
  case when a.group_slug = 'bread-choice' then 1 else null end,
  case when a.group_slug = 'bread-choice' then 1 else null end,
  a.display_order
from assignments a
join public.modifier_groups mg on mg.slug = a.group_slug and mg.deleted_at is null
on conflict (product_id, modifier_group_id) do nothing;
