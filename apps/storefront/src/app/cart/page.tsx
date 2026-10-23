import type { Metadata } from 'next';
import { CartPanel } from '@/components/cart-panel';
import { StorefrontHeader } from '@/components/storefront-header';
import { storefrontContext } from '@/lib/storefront-context';

export const metadata: Metadata = { title: 'Cart', robots: { index: false, follow: false } };
export const dynamic = 'force-dynamic';

export default async function CartPage() {
    const context = await storefrontContext();
    return <>
        <StorefrontHeader outlets={context.outlets} outletId={context.outlet?.id ?? ''} outletName={context.outlet?.name ?? ''} locale={context.locale} userId={context.user?.id ?? null} />
        <CartPanel branchId={context.outlet?.id ?? ''} locale={context.locale} userId={context.user?.id ?? null} />
    </>;
}
