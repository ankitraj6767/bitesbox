import { NextResponse, type NextRequest } from 'next/server';
import { createSupabaseServerClient } from '@/lib/supabase/server';

/**
 * Sign-out is a POST so it cannot be triggered by a stray link or prefetch.
 */
export async function POST(request: NextRequest) {
    const supabase = await createSupabaseServerClient();
    await supabase.auth.signOut();

    const url = request.nextUrl.clone();
    url.pathname = '/login';
    url.search = '';

    return NextResponse.redirect(url, { status: 303 });
}
