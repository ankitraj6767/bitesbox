import 'server-only';
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

export async function createSupabaseServerClient() {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !key) throw new Error('Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.');
    const jar = await cookies();
    return createServerClient(url, key, {
        cookies: {
            getAll: () => jar.getAll(),
            setAll: (values) => {
                try {
                    values.forEach(({ name, value, options }) => jar.set(name, value, options));
                } catch {
                    // Server Components cannot mutate cookies. Middleware refreshes sessions.
                }
            },
        },
    });
}
