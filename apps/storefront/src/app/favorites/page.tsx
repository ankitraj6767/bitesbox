import type { Metadata } from 'next';
import Link from 'next/link';
import { ProductTile, type Product } from '@/components/product-tile';
import { StorefrontHeader } from '@/components/storefront-header';
import { storefrontContext } from '@/lib/storefront-context';
import { messages } from '@/lib/site';

export const metadata: Metadata = { title: 'Favorites', robots: { index: false, follow: false } };
export const dynamic = 'force-dynamic';

export default async function FavoritesPage() {
    const context = await storefrontContext();
    const t = messages[context.locale];
    const rowsResult = context.user ? await context.supabase.rpc('my_favorites', {
        p_branch_id: context.outlet?.id, p_locale: context.locale,
    }) : { data: null };
    const products = (rowsResult.data ?? []) as unknown as Array<Product & { is_active: boolean }>;
    return <>
        <StorefrontHeader outlets={context.outlets} outletId={context.outlet?.id ?? ''} outletName={context.outlet?.name ?? ''} locale={context.locale} userId={context.user?.id ?? null} />
        <main className="page">
            <h1>{t.favorites}</h1>
            {!context.user ? <section className="panel"><p>{t.signInRequired}</p><Link className="primary-button" href={`/sign-in?next=${encodeURIComponent('/favorites')}`}>{t.signIn}</Link></section> : null}
            {context.user && products.length === 0 ? <section className="panel"><p>{t.noProducts}</p><Link href="/menu" className="primary-button">{t.browseMenu}</Link></section> : null}
            {products.length ? <div className="product-grid">{products.map((product) => <ProductTile key={product.id} product={{ ...product, is_available: product.is_active && product.is_available }} favorite locale={context.locale} />)}</div> : null}
        </main>
    </>;
}
