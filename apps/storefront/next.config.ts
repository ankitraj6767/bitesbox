import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
    poweredByHeader: false,
    transpilePackages: ['@bitesbox/shared-types'],
    images: { remotePatterns: [{ protocol: 'https', hostname: '**.supabase.co', pathname: '/storage/v1/object/**' }] },
};

export default nextConfig;
