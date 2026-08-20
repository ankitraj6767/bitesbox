import { describe, expect, it } from 'vitest';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { allNavItems, NAV_GROUPS, visibleNavigation } from './navigation';

/**
 * Navigation is role-aware, and this suite checks that it actually filters rather
 * than merely looking filtered.
 *
 * Hiding a link is convenience, not security — every route re-checks its permission
 * server-side. What matters here is that an operator is never shown a door they
 * cannot open, because that reads as a broken product.
 */
describe('visibleNavigation', () => {
    it('shows nothing to someone with no permissions', () => {
        expect(visibleNavigation([])).toEqual([]);
    });

    it('drops a group once all of its items are hidden', () => {
        const groups = visibleNavigation([PERMISSIONS.MENU_VIEW]);

        expect(groups.every((group) => group.items.length > 0)).toBe(true);
        expect(groups.map((group) => group.label)).toContain('Kitchen');
        expect(groups.map((group) => group.label)).not.toContain('Money');
    });

    it('reveals an item when the operator holds any one of its permissions', () => {
        // Availability accepts either menu.availability or inventory.view.
        const withAvailability = visibleNavigation([PERMISSIONS.MENU_AVAILABILITY]);
        const hrefs = withAvailability.flatMap((group) => group.items.map((item) => item.href));

        expect(hrefs).toContain('/availability');
    });

    it('gives a finance operator the money pages and not the kitchen', () => {
        const hrefs = visibleNavigation([
            PERMISSIONS.PAYMENT_VIEW,
            PERMISSIONS.REFUND_VIEW,
            PERMISSIONS.REPORT_VIEW,
        ]).flatMap((group) => group.items.map((item) => item.href));

        expect(hrefs).toContain('/payments');
        expect(hrefs).toContain('/refunds');
        expect(hrefs).toContain('/reports');
        expect(hrefs).not.toContain('/menu');
        expect(hrefs).not.toContain('/staff');
    });

    it('gives a support operator tickets and customers, not settings', () => {
        const hrefs = visibleNavigation([
            PERMISSIONS.SUPPORT_VIEW,
            PERMISSIONS.CUSTOMER_VIEW,
        ]).flatMap((group) => group.items.map((item) => item.href));

        expect(hrefs).toContain('/support');
        expect(hrefs).toContain('/customers');
        expect(hrefs).not.toContain('/settings');
        expect(hrefs).not.toContain('/audit');
    });

    it('shows everything to someone holding every permission', () => {
        const all = Object.values(PERMISSIONS);
        const visible = visibleNavigation(all).flatMap((group) => group.items);

        expect(visible).toHaveLength(allNavItems().length);
    });

    it('ignores a permission that does not appear in the navigation', () => {
        expect(visibleNavigation(['not.a.real.permission'])).toEqual([]);
    });
});

describe('NAV_GROUPS', () => {
    it('never declares an item without a permission, which would leak it to everyone', () => {
        for (const item of allNavItems()) {
            expect(item.permissions.length).toBeGreaterThan(0);
        }
    });

    it('uses permission codes that actually exist', () => {
        const known = new Set<string>(Object.values(PERMISSIONS));

        for (const item of allNavItems()) {
            for (const code of item.permissions) {
                expect(known.has(code), `${item.href} references unknown ${code}`).toBe(true);
            }
        }
    });

    it('has no duplicate destinations', () => {
        const hrefs = allNavItems().map((item) => item.href);
        expect(new Set(hrefs).size).toBe(hrefs.length);
    });

    it('gives every item a label and a description for the command palette', () => {
        for (const item of allNavItems()) {
            expect(item.label.trim().length).toBeGreaterThan(0);
            expect(item.description.trim().length).toBeGreaterThan(0);
        }
    });

    it('keeps the badge keys to the three the dashboard supplies', () => {
        const badges = allNavItems()
            .map((item) => item.badgeKey)
            .filter(Boolean);

        for (const badge of badges) {
            expect(['live_orders', 'pending_refunds', 'open_tickets']).toContain(badge);
        }
    });

    it('preserves group order, so the sidebar does not reshuffle per role', () => {
        const order = NAV_GROUPS.map((group) => group.label);
        const filtered = visibleNavigation(Object.values(PERMISSIONS)).map((group) => group.label);

        expect(filtered).toEqual(order);
    });
});
