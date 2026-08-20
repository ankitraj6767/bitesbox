import { requireSession, activeBranchId } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { AppShell } from '@/components/layout/app-shell';
import type { BranchOrderingState } from '@bitesbox/shared-types';

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
    const session = await requireSession();
    const supabase = await createSupabaseServerClient();

    const { data } = await supabase.rpc('branch_ordering_state', {
        p_branch_id: activeBranchId(session) ?? undefined,
    });

    const branch = (data as unknown as BranchOrderingState | null) ?? null;

    return (
        <AppShell session={session} branch={branch}>
            {children}
        </AppShell>
    );
}
