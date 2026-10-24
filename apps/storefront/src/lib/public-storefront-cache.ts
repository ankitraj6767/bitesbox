import 'server-only';

import { unstable_cache } from 'next/cache';
import { createClient } from '@supabase/supabase-js';
import type { Database } from '@bitesbox/shared-types';
import type { Locale } from '@/lib/site';

/**
 * Shared cache for read-only data that is already public through the storefront
 * RPC grants. Never use this client for a customer-specific query: it has no
 * request cookies or user session. Order/cart RPCs still recalculate current
 * price and availability before any transaction is accepted.
 */
function createPublicSupabaseClient() {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !key) throw new Error('Storefront Supabase configuration is missing.');

    return createClient<Database>(url, key, {
        auth: {
            persistSession: false,
            autoRefreshToken: false,
            detectSessionInUrl: false,
        },
    });
}

const readPublicOutlets = unstable_cache(
    async () => {
        const { data, error } = await createPublicSupabaseClient().rpc('public_outlets');
        if (error) throw new Error('Unable to load public outlets.');
        return data;
    },
    ['bitesbox-public-outlets-v1'],
    { revalidate: 5, tags: ['storefront-public-outlets'] },
);

const readPublicMenuCatalog = unstable_cache(
    async (branchId: string, locale: Locale) => {
        const { data, error } = await createPublicSupabaseClient().rpc('localized_menu_catalog', {
            p_branch_id: branchId,
            p_locale: locale,
        });
        if (error) throw new Error('Unable to load the public menu.');
        return data;
    },
    ['bitesbox-public-menu-catalog-v1'],
    { revalidate: 15, tags: ['storefront-public-menu'] },
);

const readPublicProduct = unstable_cache(
    async (slug: string, branchId: string, locale: Locale) => {
        const { data, error } = await createPublicSupabaseClient().rpc('localized_product_detail', {
            p_slug: slug,
            p_branch_id: branchId,
            p_locale: locale,
        });
        if (error) throw new Error('Unable to load the public product.');
        return data;
    },
    ['bitesbox-public-product-v1'],
    { revalidate: 15, tags: ['storefront-public-menu'] },
);

const readPublicOffers = unstable_cache(
    async (branchId: string, locale: Locale) => {
        const { data, error } = await createPublicSupabaseClient().rpc('public_storefront_offers', {
            p_branch_id: branchId,
            p_locale: locale,
        });
        if (error) throw new Error('Unable to load public offers.');
        return data;
    },
    ['bitesbox-public-offers-v1'],
    { revalidate: 15, tags: ['storefront-public-offers'] },
);

export function getCachedPublicOutlets() {
    return readPublicOutlets();
}

export function getCachedPublicMenuCatalog(branchId: string, locale: Locale) {
    return readPublicMenuCatalog(branchId, locale);
}

export function getCachedPublicProduct(slug: string, branchId: string, locale: Locale) {
    return readPublicProduct(slug, branchId, locale);
}

export function getCachedPublicOffers(branchId: string, locale: Locale) {
    return readPublicOffers(branchId, locale);
}
