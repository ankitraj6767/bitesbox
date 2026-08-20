import type { NextConfig } from 'next';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? 'http://127.0.0.1:54321';
const supabaseHost = (() => {
    try {
        return new URL(supabaseUrl).hostname;
    } catch {
        return '127.0.0.1';
    }
})();

const nextConfig: NextConfig = {
    reactStrictMode: true,
    poweredByHeader: false,

    // The shared contracts package is consumed straight from source.
    transpilePackages: ['@bitesbox/shared-types'],

    experimental: {
        // Trims the client bundle for these icon/chart heavy libraries.
        optimizePackageImports: ['lucide-react', 'recharts', 'date-fns'],
    },

    images: {
        remotePatterns: [
            { protocol: 'https', hostname: supabaseHost, pathname: '/storage/v1/object/public/**' },
            { protocol: 'http', hostname: '127.0.0.1', port: '54321', pathname: '/storage/v1/object/public/**' },
            { protocol: 'http', hostname: 'localhost', port: '54321', pathname: '/storage/v1/object/public/**' },
        ],
    },

    async headers() {
        return [
            {
                source: '/(.*)',
                headers: [
                    { key: 'X-Frame-Options', value: 'DENY' },
                    { key: 'X-Content-Type-Options', value: 'nosniff' },
                    { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
                    { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(self)' },
                    {
                        key: 'Strict-Transport-Security',
                        value: 'max-age=63072000; includeSubDomains; preload',
                    },
                ],
            },
        ];
    },
};

export default nextConfig;
