import type { MetadataRoute } from 'next';
import { storefrontContext } from '@/lib/storefront-context';
import { siteUrl } from '@/lib/site';

// The catalog and outlet list are live database reads. Keep this route dynamic
// so `next build` does not require a configured/hosted Supabase connection.
export const dynamic = 'force-dynamic';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
    const { supabase, outlet } = await storefrontContext();
    const pages: MetadataRoute.Sitemap = [
        { url: `${siteUrl}/`, changeFrequency: 'daily', priority: 1 },
        { url: `${siteUrl}/menu`, changeFrequency: 'daily', priority: 0.9 },
        { url: `${siteUrl}/help`, changeFrequency: 'monthly', priority: 0.3 },
    ];
    if (!outlet) return pages;
    const { data } = await supabase.rpc('localized_menu_catalog', { p_branch_id: outlet.id, p_locale: 'en' });
    const catalog = data as { products?: Array<{ slug?: string; is_available?: boolean }>; categories?: Array<{ slug?: string; is_active?: boolean }> } | null;
    for (const product of catalog?.products ?? []) {
        if (product.slug && product.is_available !== false) pages.push({ url: `${siteUrl}/menu/${encodeURIComponent(product.slug)}`, changeFrequency: 'weekly', priority: 0.7 });
    }
    return pages;
}
