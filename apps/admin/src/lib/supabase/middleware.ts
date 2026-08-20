import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import type { Database } from '@bitesbox/shared-types';

/** Routes reachable without a session. */
const PUBLIC_PATHS = ['/login', '/auth/callback', '/auth/signout', '/no-access'];

/**
 * Refreshes the Supabase session on every request and gates the dashboard.
 *
 * Two checks happen here:
 *   1. a valid session exists
 *   2. the account holds at least one back-office role
 *
 * Neither is the security boundary — RLS is. This only avoids rendering a
 * dashboard the user cannot use.
 */
export async function updateSession(request: NextRequest) {
    let response = NextResponse.next({ request });

    const supabase = createServerClient<Database>(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        {
            cookies: {
                getAll() {
                    return request.cookies.getAll();
                },
                setAll(cookiesToSet) {
                    cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
                    response = NextResponse.next({ request });
                    cookiesToSet.forEach(({ name, value, options }) =>
                        response.cookies.set(name, value, options),
                    );
                },
            },
        },
    );

    // getUser() (not getSession()) revalidates the JWT against the auth server.
    const {
        data: { user },
    } = await supabase.auth.getUser();

    const { pathname } = request.nextUrl;
    const isPublic = PUBLIC_PATHS.some((path) => pathname === path || pathname.startsWith(`${path}/`));

    if (!user && !isPublic) {
        const loginUrl = request.nextUrl.clone();
        loginUrl.pathname = '/login';
        loginUrl.searchParams.set('next', pathname);
        return NextResponse.redirect(loginUrl);
    }

    if (user && (pathname === '/login' || pathname === '/')) {
        const target = request.nextUrl.clone();
        target.pathname = pathname === '/' ? '/overview' : '/overview';
        target.search = '';
        return NextResponse.redirect(target);
    }

    return response;
}
