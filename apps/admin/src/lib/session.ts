import 'server-only';

import { cache } from 'react';
import { redirect } from 'next/navigation';
import { cookies, headers } from 'next/headers';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import type { Permission, Session } from '@bitesbox/shared-types';

/**
 * Loads identity, live permissions and branch scope for a protected request.
 *
 * `cache()` dedupes this across a single render pass, so a page and its nested
 * server components share one query. Permissions come from the database (not the
 * JWT), so revoking access takes effect on the next request.
 */
export const getSession = cache(async (): Promise<Session> => {
    const supabase = await createSupabaseServerClient();

    const { data: claimsData, error: claimsError } = await supabase.auth.getClaims();
    const claims = claimsData?.claims;

    // Middleware has just revalidated/rotated this cookie with getUser().
    // Verify the signed claims here without repeating its Auth-server lookup.
    if (claimsError || typeof claims?.sub !== 'string') return { authenticated: false };

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

    const isBackOffice = (session.roles ?? []).some(({ role }) =>
        ['OWNER', 'ADMIN', 'MANAGER', 'OPERATIONS', 'FINANCE', 'SUPPORT', 'MARKETING'].includes(role),
    );
    if (!isBackOffice) redirect('/no-access');

    const assuranceLevel = await getAssuranceLevel();
    if (assuranceLevel !== 'aal2') {
        const requestPath = (await headers()).get('x-bb-request-path');
        const nextPath = requestPath?.startsWith('/') && !requestPath.startsWith('//')
            ? requestPath
            : '/overview';
        redirect(`/mfa?next=${encodeURIComponent(nextPath)}`);
    }

    return session;
}

const getAssuranceLevel = cache(async (): Promise<string | null> => {
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    return error ? null : data.currentLevel;
});

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

/**
 * Selects a branch only from the server-resolved session scope. The cookie is a
 * navigation preference; every RPC/RLS permission check still decides access.
 */
export async function activeBranchId(session: Session): Promise<string | null> {
    const allowed = session.branches ?? [];
    const selected = (await cookies()).get('bb_active_branch')?.value;
    if (selected && allowed.some((branch) => branch.id === selected)) return selected;
    return allowed[0]?.id ?? null;
}
