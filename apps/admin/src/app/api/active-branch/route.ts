import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { getSession } from '@/lib/session';

export async function POST(request: Request) {
    const session = await getSession();
    if (!session.authenticated || session.account_active === false) {
        return NextResponse.json({ error: 'Sign in to select an outlet.' }, { status: 401 });
    }

    let branchId: unknown;
    try {
        ({ branchId } = await request.json());
    } catch {
        return NextResponse.json({ error: 'Invalid branch selection.' }, { status: 400 });
    }

    if (typeof branchId !== 'string' || !(session.branches ?? []).some((branch) => branch.id === branchId)) {
        return NextResponse.json({ error: 'This outlet is outside your authorized branch scope.' }, { status: 403 });
    }

    const jar = await cookies();
    jar.set('bb_active_branch', branchId, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: 60 * 60 * 24 * 30,
    });
    return NextResponse.json({ ok: true });
}
