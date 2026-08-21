import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { PageHeader } from '@/components/layout/page-header';
import { PromotionEditor, type PromotionEditorInitial } from '@/features/promotions/promotion-editor';

export const metadata: Metadata = { title: 'Edit promotion' };

export default async function EditPromotionPage({ params }: { params: Promise<{ id: string }> }) {
    await requirePermission(PERMISSIONS.PROMOTION_MANAGE);
    const { id } = await params;
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase
        .from('promotions')
        .select('id, name, headline, description, badge_text, trigger, discount_kind, discount_value, max_discount_amount, min_order_amount, priority, stacks_with_coupon, starts_at, ends_at')
        .eq('id', id)
        .maybeSingle();
    if (error || !data) notFound();
    return (
        <>
            <PageHeader title={`Edit ${data.name}`} description="Update the promotion rules and customer-facing copy." actions={<Link href="/promotions" className="text-sm text-brand-600">Back to promotions</Link>} />
            <PromotionEditor initial={data as PromotionEditorInitial} />
        </>
    );
}
