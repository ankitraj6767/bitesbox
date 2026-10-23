import type { Metadata } from 'next';
import Link from 'next/link';
import { StorefrontHeader } from '@/components/storefront-header';
import { storefrontContext } from '@/lib/storefront-context';
import { messages } from '@/lib/site';

export const metadata: Metadata = { title: 'Offers', robots: { index: false, follow: false } };
export const dynamic = 'force-dynamic';

export default async function OffersPage() {
    const context = await storefrontContext();
    const t = messages[context.locale];
    const [publicResult, applicableResult] = await Promise.all([
        context.outlet
            ? context.supabase.rpc('public_storefront_offers', { p_branch_id: context.outlet.id, p_locale: context.locale })
            : Promise.resolve({ data: null }),
        context.user && context.outlet
            ? context.supabase.rpc('localized_available_coupons', { p_branch_id: context.outlet.id, p_locale: context.locale })
            : Promise.resolve({ data: null }),
    ]);
    const applicable = new Map(((applicableResult.data ?? []) as Array<{ id: string; is_applicable: boolean; reason: string | null }>).map((offer) => [offer.id, offer]));
    const offers = ((publicResult.data ?? []) as Array<{ id: string; code: string; title: string; description: string | null; terms: string | null; discount_kind: string; discount_value: number; min_order_amount: number; max_discount_amount: number | null; ends_at: string | null }>).map((offer) => ({ ...offer, ...applicable.get(offer.id) }));
    return <>
        <StorefrontHeader outlets={context.outlets} outletId={context.outlet?.id ?? ''} outletName={context.outlet?.name ?? ''} locale={context.locale} userId={context.user?.id ?? null} />
        <main className="page"><h1>{t.offers}</h1>
            {!offers.length ? <p className="muted">{t.noOffers}</p> : null}
            <div className="offers-grid">{offers.map((offer) => <article className="panel" key={offer.id}>
                <h2>{offer.title}</h2>{offer.description ? <p>{offer.description}</p> : null}<p className="offer-code">{offer.code}</p>
                <p className="muted">{context.user ? (offer.is_applicable ? (context.locale === 'hi' ? 'आपके कार्ट पर लागू' : 'Applicable to your cart') : (offer.reason ?? (context.locale === 'hi' ? 'शर्तें पूरी नहीं हुईं' : 'Not applicable to the current cart'))) : t.signInToSeeOffer}</p>
                {offer.terms ? <small>{offer.terms}</small> : null}
            </article>)}</div>
            {!context.user && offers.length ? <Link className="primary-button" href={`/sign-in?next=${encodeURIComponent('/offers')}`}>{t.signIn}</Link> : null}
        </main>
    </>;
}
