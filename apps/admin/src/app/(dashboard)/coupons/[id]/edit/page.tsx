import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { PageHeader } from '@/components/layout/page-header';
import { CouponEditor, type CouponEditorInitial } from '@/features/coupons/coupon-editor';

export const metadata: Metadata = { title: 'Edit coupon' };

export default async function EditCouponPage({ params }: { params: Promise<{ id: string }> }) {
    await requirePermission(PERMISSIONS.COUPON_UPDATE);
    const { id } = await params;
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase.from('coupons').select('id, code, title, description, discount_kind, discount_value, min_order_amount, max_discount_amount, starts_at, ends_at, is_visible, is_active').eq('id', id).maybeSingle();
    if (error || !data) notFound();
    return (
        <>
            <PageHeader title={`Edit ${data.code}`} description="Update the coupon rules and customer visibility." actions={<Link href="/coupons" className="text-sm text-brand-600">Back to coupons</Link>} />
            <CouponEditor initial={data as CouponEditorInitial} />
        </>
    );
}
