import type { Metadata } from 'next';
import { CatalogScreen } from '@/components/catalog-screen';
import { siteUrl } from '@/lib/site';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = {
    title: 'Bites Box | Bihar favourites, made for your table',
    description: 'Explore slow-dum biryani, tandoor favourites and comforting Bihari dishes from Bites Box.',
    alternates: { canonical: siteUrl },
};

export default async function HomePage({ searchParams }: { searchParams: Promise<{ q?: string; category?: string }> }) {
    const params = await searchParams;
    return <CatalogScreen query={params.q ?? ''} categoryId={params.category} />;
}
