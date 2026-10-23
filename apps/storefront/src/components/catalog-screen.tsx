import Link from 'next/link';
import { StorefrontHeader } from '@/components/storefront-header';
import { ProductTile, type Product } from '@/components/product-tile';
import { storefrontContext } from '@/lib/storefront-context';
import { messages } from '@/lib/site';
import { StorefrontEvent } from '@/components/storefront-event';

export async function CatalogScreen({ query = '', categoryId }: { query?: string; categoryId?: string }) {
    const context = await storefrontContext();
    const { supabase, outlets, outlet, locale, user } = context;
    const t = messages[locale];
    const catalogResult = outlet
        ? query.trim()
            ? await supabase.rpc('localized_search_menu', { p_query: query.trim(), p_branch_id: outlet.id, p_locale: locale, p_limit: 50 })
            : await supabase.rpc('localized_menu_catalog', { p_branch_id: outlet.id, p_locale: locale })
        : { data: null, error: null };
    const catalog = catalogResult.data as { branch?: Record<string, unknown>; categories?: Array<Record<string, unknown>>; products?: Product[] } | null;
    const categories = catalog?.categories ?? [];
    const products = (catalog?.products ?? []).filter((product) => !categoryId || String(product.category_id) === categoryId);
    let favoriteIds = new Set<string>();
    if (user) {
        const favorites = await supabase.rpc('my_favorites', { p_branch_id: outlet?.id, p_locale: locale });
        const rows = favorites.data as Array<{ id?: string }> | null;
        favoriteIds = new Set((rows ?? []).map((row) => row.id).filter((id): id is string => Boolean(id)));
    }
    const ordering = (catalog?.branch ?? outlet?.ordering ?? {}) as Record<string, unknown>;
    const open = ordering.accepting_orders === true;

    return (
        <>
            <StorefrontEvent name={query.trim() ? 'SEARCH' : 'MENU_VIEW'} branchId={outlet?.id} />
            <StorefrontHeader outlets={outlets} outletId={outlet?.id ?? ''} outletName={outlet?.name ?? ''} locale={locale} userId={user?.id ?? null} />
            <main className="page">
                <section className="hero" aria-labelledby="hero-title">
                    <div className="eyebrow">Bites Box · {t.tagline}</div>
                    <h1 id="hero-title">{t.heroTitle}</h1>
                    <p className="muted">{t.heroDescription}</p>
                    {outlet ? <div className="status"><span className={`dot ${open ? '' : 'closed'}`} />{outlet.name} · {open ? t.outletOpen : t.outletClosed}</div> : null}
                    {outlet && !open ? <p className="status-message">{String(ordering.status_note ?? t.closedReason)}</p> : null}
                    {!outlet ? <p className="status-message">{t.noOutlets}</p> : null}
                </section>

                <section aria-labelledby="browse-heading">
                    <div className="section-heading"><h2 id="browse-heading">{query ? `${t.resultsFor}: ${query}` : t.browseMenu}</h2><p className="muted">{products.length} {t.dishes}</p></div>
                    {categories.length ? <nav className="categories" aria-label="Menu categories">
                        <Link className={`category-chip ${!categoryId ? 'active' : ''}`} href="/menu">{t.all}</Link>
                        {categories.map((category) => <Link key={String(category['id'])} className={`category-chip ${categoryId === category['id'] ? 'active' : ''}`} href={`/menu?category=${category['id']}`}>{String(category['name'])}</Link>)}
                    </nav> : null}
                    {catalogResult.error ? <div className="status-message" role="alert">Menu is temporarily unavailable. Please retry in a moment.</div> : null}
                    {products.length ? <div className="product-grid">{products.map((product) => <ProductTile key={product.id} product={product} favorite={favoriteIds.has(product.id)} locale={locale} />)}</div> : !catalogResult.error ? <p className="status-message">{t.noProducts}</p> : null}
                </section>
                <p className="status-message">{t.priceChecked}</p>
            </main>
            <footer className="site-footer"><div className="footer-inner"><span>© {new Date().getFullYear()} Bites Box</span><Link href="/help">{t.help}</Link><span>{t.terms}</span></div></footer>
        </>
    );
}
