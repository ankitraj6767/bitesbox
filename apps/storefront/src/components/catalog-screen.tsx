import Link from "next/link";
import { StorefrontHeader } from "@/components/storefront-header";
import { ProductTile, type Product } from "@/components/product-tile";
import { storefrontContext } from "@/lib/storefront-context";
import { messages } from "@/lib/site";
import { StorefrontEvent } from "@/components/storefront-event";
import { getCachedPublicMenuCatalog } from "@/lib/public-storefront-cache";
import { tasteReasonLabel } from "@/lib/site";
import { isTasteSetup } from "@/lib/taste-passport";
import { TasteMatchRefreshSignal } from "@/components/taste-match-refresh-signal";

export async function CatalogScreen({
  query = "",
  categoryId,
}: {
  query?: string;
  categoryId?: string;
}) {
  const context = await storefrontContext();
  const { supabase, outlets, outlet, locale, user } = context;
  const t = messages[locale];
  const catalogRequest = outlet
    ? query.trim()
      ? supabase.rpc("localized_search_menu", {
          p_query: query.trim(),
          p_branch_id: outlet.id,
          p_locale: locale,
          p_limit: 50,
        })
      : getCachedPublicMenuCatalog(outlet.id, locale)
          .then((data) => ({ data, error: null }))
          .catch(() => ({
            data: null,
            error: new Error("Menu is temporarily unavailable."),
          }))
    : Promise.resolve({ data: null, error: null });
  const showTasteMatch = Boolean(
    context.isCustomer && user && outlet && !query.trim() && !categoryId,
  );
  const tasteMatchRequest = showTasteMatch
    ? supabase.rpc("localized_home_feed", {
        p_branch_id: outlet!.id,
        p_locale: locale,
      })
    : Promise.resolve({ data: null, error: null });
  const [catalogResult, favoriteResult, tasteMatchResult] = await Promise.all([
    catalogRequest,
    user
      ? supabase.rpc("my_favorites", {
          p_branch_id: outlet?.id,
          p_locale: locale,
        })
      : Promise.resolve({ data: null, error: null }),
    tasteMatchRequest,
  ]);
  const catalog = catalogResult.data as {
    branch?: Record<string, unknown>;
    categories?: Array<Record<string, unknown>>;
    products?: Product[];
  } | null;
  const categories = catalog?.categories ?? [];
  const products = (catalog?.products ?? []).filter(
    (product) => !categoryId || String(product.category_id) === categoryId,
  );
  const favoriteRows = favoriteResult.data as Array<{ id?: string }> | null;
  const favoriteIds = new Set(
    (favoriteRows ?? [])
      .map((row) => row.id)
      .filter((id): id is string => Boolean(id)),
  );
  const feed = tasteMatchResult.data as {
    sections?: Array<Record<string, unknown>>;
  } | null;
  const tasteSection = (feed?.sections ?? []).find(
    (section) => section.kind === "TASTE_MATCH",
  );
  const tasteProducts = Array.isArray(tasteSection?.products)
    ? (tasteSection.products as Product[])
    : [];
  const ordering = (catalog?.branch ?? outlet?.ordering ?? {}) as Record<
    string,
    unknown
  >;
  const open = ordering.accepting_orders === true;

  return (
    <>
      <StorefrontEvent
        name={query.trim() ? "SEARCH" : "MENU_VIEW"}
        branchId={outlet?.id}
      />
      <TasteMatchRefreshSignal
        userId={context.isCustomer ? (user?.id ?? null) : null}
      />
      <StorefrontHeader
        outlets={outlets}
        outletId={outlet?.id ?? ""}
        outletName={outlet?.name ?? ""}
        locale={locale}
        userId={user?.id ?? null}
      />
      <main className="page">
        <section className="hero" aria-labelledby="hero-title">
          <div className="eyebrow">Bites Box · {t.tagline}</div>
          <h1 id="hero-title">{t.heroTitle}</h1>
          <p className="muted">{t.heroDescription}</p>
          {outlet ? (
            <div className="status">
              <span className={`dot ${open ? "" : "closed"}`} />
              {outlet.name} · {open ? t.outletOpen : t.outletClosed}
            </div>
          ) : null}
          {outlet && !open ? (
            <p className="status-message">
              {String(ordering.status_note ?? t.closedReason)}
            </p>
          ) : null}
          {!outlet ? <p className="status-message">{t.noOutlets}</p> : null}
        </section>

        <section aria-labelledby="browse-heading">
          <div className="section-heading">
            <h2 id="browse-heading">
              {query ? `${t.resultsFor}: ${query}` : t.browseMenu}
            </h2>
            <p className="muted">
              {products.length} {t.dishes}
            </p>
          </div>
          {categories.length ? (
            <nav className="categories" aria-label="Menu categories">
              <Link
                className={`category-chip ${!categoryId ? "active" : ""}`}
                href="/menu"
              >
                {t.all}
              </Link>
              {categories.map((category) => (
                <Link
                  key={String(category["id"])}
                  className={`category-chip ${categoryId === category["id"] ? "active" : ""}`}
                  href={`/menu?category=${category["id"]}`}
                >
                  {String(category["name"])}
                </Link>
              ))}
            </nav>
          ) : null}
          {catalogResult.error ? (
            <div className="status-message" role="alert">
              Menu is temporarily unavailable. Please retry in a moment.
            </div>
          ) : null}
          {products.length ? (
            <div className="product-grid">
              {products.map((product) => (
                <ProductTile
                  key={product.id}
                  product={product}
                  favorite={favoriteIds.has(product.id)}
                  locale={locale}
                />
              ))}
            </div>
          ) : !catalogResult.error ? (
            <p className="status-message">{t.noProducts}</p>
          ) : null}
        </section>
        {tasteSection ? (
          <section
            className="taste-match"
            aria-labelledby="taste-match-heading"
          >
            <div className="section-heading">
              <div>
                <h2 id="taste-match-heading">
                  {String(tasteSection.title ?? t.tastePassport)}
                </h2>
                {tasteSection.subtitle ? (
                  <p className="muted">{String(tasteSection.subtitle)}</p>
                ) : null}
              </div>
            </div>
            {isTasteSetup(tasteSection) ? (
              <div className="panel taste-setup-prompt">
                <div>
                  <strong>{t.tasteSetupTitle}</strong>
                  <p className="muted">{t.tasteSetupDescription}</p>
                </div>
                <Link
                  className="secondary-button"
                  href="/account#taste-passport"
                >
                  {t.saveTastePassport}
                </Link>
              </div>
            ) : null}
            {tasteProducts.length ? (
            <div className="taste-product-rail">
                {tasteProducts.map((product) => (
                  <ProductTile
                    key={product.id}
                    product={product}
                    favorite={favoriteIds.has(product.id)}
                    locale={locale}
                    reason={tasteReasonLabel(product.reason_code, locale)}
                  />
                ))}
              </div>
            ) : null}
          </section>
        ) : null}
        <p className="status-message">{t.priceChecked}</p>
      </main>
      <footer className="site-footer">
        <div className="footer-inner">
          <span>© {new Date().getFullYear()} Bites Box</span>
          <Link href="/help">{t.help}</Link>
          <span>{t.terms}</span>
        </div>
      </footer>
    </>
  );
}
