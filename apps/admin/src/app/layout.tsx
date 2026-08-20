import type { Metadata, Viewport } from 'next';
import './globals.css';
import { Providers } from '@/components/providers';

export const metadata: Metadata = {
    title: {
        default: 'Bites Box — Operations',
        template: '%s · Bites Box',
    },
    description:
        'Operating console for Bites Box: live orders, kitchen, delivery, payments, refunds and analytics.',
    robots: { index: false, follow: false },
    icons: { icon: '/favicon.ico' },
};

export const viewport: Viewport = {
    themeColor: '#c1121f',
    width: 'device-width',
    initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
    return (
        <html lang="en" suppressHydrationWarning>
            <body className="min-h-dvh antialiased">
                {/* Keyboard users reach the main region without traversing the sidebar. */}
                <a
                    href="#main"
                    className="sr-only focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:z-100 focus:rounded-md focus:bg-brand-600 focus:px-3 focus:py-2 focus:text-sm focus:font-medium focus:text-white"
                >
                    Skip to content
                </a>
                <Providers>{children}</Providers>
            </body>
        </html>
    );
}
