import type { Metadata } from 'next';
import { OrderTracker } from '@/components/order-tracker';
import { StorefrontHeader } from '@/components/storefront-header';
import { storefrontContext } from '@/lib/storefront-context';

export const metadata: Metadata = { title: 'Order tracking', robots: { index: false, follow: false, noarchive: true } };
export const dynamic = 'force-dynamic';

export default async function OrderPage({ params }: { params: Promise<{ id: string }> }) {
    const [context, route] = await Promise.all([storefrontContext(), params]);
    return <>
        <StorefrontHeader outlets={context.outlets} outletId={context.outlet?.id ?? ''} outletName={context.outlet?.name ?? ''} locale={context.locale} userId={context.user?.id ?? null} />
        <main className="page narrow-page"><OrderTracker orderId={route.id} locale={context.locale} /></main>
    </>;
}
