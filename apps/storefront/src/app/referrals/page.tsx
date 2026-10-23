import type { Metadata } from 'next';
import { ReferralPanel } from '@/components/referral-panel';
import { StorefrontHeader } from '@/components/storefront-header';
import { storefrontContext } from '@/lib/storefront-context';

export const metadata: Metadata = { title: 'Referrals', robots: { index: false, follow: false } };
export const dynamic = 'force-dynamic';

export default async function ReferralsPage({ searchParams }: { searchParams: Promise<{ code?: string }> }) {
    const [context, params] = await Promise.all([storefrontContext(), searchParams]);
    let code = '';
    if (context.user) {
        const { data } = await context.supabase.rpc('my_referral_summary');
        code = (data as { code?: string } | null)?.code ?? '';
    }
    return <>
        <StorefrontHeader outlets={context.outlets} outletId={context.outlet?.id ?? ''} outletName={context.outlet?.name ?? ''} locale={context.locale} userId={context.user?.id ?? null} />
        <main className="page narrow-page"><ReferralPanel locale={context.locale} userId={context.user?.id ?? null} code={code} inviteCode={params.code} />
        </main>
    </>;
}
