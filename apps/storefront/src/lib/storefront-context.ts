import { cache } from 'react';
import { cookies } from 'next/headers';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { localeFrom, type Locale } from '@/lib/site';
import { getCachedPublicOutlets } from '@/lib/public-storefront-cache';

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

export const storefrontContext = cache(async function storefrontContext() {
    const supabase = await createSupabaseServerClient();
    const [outletsResult, claimsResult, jar] = await Promise.all([
        getCachedPublicOutlets().catch(() => []),
        supabase.auth.getClaims(),
        cookies(),
    ]);
    const outlets = (outletsResult ?? []) as unknown as Outlet[];
    // `getClaims` verifies the signed access token and avoids a redundant
    // `/auth/v1/user` request after middleware has refreshed the cookie. Fall
    // back to Auth's server-side user endpoint when claims cannot be verified
    // (including older sessions and deterministic auth providers without JWKS).
    let userId = typeof claimsResult.data?.claims.sub === 'string'
        ? claimsResult.data.claims.sub
        : null;
    if (!userId) {
        const { data: userResult } = await supabase.auth.getUser();
        userId = userResult.user?.id ?? null;
    }
    const user = userId ? { id: userId } : null;
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
});
