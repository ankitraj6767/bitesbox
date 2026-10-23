export interface GuestCartLine {
    productId: string;
    slug: string;
    name: string;
    imagePath?: string | null;
    quantity: number;
    variantId?: string | null;
    variantName?: string | null;
    modifiers: Array<{ modifier_id: string; quantity: number }>;
    specialInstructions?: string;
    displayedUnitPrice: number;
}

export function guestCartKey(branchId: string) {
    return `bb_guest_cart_${branchId}`;
}

export function guestCartImportKey(branchId: string) {
    const storageKey = `bb_guest_cart_import_${branchId}`;
    const existing = localStorage.getItem(storageKey);
    if (existing) return existing;
    const created = crypto.randomUUID();
    localStorage.setItem(storageKey, created);
    return created;
}

export function readGuestCart(branchId: string): GuestCartLine[] {
    try {
        const parsed: unknown = JSON.parse(localStorage.getItem(guestCartKey(branchId)) ?? '[]');
        return Array.isArray(parsed) ? parsed.filter(isGuestCartLine) : [];
    } catch {
        return [];
    }
}

export function writeGuestCart(branchId: string, lines: GuestCartLine[]) {
    localStorage.setItem(guestCartKey(branchId), JSON.stringify(lines));
    // Any edit changes the idempotency payload. Keep a key stable only while
    // retrying the same import request.
    localStorage.removeItem(`bb_guest_cart_import_${branchId}`);
    window.dispatchEvent(new CustomEvent('bb-guest-cart-changed'));
}

function isGuestCartLine(value: unknown): value is GuestCartLine {
    if (!value || typeof value !== 'object') return false;
    const line = value as Partial<GuestCartLine>;
    return typeof line.productId === 'string' && typeof line.name === 'string' &&
        typeof line.quantity === 'number' && Number.isInteger(line.quantity) && line.quantity > 0 &&
        Array.isArray(line.modifiers);
}
