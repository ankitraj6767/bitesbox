import type { Metadata } from 'next';
import Link from 'next/link';
import { SignOutButton } from '@/components/sign-out-button';
import { StorefrontHeader } from '@/components/storefront-header';
import { storefrontContext } from '@/lib/storefront-context';
import { messages } from '@/lib/site';

export const metadata: Metadata = { title: 'Account', robots: { index: false, follow: false } };
export const dynamic = 'force-dynamic';

export default async function AccountPage() {
    const context = await storefrontContext();
    const t = messages[context.locale];
    const ordersResult = context.user ? await context.supabase.rpc('my_orders', { p_limit: 10, p_scope: 'ALL' }) : { data: null };
    const orders = ((ordersResult.data as { orders?: Array<{ id: string; order_number: string; status: string; created_at: string }> } | null)?.orders ?? []);
    return <>
        <StorefrontHeader outlets={context.outlets} outletId={context.outlet?.id ?? ''} outletName={context.outlet?.name ?? ''} locale={context.locale} userId={context.user?.id ?? null} />
        <main className="page">
            <h1>{t.account}</h1>
            {!context.user ? <section className="panel"><p>{t.signInRequired}</p><Link className="primary-button" href={`/sign-in?next=${encodeURIComponent('/account')}`}>{t.signIn}</Link></section> : <>
                <section className="panel account-summary"><h2>{context.profile?.full_name ?? t.account}</h2><p>{context.profile?.preferred_language === 'hi' ? 'हिन्दी' : 'English'}</p>
                    <div className="account-links"><Link href="/favorites">{t.favorites}</Link><Link href="/referrals">{t.referral}</Link><Link href="/help">{t.help}</Link><SignOutButton locale={context.locale} /></div>
                </section>
                <section><h2>{localeTitle(context.locale)}</h2>{orders.length ? <ul className="account-orders">{orders.map((order) => <li key={order.id}><Link href={`/order/${order.id}`}><span>{order.order_number}</span><span>{order.status.replaceAll('_', ' ').toLowerCase()}</span></Link></li>)}</ul> : <p className="muted">{t.emptyCart}</p>}</section>
            </>}
        </main>
    </>;
}

function localeTitle(locale: 'en' | 'hi') { return locale === 'hi' ? 'आपके ऑर्डर' : 'Your orders'; }
