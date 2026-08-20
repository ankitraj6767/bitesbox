-- SEED 30 · CMS, COUPONS & PROMOTIONS

-- ═══════════════════════════════════════════════════════════════════════════
-- CMS — HOMEPAGE COMPOSITION
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.cms_sections (
  id, kind, section_key, title, subtitle, action_label, action_route,
  category_id, collection_id, product_ids, rule, layout, item_limit,
  display_order, is_active, requires_auth, valid_from_time, valid_to_time
) values
  ('77777777-0000-0000-0000-000000000001', 'HERO_CAROUSEL', 'hero',
   null, null, null, null, null, null, '{}', '{}'::jsonb, 'BANNER', 5, 1, true, false, null, null),

  ('77777777-0000-0000-0000-000000000002', 'CATEGORY_CAROUSEL', 'categories',
   'What are you craving?', 'Browse by category', 'See all', 'bitesbox://menu',
   null, null, '{}', '{}'::jsonb, 'CAROUSEL', 12, 2, true, false, null, null),

  ('77777777-0000-0000-0000-000000000003', 'PRODUCT_CAROUSEL', 'breakfast-now',
   'Good morning, Bakhtiyarpur', 'Litti chokha and morning classics', 'See all', 'bitesbox://menu/breakfast',
   '33333333-0000-0000-0000-00000000000c', null, '{}', '{}'::jsonb, 'CAROUSEL', 8, 3, true, false,
   '08:00', '11:30'),

  ('77777777-0000-0000-0000-000000000004', 'BEST_SELLERS', 'best-sellers',
   'Bakhtiyarpur''s favourites', 'What everyone is ordering', 'See all', 'bitesbox://collections/best-sellers',
   null, null, '{}', '{}'::jsonb, 'CAROUSEL', 10, 4, true, false, null, null),

  ('77777777-0000-0000-0000-000000000005', 'TODAYS_OFFERS', 'offers',
   'Offers for you', 'Save more on today''s order', 'All offers', 'bitesbox://offers',
   null, null, '{}', '{}'::jsonb, 'CAROUSEL', 6, 5, true, false, null, null),

  ('77777777-0000-0000-0000-000000000006', 'BUY_AGAIN', 'buy-again',
   'Order it again', 'Your recent favourites', null, null,
   null, null, '{}', '{}'::jsonb, 'CAROUSEL', 8, 6, true, true, null, null),

  ('77777777-0000-0000-0000-000000000007', 'PRODUCT_CAROUSEL', 'biryani-rail',
   'Handi biryani, sealed and slow-cooked', 'Our signature dum biryani', 'See all', 'bitesbox://menu/biryani',
   '33333333-0000-0000-0000-000000000001', null, '{}', '{}'::jsonb, 'CAROUSEL', 8, 7, true, false, null, null),

  ('77777777-0000-0000-0000-000000000008', 'RECOMMENDED_COMBOS', 'combos',
   'Complete meal boxes', 'Everything in one box', 'See all', 'bitesbox://menu/combos-and-meals',
   null, null, '{}', '{}'::jsonb, 'GRID', 6, 8, true, false, null, null),

  ('77777777-0000-0000-0000-000000000009', 'CAMPAIGN_BANNER', 'mid-banner',
   null, null, null, null, null, null, '{}', '{}'::jsonb, 'BANNER', 2, 9, true, false, null, null),

  ('77777777-0000-0000-0000-00000000000a', 'PRICE_BUCKET', 'under-199',
   'Under ₹199', 'Big flavour, small bill', 'See all', 'bitesbox://collections/under-199',
   null, '66666666-0000-0000-0000-000000000001', '{}', '{"max_price": 199}'::jsonb, 'CAROUSEL', 10, 10, true, false, null, null),

  ('77777777-0000-0000-0000-00000000000b', 'PRODUCT_CAROUSEL', 'bihari-specials',
   'Straight from Bihar''s kitchens', 'Champaran mutton, litti chokha and more', 'See all', 'bitesbox://collections/bihari-specials',
   null, '66666666-0000-0000-0000-000000000002', '{}', '{}'::jsonb, 'CAROUSEL', 8, 11, true, false, null, null),

  ('77777777-0000-0000-0000-00000000000c', 'POPULAR_NOW', 'popular-tonight',
   'Popular tonight', 'Trending in the last few hours', null, null,
   null, null, '{}', '{}'::jsonb, 'CAROUSEL', 10, 12, true, false, '18:00', '23:30'),

  ('77777777-0000-0000-0000-00000000000d', 'NEW_ARRIVALS', 'new-arrivals',
   'New on the menu', 'Fresh additions from our kitchen', null, null,
   null, null, '{}', '{}'::jsonb, 'CAROUSEL', 8, 13, true, false, null, null),

  ('77777777-0000-0000-0000-00000000000e', 'PRODUCT_CAROUSEL', 'pure-veg',
   'Pure vegetarian', 'Cooked in a separate section', 'See all', 'bitesbox://collections/pure-veg',
   null, '66666666-0000-0000-0000-000000000003', '{}', '{}'::jsonb, 'CAROUSEL', 10, 14, true, false, null, null),

  ('77777777-0000-0000-0000-00000000000f', 'CUSTOMER_FAVOURITES', 'top-rated',
   'Top rated by customers', 'Highest rated dishes', null, null,
   null, null, '{}', '{}'::jsonb, 'CAROUSEL', 10, 15, true, false, null, null);

insert into public.cms_banners (
  section_id, title, subtitle, badge_text, image_path, image_path_wide, alt_text,
  background_color, link_kind, link_category_id, link_coupon_id, link_collection_id,
  link_route, display_order
) values
  ('77777777-0000-0000-0000-000000000001',
   'Handi biryani, sealed & slow-cooked', 'Aged basmati · saffron · 25 minutes', 'SIGNATURE',
   'banners/hero-biryani.jpg', 'banners/hero-biryani-wide.jpg',
   'Chicken dum biryani in a sealed handi', '#3B0A0D',
   'CATEGORY', '33333333-0000-0000-0000-000000000001', null, null, null, 1),

  ('77777777-0000-0000-0000-000000000001',
   'Champaran mutton is here', 'Clay-pot ahuna mutton, the Bihari way', 'MUST TRY',
   'banners/hero-champaran.jpg', 'banners/hero-champaran-wide.jpg',
   'Champaran handi mutton in a clay pot', '#2A1005',
   'CATEGORY', '33333333-0000-0000-0000-000000000003', null, null, null, 2),

  ('77777777-0000-0000-0000-000000000001',
   'Flat ₹75 off your first order', 'Use code BITES75 at checkout', 'NEW HERE?',
   'banners/hero-first-order.jpg', 'banners/hero-first-order-wide.jpg',
   'First order discount offer', '#0F2E1F',
   'IN_APP_ROUTE', null, null, null, 'bitesbox://offers', 3),

  ('77777777-0000-0000-0000-000000000009',
   'Free delivery above ₹349', 'Zone A · Bakhtiyarpur town', null,
   'banners/free-delivery.jpg', 'banners/free-delivery-wide.jpg',
   'Free delivery offer', '#1B4332',
   'IN_APP_ROUTE', null, null, null, 'bitesbox://offers', 1),

  ('77777777-0000-0000-0000-000000000009',
   'Family Feast Box — serves 4', 'Biryani, mutton, chicken & breads at ₹1299', 'SAVE ₹400',
   'banners/family-feast.jpg', 'banners/family-feast-wide.jpg',
   'Family feast combo box', '#4A0E12',
   'COLLECTION', null, null, '66666666-0000-0000-0000-000000000002', null, 2);

-- ═══════════════════════════════════════════════════════════════════════════
-- CMS — POLICIES & FAQ
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.cms_documents (kind, locale, title, body, version) values
  ('ABOUT', 'en', 'About Bites Box',
'Bites Box started in Bakhtiyarpur with a simple idea: the food Bihar actually loves, cooked properly, packed carefully, and delivered hot.

Our kitchen sits on Station Road, a short walk from Bakhtiyarpur Junction. We cook our biryani in sealed handis, roast our litti over coal, and make Champaran mutton the way it is made in Champaran — in a clay pot, sealed with dough, over a slow fire.

Everything is cooked to order. Nothing is pre-plated. If a dish is not up to standard, we do not send it out.', '1.0'),

  ('TERMS', 'en', 'Terms of Service',
'By placing an order with Bites Box you agree to these terms.

1. Orders
Orders are confirmed only after payment is verified or, for cash on delivery, after the restaurant accepts. We may decline an order if an item is unavailable, if the delivery address falls outside our service area, or if we suspect fraudulent activity.

2. Pricing
All prices shown include applicable GST. Delivery fees are calculated from your delivery zone and are shown before you pay. The amount payable is always calculated by our servers at the time you place the order.

3. Delivery
Delivery times are estimates, not guarantees. Traffic, weather and kitchen load affect them. Someone must be available at the delivery address to receive the order and share the delivery OTP.

4. Cancellation
Cancellation rights depend on the stage of your order. See our Cancellation Policy.

5. Food safety
Our kitchen handles nuts, dairy, gluten and egg. We cannot guarantee an allergen-free preparation. Tell us about allergies before ordering.

6. Conduct
We may block accounts that abuse coupons, place fraudulent cash-on-delivery orders, repeatedly cancel orders, or behave abusively towards our staff or delivery partners.', '1.0'),

  ('PRIVACY', 'en', 'Privacy Policy',
'We collect only what we need to bring you food.

What we collect
· Your name and phone number, so we can identify you and contact you about an order.
· Your delivery addresses and location, so we can check serviceability and reach you.
· Your order history, so you can reorder and we can help with support requests.
· Device information and notification tokens, so we can send order updates.

What we do with it
We use your data to fulfil orders, provide support, prevent fraud and, if you have opted in, tell you about offers. We never sell your data.

Who we share it with
· Your delivery partner sees your name, phone number and address only while your order is active.
· Our payment provider (Razorpay) processes your payment. We never store your card details.
· Our SMS and push providers deliver order notifications.

Location data
Your delivery partner''s location is shared with you only during an active delivery. Your own location is used only to check serviceability and set your delivery address.

Your choices
You can update your profile, delete saved addresses, and turn off marketing notifications at any time from the app. To request account deletion, contact us at hello@bitesbox.in.', '1.0'),

  ('CANCELLATION_POLICY', 'en', 'Cancellation Policy',
'You can cancel your order depending on how far along it is.

Before the kitchen accepts — full refund, no questions asked.

Within 2 minutes of acceptance — full refund.

While your food is being prepared — cancellation needs approval and 50% of the order value is refunded, because ingredients have already been used.

Once your order is packed, assigned to a delivery partner, or picked up — it can no longer be cancelled. If something is wrong, contact support and we will make it right.

If we cancel
If our kitchen cannot fulfil your order, or an item turns out to be unavailable, you receive a full refund automatically. You are never charged for our failure.

Refund timing
Refunds to the original payment method reach you in 3–5 working days. Refunds to your Bites Box wallet are instant.', '1.0'),

  ('REFUND_POLICY', 'en', 'Refund Policy',
'We refund in these situations.

Full refund
· We cancelled or rejected your order.
· Your order never arrived.
· You cancelled before the kitchen started cooking.

Partial or item refund
· An item was missing from your order.
· You received the wrong item.
· An item did not meet our quality standard.

How to request
Open the order in the app, tap Need help, and tell us what went wrong. Photographs help us resolve quality complaints faster.

How you get the money back
· Paid online — refunded to the original payment method in 3–5 working days.
· Paid cash on delivery — refunded as Bites Box wallet credit, instantly, or by bank transfer on request.

Our commitment
We review every refund request within 60 minutes during operating hours.', '1.0'),

  ('DELIVERY_POLICY', 'en', 'Delivery Policy',
'Where we deliver
We deliver up to 8 km from our Bakhtiyarpur kitchen. Enter your address in the app to check instantly.

Zone A (0–3 km) · ₹20 delivery · minimum order ₹99 · free above ₹349
Zone B (3–5 km) · ₹35 delivery · minimum order ₹149 · free above ₹499
Zone C (5–8 km) · ₹50 delivery · minimum order ₹249 · free above ₹799

Peak hours
A small surcharge applies between 7:30 PM and 10:00 PM, when demand is highest. It is always shown before you pay.

Delivery OTP
For your security, your delivery partner must enter a 4-digit OTP that only you receive. Never share it before receiving your food.

Self pickup
You can collect from our Station Road outlet with no delivery fee. We will send a pickup code when your order is ready.', '1.0');

insert into public.cms_faqs (category, question, answer, display_order) values
  ('ORDERING', 'How long does delivery take?',
   'Most orders in Bakhtiyarpur town reach you in 25–35 minutes. Biryani and Champaran mutton are cooked to order and take a little longer. The app shows a live estimate for your address before you pay.', 1),
  ('ORDERING', 'Can I order for later?',
   'Yes. At checkout, choose Schedule and pick a slot from 30 minutes up to 7 days ahead. We start cooking so the food reaches you fresh at your chosen time.', 2),
  ('ORDERING', 'Is there a minimum order?',
   'It depends on your zone — ₹99 in Zone A, ₹149 in Zone B and ₹249 in Zone C. The app tells you if you need to add a little more.', 3),
  ('PAYMENT', 'Which payment methods do you accept?',
   'UPI, credit and debit cards, net banking, popular wallets, Bites Box wallet credit, and cash on delivery up to ₹2,000.', 1),
  ('PAYMENT', 'Money left my account but the order did not confirm. What now?',
   'Do not worry, and do not pay again. Our system reconciles every payment with our gateway automatically. If the order genuinely did not go through, the amount is refunded within 3–5 working days. Contact support with your order number if you would like us to check immediately.', 2),
  ('DELIVERY', 'What is the delivery OTP?',
   'A 4-digit code sent to you when a delivery partner is assigned. Share it only when you have your food in hand. It stops orders being handed to the wrong person.', 1),
  ('DELIVERY', 'Can I track my delivery partner?',
   'Yes. Once your order is picked up, the tracking screen shows your delivery partner moving on a live map, along with their name and phone number.', 2),
  ('FOOD', 'Is your vegetarian food cooked separately?',
   'Yes. We keep separate preparation sections, utensils and oil for vegetarian dishes.', 1),
  ('FOOD', 'I have a food allergy. Can you help?',
   'Our kitchen handles nuts, dairy, gluten and egg, so we cannot promise an allergen-free preparation. Every dish lists its allergens, and you can add a note at checkout. For serious allergies, please call us before ordering.', 2),
  ('ACCOUNT', 'How do I delete my account?',
   'Email hello@bitesbox.in from your registered address, or ask support in the app. We remove your personal data within 30 days, keeping only what tax law requires us to retain.', 1);

-- ═══════════════════════════════════════════════════════════════════════════
-- COUPONS
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.coupons (
  id, code, title, description, terms, is_visible, banner_path,
  discount_kind, discount_value, max_discount_amount, min_order_amount,
  max_total_uses, max_uses_per_customer, audience, first_order_only,
  eligible_product_ids, eligible_category_ids, eligible_fulfilment,
  valid_days_of_week, valid_from_time, valid_to_time,
  starts_at, ends_at, is_active
) values
  ('88888888-0000-0000-0000-000000000001', 'BITES75',
   'Flat ₹75 off your first order', 'New to Bites Box? Get ₹75 off on orders above ₹299.',
   'Valid once per customer on your first order. Minimum order ₹299.',
   true, 'banners/coupon-first-order.jpg',
   'FLAT', 75, null, 299, null, 1, 'FIRST_ORDER', true,
   '{}', '{}', '{}', '{0,1,2,3,4,5,6}', null, null,
   now() - interval '30 days', now() + interval '180 days', true),

  ('88888888-0000-0000-0000-000000000002', 'BIRYANI20',
   '20% off all biryani', 'Save 20% on every handi biryani, up to ₹100.',
   'Applies to the Biryani category only. Maximum discount ₹100.',
   true, 'banners/coupon-biryani.jpg',
   'PERCENTAGE', 20, 100, 249, null, 3, 'ALL', false,
   '{}', array['33333333-0000-0000-0000-000000000001']::uuid[], '{}',
   '{0,1,2,3,4,5,6}', null, null,
   now() - interval '10 days', now() + interval '60 days', true),

  ('88888888-0000-0000-0000-000000000003', 'FREEDEL',
   'Free delivery tonight', 'No delivery fee on orders above ₹199 after 7 PM.',
   'Valid 7:00 PM to 11:00 PM. Delivery orders only.',
   true, 'banners/coupon-free-delivery.jpg',
   'FREE_DELIVERY', 0, null, 199, null, 5, 'ALL', false,
   '{}', '{}', array['DELIVERY']::public.fulfilment_type[],
   '{0,1,2,3,4,5,6}', '19:00', '23:00',
   now() - interval '5 days', now() + interval '45 days', true),

  ('88888888-0000-0000-0000-000000000004', 'WEEKEND100',
   '₹100 off above ₹599', 'Weekend treat — flat ₹100 off on orders above ₹599.',
   'Valid Saturday and Sunday only. Minimum order ₹599.',
   true, 'banners/coupon-weekend.jpg',
   'FLAT', 100, null, 599, 500, 2, 'ALL', false,
   '{}', '{}', '{}', '{0,6}', null, null,
   now() - interval '20 days', now() + interval '90 days', true),

  ('88888888-0000-0000-0000-000000000005', 'LITTI15',
   '15% off Bihari specials', 'Because litti chokha deserves a discount too.',
   'Applies to the Breakfast category. Maximum discount ₹50.',
   true, 'banners/coupon-litti.jpg',
   'PERCENTAGE', 15, 50, 149, null, 5, 'ALL', false,
   '{}', array['33333333-0000-0000-0000-00000000000c']::uuid[], '{}',
   '{0,1,2,3,4,5,6}', '08:00', '11:30',
   now() - interval '15 days', now() + interval '60 days', true),

  ('88888888-0000-0000-0000-000000000006', 'PICKUP10',
   '10% off self pickup', 'Collect from our outlet and save 10%.',
   'Self pickup orders only. Maximum discount ₹80.',
   true, null,
   'PERCENTAGE', 10, 80, 149, null, 10, 'ALL', false,
   '{}', '{}', array['PICKUP']::public.fulfilment_type[],
   '{0,1,2,3,4,5,6}', null, null,
   now() - interval '30 days', now() + interval '180 days', true),

  ('88888888-0000-0000-0000-000000000007', 'COMEBACK150',
   '₹150 off — we miss you', 'A welcome-back offer for customers who have not ordered in a while.',
   'For customers with no order in the last 30 days. Minimum order ₹499.',
   false, null,
   'FLAT', 150, null, 499, null, 1, 'INACTIVE_CUSTOMERS', false,
   '{}', '{}', '{}', '{0,1,2,3,4,5,6}', null, null,
   now() - interval '5 days', now() + interval '90 days', true),

  ('88888888-0000-0000-0000-000000000008', 'EXPIRED50',
   'Expired test coupon', 'Used by automated tests to assert the COUPON_EXPIRED path.',
   'Test fixture.',
   false, null,
   'FLAT', 50, null, 99, null, 1, 'ALL', false,
   '{}', '{}', '{}', '{0,1,2,3,4,5,6}', null, null,
   now() - interval '60 days', now() - interval '1 day', true);

insert into public.coupon_rules (coupon_id, rule_type, operator, value) values
  ('88888888-0000-0000-0000-000000000004', 'MIN_ITEM_COUNT', 'GTE', '2'::jsonb);

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTOMATIC PROMOTIONS
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.promotions (
  name, headline, description, badge_text, banner_path, trigger,
  discount_kind, discount_value, max_discount_amount, min_order_amount,
  eligible_category_ids, eligible_fulfilment, valid_days_of_week,
  valid_from_time, valid_to_time, priority, stacks_with_coupon,
  starts_at, ends_at, is_active
) values
  ('Happy Hours Chinese', '15% off Chinese, 3–6 PM',
   'Beat the afternoon slump with wok-fresh Chinese at 15% off.',
   'HAPPY HOURS', 'banners/promo-chinese.jpg', 'AUTOMATIC',
   'CATEGORY_DISCOUNT', 15, 75, 149,
   array['33333333-0000-0000-0000-000000000005']::uuid[], '{}',
   '{1,2,3,4,5}', '15:00', '18:00', 200, false,
   now() - interval '7 days', now() + interval '90 days', true),

  ('Free delivery over 499', 'Free delivery on orders above ₹499',
   'Spend ₹499 or more and we cover the delivery.',
   'FREE DELIVERY', null, 'AUTOMATIC',
   'FREE_DELIVERY', 0, null, 499,
   '{}', array['DELIVERY']::public.fulfilment_type[],
   '{0,1,2,3,4,5,6}', null, null, 150, true,
   now() - interval '30 days', null, true),

  ('Dessert Sunday', '10% off desserts on Sundays',
   'Because Sunday deserves gulab jamun.',
   'SUNDAY TREAT', null, 'AUTOMATIC',
   'CATEGORY_DISCOUNT', 10, 40, 99,
   array['33333333-0000-0000-0000-00000000000a']::uuid[], '{}',
   '{0}', null, null, 100, false,
   now() - interval '30 days', now() + interval '180 days', true);
