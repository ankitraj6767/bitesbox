import type { Metadata } from 'next';
import './globals.css';
import { siteUrl } from '@/lib/site';
import { storefrontContext } from '@/lib/storefront-context';

export const metadata: Metadata = {
    metadataBase: new URL(siteUrl),
    title: { default: 'Bites Box | Bihar favourites', template: '%s | Bites Box' },
    description: 'Browse the Bites Box menu, check outlet availability and order your favourites.',
    robots: { index: true, follow: true },
};

export default async function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
    const { locale } = await storefrontContext();
    return <html lang={locale}><body>{children}</body></html>;
}
