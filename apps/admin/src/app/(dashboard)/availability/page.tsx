import type { Metadata } from 'next';
import { activeBranchId, hasPermission, requirePermission } from '@/lib/session';
import { PageHeader } from '@/components/layout/page-header';
import { AvailabilityGrid } from '@/features/menu/availability-grid';
import { PERMISSIONS } from '@bitesbox/shared-types';

export const metadata: Metadata = { title: 'Availability' };

export default async function AvailabilityPage() {
    const session = await requirePermission([
        PERMISSIONS.MENU_AVAILABILITY,
        PERMISSIONS.INVENTORY_VIEW,
        PERMISSIONS.MENU_VIEW,
    ]);

    return (
        <>
            <PageHeader
                title="Availability"
                description="Mark dishes out of stock or pause them for a while. Customers see the change immediately."
            />

            <AvailabilityGrid
                branchId={activeBranchId(session)}
                canToggle={hasPermission(session, PERMISSIONS.MENU_AVAILABILITY)}
            />
        </>
    );
}
