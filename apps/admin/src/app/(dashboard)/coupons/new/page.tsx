import type { Metadata } from 'next';
import Link from 'next/link';
import { requirePermission } from '@/lib/session';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { PageHeader } from '@/components/layout/page-header';
import { CouponEditor } from '@/features/coupons/coupon-editor';

export const metadata: Metadata = { title: 'New coupon' };

export default async function NewCouponPage() {
    await requirePermission(PERMISSIONS.COUPON_CREATE);
    return (
        <>
            <PageHeader title="New coupon" description="Create a server-validated code-driven offer." actions={<Link href="/coupons" className="text-sm text-brand-600">Back to coupons</Link>} />
            <CouponEditor initial={{ code: '', title: '', description: '', discount_kind: 'PERCENTAGE', discount_value: 10, min_order_amount: 0, max_discount_amount: null, starts_at: new Date().toISOString(), ends_at: null, is_visible: true, is_active: true }} />
        </>
    );
}
