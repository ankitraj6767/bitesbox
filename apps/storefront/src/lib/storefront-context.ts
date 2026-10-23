import { cookies } from 'next/headers';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { localeFrom, type Locale } from '@/lib/site';

export interface Outlet {
    id: string;
    name: string;
    slug: string;
    city: string;
    service_mode: string;
    ordering: Record<string, unknown>;
}

interface CustomerSessionPayload {
    profile?: {
        full_name?: string | null;
        preferred_branch_id?: string | null;
        preferred_language?: 'en' | 'hi';
    } | null;
}

export async function storefrontContext() {
    const supabase = await createSupabaseServerClient();
    const [outletResult, userResult, jar] = await Promise.all([
        supabase.rpc('public_outlets'),
        supabase.auth.getUser(),
        cookies(),
    ]);
    const outlets = (outletResult.data ?? []) as unknown as Outlet[];
    const user = userResult.data.user;
    let session: CustomerSessionPayload | null = null;
    if (user) {
        const { data } = await supabase.rpc('my_session');
        session = (data as CustomerSessionPayload | null) ?? null;
    }
    const profile = session?.profile ?? null;
    const preferred = profile?.preferred_branch_id ?? null;
    const cookieBranch = jar.get('bb_customer_outlet')?.value ?? null;
    const candidate = preferred ?? cookieBranch;
    const outlet = outlets.find((item) => item.id === candidate) ?? outlets[0] ?? null;
    const localeCookie = jar.get('bb_customer_locale')?.value;
    const locale = localeFrom(profile?.preferred_language ?? localeCookie) as Locale;
    return { supabase, outlets, outlet, locale, user, profile };
}
