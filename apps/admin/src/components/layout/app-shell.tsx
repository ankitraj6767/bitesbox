'use client';

import * as React from 'react';
import { useQuery } from '@tanstack/react-query';
import { usePathname } from 'next/navigation';
import * as Sentry from '@sentry/nextjs';
import { Sidebar, type SidebarCounts } from './sidebar';
import { Topbar } from './topbar';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import type { BranchOrderingState, Session } from '@bitesbox/shared-types';

/**
 * Client shell so the sidebar drawer, palette and live badge counts can hold
 * state. Page content itself stays server-rendered and streams into `children`.
 */
export function AppShell({
    session,
    branch,
    activeBranchId,
    children,
}: {
    session: Session;
    branch: BranchOrderingState | null;
    activeBranchId: string | null;
    children: React.ReactNode;
}) {
    const [navOpen, setNavOpen] = React.useState(false);
    const permissions = session.permissions ?? [];
    const pathname = usePathname();

    React.useEffect(() => {
        const primaryRole = session.primary_role ?? 'STAFF';
        const roleCategory = ['OWNER', 'ADMIN'].includes(primaryRole)
            ? 'admin'
            : ['FINANCE', 'SUPPORT', 'MARKETING'].includes(primaryRole)
                ? primaryRole.toLowerCase()
                : 'operations';
        Sentry.setTags({ role_category: roleCategory, route: pathname.split('/').filter(Boolean)[0] ?? 'overview' });
        return () => Sentry.setTags({ route: 'unknown' });
    }, [pathname, session.primary_role]);

    // Sidebar badges. Cheap head-only counts, refreshed on a slow interval so a
    // long-lived dashboard tab stays roughly accurate without polling hard.
    const { data: counts = {} } = useQuery<SidebarCounts>({
        queryKey: ['sidebar-counts', branch?.branch_id],
        refetchInterval: 60_000,
        staleTime: 30_000,
        queryFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const result: SidebarCounts = {};

            if (permissions.includes('order.view')) {
                let query = supabase
                    .from('orders')
                    .select('id', { count: 'exact', head: true })
                    .in('status', [
                        'ORDER_PLACED',
                        'STORE_ACCEPTED',
                        'PREPARING',
                        'READY_FOR_PICKUP',
                        'RIDER_ASSIGNED',
                        'RIDER_ARRIVED_STORE',
                        'PICKED_UP',
                        'OUT_FOR_DELIVERY',
                        'RIDER_ARRIVED_CUSTOMER',
                    ]);
                if (branch?.branch_id) query = query.eq('branch_id', branch.branch_id);
                const { count } = await query;
                result.live_orders = count ?? 0;
            }

            if (permissions.includes('refund.view')) {
                let query = supabase
                    .from('refunds')
                    .select('id, orders!inner(branch_id)', { count: 'exact', head: true })
                    .in('status', ['REQUESTED', 'APPROVAL_PENDING']);
                if (branch?.branch_id) query = query.eq('orders.branch_id', branch.branch_id);
                const { count } = await query;
                result.pending_refunds = count ?? 0;
            }

            if (permissions.includes('support.view')) {
                let query = supabase
                    .from('support_tickets')
                    .select('id', { count: 'exact', head: true })
                    .in('status', ['OPEN', 'IN_PROGRESS', 'ESCALATED']);
                if (branch?.branch_id) query = query.eq('branch_id', branch.branch_id);
                const { count } = await query;
                result.open_tickets = count ?? 0;
            }

            return result;
        },
    });

    return (
        <div className="flex min-h-dvh">
            <Sidebar
                permissions={permissions}
                counts={counts}
                branchName={branch?.branch_name ?? 'Bakhtiyarpur'}
                open={navOpen}
                onClose={() => setNavOpen(false)}
            />

            <div className="flex min-w-0 flex-1 flex-col">
                <Topbar session={session} branch={branch} activeBranchId={activeBranchId} onOpenNav={() => setNavOpen(true)} />
                <main id="main" className="min-w-0 flex-1 px-4 py-5 lg:px-6 lg:py-6">
                    {children}
                </main>
            </div>
        </div>
    );
}
