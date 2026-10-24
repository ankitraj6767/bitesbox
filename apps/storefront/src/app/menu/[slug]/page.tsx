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
    food_type?: string; spice_level?: string; allergens?: string[]; dietary_tags?: string[];
    preparation_minutes?: number | null; serves_count?: number | null; calories?: number | null;
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
    const foodTypeLabel = product.food_type === 'NON_VEG' ? t.nonVeg : product.food_type === 'EGG' ? t.egg : product.food_type === 'VEGAN' ? t.vegan : t.vegetarian;
    const spiceLabels = { NONE: t.noSpice, MILD: t.mild, MEDIUM: t.medium, HOT: t.hot, EXTRA_HOT: t.extraHot };
    const spiceLabel = product.spice_level ? spiceLabels[product.spice_level as keyof typeof spiceLabels] : null;
    const prepTimeLabel = product.preparation_minutes == null ? null : locale === 'hi' ? `${product.preparation_minutes} मिनट` : `${product.preparation_minutes} min`;
    const portionLabel = product.serves_count == null ? null : locale === 'hi'
        ? product.serves_count === 1 ? '1 व्यक्ति के लिए' : `${product.serves_count} लोगों के लिए`
        : `Serves ${product.serves_count}`;
    const calorieLabel = product.calories == null ? null : locale === 'hi' ? `${product.calories} किलोकैलोरी` : `${product.calories} kcal`;
    const dietaryLabels = (product.dietary_tags ?? []).map((tag) => {
        if (tag === 'vegetarian') return t.vegetarian;
        if (tag === 'vegan') return t.vegan;
        if (tag === 'high-protein') return locale === 'hi' ? 'प्रोटीन से भरपूर' : 'High protein';
        return tag.replaceAll('-', ' ');
    });
    const allergenNames: Record<string, { en: string; hi: string }> = {
        dairy: { en: 'Dairy', hi: 'दूध से बने पदार्थ' }, egg: { en: 'Egg', hi: 'अंडा' },
        gluten: { en: 'Gluten', hi: 'ग्लूटेन' }, nuts: { en: 'Tree nuts', hi: 'मेवे' },
        sesame: { en: 'Sesame', hi: 'तिल' }, soy: { en: 'Soy', hi: 'सोया' }, fish: { en: 'Fish', hi: 'मछली' },
    };
    const allergenLabels = (product.allergens ?? []).map((item) => allergenNames[item]?.[locale] ?? item);
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
                    <div className="dish-facts" aria-label={locale === 'hi' ? 'व्यंजन की जानकारी' : 'Dish details'}>
                        <span className="dish-fact-type">{foodTypeLabel}</span>
                        {prepTimeLabel ? <span className="dish-fact"><small>{t.prepTime}</small><strong>{prepTimeLabel}</strong></span> : null}
                        {portionLabel ? <span className="dish-fact"><small>{t.servesLabel}</small><strong>{portionLabel}</strong></span> : null}
                        {calorieLabel ? <span className="dish-fact"><small>{t.calorieEstimate}</small><strong>{calorieLabel}</strong></span> : null}
                        {spiceLabel ? <span className="dish-fact"><small>{t.spiceLevel}</small><strong>{spiceLabel}</strong></span> : null}
                    </div>
                    {dietaryLabels.length ? <div className="dish-tags" aria-label={t.dietaryInfo}>{dietaryLabels.map((tag) => <span className="dish-tag" key={tag}>{tag}</span>)}</div> : null}
                    {allergenLabels.length ? <p className="allergen-note"><strong>{t.containsAllergens}:</strong> {allergenLabels.join(', ')}</p> : null}
                    {product.base_price ? <p className="product-price">{currency.format(Number(product.base_price))}</p> : null}
                    <ProductDetailActions product={product as never} branchId={outlet.id} locale={locale} signedIn={Boolean(user)} />
                </div>
            </section>
            {product.description ? <section className="description-block"><h2>{locale === 'hi' ? 'इस व्यंजन के बारे में' : 'About this dish'}</h2><p>{product.description}</p></section> : null}
        </main>
    </>;
}
