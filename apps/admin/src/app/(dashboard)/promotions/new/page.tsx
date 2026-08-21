import type { Metadata } from 'next';
import Link from 'next/link';
import { requirePermission } from '@/lib/session';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { PageHeader } from '@/components/layout/page-header';
import { PromotionEditor } from '@/features/promotions/promotion-editor';

export const metadata: Metadata = { title: 'New promotion' };

export default async function NewPromotionPage() {
    await requirePermission(PERMISSIONS.PROMOTION_MANAGE);
    return (
        <>
            <PageHeader title="New promotion" description="Create an automatic offer with server-validated rules." actions={<Link href="/promotions" className="text-sm text-brand-600">Back to promotions</Link>} />
            <PromotionEditor initial={{ name: '', headline: '', description: '', badge_text: '', trigger: 'AUTOMATIC', discount_kind: 'PERCENTAGE', discount_value: 10, max_discount_amount: null, min_order_amount: 0, priority: 100, stacks_with_coupon: false, starts_at: new Date().toISOString(), ends_at: null }} />
        </>
    );
}
