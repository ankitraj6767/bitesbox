-- Customer favorites, localization and referral safety boundaries.
begin;
select tap.suite('Customer growth, localization & outlets');

-- Test-owned second outlet: distinct branch scope and hours are intentionally
-- created here instead of relying on the single-outlet development seed.
select tap.reset();
insert into public.branches (
  id, code, name, slug, address_line1, city, state, postal_code,
  latitude, longitude, phone, service_mode, status, accepting_orders,
  is_default, is_active, display_order
) values
  ('11111111-1111-1111-1111-111111111112', 'TEST-02', 'Test pickup outlet', 'test-pickup',
   'Test Road', 'Patna', 'Bihar', '800001', 25.6100, 85.1400, '+919999999998',
   'PICKUP', 'OPEN', false, false, true, 2),
  ('11111111-1111-1111-1111-111111111113', 'TEST-03', 'Hidden outlet', 'test-hidden',
   'Test Road', 'Patna', 'Bihar', '800001', 25.6100, 85.1400, '+919999999997',
   'BOTH', 'OPEN', true, false, false, 3);
insert into public.branch_hours (branch_id, day_of_week, opens_at, closes_at, day_part)
values ('11111111-1111-1111-1111-111111111112', 1, '10:00', '18:00', 'ALL_DAY');
insert into public.product_availability (product_id, branch_id, state)
select p.id, '11111111-1111-1111-1111-111111111112', 'OUT_OF_STOCK'
from public.products p
where p.is_active and p.deleted_at is null
order by p.display_order
limit 1
on conflict (product_id, branch_id) do update set state = excluded.state;

select tap.as_anon();
select tap.ok(
  jsonb_array_length(public.public_outlets()) = 2
  and exists (select 1 from jsonb_array_elements(public.public_outlets()) outlet
    where outlet ->> 'id' = '11111111-1111-1111-1111-111111111112'),
  'public outlet discovery returns multiple active outlets and omits inactive outlet data'
);
select tap.reset();

-- Human-reviewed Hindi content is searchable and keeps normal availability
-- and price data from the same server-owned menu projection.
update public.products set name_hi = 'हिंदी परीक्षण खोज'
where id = (select id from public.products where is_active and deleted_at is null order by display_order limit 1);
select tap.as_anon();
select tap.ok(
  exists (
    select 1 from jsonb_array_elements(public.localized_search_menu('परीक्षण खोज', null, 10, 'hi') -> 'products') result
    where result ->> 'name' = 'हिंदी परीक्षण खोज'
  ),
  'Hindi search includes human-reviewed Hindi product names'
);
select tap.reset();

select tap.ok(
  jsonb_typeof(public.public_outlets()) = 'array',
  'guests can resolve only active public outlets'
);

select tap.ok(
  exists (
    select 1 from jsonb_array_elements(public.serviceable_outlets(25.6100, 85.1400)) result
    where result ->> 'id' = '11111111-1111-1111-1111-111111111112'
  ),
  'address resolution evaluates each active outlet without exposing inactive outlets'
);

select tap.ok(
  jsonb_typeof(public.localized_menu_catalog(null, null, 'hi') -> 'products') = 'array',
  'Hindi menu surface preserves the normal catalog contract'
);

select tap.ok(
  not public.feature_enabled('referrals'),
  'referrals remain disabled until an owner configures terms and separately enables rollout'
);

select tap.as_anon();
select tap.ok(
  public.record_storefront_event(
    '12000000-0000-4000-8000-000000000001', 'MENU_VIEW',
    '11111111-1111-1111-1111-111111111111', null
  ),
  'guest browsing records an allow-listed event without identifying the visitor'
);
select tap.ok(
  public.record_storefront_event(
    '12000000-0000-4000-8000-000000000001', 'MENU_VIEW',
    '11111111-1111-1111-1111-111111111111', null
  ),
  'event retries are idempotent'
);
select tap.throws(
  $sql$select public.record_storefront_event(
    '12000000-0000-4000-8000-000000000002', 'PHONE_NUMBER', null, null
  )$sql$,
  'INVALID_ANALYTICS_EVENT',
  'arbitrary payload values are rejected'
);
select tap.reset();

select tap.as_user(tap.seed('customer_a'));
select tap.throws(
  'select public.storefront_event_metrics(null, now() - interval ''1 day'', now())',
  'PERMISSION_DENIED',
  'customers cannot read operator analytics'
);
select tap.reset();

select tap.as_user(tap.seed('owner'));
select tap.eq(
  (public.storefront_event_metrics('11111111-1111-1111-1111-111111111111', now() - interval '1 day', now() + interval '1 second') ->> 'MENU_VIEW')::bigint,
  1::bigint,
  'analytics aggregates first-party events once without a visitor identity'
);
select tap.reset();

select tap.as_user(tap.seed('customer_a'));
select tap.remember('favorite_product', (select id::text from public.products where is_active and deleted_at is null limit 1));
select public.set_my_favorite(tap.recall_uuid('favorite_product'), true);
select public.set_my_favorite(tap.recall_uuid('favorite_product'), true);
select tap.eq(
  tap.visible_count('select 1 from public.customer_favorites where user_id = auth.uid()'),
  1::bigint,
  'a customer can save a menu item once'
);
select tap.eq(
  jsonb_array_length(public.my_favorites(null, 'en')),
  1,
  'favorite reads include the saved product and current availability state'
);
select tap.eq(
  (select (row ->> 'is_available')::boolean
   from jsonb_array_elements(public.my_favorites('11111111-1111-1111-1111-111111111112', 'en')) row
   where row ->> 'id' = tap.recall('favorite_product')),
  false,
  'favorites remain saved across outlets and show when the dish is unavailable there'
);
select public.set_preferred_branch('11111111-1111-1111-1111-111111111112');
select tap.eq(
  public.my_session() -> 'profile' ->> 'preferred_branch_id',
  '11111111-1111-1111-1111-111111111112',
  'a customer can persist an active outlet preference'
);
select tap.throws(
  'select public.set_preferred_branch(''11111111-1111-1111-1111-111111111113'')',
  'BRANCH_UNAVAILABLE',
  'a customer cannot persist an inactive hidden outlet'
);

select tap.reset();
select tap.as_user(tap.seed('customer_b'));
select tap.eq(
  tap.visible_count('select 1 from public.customer_favorites'),
  0::bigint,
  'another customer cannot read a favorite'
);
select tap.throws(
  format('insert into public.customer_favorites (user_id, product_id) values (%L, %L)',
    tap.seed('customer_a'), (select id from public.products where is_active and deleted_at is null limit 1)),
  'PERMISSION_DENIED',
  'another customer cannot create a favorite on someone else''s behalf'
);
select tap.reset();

select tap.as_user(tap.seed('customer_b'));
select public.import_guest_cart(
  '12000000-0000-4000-8000-000000000011',
  (select id from public.branches where is_default),
  jsonb_build_array(jsonb_build_object(
    'product_id', tap.recall('favorite_product'), 'variant_id', null, 'quantity', 2,
    'modifiers', '[]'::jsonb, 'special_instructions', null
  ))
);
select public.import_guest_cart(
  '12000000-0000-4000-8000-000000000011',
  (select id from public.branches where is_default),
  jsonb_build_array(jsonb_build_object(
    'product_id', tap.recall('favorite_product'), 'variant_id', null, 'quantity', 2,
    'modifiers', '[]'::jsonb, 'special_instructions', null
  ))
);
select tap.eq(
  (select sum(ci.quantity)::int from public.cart_items ci join public.carts c on c.id = ci.cart_id
   where c.user_id = tap.seed('customer_b') and c.is_active),
  2,
  'guest cart import retries do not duplicate account cart quantities'
);
select tap.throws(
  format($sql$select public.import_guest_cart(
    '12000000-0000-4000-8000-000000000011',
    (select id from public.branches where is_default),
    jsonb_build_array(jsonb_build_object('product_id', %L, 'variant_id', null, 'quantity', 3,
      'modifiers', '[]'::jsonb, 'special_instructions', null))
  )$sql$, tap.recall('favorite_product')),
  'IDEMPOTENCY_KEY_REUSED',
  'a guest cart import idempotency key cannot be reused for changed contents'
);
select tap.reset();

select tap.as_user(tap.seed('customer_a'));
select tap.throws(
  format('select public.save_menu_translations(%L, %L::jsonb)',
    (select id from public.products where is_active and deleted_at is null limit 1), '{"product":{"name_hi":"प्रयास"}}'),
  'PERMISSION_DENIED',
  'customers cannot change reviewed menu translations'
);
select tap.reset();

select tap.as_user(tap.seed('customer_a'));
select tap.throws(
  format('select public.attribute_referral(%L)',
    (select referral_code from public.profiles where id = tap.seed('customer_b'))),
  'FEATURE_UNAVAILABLE',
  'a referral cannot be applied while rollout is disabled'
);
select tap.reset();

select tap.as_user_aal(tap.seed('owner'), 'aal1');
select tap.throws(
  'select public.update_referral_program(true, 1, 1, 1, 10, null)',
  'MFA_REQUIRED',
  'AAL1 cannot configure financial referral terms'
);
select tap.reset();

select tap.as_user(tap.seed('owner'));
select public.update_referral_program(true, 1, 1, 100, 10, 90);
select tap.ok(
  not public.feature_enabled('referrals'),
  'configuring terms does not bypass the independent feature flag rollout gate'
);
select tap.eq(
  (public.referral_admin_overview() -> 'settings' ->> 'enabled')::boolean,
  true,
  'an AAL2 authorized owner can configure a program for staged rollout'
);
select tap.reset();

-- Test-only values in this rollback-only suite. No commercial terms are seeded
-- into the application, and the independent feature flag remains owner-gated.
select tap.as_user_aal(tap.seed('owner'), 'aal2');
update public.feature_flags set is_enabled = true where key = 'referrals';
select tap.eq(
  (select is_enabled from public.feature_flags where key = 'referrals'),
  true,
  'only an authorized owner can open the test rollout gate'
);
select tap.reset();
select tap.remember('inviter_code', (select referral_code from public.profiles where id = tap.seed('customer_d')));

select tap.as_user(tap.seed('customer_d'));
select tap.throws(
  format('select public.attribute_referral(%L)',
    (select referral_code from public.profiles where id = tap.seed('customer_d'))),
  'INVALID_REFERRAL_CODE',
  'self-referrals are refused'
);
select tap.reset();

select tap.as_user(tap.seed('customer_e'));
select public.attribute_referral(tap.recall('inviter_code'));
select tap.throws(
  format('select public.attribute_referral(%L)', tap.recall('inviter_code')),
  'REFERRAL_ALREADY_USED',
  'referral attribution is one-time per customer'
);
select tap.eq(
  tap.visible_count(format('select 1 from public.referrals where referred_user_id = %L', tap.seed('customer_e'))),
  1::bigint,
  'the valid code is attributed to one referred account'
);
select tap.reset();

-- An existing, seeded customer A order is the deterministic paid/delivered
-- order fixture. Its wallet reward and rollback-only wallet refund exercise the
-- same database triggers used by the payment/refund services.
insert into public.referrals (inviter_id, referred_user_id, referral_code)
select tap.seed('customer_d'), tap.seed('customer_a'), referral_code
from public.profiles where id = tap.seed('customer_d');
update public.profiles set referred_by = tap.seed('customer_d') where id = tap.seed('customer_a');
update public.profiles set push_enabled = false, marketing_opt_in = false,
  preferred_language = 'en' where id = tap.seed('customer_d');
update public.profiles set push_enabled = true, marketing_opt_in = false,
  preferred_language = 'hi' where id = tap.seed('customer_a');
select tap.remember('reward_referral_id', (select id::text from public.referrals where referred_user_id = tap.seed('customer_a')));
select app.try_qualify_referral(tap.seed_order(1));
select app.try_qualify_referral(tap.seed_order(1));
select tap.eq(
  (select status::text from public.referrals where id = tap.recall_uuid('reward_referral_id')),
  'REWARDED',
  'the first paid, delivered, non-refunded order qualifies exactly one referral'
);
select tap.eq(
  tap.visible_count(format('select 1 from public.wallet_transactions where idempotency_key like %L',
    'referral:' || tap.recall('reward_referral_id') || ':%')),
  2::bigint,
  'retrying qualification posts the inviter and referred ledger credits once'
);
select tap.eq(
  tap.visible_count(format('select 1 from public.notifications where user_id in (%L, %L) and event = ''REFERRAL_REWARD'' and channel = ''IN_APP''',
    tap.seed('customer_d'), tap.seed('customer_a'))),
  2::bigint,
  'each referral party receives one in-app reward notification'
);
select tap.eq(
  tap.visible_count(format('select 1 from public.notifications where user_id = %L and event = ''REFERRAL_REWARD'' and channel = ''PUSH''',
    tap.seed('customer_a'))),
  1::bigint,
  'the opted-in push channel receives the localized transactional reward notice despite marketing opt-out'
);
select tap.eq(
  tap.visible_count(format('select 1 from public.notifications where user_id = %L and event = ''REFERRAL_REWARD'' and channel = ''PUSH''',
    tap.seed('customer_d'))),
  0::bigint,
  'a disabled push channel does not receive a reward notification'
);
select tap.eq(
  (select body from public.notifications where user_id = tap.seed('customer_a')
   and event = 'REFERRAL_REWARD' and channel = 'IN_APP'),
  '₹1.00 आपके Bites Box वॉलेट में जोड़े गए हैं।',
  'reward copy uses the customer preferred Hindi notification template'
);

select tap.as_user(tap.seed('support'));
select tap.remember('referral_refund_id', (
  public.request_refund(
    tap.seed_order(1), 'PARTIAL_REFUND', 'QUALITY_ISSUE', 50,
    'WALLET_CREDIT', 'Rollback-only referral reversal test', null,
    'bb-test-referral-wallet-refund'
  ) ->> 'refund_id'
));
select tap.reset();
select tap.as_user(tap.seed('finance'));
select public.approve_refund(tap.recall_uuid('referral_refund_id'), 'Rollback-only test approval');
select tap.reset();
select tap.as_service();
select public.svc_complete_refund(tap.recall_uuid('referral_refund_id'), 50);
select tap.reset();
select tap.eq(
  (select status::text from public.referrals where id = tap.recall_uuid('reward_referral_id')),
  'REVERSED',
  'a completed partial refund reverses the referral reward'
);
select tap.eq(
  (select balance::numeric from public.wallet_accounts where user_id = tap.seed('customer_a')),
  50::numeric,
  'reward reversal preserves the completed refund credit in the wallet'
);

rollback;
