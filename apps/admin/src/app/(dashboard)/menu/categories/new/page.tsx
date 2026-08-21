import type { Metadata } from 'next';
import Link from 'next/link';
import { requirePermission } from '@/lib/session';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { PageHeader } from '@/components/layout/page-header';
import { CategoryEditor } from '@/features/menu/category-editor';

export const metadata: Metadata = { title: 'New category' };

export default async function NewCategoryPage() {
    await requirePermission(PERMISSIONS.MENU_CREATE);
    return (
        <>
            <PageHeader title="New category" description="Create a menu category for customer browsing." actions={<Link href="/menu" className="text-sm text-brand-600">Back to menu</Link>} />
            <CategoryEditor initial={{ name: '', slug: '', short_description: '', description: '', display_order: 0, day_part: 'ALL_DAY', accent_color: '', is_active: true, is_featured: false }} />
        </>
    );
}
