import { requireSession, activeBranchId } from '@/lib/session';
import { AppShell } from '@/components/layout/app-shell';

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
    const session = await requireSession();
    const selectedBranchId = await activeBranchId(session);

    return (
        <AppShell session={session} activeBranchId={selectedBranchId}>
            {children}
        </AppShell>
    );
}
