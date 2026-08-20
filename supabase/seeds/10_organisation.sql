-- ═══════════════════════════════════════════════════════════════════════════
-- BITES BOX — DEVELOPMENT SEED
--
-- Realistic operating data for the Bakhtiyarpur outlet: real Bihari menu,
-- working delivery zones, live coupons, a composed homepage, staff accounts and
-- a handful of orders across the whole lifecycle.
--
-- Development / staging only. Production content is entered through the admin.
-- Every password below is `Password123!`.
-- ═══════════════════════════════════════════════════════════════════════════

set session_replication_role = 'origin';

-- ═══════════════════════════════════════════════════════════════════════════
-- BRANCH
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.branches (
  id, code, name, legal_name, slug,
  address_line1, address_line2, landmark, city, state, postal_code,
  latitude, longitude, google_maps_url,
  phone, alternate_phone, whatsapp_phone, email,
  gstin, fssai_licence_no, fssai_valid_till,
  timezone, currency_code, service_mode, status, accepting_orders,
  default_prep_minutes, rush_buffer_minutes, max_concurrent_orders,
  is_default, is_active, display_order
) values (
  '11111111-1111-1111-1111-111111111111',
  'BKP-01',
  'Bites Box Bakhtiyarpur',
  'Bites Box Foods Private Limited',
  'bakhtiyarpur',
  'Station Road, Near Bakhtiyarpur Junction',
  'Ward 12, Bakhtiyarpur',
  'Opposite State Bank of India',
  'Bakhtiyarpur',
  'Bihar',
  '803212',
  25.4608000,
  85.5230000,
  'https://maps.google.com/?q=25.4608,85.5230',
  '+919431100100',
  '+916122200100',
  '+919431100100',
  'bakhtiyarpur@bitesbox.in',
  '10ABCDE1234F1Z5',
  '20424001000123',
  '2027-03-31',
  'Asia/Kolkata',
  'INR',
  'BOTH',
  'OPEN',
  true,
  22,
  0,
  40,
  true,
  true,
  1
);

-- Trading hours: 08:00–23:00 Mon–Thu, until 23:30 Fri–Sun.
insert into public.branch_hours (branch_id, day_of_week, opens_at, closes_at, day_part)
select '11111111-1111-1111-1111-111111111111'::uuid, d::smallint, '08:00'::time, '11:30'::time, 'BREAKFAST'::public.day_part
from generate_series(0, 6) d
union all
select '11111111-1111-1111-1111-111111111111'::uuid, d::smallint, '11:30'::time, '16:30'::time, 'LUNCH'::public.day_part
from generate_series(0, 6) d
union all
select '11111111-1111-1111-1111-111111111111'::uuid, d::smallint, '16:30'::time, '19:00'::time, 'SNACKS'::public.day_part
from generate_series(0, 6) d
union all
select '11111111-1111-1111-1111-111111111111'::uuid, d::smallint, '19:00'::time, '23:00'::time, 'DINNER'::public.day_part
from generate_series(1, 4) d
union all
select '11111111-1111-1111-1111-111111111111'::uuid, d::smallint, '19:00'::time, '23:30'::time, 'DINNER'::public.day_part
from unnest(array[0, 5, 6]) d;

insert into public.branch_holidays (branch_id, holiday_on, label, is_closed) values
  ('11111111-1111-1111-1111-111111111111', '2026-10-20', 'Chhath Puja — Nahay Khay', true),
  ('11111111-1111-1111-1111-111111111111', '2026-10-21', 'Chhath Puja — Kharna', true);

-- ═══════════════════════════════════════════════════════════════════════════
-- TAX CATEGORIES (Indian restaurant GST)
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.tax_categories (
  id, code, name, description, rate, cgst_rate, sgst_rate, hsn_sac_code, is_inclusive, is_default
) values
  ('22222222-0000-0000-0000-000000000001', 'GST_5', 'Restaurant service 5%',
   'Standard restaurant supply — 5% GST with no input tax credit.',
   0.0500, 0.0250, 0.0250, '996331', true, true),
  ('22222222-0000-0000-0000-000000000002', 'GST_12', 'Packaged food 12%',
   'Pre-packaged branded food items.',
   0.1200, 0.0600, 0.0600, '210690', true, false),
  ('22222222-0000-0000-0000-000000000003', 'GST_18', 'Beverages 18%',
   'Aerated and sweetened beverages.',
   0.1800, 0.0900, 0.0900, '220210', true, false),
  ('22222222-0000-0000-0000-000000000004', 'GST_0', 'Exempt',
   'Zero-rated items such as plain drinking water.',
   0.0000, 0.0000, 0.0000, '220110', true, false);

-- ═══════════════════════════════════════════════════════════════════════════
-- DELIVERY ZONES
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.delivery_zones (
  branch_id, name, description, kind, min_distance_km, max_distance_km,
  delivery_fee, min_order_amount, free_delivery_threshold,
  per_km_surcharge, surcharge_after_km, peak_surcharge, peak_starts_at, peak_ends_at,
  base_eta_minutes, extra_eta_minutes, cod_enabled, max_cod_amount,
  is_serviceable, is_active, priority
) values
  ('11111111-1111-1111-1111-111111111111', 'Zone A — Bakhtiyarpur Town',
   'Station Road, Main Bazaar, Ward 1–14. Fastest deliveries.',
   'RADIUS', 0, 3, 20, 99, 349, 0, null, 10, '19:30', '22:00', 25, 0, true, 2000, true, true, 10),
  ('11111111-1111-1111-1111-111111111111', 'Zone B — Outskirts',
   'Athmalgola Road, Karauta, Sabalpur side.',
   'RADIUS', 3, 5, 35, 149, 499, 0, null, 15, '19:30', '22:00', 32, 5, true, 1500, true, true, 20),
  ('11111111-1111-1111-1111-111111111111', 'Zone C — Extended',
   'Barh Road belt and nearby villages. Longer delivery window.',
   'RADIUS', 5, 8, 50, 249, 799, 8, 6, 20, '19:30', '22:00', 45, 10, false, null, true, true, 30);

insert into public.delivery_payout_config (
  branch_id, base_payout, per_km_payout, free_km, peak_bonus, peak_starts_at, peak_ends_at
) values
  ('11111111-1111-1111-1111-111111111111', 25, 6, 2, 15, '19:30', '22:00');

-- ═══════════════════════════════════════════════════════════════════════════
-- SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.settings (key, value, value_type, "group", label, description, is_public) values
  -- Brand
  ('brand.name', '"Bites Box"', 'string', 'branding', 'Brand name', 'Displayed across every surface.', true),
  ('brand.tagline', '"Bihar ka swaad, box mein."', 'string', 'branding', 'Tagline', null, true),
  ('brand.logo_path', '"brand-assets/logo.png"', 'string', 'branding', 'Logo', null, true),
  ('brand.logo_dark_path', '"brand-assets/logo-dark.png"', 'string', 'branding', 'Logo (dark)', null, true),
  ('brand.app_icon_path', '"brand-assets/app-icon.png"', 'string', 'branding', 'App icon', null, true),
  ('brand.favicon_path', '"brand-assets/favicon.ico"', 'string', 'branding', 'Favicon', null, true),
  ('brand.color_primary', '"#C1121F"', 'string', 'branding', 'Primary colour', 'Bites Box chilli red.', true),
  ('brand.color_primary_dark', '"#8E0D17"', 'string', 'branding', 'Primary dark', null, true),
  ('brand.color_secondary', '"#1B4332"', 'string', 'branding', 'Secondary colour', 'Deep herb green.', true),
  ('brand.color_accent', '"#F0A202"', 'string', 'branding', 'Accent colour', 'Turmeric gold.', true),
  ('brand.color_background', '"#FFFBF6"', 'string', 'branding', 'Background', null, true),
  ('brand.color_surface', '"#FFFFFF"', 'string', 'branding', 'Surface', null, true),
  ('brand.color_success', '"#1B7F4B"', 'string', 'branding', 'Success', null, true),
  ('brand.color_warning', '"#B45309"', 'string', 'branding', 'Warning', null, true),
  ('brand.color_error', '"#B3261E"', 'string', 'branding', 'Error', null, true),
  ('brand.color_text_primary', '"#1A1614"', 'string', 'branding', 'Text primary', null, true),
  ('brand.color_text_secondary', '"#6B625C"', 'string', 'branding', 'Text secondary', null, true),
  ('brand.radius_scale', '1.0', 'number', 'branding', 'Corner radius scale', null, true),

  -- Contact
  ('contact.phone', '"+919431100100"', 'string', 'contact', 'Support phone', null, true),
  ('contact.whatsapp', '"+919431100100"', 'string', 'contact', 'WhatsApp', null, true),
  ('contact.email', '"hello@bitesbox.in"', 'string', 'contact', 'Support email', null, true),
  ('contact.support_hours', '"8:00 AM – 11:30 PM daily"', 'string', 'contact', 'Support hours', null, true),
  ('social.instagram', '"https://instagram.com/bitesbox.in"', 'string', 'contact', 'Instagram', null, true),
  ('social.facebook', '"https://facebook.com/bitesbox.in"', 'string', 'contact', 'Facebook', null, true),

  -- Ordering
  ('ordering.service_fee', '0', 'money', 'ordering', 'Service fee', 'Flat platform fee per order.', true),
  ('ordering.round_off_enabled', 'true', 'boolean', 'ordering', 'Round off totals', 'Round the payable amount to the nearest rupee.', true),
  ('ordering.schedule_lead_minutes', '45', 'number', 'ordering', 'Scheduled order lead time', 'Minutes before the slot that the kitchen receives the order.', false),
  ('ordering.auto_complete_hours', '6', 'number', 'ordering', 'Auto-complete window', 'Hours after delivery before an order is auto-completed.', false),
  ('ordering.max_tip_amount', '200', 'money', 'ordering', 'Maximum tip', null, true),
  ('ordering.tip_presets', '[20, 30, 50]', 'array', 'ordering', 'Tip presets', null, true),

  -- Delivery
  ('delivery.max_distance_km', '8', 'number', 'delivery', 'Maximum delivery distance', null, true),
  ('delivery.fallback_fee', '40', 'money', 'delivery', 'Fallback delivery fee', 'Used only if a zone lookup fails.', false),
  ('delivery.otp_length', '4', 'number', 'delivery', 'Delivery OTP length', null, false),
  ('delivery.require_pickup_verification', 'true', 'boolean', 'delivery', 'Require pickup verification', 'Riders must enter the kitchen code before leaving.', false),
  ('delivery.offer_ttl_seconds', '120', 'number', 'delivery', 'Rider offer TTL', null, false),
  ('delivery.location_sample_seconds', '20', 'number', 'delivery', 'Location sample interval', 'How often a breadcrumb row is stored.', false),
  ('delivery.location_retention_days', '30', 'number', 'delivery', 'Location retention', null, false),
  ('delivery.nearby_radius_km', '0.5', 'number', 'delivery', 'Rider nearby radius', 'Distance at which the customer is told the rider is close.', false),

  -- Payments
  ('cod.enabled', 'true', 'boolean', 'payments', 'Cash on delivery', null, true),
  ('cod.max_amount', '2000', 'money', 'payments', 'Maximum COD value', null, true),
  ('cod.min_order_amount', '0', 'money', 'payments', 'Minimum COD order', null, true),
  ('payment.pending_ttl_minutes', '20', 'number', 'payments', 'Unpaid order TTL', 'Minutes before an unpaid order is failed.', false),
  ('payment.currency', '"INR"', 'string', 'payments', 'Currency', null, true),
  ('refund.self_approval_limit', '500', 'money', 'payments', 'Self-approval limit', 'Above this, a refund needs a second approver.', false),

  -- Kitchen
  ('kitchen.accept_sla_seconds', '180', 'number', 'kitchen', 'Acceptance SLA', 'Seconds before an unaccepted order raises an alert.', false),
  ('kitchen.delay_threshold_seconds', '900', 'number', 'kitchen', 'Stage delay threshold', null, false),
  ('kitchen.sound_alerts', 'true', 'boolean', 'kitchen', 'Sound alerts', 'Play a chime on new orders.', true),

  -- Cart & growth
  ('cart.abandon_minutes', '60', 'number', 'growth', 'Abandoned cart delay', null, false),
  ('segment.high_value_ltv', '5000', 'money', 'growth', 'High-value threshold', null, false),
  ('segment.inactive_days', '30', 'number', 'growth', 'Inactive threshold (days)', null, false),
  ('loyalty.earn_points_per_100', '5', 'number', 'growth', 'Points earned per ₹100', null, true),
  ('loyalty.redeem_value_per_point', '0.25', 'number', 'growth', 'Rupee value per point', null, true),
  ('loyalty.max_redeem_percent', '20', 'number', 'growth', 'Maximum redemption', 'Percent of order value redeemable with points.', true),
  ('loyalty.min_redemption_points', '100', 'number', 'growth', 'Minimum points to redeem', null, true),

  -- Invoice & tax
  ('tax.inclusive_note', 'true', 'boolean', 'tax', 'Show inclusive tax note', null, true),
  ('invoice.footer_note', '"Thank you for ordering from Bites Box. Bihar ka swaad, box mein."', 'string', 'tax', 'Invoice footer', null, true),

  -- Maintenance
  ('maintenance.enabled', 'false', 'boolean', 'system', 'Maintenance mode', 'Blocks all ordering platform-wide.', true),
  ('maintenance.message', '"We are making Bites Box even better. Please check back in a few minutes."', 'string', 'system', 'Maintenance message', null, true),
  ('otp.provider', '"console"', 'string', 'system', 'OTP provider', null, false),
  ('otp.resend_seconds', '30', 'number', 'system', 'OTP resend cooldown', null, true),
  ('app.min_supported_version', '"1.0.0"', 'string', 'system', 'Minimum app version', null, true),
  ('app.latest_version', '"1.0.0"', 'string', 'system', 'Latest app version', null, true);

-- ═══════════════════════════════════════════════════════════════════════════
-- FEATURE FLAGS
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.feature_flags (key, label, description, is_enabled, rollout_percentage) values
  ('cod', 'Cash on delivery', 'Allow COD at checkout.', true, 100),
  ('scheduled_orders', 'Scheduled orders', 'Let customers order for later.', true, 100),
  ('self_pickup', 'Self pickup', 'Allow collecting from the outlet.', true, 100),
  ('wallet', 'Bites Box wallet', 'Store credit and wallet payments.', true, 100),
  ('loyalty', 'Loyalty points', 'Earn and redeem points.', false, 100),
  ('reviews', 'Reviews & ratings', 'Order rating flow.', true, 100),
  ('coupons', 'Coupons', 'Coupon codes at checkout.', true, 100),
  ('delivery_tracking', 'Live delivery tracking', 'Live rider map on the tracking screen.', true, 100),
  ('tipping', 'Rider tipping', 'Let customers add a tip.', true, 100),
  ('abandoned_cart_nudge', 'Abandoned cart nudge', 'Push reminder for abandoned carts.', true, 100),
  ('referrals', 'Referral programme', 'Refer-a-friend rewards.', false, 100),
  ('maintenance_mode', 'Maintenance mode', 'Master ordering kill switch.', false, 100);

-- ═══════════════════════════════════════════════════════════════════════════
-- CANCELLATION & REFUND POLICY
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.cancellation_policies (
  status, customer_can_cancel, requires_approval, refund_percentage,
  cancellation_fee, grace_period_seconds, customer_message
) values
  ('PENDING_PAYMENT',   true,  false, 100, 0,  0,
   'You can cancel freely — no payment has been taken.'),
  ('PAYMENT_CONFIRMED', true,  false, 100, 0,  300,
   'Cancel now for a full refund. Refunds reach your account in 3–5 working days.'),
  ('ORDER_PLACED',      true,  false, 100, 0,  180,
   'The kitchen has not started yet, so you get a full refund.'),
  ('STORE_ACCEPTED',    true,  false, 100, 0,  120,
   'Cancel within 2 minutes of acceptance for a full refund.'),
  ('PREPARING',         true,  true,   50, 0,  0,
   'Your food is already being cooked. Cancelling now refunds 50% of the order value.'),
  ('READY_FOR_PICKUP',  false, false,   0, 0,  0,
   'Your order is packed and ready. Please contact support if there is a problem.'),
  ('RIDER_ASSIGNED',    false, false,   0, 0,  0,
   'A delivery partner is collecting your order. Contact support for help.'),
  ('PICKED_UP',         false, false,   0, 0,  0,
   'Your order is on the way and can no longer be cancelled.'),
  ('OUT_FOR_DELIVERY',  false, false,   0, 0,  0,
   'Your order is on the way and can no longer be cancelled.');

insert into public.refund_policies (role_code, auto_approve_limit, max_request_amount, requires_second_approval_above) values
  ('SUPPORT',    300,  2000, 1000),
  ('OPERATIONS', 500,  3000, 1500),
  ('MANAGER',    2000, 10000, 5000),
  ('FINANCE',    10000, null, 25000),
  ('ADMIN',      25000, null, null),
  -- Effectively unlimited; the column is NOT NULL so we use a ceiling no real
  -- Bites Box order can reach rather than a null.
  ('OWNER',      999999, null, null);

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATION TEMPLATES
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.notification_templates (event, channel, locale, title, body, action_route, variables) values
  ('ORDER_PLACED', 'PUSH', 'en', 'Order {{order_number}} placed 🎉',
   'Thanks {{customer_name}}! We have received your order of ₹{{grand_total}}. The kitchen will confirm shortly.',
   'bitesbox://orders/{{order_id}}', array['order_number','customer_name','grand_total','order_id']),
  ('ORDER_PLACED', 'IN_APP', 'en', 'Order placed',
   'Your order {{order_number}} has been placed successfully.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('ORDER_PLACED', 'SMS', 'en', null,
   'Bites Box: Order {{order_number}} placed for Rs {{grand_total}}. Track it in the app.',
   null, array['order_number','grand_total']),

  ('PAYMENT_CONFIRMED', 'PUSH', 'en', 'Payment received ✅',
   'We have received ₹{{grand_total}} for order {{order_number}}.',
   'bitesbox://orders/{{order_id}}', array['grand_total','order_number','order_id']),
  ('PAYMENT_CONFIRMED', 'IN_APP', 'en', 'Payment confirmed',
   'Payment of ₹{{grand_total}} confirmed for {{order_number}}.',
   'bitesbox://orders/{{order_id}}', array['grand_total','order_number','order_id']),

  ('PAYMENT_FAILED', 'PUSH', 'en', 'Payment could not be completed',
   'We could not process the payment for {{order_number}}. Please try again — nothing has been charged.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('PAYMENT_FAILED', 'IN_APP', 'en', 'Payment failed',
   'Payment for {{order_number}} did not go through.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),

  ('ORDER_ACCEPTED', 'PUSH', 'en', 'Kitchen accepted your order 👨‍🍳',
   'Our chefs are on it. {{order_number}} will be ready in about {{eta_minutes}} minutes.',
   'bitesbox://orders/{{order_id}}', array['order_number','eta_minutes','order_id']),
  ('ORDER_ACCEPTED', 'IN_APP', 'en', 'Order accepted',
   'The kitchen has accepted {{order_number}}.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),

  ('ORDER_REJECTED', 'PUSH', 'en', 'We could not take this order',
   'Sorry — {{order_number}} could not be accepted. Any payment will be refunded in full.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),

  ('ORDER_PREPARING', 'PUSH', 'en', 'Your food is cooking 🍳',
   '{{order_number}} is being prepared fresh right now.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('ORDER_PREPARING', 'IN_APP', 'en', 'Preparing',
   '{{order_number}} is being prepared.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),

  ('ORDER_READY', 'PUSH', 'en', 'Order ready 🛍️',
   '{{order_number}} is packed and ready. Pickup code: {{pickup_code}}',
   'bitesbox://orders/{{order_id}}', array['order_number','pickup_code','order_id']),
  ('ORDER_READY', 'IN_APP', 'en', 'Ready',
   '{{order_number}} is ready.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('ORDER_READY', 'SMS', 'en', null,
   'Bites Box: Order {{order_number}} is ready for pickup. Code: {{pickup_code}}',
   null, array['order_number','pickup_code']),

  ('RIDER_ASSIGNED', 'PUSH', 'en', '{{rider_name}} is picking up your order 🛵',
   'Your delivery partner is on the way to the restaurant for {{order_number}}.',
   'bitesbox://orders/{{order_id}}/track', array['rider_name','order_number','order_id']),
  ('RIDER_ASSIGNED', 'IN_APP', 'en', 'Delivery partner assigned',
   '{{rider_name}} will deliver {{order_number}}.',
   'bitesbox://orders/{{order_id}}/track', array['rider_name','order_number','order_id']),

  ('DELIVERY_OTP', 'PUSH', 'en', 'Your delivery code is {{delivery_otp}}',
   'Share {{delivery_otp}} with your delivery partner to receive {{order_number}}.',
   'bitesbox://orders/{{order_id}}/track', array['delivery_otp','order_number','order_id']),
  ('DELIVERY_OTP', 'IN_APP', 'en', 'Delivery OTP',
   'Delivery code for {{order_number}}: {{delivery_otp}}',
   'bitesbox://orders/{{order_id}}/track', array['delivery_otp','order_number']),
  ('DELIVERY_OTP', 'SMS', 'en', null,
   'Bites Box: Share OTP {{delivery_otp}} with your delivery partner for order {{order_number}}. Do not share with anyone else.',
   null, array['delivery_otp','order_number']),

  ('ORDER_PICKED_UP', 'PUSH', 'en', 'On the way 🛵',
   '{{order_number}} has been picked up and is heading to you.',
   'bitesbox://orders/{{order_id}}/track', array['order_number','order_id']),
  ('ORDER_PICKED_UP', 'IN_APP', 'en', 'Out for delivery',
   '{{order_number}} is out for delivery.',
   'bitesbox://orders/{{order_id}}/track', array['order_number','order_id']),

  ('RIDER_NEARBY', 'PUSH', 'en', 'Almost there! 📍',
   'Your delivery partner is arriving with {{order_number}}. Please keep your OTP handy.',
   'bitesbox://orders/{{order_id}}/track', array['order_number','order_id']),
  ('RIDER_NEARBY', 'IN_APP', 'en', 'Arriving now',
   'Your delivery partner is nearby.',
   'bitesbox://orders/{{order_id}}/track', array['order_id']),

  ('ORDER_DELIVERED', 'PUSH', 'en', 'Delivered — enjoy your meal! 😋',
   '{{order_number}} has been delivered. Tap to rate your experience.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('ORDER_DELIVERED', 'IN_APP', 'en', 'Delivered',
   '{{order_number}} was delivered.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),

  ('ORDER_CANCELLED', 'PUSH', 'en', 'Order cancelled',
   '{{order_number}} has been cancelled. {{reason}}',
   'bitesbox://orders/{{order_id}}', array['order_number','reason','order_id']),
  ('ORDER_CANCELLED', 'IN_APP', 'en', 'Order cancelled',
   '{{order_number}} was cancelled. {{reason}}',
   'bitesbox://orders/{{order_id}}', array['order_number','reason','order_id']),
  ('ORDER_CANCELLED', 'SMS', 'en', null,
   'Bites Box: Order {{order_number}} has been cancelled. Refund, if any, is being processed.',
   null, array['order_number']),

  ('REFUND_INITIATED', 'PUSH', 'en', 'Refund started 💸',
   'We have initiated your refund for {{order_number}}. It reaches you in 3–5 working days.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('REFUND_INITIATED', 'IN_APP', 'en', 'Refund initiated',
   'Refund for {{order_number}} has been initiated.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),

  ('REFUND_COMPLETED', 'PUSH', 'en', 'Refund complete ✅',
   '₹{{refund_amount}} for {{order_number}} has been refunded to {{destination}}.',
   'bitesbox://orders/{{order_id}}', array['refund_amount','order_number','destination','order_id']),
  ('REFUND_COMPLETED', 'IN_APP', 'en', 'Refund completed',
   '₹{{refund_amount}} refunded for {{order_number}}.',
   'bitesbox://orders/{{order_id}}', array['refund_amount','order_number','order_id']),
  ('REFUND_COMPLETED', 'SMS', 'en', null,
   'Bites Box: Rs {{refund_amount}} refunded for order {{order_number}}.',
   null, array['refund_amount','order_number']),

  ('NEW_ORDER_KITCHEN', 'PUSH', 'en', '🔔 New order {{order_number}}',
   '{{item_count}} item(s) · ₹{{grand_total}}. Tap to accept.',
   'bitesbox://kitchen/queue', array['order_number','item_count','grand_total']),

  ('NEW_ASSIGNMENT_RIDER', 'PUSH', 'en', '🛵 New delivery — {{order_number}}',
   '{{area}} · {{distance_km}} km. Tap to view.',
   'bitesbox://delivery/assignments', array['order_number','area','distance_km']),

  ('SUPPORT_REPLY', 'PUSH', 'en', 'Support replied to {{ticket_number}}',
   'Our team has responded to your request. Tap to read.',
   'bitesbox://support/{{ticket_id}}', array['ticket_number','ticket_id']),
  ('SUPPORT_REPLY', 'IN_APP', 'en', 'Support replied',
   'New reply on {{ticket_number}}.',
   'bitesbox://support/{{ticket_id}}', array['ticket_number','ticket_id']),

  ('REVIEW_REQUEST', 'PUSH', 'en', 'How was your meal? ⭐',
   'Rate {{order_number}} in a few taps — it helps our kitchen improve.',
   'bitesbox://orders/{{order_id}}/review', array['order_number','order_id']),

  ('SYSTEM_ALERT', 'PUSH', 'en', 'Running a little late',
   'Sorry — {{order_number}} is about {{minutes_late}} min behind schedule. We are on it.',
   'bitesbox://orders/{{order_id}}', array['order_number','minutes_late','order_id']),
  ('SYSTEM_ALERT', 'IN_APP', 'en', 'Order delayed',
   '{{order_number}} is running late.',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),

  ('PROMOTION', 'PUSH', 'en', 'Still hungry? 🍛',
   'You left {{item_count}} item(s) in your cart. Complete your order before it sells out.',
   'bitesbox://cart', array['item_count']),

  ('CAMPAIGN', 'PUSH', 'en', '{{title}}', '{{body}}', '{{route}}', array['title','body','route']),

  ('OTP', 'SMS', 'en', null,
   '{{code}} is your Bites Box verification code. Valid for 10 minutes. Do not share it.',
   null, array['code']);

-- Hindi variants for the most customer-visible events.
insert into public.notification_templates (event, channel, locale, title, body, action_route, variables) values
  ('ORDER_PLACED', 'PUSH', 'hi', 'ऑर्डर {{order_number}} मिल गया 🎉',
   'धन्यवाद {{customer_name}}! ₹{{grand_total}} का आपका ऑर्डर मिल गया है।',
   'bitesbox://orders/{{order_id}}', array['order_number','customer_name','grand_total','order_id']),
  ('ORDER_ACCEPTED', 'PUSH', 'hi', 'रसोई ने ऑर्डर स्वीकार किया 👨‍🍳',
   '{{order_number}} लगभग {{eta_minutes}} मिनट में तैयार होगा।',
   'bitesbox://orders/{{order_id}}', array['order_number','eta_minutes','order_id']),
  ('ORDER_DELIVERED', 'PUSH', 'hi', 'डिलीवर हो गया — भोजन का आनंद लें! 😋',
   '{{order_number}} डिलीवर कर दिया गया है।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('DELIVERY_OTP', 'SMS', 'hi', null,
   'Bites Box: ऑर्डर {{order_number}} के लिए OTP {{delivery_otp}} डिलीवरी पार्टनर को बताएं।',
   null, array['delivery_otp','order_number']);
