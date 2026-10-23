export type StorefrontEventName = 'MENU_VIEW' | 'SEARCH' | 'PRODUCT_VIEW' | 'SERVICEABILITY_SUCCESS' | 'SERVICEABILITY_FAILURE' | 'CHECKOUT_START' | 'CHECKOUT_COMPLETED';

export function recordStorefrontEvent(name: StorefrontEventName, branchId?: string | null, productId?: string | null) {
    const eventId = crypto.randomUUID();
    const body = JSON.stringify({ eventId, eventName: name, branchId: branchId || null, productId: productId || null });
    if (navigator.sendBeacon) {
        navigator.sendBeacon('/api/storefront-event', new Blob([body], { type: 'application/json' }));
        return;
    }
    void fetch('/api/storefront-event', { method: 'POST', headers: { 'content-type': 'application/json' }, body, keepalive: true });
}
