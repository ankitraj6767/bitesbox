'use client';

import { createBrowserClient } from '@supabase/ssr';
import type { Database } from '@bitesbox/shared-types';

let cached: ReturnType<typeof createBrowserClient<Database>> | null = null;

/**
 * Browser Supabase client. Singleton so realtime subscriptions and the auth
 * listener are shared across the app instead of duplicated per component.
 */
export function createSupabaseBrowserClient() {
    if (cached) return cached;

    cached = createBrowserClient<Database>(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        {
            realtime: {
                // Live operations and the kitchen board are chatty; a modest cap keeps
                // a busy dinner service from flooding the browser.
                params: { eventsPerSecond: 10 },
            },
        },
    );

    return cached;
}
