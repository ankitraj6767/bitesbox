import { NextResponse, type NextRequest } from 'next/server';
import { createServerClient } from '@supabase/ssr';

export async function middleware(request: NextRequest) {
    let response = NextResponse.next({ request });
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !key) return response;

    const pathname = request.nextUrl.pathname;
    const isPublicPage = pathname === '/' || pathname === '/menu' || pathname === '/offers' || pathname === '/help' || /^\/menu\/[^/]+$/.test(pathname);
    const isAnonymousDocument = request.method === 'GET'
        && request.headers.get('rsc') !== '1'
        && request.headers.get('accept')?.includes('text/html') === true
        && request.cookies.getAll().length === 0
        && request.nextUrl.search === ''
        && isPublicPage;
    if (isAnonymousDocument) {
        // Only cache the cookie-free public document shell. Customer preferences
        // and Supabase sessions always bypass this shared cache; mutations and
        // order/cart quotes remain dynamic and server-authoritative.
        response.headers.set('CDN-Cache-Control', 'public, s-maxage=10, stale-while-revalidate=20');
    }

    // Anonymous storefront reads do not need an Auth server round trip. The
    // browser client stores SSR sessions under this project-scoped cookie name.
    // Skip refresh work entirely when it is absent (the common first-visit case).
    const projectRef = new URL(url).hostname.split('.')[0];
    const authCookie = `sb-${projectRef}-auth-token`;
    const hasAuthCookie = request.cookies.getAll().some(({ name }) =>
        name === authCookie || name.startsWith(`${authCookie}.`),
    );
    if (!hasAuthCookie) return response;

    const supabase = createServerClient(url, key, {
        cookies: {
            getAll: () => request.cookies.getAll(),
            setAll(values) {
                values.forEach(({ name, value }) => request.cookies.set(name, value));
                response = NextResponse.next({ request });
                values.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
            },
        },
    });

    // Refresh and validate signed-in customer sessions normally. Anonymous
    // traffic took the fast path above and never reaches the Auth service.
    await supabase.auth.getUser();
    return response;
}

export const config = { matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'] };
