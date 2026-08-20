import type { NextRequest } from 'next/server';
import { updateSession } from '@/lib/supabase/middleware';

export async function middleware(request: NextRequest) {
    return updateSession(request);
}

export const config = {
    matcher: [
        /*
         * Everything except Next internals and static assets. Keeping images out of
         * the matcher avoids a needless auth round trip per asset.
         */
        '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|avif|ico|woff2?)$).*)',
    ],
};
