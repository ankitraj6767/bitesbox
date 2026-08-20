import { describe, expect, it } from 'vitest';
import {
    compactNumber,
    csvEscape,
    dateOnly,
    elapsed,
    humanise,
    initials,
    money,
    percent,
    storageUrl,
    toCsv,
} from './utils';

describe('money', () => {
    // Indian grouping is lakhs and crores, not thousands: 1,23,456 not 123,456.
    // Getting this wrong on an invoice is the kind of detail an operator notices
    // immediately, so it is asserted rather than assumed.
    it('groups digits the Indian way', () => {
        expect(money(123456)).toBe('₹1,23,456');
        expect(money(1234)).toBe('₹1,234');
    });

    it('omits paise unless asked', () => {
        expect(money(249.5)).toBe('₹250');
        expect(money(249.5, true)).toBe('₹249.50');
    });

    it('treats a missing amount as zero rather than blank', () => {
        expect(money(null)).toBe('₹0');
        expect(money(undefined)).toBe('₹0');
    });
});

describe('compactNumber', () => {
    it('shortens large counts', () => {
        expect(compactNumber(1500)).toMatch(/1\.5/);
        expect(compactNumber(0)).toBe('0');
    });
});

describe('percent', () => {
    it('formats to one decimal by default', () => {
        expect(percent(12.34)).toBe('12.3%');
    });

    it('distinguishes zero from unknown', () => {
        expect(percent(0)).toBe('0.0%');
        expect(percent(null)).toBe('—');
    });
});

describe('dateOnly', () => {
    it('formats a date', () => {
        expect(dateOnly('2026-08-19T10:00:00Z')).toBe('19 Aug 2026');
    });

    it('does not render an em dash as a valid date', () => {
        expect(dateOnly(null)).toBe('—');
        expect(dateOnly('not-a-date')).toBe('—');
    });
});

describe('elapsed', () => {
    it('counts in mm:ss below an hour', () => {
        expect(elapsed(0)).toBe('0:00');
        expect(elapsed(65)).toBe('1:05');
        expect(elapsed(3599)).toBe('59:59');
    });

    it('switches to hours past sixty minutes', () => {
        expect(elapsed(3600)).toBe('1h 0m');
        expect(elapsed(3900)).toBe('1h 5m');
    });

    // A clock skew between the server and the tablet can produce a negative age;
    // a kitchen timer must never show "-3:-12".
    it('clamps a negative duration to zero', () => {
        expect(elapsed(-90)).toBe('0:00');
    });
});

describe('humanise', () => {
    it('turns an enum into a sentence', () => {
        expect(humanise('ORDER_PLACED')).toBe('Order placed');
        expect(humanise('OUT_FOR_DELIVERY')).toBe('Out for delivery');
    });

    it('handles nothing gracefully', () => {
        expect(humanise(null)).toBe('—');
        expect(humanise('')).toBe('—');
    });
});

describe('initials', () => {
    it('takes at most two initials', () => {
        expect(initials('Aarav Kumar')).toBe('AK');
        expect(initials('Aarav Kumar Singh')).toBe('AK');
        expect(initials('Aarav')).toBe('A');
    });

    it('copes with untidy whitespace', () => {
        expect(initials('  aarav   kumar ')).toBe('AK');
    });
});

describe('storageUrl', () => {
    it('leaves an absolute URL alone', () => {
        expect(storageUrl('https://cdn.example.com/a.jpg')).toBe('https://cdn.example.com/a.jpg');
    });

    // Seeded paths already carry the bucket, so it must not be prefixed twice.
    it('does not double the bucket when the path already carries it', () => {
        expect(storageUrl('menu-images/products/biryani.jpg')).toBe(
            'https://test.supabase.co/storage/v1/object/public/menu-images/products/biryani.jpg',
        );
    });

    it('applies the default bucket to a bare path', () => {
        expect(storageUrl('products/biryani.jpg')).toBe(
            'https://test.supabase.co/storage/v1/object/public/menu-images/products/biryani.jpg',
        );
    });

    it('honours an explicit bucket', () => {
        expect(storageUrl('logo.png', 'brand-assets')).toBe(
            'https://test.supabase.co/storage/v1/object/public/brand-assets/logo.png',
        );
    });

    it('returns null for no path', () => {
        expect(storageUrl(null)).toBeNull();
        expect(storageUrl('')).toBeNull();
    });
});

describe('csvEscape', () => {
    // An unescaped comma in a customer's address silently shifts every later column
    // in an exported report.
    it('quotes values containing a comma, quote or newline', () => {
        expect(csvEscape('Bakhtiyarpur, Patna')).toBe('"Bakhtiyarpur, Patna"');
        expect(csvEscape('5" plate')).toBe('"5"" plate"');
        expect(csvEscape('line1\nline2')).toBe('"line1\nline2"');
    });

    it('leaves a plain value alone', () => {
        expect(csvEscape('Biryani')).toBe('Biryani');
        expect(csvEscape(249)).toBe('249');
    });

    it('renders null as empty rather than "null"', () => {
        expect(csvEscape(null)).toBe('');
        expect(csvEscape(undefined)).toBe('');
    });
});

describe('toCsv', () => {
    it('writes a header from the first row', () => {
        const csv = toCsv([
            { order: 'BB-1', total: 249 },
            { order: 'BB-2', total: 199 },
        ]);

        expect(csv).toBe('order,total\nBB-1,249\nBB-2,199');
    });

    it('honours an explicit column order', () => {
        const csv = toCsv([{ a: 1, b: 2 }], ['b', 'a']);
        expect(csv).toBe('b,a\n2,1');
    });

    it('returns nothing for no rows', () => {
        expect(toCsv([])).toBe('');
    });
});
