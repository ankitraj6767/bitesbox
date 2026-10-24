import Image from "next/image";
import Link from "next/link";
import { StorefrontHeader } from "@/components/storefront-header";
import { ProductTile, type Product } from "@/components/product-tile";
import { storefrontContext } from "@/lib/storefront-context";
import { messages, storageUrl, tasteReasonLabel } from "@/lib/site";
import { StorefrontEvent } from "@/components/storefront-event";
import { getCachedPublicMenuCatalog } from "@/lib/public-storefront-cache";
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
  const isHome = !query.trim() && !categoryId;
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
  const heroProduct =
    products.find(
      (product) => product.slug === "lucknowi-chicken-dum-biryani",
    ) ??
    products.find((product) => product.slug === "chicken-dum-biryani") ??
    products[0];
  const heroImage = storageUrl(
    heroProduct?.hero_image_path ?? heroProduct?.thumbnail_path,
  );
  const freshProducts = categories
    .map((category) =>
      products.find(
        (product) =>
          product.is_new && product.category_id === String(category["id"]),
      ),
    )
    .filter((product): product is Product => Boolean(product))
    .slice(0, 12);

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
        {isHome ? (
          <>
            <section className="hero hero-premium" aria-labelledby="hero-title">
              <div className="hero-copy">
                <div className="hero-kicker">
                  <span aria-hidden="true">✦</span> Bites Box · {t.tagline}
                </div>
                <h1 id="hero-title">{t.heroTitle}</h1>
                <p className="hero-description">{t.heroDescription}</p>
                <div className="hero-actions">
                  <Link
                    className="primary-button hero-primary"
                    href="#menu-categories"
                  >
                    {t.exploreFullMenu}
                    <span aria-hidden="true">↗</span>
                  </Link>
                  <Link className="hero-secondary" href="/offers">
                    {t.seeOffers}
                  </Link>
                </div>
                {outlet ? (
                  <div className="status hero-status">
                    <span className={`dot ${open ? "" : "closed"}`} />
                    {outlet.name} · {open ? t.outletOpen : t.outletClosed}
                  </div>
                ) : null}
                {outlet && !open ? (
                  <p className="hero-status-note">
                    {String(ordering.status_note ?? t.closedReason)}
                  </p>
                ) : null}
                {!outlet ? (
                  <p className="hero-status-note">{t.noOutlets}</p>
                ) : null}
                <div
                  className="hero-proof"
                  aria-label="Bites Box menu highlights"
                >
                  <span>
                    <strong>{products.length}</strong> {t.curatedCount}
                  </span>
                  <span>
                    <i aria-hidden="true">✦</i> {t.freshlyPrepared}
                  </span>
                  <span>
                    <i aria-hidden="true">⌂</i> {t.regionalFlavours}
                  </span>
                </div>
              </div>
              <div className="hero-visual">
                <div className="hero-orbit hero-orbit-one" />
                <div className="hero-orbit hero-orbit-two" />
                {heroProduct && heroImage ? (
                  <Link
                    className="hero-food-photo"
                    href={`/menu/${encodeURIComponent(heroProduct.slug)}`}
                    aria-label={`${locale === "hi" ? "देखें" : "View"} ${heroProduct.name}`}
                  >
                    <Image
                      src={heroImage}
                      alt={heroProduct.name}
                      fill
                      priority
                      sizes="(max-width: 760px) 82vw, 46vw"
                    />
                    <span className="hero-photo-stamp">{t.featuredDish}</span>
                  </Link>
                ) : null}
                {heroProduct ? (
                  <Link
                    className="hero-dish-caption"
                    href={`/menu/${encodeURIComponent(heroProduct.slug)}`}
                  >
                    <span className="hero-caption-kicker">
                      {t.featuredDish}
                    </span>
                    <strong>{heroProduct.name}</strong>
                    <span className="hero-caption-arrow" aria-hidden="true">
                      ↗
                    </span>
                  </Link>
                ) : null}
                <div className="hero-floating-note">
                  <span className="hero-note-mark" aria-hidden="true">
                    ✺
                  </span>
                  <span>
                    <strong>{t.heroCareLabel}</strong>
                    <small>{t.heroCareSub}</small>
                  </span>
                </div>
              </div>
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

            {categories.length ? (
              <section
                className="category-discovery"
                aria-labelledby="mood-heading"
              >
                <div className="discovery-heading">
                  <div>
                    <span className="section-eyebrow">{t.moodEyebrow}</span>
                    <h2 id="mood-heading">{t.chooseYourMood}</h2>
                    <p className="muted">{t.chooseYourMoodDescription}</p>
                  </div>
                  <Link className="discovery-link" href="#menu-categories">
                    {t.exploreFullMenu} <span aria-hidden="true">→</span>
                  </Link>
                </div>
                <div className="category-showcase">
                  {categories.slice(0, 6).map((category, index) => {
                    const image = storageUrl(
                      String(
                        category["thumbnail_path"] ??
                          category["image_path"] ??
                          "",
                      ),
                    );
                    const categoryCount = Number(
                      category["product_count"] ?? 0,
                    );
                    return (
                      <Link
                        key={String(category["id"])}
                        className={`category-showcase-card category-tone-${index % 6}`}
                        href={`/menu?category=${category["id"]}`}
                      >
                        <span className="category-showcase-image">
                          {image ? (
                            <Image
                              src={image}
                              alt=""
                              fill
                              sizes="(max-width:640px) 42vw, 20vw"
                            />
                          ) : null}
                        </span>
                        <span className="category-showcase-copy">
                          <strong>{String(category["name"])}</strong>
                          <span>
                            {String(
                              category["short_description"] ?? t.viewMenu,
                            )}
                          </span>
                          {categoryCount > 0 ? (
                            <span className="category-showcase-count">
                              {categoryCount} {t.dishes}
                            </span>
                          ) : null}
                        </span>
                        <span
                          className="category-showcase-arrow"
                          aria-hidden="true"
                        >
                          ↗
                        </span>
                      </Link>
                    );
                  })}
                </div>
              </section>
            ) : null}

            {freshProducts.length ? (
              <section
                className="fresh-picks"
                aria-labelledby="fresh-picks-heading"
              >
                <div className="section-heading fresh-heading">
                  <div>
                    <span className="section-eyebrow">{t.freshEyebrow}</span>
                    <h2 id="fresh-picks-heading">{t.freshPicks}</h2>
                    <p className="muted">{t.freshPicksDescription}</p>
                  </div>
                  <Link className="discovery-link" href="#menu-categories">
                    {t.exploreFullMenu} <span aria-hidden="true">→</span>
                  </Link>
                </div>
                <div className="fresh-product-rail">
                  {freshProducts.map((product) => (
                    <ProductTile
                      key={product.id}
                      product={product}
                      favorite={favoriteIds.has(product.id)}
                      locale={locale}
                      linkContext={t.freshEyebrow}
                    />
                  ))}
                </div>
              </section>
            ) : null}
          </>
        ) : null}

        <section id="menu-categories" aria-labelledby="browse-heading">
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
