import type { Metadata } from 'next';
import Link from 'next/link';
import { ReferralPanel } from '@/components/referral-panel';
import { StorefrontHeader } from '@/components/storefront-header';
import { storefrontContext } from '@/lib/storefront-context';
import { messages } from '@/lib/site';

export const dynamic = 'force-dynamic';
export async function generateMetadata(): Promise<Metadata> {
    return { title: 'Bites Box invitation', robots: { index: false, follow: false } };
}

export default async function ReferralInvitePage({ params }: { params: Promise<{ code: string }> }) {
    const [context, route] = await Promise.all([storefrontContext(), params]);
    const t = messages[context.locale];
    if (!context.user) return <>
        <StorefrontHeader outlets={context.outlets} outletId={context.outlet?.id ?? ''} outletName={context.outlet?.name ?? ''} locale={context.locale} userId={null} />
        <main className="page narrow-page"><section className="panel"><h1>{t.referralShare}</h1><p>{t.referralTerms}</p><Link className="primary-button" href={`/sign-in?ref=${encodeURIComponent(route.code)}&next=${encodeURIComponent('/referrals')}`}>{t.signIn}</Link></section></main>
    </>;
    const { data: ownSummary } = await context.supabase.rpc('my_referral_summary');
    const ownCode = (ownSummary as { code?: string } | null)?.code;
    return <>
        <StorefrontHeader outlets={context.outlets} outletId={context.outlet?.id ?? ''} outletName={context.outlet?.name ?? ''} locale={context.locale} userId={context.user.id} />
        <main className="page narrow-page"><ReferralPanel locale={context.locale} userId={context.user.id} code={ownCode} inviteCode={route.code.toUpperCase()} /></main>
    </>;
}
