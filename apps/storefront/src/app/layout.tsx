import type { Metadata } from 'next';
import { cookies } from 'next/headers';
import './globals.css';
import { localeFrom, siteUrl } from '@/lib/site';

export const metadata: Metadata = {
    metadataBase: new URL(siteUrl),
    title: { default: 'Bites Box | Bihar favourites', template: '%s | Bites Box' },
    description: 'Browse the Bites Box menu, check outlet availability and order your favourites.',
    robots: { index: true, follow: true },
};

export default async function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
    // Keep the document shell independent of Supabase so the route loading
    // boundary can render immediately while page data is fetched.
    const locale = localeFrom((await cookies()).get('bb_customer_locale')?.value);
    return <html lang={locale}><body>{children}</body></html>;
}
