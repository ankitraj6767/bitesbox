import { describe, expect, it } from 'vitest';
import type { Event } from '@sentry/nextjs';
import { scrubSentryEvent } from './scrub';

describe('Sentry event scrubbing', () => {
    it('removes credentials, PII, request bodies and uploaded image data', () => {
        const event = {
            event_id: 'event-123',
            user: { id: 'customer-1', email: 'customer@example.test' },
            request: {
                url: 'https://admin.example.test/customers/12345678?token=private',
                headers: { authorization: 'Bearer private-token' },
                cookies: 'session=private',
                data: { address: '21 Main Street' },
                query_string: 'token=private',
            },
            exception: { values: [{ type: 'Error', value: 'Failed for customer@example.test +91 98765 43210' }] },
            message: 'Image data:image/png;base64,AAAA1111 from customer@example.test',
            breadcrumbs: [{ message: 'Request to https://api.example.test/?phone=1234567890', data: { raw: 'private' } }],
            tags: { role_category: 'finance', route: 'customers', phone: '+919876543210' },
            extra: { customer_address: '21 Main Street' },
        } as unknown as Event;

        const cleaned = scrubSentryEvent(event)!;
        expect(cleaned.user).toBeUndefined();
        expect(cleaned.request?.url).toBe('https://admin.example.test/customers/[id]');
        expect(cleaned.request?.headers).toBeUndefined();
        expect(cleaned.request?.cookies).toBeUndefined();
        expect(cleaned.request?.data).toBeUndefined();
        expect(cleaned.request?.query_string).toBeUndefined();
        expect(cleaned.exception?.values?.[0]?.value).not.toContain('customer@example.test');
        expect(cleaned.message).not.toContain('customer@example.test');
        expect(cleaned.breadcrumbs?.[0]?.data).toBeUndefined();
        expect(cleaned.tags).toEqual({ role_category: 'finance', route: 'customers' });
        expect(cleaned.extra).toBeUndefined();
    });
});
