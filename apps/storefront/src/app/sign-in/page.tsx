import type { Metadata } from 'next';
import { PhoneSignInForm } from '@/components/phone-sign-in-form';
import { StorefrontHeader } from '@/components/storefront-header';
import { storefrontContext } from '@/lib/storefront-context';

export const metadata: Metadata = { title: 'Sign in', robots: { index: false, follow: false } };
export const dynamic = 'force-dynamic';

export default async function SignInPage({ searchParams }: { searchParams: Promise<{ next?: string; ref?: string }> }) {
    const [context, params] = await Promise.all([storefrontContext(), searchParams]);
    return <>
        <StorefrontHeader outlets={context.outlets} outletId={context.outlet?.id ?? ''} outletName={context.outlet?.name ?? ''} locale={context.locale} userId={context.user?.id ?? null} />
        <main className="page narrow-page"><PhoneSignInForm locale={context.locale} next={params.next ?? null} referralCode={params.ref ?? null} /></main>
    </>;
}
