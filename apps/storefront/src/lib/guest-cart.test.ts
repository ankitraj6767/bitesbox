import { afterEach, describe, expect, it, vi } from 'vitest';
import { guestCartImportKey, guestCartKey, readGuestCart, writeGuestCart, type GuestCartLine } from './guest-cart';
import { localeFrom, messages } from './site';

class MemoryStorage {
    private values = new Map<string, string>();
    getItem(key: string) { return this.values.get(key) ?? null; }
    setItem(key: string, value: string) { this.values.set(key, value); }
    removeItem(key: string) { this.values.delete(key); }
}

afterEach(() => vi.unstubAllGlobals());

describe('storefront customer preferences', () => {
    it('keeps anonymous carts separate for each outlet', () => {
        const storage = new MemoryStorage();
        vi.stubGlobal('localStorage', storage);
        vi.stubGlobal('window', { dispatchEvent: vi.fn() });
        const line: GuestCartLine = {
            productId: 'dish-1', slug: 'litti-chokha', name: 'Litti Chokha', quantity: 2,
            modifiers: [], displayedUnitPrice: 180,
        };

        writeGuestCart('outlet-a', [line]);

        expect(guestCartKey('outlet-a')).not.toBe(guestCartKey('outlet-b'));
        expect(readGuestCart('outlet-a')).toEqual([line]);
        expect(readGuestCart('outlet-b')).toEqual([]);
        expect(window.dispatchEvent).toHaveBeenCalledOnce();
    });

    it('keeps an import key stable for retries and rotates it when cart contents change', () => {
        const storage = new MemoryStorage();
        let generated = 0;
        vi.stubGlobal('localStorage', storage);
        vi.stubGlobal('crypto', { randomUUID: () => `import-key-${++generated}` });
        vi.stubGlobal('window', { dispatchEvent: vi.fn() });
        const line: GuestCartLine = {
            productId: 'dish-1', slug: 'litti-chokha', name: 'Litti Chokha', quantity: 1,
            modifiers: [], displayedUnitPrice: 180,
        };
        const first = guestCartImportKey('outlet-a');
        expect(guestCartImportKey('outlet-a')).toBe(first);
        writeGuestCart('outlet-a', [line]);
        expect(guestCartImportKey('outlet-a')).not.toBe(first);
    });

    it('drops malformed and non-positive cart lines', () => {
        const storage = new MemoryStorage();
        storage.setItem(guestCartKey('outlet-a'), JSON.stringify([
            { productId: 'ok', name: 'Dish', quantity: 1, modifiers: [] },
            { productId: 'bad', name: 'Dish', quantity: 0, modifiers: [] },
            null,
        ]));
        vi.stubGlobal('localStorage', storage);
        expect(readGuestCart('outlet-a')).toHaveLength(1);
        expect(readGuestCart('outlet-a')[0].productId).toBe('ok');
    });

    it('defaults unknown language values to English and has Hindi critical copy', () => {
        expect(localeFrom()).toBe('en');
        expect(localeFrom('unknown')).toBe('en');
        expect(localeFrom('hi')).toBe('hi');
        expect(messages.hi.checkout).not.toBe(messages.en.checkout);
        expect(messages.hi.paymentDisclaimer).toContain('Razorpay');
    });
});
