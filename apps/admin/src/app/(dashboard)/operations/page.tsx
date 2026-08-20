import type { Metadata } from 'next';
import { activeBranchId, hasPermission, requirePermission } from '@/lib/session';
import { PageHeader } from '@/components/layout/page-header';
import { OperationsBoard } from '@/features/operations/operations-board';
import { PERMISSIONS } from '@bitesbox/shared-types';

export const metadata: Metadata = { title: 'Live operations' };

export default async function OperationsPage() {
    const session = await requirePermission(PERMISSIONS.ORDER_VIEW);

    return (
        <>
            <PageHeader
                title="Live operations"
                description="Every order in flight, the alerts that need a decision, and who is free to deliver."
            />

            <OperationsBoard
                branchId={activeBranchId(session)}
                canAssign={hasPermission(session, PERMISSIONS.DELIVERY_ASSIGN)}
                canOperate={hasPermission(session, [
                    PERMISSIONS.ORDER_ACCEPT,
                    PERMISSIONS.ORDER_PREPARE,
                    PERMISSIONS.ORDER_READY,
                ])}
                canCancel={hasPermission(session, [PERMISSIONS.ORDER_CANCEL, PERMISSIONS.ORDER_REJECT])}
            />
        </>
    );
}
