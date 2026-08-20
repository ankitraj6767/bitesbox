import 'server-only';

import { cache } from 'react';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import type { Permission, Session } from '@bitesbox/shared-types';

/**
 * Loads identity, live permissions and branch scope in one round trip.
 *
 * `cache()` dedupes this across a single render pass, so a page and its nested
 * server components share one query. Permissions come from the database (not the
 * JWT), so revoking access takes effect on the next request.
 */
export const getSession = cache(async (): Promise<Session> => {
    const supabase = await createSupabaseServerClient();

    const {
        data: { user },
    } = await supabase.auth.getUser();

    if (!user) return { authenticated: false };

    const { data, error } = await supabase.rpc('my_session');

    if (error || !data) {
        return { authenticated: false };
    }

    return data as unknown as Session;
});

/** Session or redirect to login. Use at the top of every protected page. */
export async function requireSession(): Promise<Session> {
    const session = await getSession();

    if (!session.authenticated) {
        redirect('/login');
    }

    if (session.account_active === false) {
        redirect('/no-access?reason=blocked');
    }

    return session;
}

/**
 * Session plus a permission check. Redirects rather than throwing, so an
 * operator who follows a stale link gets an explanation instead of a crash.
 */
export async function requirePermission(permission: Permission | Permission[]): Promise<Session> {
    const session = await requireSession();
    const required = Array.isArray(permission) ? permission : [permission];
    const held = new Set(session.permissions ?? []);

    if (!required.some((code) => held.has(code))) {
        redirect(`/no-access?permission=${encodeURIComponent(required[0]!)}`);
    }

    return session;
}

export function hasPermission(session: Session, permission: Permission | Permission[]): boolean {
    const required = Array.isArray(permission) ? permission : [permission];
    const held = new Set(session.permissions ?? []);
    return required.some((code) => held.has(code));
}

/** Branch the operator is acting on. Single branch today, scoped grants later. */
export function activeBranchId(session: Session): string | null {
    return session.branches?.[0]?.id ?? null;
}
