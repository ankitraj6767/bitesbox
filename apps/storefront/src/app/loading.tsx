/**
 * Keep the storefront frame visible while dynamic menu/order data streams in.
 * This boundary also gives first-time visits immediate feedback while the
 * Supabase-backed route content is prepared.
 */
export default function StorefrontLoading() {
  return (
    <div aria-busy="true" aria-live="polite">
      <span className="sr-only">Loading the Bites Box menu…</span>

      <header className="site-header" aria-hidden="true">
        <div className="header-top">
          <div className="loading-shimmer loading-brand" />
          <div className="loading-shimmer loading-outlet" />
          <div className="loading-shimmer loading-search" />
          <div className="loading-shimmer loading-nav" />
        </div>
      </header>

      <main className="page">
        <div className="loading-shimmer loading-hero" />
        <div className="loading-section-heading">
          <div className="loading-shimmer loading-heading" />
          <div className="loading-shimmer loading-caption" />
        </div>
        <div className="loading-products">
          {Array.from({ length: 8 }, (_, index) => (
            <div className="loading-shimmer loading-product" key={index} />
          ))}
        </div>
      </main>
    </div>
  );
}
