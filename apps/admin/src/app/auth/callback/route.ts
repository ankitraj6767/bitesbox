import { NextResponse, type NextRequest } from 'next/server';
import { createSupabaseServerClient } from '@/lib/supabase/server';

/**
 * Exchanges an auth code for a session (invite links, password recovery,
 * magic links). Only relative `next` paths are honoured, so the callback cannot
 * be used as an open redirect.
 */
export async function GET(request: NextRequest) {
    const { searchParams, origin } = request.nextUrl;
    const code = searchParams.get('code');
    const nextParam = searchParams.get('next');
    const next = nextParam && nextParam.startsWith('/') ? nextParam : '/overview';

    if (!code) {
        return NextResponse.redirect(`${origin}/login?error=Missing%20authorisation%20code`);
    }

    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (error) {
        return NextResponse.redirect(
            `${origin}/login?error=${encodeURIComponent('That sign-in link is no longer valid.')}`,
        );
    }

    return NextResponse.redirect(`${origin}${next}`);
}
