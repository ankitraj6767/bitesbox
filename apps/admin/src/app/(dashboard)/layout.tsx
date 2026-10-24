import { Suspense } from 'react';
import { requireSession, activeBranchId } from '@/lib/session';
import { AppShell } from '@/components/layout/app-shell';
import { DashboardShellLoading } from '@/components/layout/dashboard-shell-loading';

async function AuthenticatedDashboard({ children }: { children: React.ReactNode }) {
    const session = await requireSession();
    const selectedBranchId = await activeBranchId(session);

    return (
        <AppShell session={session} activeBranchId={selectedBranchId}>
            {children}
        </AppShell>
    );
}

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
    return (
        <Suspense fallback={<DashboardShellLoading />}>
            <AuthenticatedDashboard>{children}</AuthenticatedDashboard>
        </Suspense>
    );
}
