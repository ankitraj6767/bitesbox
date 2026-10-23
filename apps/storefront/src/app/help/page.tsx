import type { Metadata } from 'next';
import Link from 'next/link';
import { StorefrontHeader } from '@/components/storefront-header';
import { storefrontContext } from '@/lib/storefront-context';
import { messages } from '@/lib/site';

export const metadata: Metadata = { title: 'Help and contact' };
export const dynamic = 'force-dynamic';

export default async function HelpPage() {
    const context = await storefrontContext();
    const t = messages[context.locale];
    const faqs = await context.supabase.from('cms_faqs').select('id,question,answer,category').eq('is_published', true).eq('locale', context.locale).order('display_order');
    const rows = faqs.data ?? [];
    const supportPhone = process.env.NEXT_PUBLIC_SUPPORT_PHONE;
    return <>
        <StorefrontHeader outlets={context.outlets} outletId={context.outlet?.id ?? ''} outletName={context.outlet?.name ?? ''} locale={context.locale} userId={context.user?.id ?? null} />
        <main className="page narrow-page"><h1>{t.contactHelp}</h1><p className="muted">{t.helpText}</p>
            {supportPhone ? <p><a href={`tel:${supportPhone}`}>{supportPhone}</a></p> : null}
            {rows.map((faq) => <details className="faq-panel" key={faq.id}><summary>{faq.question}</summary><p>{faq.answer}</p></details>)}
            {faqs.error ? <p className="status-message">{t.retry}</p> : null}
            {context.user ? <Link href="/account">{t.account}</Link> : <Link href={`/sign-in?next=${encodeURIComponent('/help')}`}>{t.signIn}</Link>}
        </main>
    </>;
}
