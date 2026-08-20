import 'server-only';

import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import type { Database } from '@bitesbox/shared-types';

/**
 * Request-scoped Supabase client for Server Components, Server Actions and
 * Route Handlers. Uses the publishable key and the caller's session cookie, so
 * RLS applies exactly as it would for the browser.
 */
export async function createSupabaseServerClient() {
    const cookieStore = await cookies();

    return createServerClient<Database>(
        requiredEnv('NEXT_PUBLIC_SUPABASE_URL'),
        requiredEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
        {
            cookies: {
                getAll() {
                    return cookieStore.getAll();
                },
                setAll(cookiesToSet) {
                    try {
                        cookiesToSet.forEach(({ name, value, options }) => {
                            cookieStore.set(name, value, options);
                        });
                    } catch {
                        // Called from a Server Component render, where cookies are readonly.
                        // Middleware refreshes the session, so this is safe to ignore.
                    }
                },
            },
        },
    );
}

/**
 * Service-role client. NEVER import this from a Client Component.
 *
 * Only used for the few operations that must bypass RLS: reading secret
 * settings, and invoking Edge Functions that require the service key. Every
 * caller must have already verified the user's permissions.
 */
export function createSupabaseAdminClient() {
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!serviceKey) {
        throw new Error(
            'SUPABASE_SERVICE_ROLE_KEY is not configured. Set it in apps/admin/.env.local (server only).',
        );
    }

    return createServerClient<Database>(requiredEnv('NEXT_PUBLIC_SUPABASE_URL'), serviceKey, {
        cookies: {
            getAll: () => [],
            setAll: () => { },
        },
        auth: { persistSession: false, autoRefreshToken: false },
    });
}

function requiredEnv(name: string): string {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Missing required environment variable ${name}. See .env.example.`);
    }
    return value;
}
