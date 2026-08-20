/**
 * Permission codes, mirrored from the `permissions` table seeded in
 * migration 0004. Used by the admin dashboard to gate navigation and actions.
 *
 * The client list is a rendering hint only — the database re-checks every
 * permission through `app.has_permission()` on each request.
 */
export const PERMISSIONS = {
    MENU_VIEW: 'menu.view',
    MENU_CREATE: 'menu.create',
    MENU_UPDATE: 'menu.update',
    MENU_DELETE: 'menu.delete',
    MENU_PRICE_UPDATE: 'menu.price_update',
    MENU_AVAILABILITY: 'menu.availability',

    ORDER_VIEW: 'order.view',
    ORDER_CREATE: 'order.create',
    ORDER_ACCEPT: 'order.accept',
    ORDER_REJECT: 'order.reject',
    ORDER_PREPARE: 'order.prepare',
    ORDER_READY: 'order.ready',
    ORDER_CANCEL: 'order.cancel',
    ORDER_OVERRIDE: 'order.override',
    ORDER_NOTE: 'order.note',

    DELIVERY_VIEW: 'delivery.view',
    DELIVERY_ASSIGN: 'delivery.assign',
    DELIVERY_PICKUP: 'delivery.pickup',
    DELIVERY_COMPLETE: 'delivery.complete',
    DELIVERY_OVERRIDE: 'delivery.override',
    DELIVERY_TRACK: 'delivery.track',

    RIDER_VIEW: 'rider.view',
    RIDER_CREATE: 'rider.create',
    RIDER_UPDATE: 'rider.update',
    RIDER_APPROVE: 'rider.approve',
    RIDER_SUSPEND: 'rider.suspend',

    PAYMENT_VIEW: 'payment.view',
    PAYMENT_RECONCILE: 'payment.reconcile',
    PAYMENT_SETTINGS: 'payment.settings',

    REFUND_VIEW: 'refund.view',
    REFUND_CREATE: 'refund.create',
    REFUND_APPROVE: 'refund.approve',
    REFUND_REJECT: 'refund.reject',

    COUPON_VIEW: 'coupon.view',
    COUPON_CREATE: 'coupon.create',
    COUPON_UPDATE: 'coupon.update',
    COUPON_DELETE: 'coupon.delete',
    PROMOTION_MANAGE: 'promotion.manage',

    CUSTOMER_VIEW: 'customer.view',
    CUSTOMER_UPDATE: 'customer.update',
    CUSTOMER_BLOCK: 'customer.block',
    CUSTOMER_CREDIT: 'customer.credit',

    STAFF_VIEW: 'staff.view',
    STAFF_CREATE: 'staff.create',
    STAFF_UPDATE: 'staff.update',
    ROLE_ASSIGN: 'role.assign',
    ROLE_MANAGE: 'role.manage',

    SUPPORT_VIEW: 'support.view',
    SUPPORT_RESPOND: 'support.respond',
    SUPPORT_CLOSE: 'support.close',

    REVIEW_VIEW: 'review.view',
    REVIEW_MODERATE: 'review.moderate',

    NOTIFICATION_SEND: 'notification.send',
    NOTIFICATION_TEMPLATE: 'notification.template',
    CAMPAIGN_MANAGE: 'campaign.manage',

    ANALYTICS_VIEW: 'analytics.view',
    REPORT_VIEW: 'report.view',
    REPORT_EXPORT: 'report.export',
    FINANCE_VIEW: 'finance.view',

    CMS_VIEW: 'cms.view',
    CMS_UPDATE: 'cms.update',

    SETTINGS_VIEW: 'settings.view',
    SETTINGS_UPDATE: 'settings.update',
    BRANCH_MANAGE: 'branch.manage',
    FEATURE_FLAG_UPDATE: 'feature_flag.update',

    INVENTORY_VIEW: 'inventory.view',
    INVENTORY_UPDATE: 'inventory.update',

    AUDIT_VIEW: 'audit.view',

    KITCHEN_VIEW: 'kitchen.view',
    KITCHEN_OPERATE: 'kitchen.operate',
} as const;

export type Permission = (typeof PERMISSIONS)[keyof typeof PERMISSIONS];

/** Permissions that always produce an audit record when exercised. */
export const SENSITIVE_PERMISSIONS: readonly Permission[] = [
    PERMISSIONS.MENU_DELETE,
    PERMISSIONS.MENU_PRICE_UPDATE,
    PERMISSIONS.ORDER_REJECT,
    PERMISSIONS.ORDER_CANCEL,
    PERMISSIONS.ORDER_OVERRIDE,
    PERMISSIONS.DELIVERY_OVERRIDE,
    PERMISSIONS.RIDER_APPROVE,
    PERMISSIONS.RIDER_SUSPEND,
    PERMISSIONS.PAYMENT_RECONCILE,
    PERMISSIONS.PAYMENT_SETTINGS,
    PERMISSIONS.REFUND_CREATE,
    PERMISSIONS.REFUND_APPROVE,
    PERMISSIONS.REFUND_REJECT,
    PERMISSIONS.COUPON_UPDATE,
    PERMISSIONS.COUPON_DELETE,
    PERMISSIONS.CUSTOMER_BLOCK,
    PERMISSIONS.CUSTOMER_CREDIT,
    PERMISSIONS.STAFF_CREATE,
    PERMISSIONS.STAFF_UPDATE,
    PERMISSIONS.ROLE_ASSIGN,
    PERMISSIONS.ROLE_MANAGE,
    PERMISSIONS.SETTINGS_UPDATE,
    PERMISSIONS.BRANCH_MANAGE,
    PERMISSIONS.FEATURE_FLAG_UPDATE,
    PERMISSIONS.REPORT_EXPORT,
    PERMISSIONS.AUDIT_VIEW,
];

/** Feature flag keys seeded in 10_organisation.sql. */
export const FEATURE_FLAGS = {
    COD: 'cod',
    SCHEDULED_ORDERS: 'scheduled_orders',
    SELF_PICKUP: 'self_pickup',
    WALLET: 'wallet',
    LOYALTY: 'loyalty',
    REVIEWS: 'reviews',
    COUPONS: 'coupons',
    DELIVERY_TRACKING: 'delivery_tracking',
    TIPPING: 'tipping',
    ABANDONED_CART_NUDGE: 'abandoned_cart_nudge',
    REFERRALS: 'referrals',
    MAINTENANCE_MODE: 'maintenance_mode',
} as const;

export type FeatureFlagKey = (typeof FEATURE_FLAGS)[keyof typeof FEATURE_FLAGS];

/** Supabase Storage buckets declared in config.toml. */
export const STORAGE_BUCKETS = {
    MENU_IMAGES: 'menu-images',
    BANNERS: 'banners',
    BRAND_ASSETS: 'brand-assets',
    STAFF_PHOTOS: 'staff-photos',
    RIDER_DOCUMENTS: 'rider-documents',
    DELIVERY_PROOFS: 'delivery-proofs',
    SUPPORT_ATTACHMENTS: 'support-attachments',
    INVOICES: 'invoices',
} as const;

export const PUBLIC_BUCKETS: readonly string[] = [
    STORAGE_BUCKETS.MENU_IMAGES,
    STORAGE_BUCKETS.BANNERS,
    STORAGE_BUCKETS.BRAND_ASSETS,
];
