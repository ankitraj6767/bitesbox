import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import type { Database } from '@bitesbox/shared-types';
import { hasBackOfficeRole, safeAdminNextPath, staffNeedsMfa } from '@/lib/mfa-policy';

/** Routes reachable without a session. */
const PUBLIC_PATHS = ['/login', '/auth/callback', '/auth/signout', '/no-access'];

/**
 * Refreshes the Supabase session on every request and gates the dashboard.
 *
 * Middleware refreshes/revalidates the cookie session and handles login,
 * MFA-entry and root redirects. Dashboard routes resolve live roles, permissions
 * and AAL in their server pages, so duplicating those calls here would block
 * every client navigation twice.
 *
 * Neither is the security boundary — RLS is. This only avoids rendering a
 * dashboard the user cannot use.
 */
export async function updateSession(request: NextRequest) {
    // Server-side permission redirects use this as a return path only. Replace
    // caller-supplied values so it cannot become an open redirect.
    request.headers.set('x-bb-request-path', `${request.nextUrl.pathname}${request.nextUrl.search}`);
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

    if (user && (pathname === '/login' || pathname === '/' || pathname === '/mfa')) {
        const { data: session } = await supabase.rpc('my_session');
        const roles = (session as { roles?: Array<{ role?: string }> } | null)?.roles ?? [];
        const backOffice = hasBackOfficeRole(roles.map((grant) => grant.role ?? ''));

        if (!backOffice) {
            const target = request.nextUrl.clone();
            target.pathname = '/no-access';
            target.search = '';
            return NextResponse.redirect(target);
        }

        const { data: assurance } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
        const nextPath = safeAdminNextPath(request.nextUrl.searchParams.get('next')) ??
            (pathname !== '/login' && pathname !== '/' && pathname !== '/mfa'
                ? `${pathname}${request.nextUrl.search}`
                : '/overview');

        if (staffNeedsMfa(roles.map((grant) => grant.role ?? ''), assurance?.currentLevel) && pathname !== '/mfa') {
            const target = request.nextUrl.clone();
            target.pathname = '/mfa';
            target.search = '';
            target.searchParams.set('next', nextPath);
            return NextResponse.redirect(target);
        }

        if (pathname === '/login' || pathname === '/') {
            const target = request.nextUrl.clone();
            target.pathname = staffNeedsMfa(roles.map((grant) => grant.role ?? ''), assurance?.currentLevel)
                ? '/mfa'
                : nextPath;
            target.search = '';
            if (staffNeedsMfa(roles.map((grant) => grant.role ?? ''), assurance?.currentLevel)) {
                target.searchParams.set('next', nextPath);
            }
            return NextResponse.redirect(target);
        }
    }

    return response;
}
