-- Taste Passport ownership, rollout, hard constraints, ranking and outlet scope.
begin;
select tap.suite('Taste Passport and Taste Match');

select tap.reset();
insert into public.categories (id, name, slug, display_order, is_active)
values
  ('14000000-0000-4000-8000-000000000001', 'Taste test category', 'taste-test-category', 900, true),
  ('14000000-0000-4000-8000-000000000002', 'Other taste category', 'other-taste-category', 901, true),
  ('14000000-0000-4000-8000-000000000003', 'Archived taste category', 'archived-taste-category', 902, true);

insert into public.products (
  id, category_id, name, slug, food_type, spice_level, base_price, is_active, is_best_seller, display_order
) values
  ('14000000-0000-4000-8000-000000000101', '14000000-0000-4000-8000-000000000001', 'Taste Match Veg Mild', 'taste-match-veg-mild', 'VEG', 'MILD', 120, true, true, 901),
  ('14000000-0000-4000-8000-000000000102', '14000000-0000-4000-8000-000000000001', 'Taste Match Non Veg', 'taste-match-non-veg', 'NON_VEG', 'MILD', 100, true, false, 902),
  ('14000000-0000-4000-8000-000000000103', '14000000-0000-4000-8000-000000000001', 'Taste Match Hot', 'taste-match-hot', 'VEG', 'HOT', 100, true, false, 903),
  ('14000000-0000-4000-8000-000000000104', '14000000-0000-4000-8000-000000000001', 'Taste Match High Price', 'taste-match-high-price', 'VEG', 'MILD', 300, true, false, 904),
  ('14000000-0000-4000-8000-000000000105', '14000000-0000-4000-8000-000000000002', 'Taste Match Saved Favorite', 'taste-match-saved-favorite', 'VEG', 'MILD', 140, true, false, 905),
  ('14000000-0000-4000-8000-000000000106', '14000000-0000-4000-8000-000000000002', 'Taste Match Current Variant Price', 'taste-match-current-variant-price', 'VEG', 'MILD', 400, true, false, 906);

insert into public.product_variants (id, product_id, name, option_group, price, is_default)
values (
  '14000000-0000-4000-8000-000000000301',
  '14000000-0000-4000-8000-000000000106',
  'Single', 'Portion', 175, true
);

insert into public.branches (
  id, code, name, slug, address_line1, city, state, postal_code,
  latitude, longitude, phone, service_mode, status, accepting_orders,
  is_default, is_active, display_order
) values (
  '14000000-0000-4000-8000-000000000201', 'TASTE-02', 'Taste test outlet', 'taste-test-outlet',
  'Test Road', 'Patna', 'Bihar', '800001', 25.6100, 85.1400, '+919999999996',
  'BOTH', 'OPEN', true, false, true, 900
);
insert into public.product_availability (product_id, branch_id, state)
select p.id, '14000000-0000-4000-8000-000000000201', 'AVAILABLE'
from public.products p
where p.id in (
  '14000000-0000-4000-8000-000000000101', '14000000-0000-4000-8000-000000000102',
  '14000000-0000-4000-8000-000000000103', '14000000-0000-4000-8000-000000000104',
  '14000000-0000-4000-8000-000000000105', '14000000-0000-4000-8000-000000000106'
)
on conflict (product_id, branch_id) do update set state = excluded.state;

select tap.as_user(tap.seed('customer_a'));
select tap.eq(
  public.my_taste_profile() ->> 'has_profile', 'false',
  'a customer without saved choices receives an empty private profile'
);
select tap.throws(
  $sql$select public.save_my_taste_profile(array['ALLERGY_SAFE'], null, '{}', null)$sql$,
  'INVALID_TASTE_PREFERENCES',
  'unsupported food attributes are rejected'
);
select tap.throws(
  $sql$select public.save_my_taste_profile(array[null]::text[], null, '{}', null)$sql$,
  'INVALID_TASTE_PREFERENCES',
  'null food types are rejected'
);
select tap.throws(
  $sql$select public.save_my_taste_profile('{}', 'EXTREME', '{}', null)$sql$,
  'INVALID_TASTE_PREFERENCES',
  'unsupported spice values are rejected'
);
select tap.throws(
  $sql$select public.save_my_taste_profile('{}', null, '{}', 0)$sql$,
  'INVALID_TASTE_PREFERENCES',
  'a non-positive price ceiling is rejected'
);
select public.save_my_taste_profile(
  array['VEG'], 'MILD', array['14000000-0000-4000-8000-000000000001'::uuid], 200
);
select tap.eq(
  public.my_taste_profile() ->> 'has_profile', 'true',
  'a customer can save supported food, spice, category and price preferences'
);
select tap.eq(
  public.my_taste_profile() -> 'category_ids' ->> 0,
  '14000000-0000-4000-8000-000000000001',
  'the read RPC returns only the caller''s selected categories'
);
select tap.throws(
  $sql$select public.save_my_taste_profile('{}', null, array['14000000-0000-4000-8000-000000000099'::uuid], null)$sql$,
  'INVALID_TASTE_PREFERENCES',
  'inactive or unknown categories are rejected'
);
select tap.reset();

select tap.as_user(tap.seed('customer_b'));
select tap.eq(
  tap.visible_count('select 1 from public.customer_taste_profiles'), 0::bigint,
  'another customer cannot read the owner''s taste profile row'
);
select tap.eq(
  public.my_taste_profile() ->> 'has_profile', 'false',
  'the read RPC never accepts a customer id from the caller'
);
select tap.throws(
  format('insert into public.customer_taste_profiles (user_id) values (%L)', tap.seed('customer_a')),
  'PERMISSION_DENIED',
  'customers cannot write another customer''s profile directly'
);
select tap.throws(
  format('select app.taste_match_state(%L)', tap.seed('customer_a')),
  'PERMISSION_DENIED',
  'customers cannot probe another user''s taste history through internal helpers'
);
select tap.reset();

select tap.as_anon();
select tap.throws(
  'select public.my_taste_profile()',
  'PERMISSION_DENIED',
  'guests cannot execute the private taste profile RPC'
);
select tap.ok(
  not public.feature_enabled('taste_match')
  and not exists (
    select 1 from jsonb_array_elements(public.home_feed(tap.seed('branch')) -> 'sections') section
    where section ->> 'kind' = 'TASTE_MATCH'
  ),
  'the disabled rollout flag keeps Taste Match out of the guest home feed'
);
select tap.reset();

select tap.as_user(tap.seed('customer_a'));
select tap.ok(
  not exists (
    select 1 from jsonb_array_elements(public.home_feed(tap.seed('branch')) -> 'sections') section
    where section ->> 'kind' = 'TASTE_MATCH'
  ),
  'the disabled rollout flag also hides Taste Match from signed-in customers'
);
select tap.reset();

select tap.as_user(tap.seed('owner'));
select tap.no_throw(
  'update public.feature_flags set is_enabled = true, rollout_percentage = 100 where key = ''taste_match''',
  'the existing settings permission flow can enable Taste Match'
);
select tap.no_throw(
  'update public.cms_sections set item_limit = 50 where kind = ''TASTE_MATCH''',
  'the CMS controls the personalized rail limit'
);
select tap.reset();

select tap.as_user(tap.seed('owner'));
select tap.ok(
  not exists (
    select 1 from jsonb_array_elements(public.home_feed(tap.seed('branch')) -> 'sections') section
    where section ->> 'kind' = 'TASTE_MATCH'
  ),
  'staff accounts never receive the customer Taste Match rail'
);
select tap.throws(
  'select public.my_taste_profile()',
  'PERMISSION_DENIED',
  'staff accounts cannot read customer taste preferences'
);
select tap.throws(
  'select public.save_my_taste_profile(array[''VEG''], null, ''{}'', null)',
  'PERMISSION_DENIED',
  'staff accounts cannot save customer taste preferences'
);
select tap.reset();

insert into public.customer_taste_profiles (user_id)
values (tap.seed('customer_b'));
insert into public.customer_taste_categories (user_id, category_id)
values (tap.seed('customer_b'), '14000000-0000-4000-8000-000000000003');
update public.categories set is_active = false
where id = '14000000-0000-4000-8000-000000000003';
select tap.as_user(tap.seed('customer_b'));
select tap.eq(
  public.my_taste_profile() -> 'category_ids', '[]'::jsonb,
  'archived categories are removed from the editable taste profile'
);
select tap.reset();

select tap.as_user(tap.seed('customer_a'));
select public.set_my_favorite('14000000-0000-4000-8000-000000000105', true);
select tap.remember('taste_section', (
  select section::text
  from jsonb_array_elements(public.home_feed(tap.seed('branch')) -> 'sections') section
  where section ->> 'kind' = 'TASTE_MATCH'
));
select tap.ok(tap.recall('taste_section') is not null, 'signed-in customers receive the CMS-driven Taste Match section');
select tap.eq(
  (select count(*)::int from jsonb_array_elements(tap.recall('taste_section')::jsonb -> 'products') product
   where product ->> 'food_type' <> 'VEG'
      or array_position(enum_range(null::public.spice_level), (product ->> 'spice_level')::public.spice_level)
         > array_position(enum_range(null::public.spice_level), 'MILD'::public.spice_level)
      or coalesce((product ->> 'min_price')::numeric, (product ->> 'base_price')::numeric) > 200),
  0,
  'food type, maximum spice and current item price remain hard constraints'
);
select tap.ok(
  not exists (
    select 1 from jsonb_array_elements(tap.recall('taste_section')::jsonb -> 'products') product
    where product ->> 'id' in (
      '14000000-0000-4000-8000-000000000102',
      '14000000-0000-4000-8000-000000000103',
      '14000000-0000-4000-8000-000000000104'
    )
  ),
  'products that fail any selected hard constraint are excluded'
);
select tap.ok(
  exists (
    select 1 from jsonb_array_elements(tap.recall('taste_section')::jsonb -> 'products') product
    where product ->> 'id' = '14000000-0000-4000-8000-000000000106'
      and (product ->> 'base_price')::numeric = 400
      and (product ->> 'min_price')::numeric = 175
  ),
  'price ceilings use the current lowest orderable variant price instead of the base price'
);
select tap.eq(
  (tap.recall('taste_section')::jsonb -> 'products' -> 0 ->> 'id'),
  '14000000-0000-4000-8000-000000000101',
  'category preference outranks the otherwise strong favorite signal deterministically'
);
select tap.eq(
  (select product ->> 'reason_code'
   from jsonb_array_elements(tap.recall('taste_section')::jsonb -> 'products') product
   where product ->> 'id' = '14000000-0000-4000-8000-000000000101'),
  'FAVORITE_CATEGORY',
  'reason codes explain the strongest customer-selected match'
);
select tap.eq(
  (select product ->> 'reason_code'
   from jsonb_array_elements(tap.recall('taste_section')::jsonb -> 'products') product
   where product ->> 'id' = '14000000-0000-4000-8000-000000000105'),
  'SAVED_FAVORITE',
  'favorite history is a ranking signal and has an honest reason code'
);
select tap.ok(
  not exists (
    select 1 from (
      select product ->> 'category_id' as category_id, count(*) as count
      from jsonb_array_elements(tap.recall('taste_section')::jsonb -> 'products') product
      group by product ->> 'category_id'
    ) grouped where grouped.count > 3
  ),
  'the ranked rail caps repeated products from any one category'
);
select tap.reset();

select tap.as_user(tap.seed('customer_a'));
select public.save_my_taste_profile('{}', null, '{}', null);
select tap.remember('history_section', (
  select section::text
  from jsonb_array_elements(public.home_feed(tap.seed('branch')) -> 'sections') section
  where section ->> 'kind' = 'TASTE_MATCH'
));
select tap.ok(
  exists (
    select 1 from jsonb_array_elements(tap.recall('history_section')::jsonb -> 'products') product
    where product ->> 'reason_code' = 'POSITIVE_REVIEW'
  ),
  'a published positive food review is used as a Taste Match signal'
);
select tap.ok(
  exists (
    select 1 from jsonb_array_elements(tap.recall('history_section')::jsonb -> 'products') product
    where product ->> 'reason_code' = 'ORDERED_BEFORE'
  ),
  'fulfilled order history ranks a repeat item with a stable explanation'
);
select tap.reset();

select tap.as_user(tap.seed('customer_e'));
select tap.remember('empty_profile_section', (
  select section::text
  from jsonb_array_elements(public.home_feed(tap.seed('branch')) -> 'sections') section
  where section ->> 'kind' = 'TASTE_MATCH'
));
select tap.eq(
  tap.recall('empty_profile_section')::jsonb ->> 'taste_state', 'SETUP',
  'customers without taste history or saved preferences see the setup prompt state'
);
select tap.ok(
  jsonb_array_length(tap.recall('empty_profile_section')::jsonb -> 'products') > 0
  and exists (
    select 1 from jsonb_array_elements(tap.recall('empty_profile_section')::jsonb -> 'products') product
    where product ->> 'reason_code' in (
      'POPULAR_AT_OUTLET', 'POPULAR_MENU_PICK', 'CURATED_MENU_PICK', 'CUSTOMER_RATED_MENU_PICK'
    )
  ),
  'an empty profile falls back to available popular or curated menu products with an honest reason'
);
select tap.reset();

insert into public.product_availability (product_id, branch_id, state)
values ('14000000-0000-4000-8000-000000000105', '14000000-0000-4000-8000-000000000201', 'OUT_OF_STOCK')
on conflict (product_id, branch_id) do update set state = excluded.state;
select tap.as_user(tap.seed('customer_a'));
select public.save_my_taste_profile('{}', null, '{}', null);
select tap.remember('outlet_section', (
  select section::text
  from jsonb_array_elements(public.home_feed('14000000-0000-4000-8000-000000000201') -> 'sections') section
  where section ->> 'kind' = 'TASTE_MATCH'
));
select tap.ok(
  not exists (
    select 1 from jsonb_array_elements(tap.recall('outlet_section')::jsonb -> 'products') product
    where product ->> 'id' = '14000000-0000-4000-8000-000000000105'
  ),
  'out-of-stock products at the selected outlet do not enter recommendations'
);
select tap.ok(
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'customer_favorites'
  ),
  'favorite updates are available as an owner-scoped refresh signal'
);
select tap.reset();

rollback;
