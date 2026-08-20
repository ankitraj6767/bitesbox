import {
    Activity,
    BadgePercent,
    BarChart3,
    Bell,
    Boxes,
    ClipboardList,
    CreditCard,
    FileClock,
    LayoutDashboard,
    LifeBuoy,
    Megaphone,
    Palette,
    ReceiptText,
    Settings,
    Star,
    Truck,
    UsersRound,
    UtensilsCrossed,
} from 'lucide-react';
import { PERMISSIONS, type Permission } from '@bitesbox/shared-types';

export interface NavItem {
    label: string;
    href: string;
    icon: React.ComponentType<{ className?: string }>;
    /** Any one of these permissions reveals the item. */
    permissions: Permission[];
    description: string;
    /** Shows a live count badge when the dashboard supplies one. */
    badgeKey?: 'live_orders' | 'pending_refunds' | 'open_tickets';
}

export interface NavGroup {
    label: string;
    items: NavItem[];
}

/**
 * Role-aware navigation. One admin application; RBAC decides what each operator
 * sees. Every route additionally re-checks its permission server-side, so hiding
 * an item is convenience, not security.
 */
export const NAV_GROUPS: NavGroup[] = [
    {
        label: 'Today',
        items: [
            {
                label: 'Overview',
                href: '/overview',
                icon: LayoutDashboard,
                permissions: [PERMISSIONS.ANALYTICS_VIEW, PERMISSIONS.ORDER_VIEW],
                description: 'Revenue, orders and live counters',
            },
            {
                label: 'Live operations',
                href: '/operations',
                icon: Activity,
                permissions: [PERMISSIONS.ORDER_VIEW],
                description: 'Command centre for the current service',
                badgeKey: 'live_orders',
            },
            {
                label: 'Orders',
                href: '/orders',
                icon: ClipboardList,
                permissions: [PERMISSIONS.ORDER_VIEW],
                description: 'Search and inspect every order',
            },
        ],
    },
    {
        label: 'Kitchen',
        items: [
            {
                label: 'Menu',
                href: '/menu',
                icon: UtensilsCrossed,
                permissions: [PERMISSIONS.MENU_VIEW],
                description: 'Categories, dishes, variants and add-ons',
            },
            {
                label: 'Availability',
                href: '/availability',
                icon: Boxes,
                permissions: [PERMISSIONS.MENU_AVAILABILITY, PERMISSIONS.INVENTORY_VIEW],
                description: 'Mark items in or out of stock',
            },
        ],
    },
    {
        label: 'Delivery',
        items: [
            {
                label: 'Delivery partners',
                href: '/delivery',
                icon: Truck,
                permissions: [PERMISSIONS.RIDER_VIEW, PERMISSIONS.DELIVERY_VIEW],
                description: 'Riders, documents and dispatch history',
            },
        ],
    },
    {
        label: 'Money',
        items: [
            {
                label: 'Payments',
                href: '/payments',
                icon: CreditCard,
                permissions: [PERMISSIONS.PAYMENT_VIEW],
                description: 'Gateway captures, COD and reconciliation',
            },
            {
                label: 'Refunds',
                href: '/refunds',
                icon: ReceiptText,
                permissions: [PERMISSIONS.REFUND_VIEW],
                description: 'Approve, reject and track refunds',
                badgeKey: 'pending_refunds',
            },
        ],
    },
    {
        label: 'Growth',
        items: [
            {
                label: 'Coupons',
                href: '/coupons',
                icon: BadgePercent,
                permissions: [PERMISSIONS.COUPON_VIEW],
                description: 'Codes, rules and redemption limits',
            },
            {
                label: 'Promotions',
                href: '/promotions',
                icon: Megaphone,
                permissions: [PERMISSIONS.COUPON_VIEW, PERMISSIONS.PROMOTION_MANAGE],
                description: 'Automatic offers with no code',
            },
            {
                label: 'Campaigns',
                href: '/campaigns',
                icon: Bell,
                permissions: [PERMISSIONS.CAMPAIGN_MANAGE, PERMISSIONS.NOTIFICATION_SEND],
                description: 'Push and SMS to customer segments',
            },
            {
                label: 'Storefront',
                href: '/cms',
                icon: Palette,
                permissions: [PERMISSIONS.CMS_VIEW],
                description: 'Home sections, banners and policies',
            },
        ],
    },
    {
        label: 'Customers',
        items: [
            {
                label: 'Customers',
                href: '/customers',
                icon: UsersRound,
                permissions: [PERMISSIONS.CUSTOMER_VIEW],
                description: 'Profiles, lifetime value and history',
            },
            {
                label: 'Support',
                href: '/support',
                icon: LifeBuoy,
                permissions: [PERMISSIONS.SUPPORT_VIEW],
                description: 'Tickets and conversations',
                badgeKey: 'open_tickets',
            },
            {
                label: 'Reviews',
                href: '/reviews',
                icon: Star,
                permissions: [PERMISSIONS.REVIEW_VIEW],
                description: 'Ratings and moderation',
            },
        ],
    },
    {
        label: 'Insight',
        items: [
            {
                label: 'Analytics',
                href: '/analytics',
                icon: BarChart3,
                permissions: [PERMISSIONS.ANALYTICS_VIEW, PERMISSIONS.REPORT_VIEW],
                description: 'Trends, products and performance',
            },
            {
                label: 'Reports',
                href: '/reports',
                icon: FileClock,
                permissions: [PERMISSIONS.REPORT_VIEW, PERMISSIONS.FINANCE_VIEW],
                description: 'Sales register, GST and exports',
            },
        ],
    },
    {
        label: 'Administration',
        items: [
            {
                label: 'Staff & roles',
                href: '/staff',
                icon: UsersRound,
                permissions: [PERMISSIONS.STAFF_VIEW],
                description: 'Accounts, roles and permissions',
            },
            {
                label: 'Settings',
                href: '/settings',
                icon: Settings,
                permissions: [PERMISSIONS.SETTINGS_VIEW],
                description: 'Branch, delivery, payments and flags',
            },
            {
                label: 'Audit log',
                href: '/audit',
                icon: FileClock,
                permissions: [PERMISSIONS.AUDIT_VIEW],
                description: 'Who changed what, and when',
            },
        ],
    },
];

/** Filters the navigation down to what this operator may open. */
export function visibleNavigation(permissions: string[]): NavGroup[] {
    const held = new Set(permissions);

    return NAV_GROUPS.map((group) => ({
        ...group,
        items: group.items.filter((item) => item.permissions.some((code) => held.has(code))),
    })).filter((group) => group.items.length > 0);
}

export function allNavItems(): NavItem[] {
    return NAV_GROUPS.flatMap((group) => group.items);
}
