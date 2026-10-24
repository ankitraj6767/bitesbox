import Image from 'next/image';
import Link from 'next/link';
import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { cache } from 'react';
import { ProductDetailActions } from '@/components/product-detail-actions';
import { FavoriteToggle } from '@/components/favorite-toggle';
import { StorefrontHeader } from '@/components/storefront-header';
import { storefrontContext } from '@/lib/storefront-context';
import { messages, storageUrl } from '@/lib/site';
import { StorefrontEvent } from '@/components/storefront-event';
import { getCachedPublicProduct } from '@/lib/public-storefront-cache';

interface ProductDetail {
    id: string; name: string; slug: string; description?: string | null; short_description?: string | null;
    meta_title?: string | null; meta_description?: string | null; base_price: number; thumbnail_path?: string | null;
    hero_image_path?: string | null; is_available: boolean; variants?: unknown[]; images?: Array<{ storage_path?: string | null; alt_text?: string | null }>;
}

const loadProduct = cache(async (slug: string) => {
    const context = await storefrontContext();
    if (!context.outlet) return { context, product: null, favorite: false };
    const [productResult, favoritesResult] = await Promise.all([
        getCachedPublicProduct(slug, context.outlet.id, context.locale).catch(() => null),
        context.user
            ? context.supabase.rpc('my_favorites', { p_branch_id: context.outlet.id, p_locale: context.locale })
            : Promise.resolve({ data: null, error: null }),
    ]);
    const product = productResult as unknown as ProductDetail | null;
    const favorite = product
        ? ((favoritesResult.data ?? []) as Array<{ id?: string }>).some((row) => row.id === product.id)
        : false;
    return { context, product, favorite };
});

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
    const { slug } = await params;
    const { product } = await loadProduct(slug);
    if (!product) return { title: 'Dish unavailable' };
    return {
        title: product.meta_title ?? product.name,
        description: product.meta_description ?? product.short_description ?? product.description ?? 'Explore this dish from Bites Box.',
        alternates: { canonical: `/menu/${encodeURIComponent(product.slug)}` },
        openGraph: { title: product.meta_title ?? product.name, description: product.meta_description ?? product.short_description ?? undefined, type: 'website' },
    };
}

export const dynamic = 'force-dynamic';

export default async function ProductPage({ params }: { params: Promise<{ slug: string }> }) {
    const { slug } = await params;
    const { context, product, favorite } = await loadProduct(slug);
    if (!product || !context.outlet) notFound();
    const { outlets, outlet, locale, user } = context;
    const t = messages[locale];
    const image = storageUrl(product.hero_image_path ?? product.thumbnail_path ?? product.images?.[0]?.storage_path);
    const currency = new Intl.NumberFormat(locale === 'hi' ? 'hi-IN' : 'en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 });
    const structuredData = {
        '@context': 'https://schema.org', '@type': 'Product', name: product.name,
        description: product.meta_description ?? product.short_description ?? undefined,
        image: image ? [image] : undefined,
        offers: { '@type': 'Offer', priceCurrency: 'INR', price: Number(product.base_price).toFixed(2), availability: product.is_available ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock', url: `${process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3001'}/menu/${encodeURIComponent(product.slug)}` },
    };
    return <>
        <StorefrontEvent name="PRODUCT_VIEW" branchId={outlet.id} productId={product.id} />
        <StorefrontHeader outlets={outlets} outletId={outlet.id} outletName={outlet.name} locale={locale} userId={user?.id ?? null} />
        <main className="page">
            <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData).replace(/</g, '\\u003c') }} />
            <nav aria-label={locale === 'hi' ? 'ब्रेडक्रम्ब' : 'Breadcrumb'} className="breadcrumb"><Link href="/">{t.home}</Link> / <Link href="/menu">{t.menu}</Link> / <span>{product.name}</span></nav>
            <section className="two-column product-detail">
                <div className="detail-image">
                    {image ? <Image src={image} alt={product.name} fill priority sizes="(max-width:800px) 100vw, 55vw" /> : <div className="detail-placeholder" aria-hidden>🍽️</div>}
                </div>
                <div>
                    <div className="section-heading detail-heading"><div><p className="eyebrow">{product.is_available ? t.available : t.unavailable}</p><h1>{product.name}</h1></div>
                        <FavoriteToggle productId={product.id} initial={favorite} label={favorite ? (locale === 'hi' ? 'पसंदीदा से हटाएँ' : 'Remove from favorites') : (locale === 'hi' ? 'पसंदीदा में सहेजें' : 'Save to favorites')} />
                    </div>
                    <p className="muted">{product.short_description ?? product.description}</p>
                    {product.base_price ? <p className="product-price">{currency.format(Number(product.base_price))}</p> : null}
                    <ProductDetailActions product={product as never} branchId={outlet.id} locale={locale} signedIn={Boolean(user)} />
                </div>
            </section>
            {product.description ? <section className="description-block"><h2>{locale === 'hi' ? 'इस व्यंजन के बारे में' : 'About this dish'}</h2><p>{product.description}</p></section> : null}
        </main>
    </>;
}
