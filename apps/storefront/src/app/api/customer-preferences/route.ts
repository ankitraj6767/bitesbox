import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { hasSameSiteOrigin } from '@/lib/site';

export async function POST(request: Request) {
    if (!hasSameSiteOrigin(request)) return NextResponse.json({ error: 'Invalid origin.' }, { status: 403 });
    const body = await request.json().catch(() => null) as { branchId?: unknown; locale?: unknown } | null;
    const jar = await cookies();
    if (typeof body?.branchId === 'string' && /^[0-9a-f-]{36}$/i.test(body.branchId)) {
        jar.set('bb_customer_outlet', body.branchId, {
            httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production',
            path: '/', maxAge: 60 * 60 * 24 * 180,
        });
    }
    if (body?.locale === 'en' || body?.locale === 'hi') {
        jar.set('bb_customer_locale', body.locale, {
            httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production',
            path: '/', maxAge: 60 * 60 * 24 * 365,
        });
    }
    return NextResponse.json({ ok: true });
}
