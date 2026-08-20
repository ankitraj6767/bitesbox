-- ═══════════════════════════════════════════════════════════════════════════
-- 0002 · ENUMERATED DOMAINS
-- Every state in the platform is a first-class Postgres type so invalid values
-- cannot be written by any client, function or migration.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Identity & access ─────────────────────────────────────────────────────
create type public.account_status as enum (
  'ACTIVE',
  'BLOCKED',
  'SUSPENDED',
  'DELETED'
);

-- The role a signed-in user experiences. Drives which Flutter shell loads and
-- which admin navigation is rendered. Authorisation itself is permission-based.
create type public.app_role as enum (
  'CUSTOMER',
  'DELIVERY_PARTNER',
  'KITCHEN_STAFF',
  'MANAGER',
  'OPERATIONS',
  'FINANCE',
  'SUPPORT',
  'MARKETING',
  'ADMIN',
  'OWNER'
);

-- Which surface a role is allowed to sign in to.
create type public.role_surface as enum (
  'MOBILE_CUSTOMER',
  'MOBILE_DELIVERY',
  'MOBILE_KITCHEN',
  'ADMIN_WEB'
);

-- ─── Branch & operations ───────────────────────────────────────────────────
create type public.branch_status as enum (
  'OPEN',
  'CLOSED',
  'PAUSED',
  'BUSY'
);

create type public.branch_closure_reason as enum (
  'SCHEDULED_CLOSED',
  'TOO_BUSY',
  'TECHNICAL_ISSUE',
  'KITCHEN_ISSUE',
  'WEATHER',
  'HOLIDAY',
  'OTHER'
);

create type public.service_mode as enum (
  'DELIVERY',
  'PICKUP',
  'BOTH'
);

create type public.zone_kind as enum (
  'RADIUS',
  'POLYGON'
);

-- ─── Catalog ───────────────────────────────────────────────────────────────
create type public.food_type as enum (
  'VEG',
  'NON_VEG',
  'EGG',
  'VEGAN'
);

create type public.spice_level as enum (
  'NONE',
  'MILD',
  'MEDIUM',
  'HOT',
  'EXTRA_HOT'
);

create type public.availability_state as enum (
  'AVAILABLE',
  'OUT_OF_STOCK',
  'TEMPORARILY_UNAVAILABLE'
);

create type public.modifier_selection as enum (
  'SINGLE',
  'MULTIPLE'
);

create type public.day_part as enum (
  'BREAKFAST',
  'LUNCH',
  'SNACKS',
  'DINNER',
  'LATE_NIGHT',
  'ALL_DAY'
);

-- ─── Cart / order fulfilment ───────────────────────────────────────────────
create type public.fulfilment_type as enum (
  'DELIVERY',
  'PICKUP'
);

create type public.order_timing as enum (
  'NOW',
  'SCHEDULED'
);

create type public.order_channel as enum (
  'MOBILE_APP',
  'ADMIN_MANUAL',
  'PHONE',
  'WEB',
  'WALK_IN'
);

-- ─── Order state machine ───────────────────────────────────────────────────
-- Backend-controlled. Transitions are validated by app.assert_transition().
create type public.order_status as enum (
  -- happy path
  'PENDING_PAYMENT',
  'PAYMENT_CONFIRMED',
  'ORDER_PLACED',
  'STORE_ACCEPTED',
  'PREPARING',
  'READY_FOR_PICKUP',
  'RIDER_ASSIGNED',
  'RIDER_ARRIVED_STORE',
  'PICKED_UP',
  'OUT_FOR_DELIVERY',
  'RIDER_ARRIVED_CUSTOMER',
  'DELIVERED',
  'COMPLETED',
  -- failure / cancellation
  'PAYMENT_FAILED',
  'STORE_REJECTED',
  'CUSTOMER_CANCELLED',
  'ADMIN_CANCELLED',
  'DELIVERY_FAILED',
  -- money-back lifecycle
  'REFUND_PENDING',
  'PARTIALLY_REFUNDED',
  'REFUNDED'
);

create type public.cancellation_actor as enum (
  'CUSTOMER',
  'STORE',
  'ADMIN',
  'RIDER',
  'SYSTEM'
);

create type public.cancellation_reason as enum (
  'CUSTOMER_CHANGED_MIND',
  'ORDERED_BY_MISTAKE',
  'DELIVERY_TOO_LONG',
  'ADDRESS_WRONG',
  'ITEM_UNAVAILABLE',
  'KITCHEN_OVERLOADED',
  'RESTAURANT_CLOSED',
  'NO_DELIVERY_PARTNER',
  'PAYMENT_ISSUE',
  'DUPLICATE_ORDER',
  'CUSTOMER_UNREACHABLE',
  'WEATHER',
  'FRAUD_SUSPECTED',
  'OTHER'
);

-- ─── Payments ──────────────────────────────────────────────────────────────
create type public.payment_mode as enum (
  'ONLINE',
  'COD',
  'WALLET',
  'SPLIT_WALLET_ONLINE',
  'SPLIT_WALLET_COD'
);

create type public.payment_method as enum (
  'UPI',
  'CARD',
  'CREDIT_CARD',
  'DEBIT_CARD',
  'NETBANKING',
  'WALLET_PROVIDER',
  'EMI',
  'PAYLATER',
  'CASH',
  'STORE_CREDIT'
);

create type public.payment_status as enum (
  'CREATED',
  'PENDING',
  'AUTHORIZED',
  'CAPTURED',
  'FAILED',
  'CANCELLED',
  'EXPIRED',
  'REFUND_PENDING',
  'PARTIALLY_REFUNDED',
  'REFUNDED'
);

create type public.cod_status as enum (
  'COD_PENDING',
  'COD_COLLECTED',
  'COD_FAILED',
  'COD_WAIVED'
);

create type public.payment_gateway as enum (
  'RAZORPAY',
  'CASH',
  'WALLET',
  'MANUAL'
);

-- ─── Refunds ───────────────────────────────────────────────────────────────
create type public.refund_kind as enum (
  'FULL_REFUND',
  'PARTIAL_REFUND',
  'ITEM_REFUND'
);

create type public.refund_destination as enum (
  'ORIGINAL_PAYMENT_METHOD',
  'WALLET_CREDIT',
  'BANK_TRANSFER',
  'CASH'
);

create type public.refund_status as enum (
  'REQUESTED',
  'APPROVAL_PENDING',
  'APPROVED',
  'REJECTED',
  'PROCESSING',
  'COMPLETED',
  'FAILED'
);

create type public.refund_reason as enum (
  'RESTAURANT_CANCELLED',
  'ITEM_UNAVAILABLE',
  'PAYMENT_ISSUE',
  'WRONG_ITEM',
  'MISSING_ITEM',
  'QUALITY_ISSUE',
  'DELIVERY_FAILURE',
  'LATE_DELIVERY',
  'CUSTOMER_CANCELLATION',
  'DUPLICATE_PAYMENT',
  'MANUAL_ADJUSTMENT',
  'GOODWILL'
);

-- ─── Delivery ──────────────────────────────────────────────────────────────
create type public.rider_onboarding_status as enum (
  'PENDING',
  'DOCUMENTS_SUBMITTED',
  'VERIFIED',
  'ACTIVE',
  'SUSPENDED',
  'REJECTED'
);

create type public.rider_duty_state as enum (
  'OFFLINE',
  'AVAILABLE',
  'BUSY',
  'ON_BREAK'
);

create type public.vehicle_type as enum (
  'BICYCLE',
  'SCOOTER',
  'MOTORCYCLE',
  'CAR',
  'ON_FOOT'
);

create type public.rider_document_type as enum (
  'DRIVING_LICENCE',
  'AADHAAR',
  'PAN',
  'VEHICLE_RC',
  'INSURANCE',
  'BANK_PASSBOOK',
  'PROFILE_PHOTO',
  'POLICE_VERIFICATION'
);

create type public.document_status as enum (
  'PENDING',
  'APPROVED',
  'REJECTED',
  'EXPIRED'
);

create type public.assignment_status as enum (
  'OFFERED',
  'ACCEPTED',
  'REJECTED',
  'EXPIRED',
  'CANCELLED',
  'AT_STORE',
  'PICKED_UP',
  'AT_CUSTOMER',
  'COMPLETED',
  'FAILED'
);

create type public.assignment_mode as enum (
  'MANUAL',
  'AUTO',
  'SELF_ASSIGNED'
);

-- ─── Promotions ────────────────────────────────────────────────────────────
create type public.discount_kind as enum (
  'PERCENTAGE',
  'FLAT',
  'FREE_DELIVERY',
  'PRODUCT_DISCOUNT',
  'CATEGORY_DISCOUNT',
  'BUY_X_GET_Y'
);

create type public.coupon_audience as enum (
  'ALL',
  'FIRST_ORDER',
  'SPECIFIC_CUSTOMERS',
  'SEGMENT',
  'INACTIVE_CUSTOMERS',
  'HIGH_VALUE_CUSTOMERS'
);

create type public.promotion_trigger as enum (
  'AUTOMATIC',
  'COUPON_CODE'
);

-- ─── Notifications ─────────────────────────────────────────────────────────
create type public.notification_channel as enum (
  'PUSH',
  'SMS',
  'EMAIL',
  'IN_APP',
  'WHATSAPP'
);

create type public.notification_event as enum (
  'OTP',
  'ORDER_PLACED',
  'PAYMENT_CONFIRMED',
  'PAYMENT_FAILED',
  'ORDER_ACCEPTED',
  'ORDER_REJECTED',
  'ORDER_PREPARING',
  'ORDER_READY',
  'RIDER_ASSIGNED',
  'ORDER_PICKED_UP',
  'RIDER_NEARBY',
  'ORDER_DELIVERED',
  'ORDER_CANCELLED',
  'REFUND_INITIATED',
  'REFUND_COMPLETED',
  'DELIVERY_OTP',
  'PICKUP_OTP',
  'NEW_ORDER_KITCHEN',
  'NEW_ASSIGNMENT_RIDER',
  'SUPPORT_REPLY',
  'REVIEW_REQUEST',
  'PROMOTION',
  'CAMPAIGN',
  'SYSTEM_ALERT'
);

create type public.notification_status as enum (
  'QUEUED',
  'SENDING',
  'SENT',
  'DELIVERED',
  'READ',
  'FAILED',
  'SUPPRESSED'
);

create type public.device_platform as enum (
  'ANDROID',
  'IOS',
  'WEB'
);

create type public.campaign_status as enum (
  'DRAFT',
  'SCHEDULED',
  'RUNNING',
  'PAUSED',
  'COMPLETED',
  'CANCELLED'
);

create type public.audience_segment as enum (
  'ALL_CUSTOMERS',
  'NEW_CUSTOMERS',
  'INACTIVE_CUSTOMERS',
  'HIGH_VALUE_CUSTOMERS',
  'CATEGORY_BUYERS',
  'ABANDONED_CART',
  'CUSTOM_LIST'
);

-- ─── Support ───────────────────────────────────────────────────────────────
create type public.ticket_category as enum (
  'ORDER_DELAYED',
  'MISSING_ITEM',
  'WRONG_ITEM',
  'FOOD_QUALITY',
  'PAYMENT_PROBLEM',
  'REFUND',
  'DELIVERY_ISSUE',
  'CANCELLATION',
  'APP_ISSUE',
  'OTHER'
);

create type public.ticket_status as enum (
  'OPEN',
  'IN_PROGRESS',
  'WAITING_ON_CUSTOMER',
  'ESCALATED',
  'RESOLVED',
  'CLOSED'
);

create type public.ticket_priority as enum (
  'LOW',
  'NORMAL',
  'HIGH',
  'URGENT'
);

create type public.message_author as enum (
  'CUSTOMER',
  'AGENT',
  'SYSTEM'
);

-- ─── CMS ───────────────────────────────────────────────────────────────────
create type public.home_section_kind as enum (
  'HERO_CAROUSEL',
  'CATEGORY_GRID',
  'CATEGORY_CAROUSEL',
  'PRODUCT_CAROUSEL',
  'BEST_SELLERS',
  'TODAYS_OFFERS',
  'RECOMMENDED_COMBOS',
  'NEW_ARRIVALS',
  'PRICE_BUCKET',
  'POPULAR_NOW',
  'BUY_AGAIN',
  'RECENTLY_ORDERED',
  'CUSTOMER_FAVOURITES',
  'CAMPAIGN_BANNER',
  'COUPON_STRIP',
  'RICH_TEXT'
);

create type public.banner_link_kind as enum (
  'NONE',
  'CATEGORY',
  'PRODUCT',
  'COUPON',
  'COLLECTION',
  'EXTERNAL_URL',
  'IN_APP_ROUTE'
);

create type public.legal_document_kind as enum (
  'TERMS',
  'PRIVACY',
  'REFUND_POLICY',
  'CANCELLATION_POLICY',
  'DELIVERY_POLICY',
  'ABOUT',
  'FAQ',
  'SHIPPING_POLICY'
);

-- ─── Ledgers ───────────────────────────────────────────────────────────────
create type public.wallet_entry_kind as enum (
  'CREDIT',
  'DEBIT',
  'REFUND',
  'PROMOTION',
  'CASHBACK',
  'ADJUSTMENT',
  'EXPIRY',
  'REVERSAL'
);

create type public.loyalty_entry_kind as enum (
  'EARN',
  'REDEEM',
  'EXPIRE',
  'ADJUSTMENT',
  'REVERSAL'
);

-- ─── Inventory (phase 2 ready) ─────────────────────────────────────────────
create type public.stock_movement_kind as enum (
  'PURCHASE',
  'CONSUMPTION',
  'WASTAGE',
  'ADJUSTMENT',
  'RETURN',
  'OPENING_BALANCE',
  'TRANSFER'
);

create type public.unit_of_measure as enum (
  'GRAM',
  'KILOGRAM',
  'MILLILITRE',
  'LITRE',
  'PIECE',
  'PACKET',
  'DOZEN'
);

-- ─── Audit ─────────────────────────────────────────────────────────────────
create type public.audit_action as enum (
  'CREATE',
  'UPDATE',
  'DELETE',
  'RESTORE',
  'LOGIN',
  'LOGOUT',
  'PERMISSION_GRANT',
  'PERMISSION_REVOKE',
  'ROLE_ASSIGN',
  'ROLE_REVOKE',
  'ORDER_STATUS_OVERRIDE',
  'ORDER_CANCEL',
  'PRICE_CHANGE',
  'REFUND_REQUEST',
  'REFUND_APPROVE',
  'REFUND_REJECT',
  'RIDER_ASSIGN',
  'RIDER_REASSIGN',
  'SETTINGS_CHANGE',
  'FEATURE_FLAG_CHANGE',
  'CUSTOMER_BLOCK',
  'CUSTOMER_UNBLOCK',
  'RIDER_SUSPEND',
  'MANUAL_DELIVERY_OVERRIDE',
  'WALLET_ADJUSTMENT',
  'COUPON_CHANGE',
  'BULK_UPDATE',
  'EXPORT'
);

create type public.actor_kind as enum (
  'USER',
  'SYSTEM',
  'WEBHOOK',
  'SCHEDULER'
);

-- ─── Reviews ───────────────────────────────────────────────────────────────
create type public.review_status as enum (
  'PUBLISHED',
  'PENDING_MODERATION',
  'FLAGGED',
  'HIDDEN'
);
