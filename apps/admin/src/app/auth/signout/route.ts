import { NextResponse, type NextRequest } from 'next/server';
import { createSupabaseServerClient } from '@/lib/supabase/server';

/**
 * Sign-out is a POST so it cannot be triggered by a stray link or prefetch.
 */
export async function POST(request: NextRequest) {
    const supabase = await createSupabaseServerClient();
    // Revoke this browser's refresh token when Auth is reachable. Regardless of
    // that request's result, clear the local SSR cookies so a transient Auth
    // outage cannot leave the operator signed in on this browser.
    try {
        await supabase.auth.signOut({ scope: 'local' });
    } catch {
        // Local cookie removal below is the logout guarantee.
    }

    const projectRef = new URL(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
    ).hostname.split('.')[0];
    const authCookie = `sb-${projectRef}-auth-token`;
    const cookiesToClear = new Set(
        request.cookies
            .getAll()
            .map(({ name }) => name)
            .filter(
                (name) =>
                    name === authCookie || name.startsWith(`${authCookie}.`),
            ),
    );
    // Clear the unchunked name as well in case middleware refreshed the session
    // during this request and the incoming cookie list was stale.
    cookiesToClear.add(authCookie);

    const url = new URL('/login', request.url);
    const response = NextResponse.redirect(url, { status: 303 });
    response.headers.set('Cache-Control', 'no-store');
    for (const name of cookiesToClear) {
        response.cookies.set(name, '', {
            path: '/',
            maxAge: 0,
            expires: new Date(0),
            httpOnly: true,
            secure: url.protocol === 'https:',
            sameSite: 'lax',
        });
    }

    return response;
}
