import '@testing-library/jest-dom/vitest';
import { afterEach, vi } from 'vitest';
import { cleanup } from '@testing-library/react';

// Every test starts from an empty DOM.
afterEach(() => {
    cleanup();
    vi.clearAllMocks();
});

// `storageUrl` reads this, and a CDN URL should be asserted as a stable string
// rather than depending on whatever .env.local happens to hold.
process.env.NEXT_PUBLIC_SUPABASE_URL = 'https://test.supabase.co';

// jsdom implements neither, and the shadcn/Radix components rely on both.
if (!window.matchMedia) {
    Object.defineProperty(window, 'matchMedia', {
        writable: true,
        value: (query: string) => ({
            matches: false,
            media: query,
            onchange: null,
            addListener: vi.fn(),
            removeListener: vi.fn(),
            addEventListener: vi.fn(),
            removeEventListener: vi.fn(),
            dispatchEvent: vi.fn(),
        }),
    });
}

if (!globalThis.ResizeObserver) {
    globalThis.ResizeObserver = class {
        observe() {}
        unobserve() {}
        disconnect() {}
    } as unknown as typeof ResizeObserver;
}
