import type { Metadata } from 'next';
import { CatalogScreen } from '@/components/catalog-screen';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { title: 'Menu' };

export default async function MenuPage({ searchParams }: { searchParams: Promise<{ q?: string; category?: string }> }) {
    const params = await searchParams;
    return <CatalogScreen query={params.q ?? ''} categoryId={params.category} />;
}
