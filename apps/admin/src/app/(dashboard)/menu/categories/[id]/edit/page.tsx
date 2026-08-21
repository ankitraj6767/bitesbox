import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { PageHeader } from '@/components/layout/page-header';
import { CategoryEditor, type CategoryEditorInitial } from '@/features/menu/category-editor';

export const metadata: Metadata = { title: 'Edit category' };

export default async function EditCategoryPage({ params }: { params: Promise<{ id: string }> }) {
    await requirePermission(PERMISSIONS.MENU_UPDATE);
    const { id } = await params;
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase
        .from('categories')
        .select('id, name, slug, short_description, description, display_order, day_part, accent_color, is_active, is_featured')
        .eq('id', id)
        .maybeSingle();
    if (error || !data) notFound();
    return (
        <>
            <PageHeader title={`Edit ${data.name}`} description="Update the category name, schedule and visibility." actions={<Link href="/menu" className="text-sm text-brand-600">Back to menu</Link>} />
            <CategoryEditor initial={data as CategoryEditorInitial} />
        </>
    );
}
