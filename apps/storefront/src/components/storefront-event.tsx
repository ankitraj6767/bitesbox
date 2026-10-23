'use client';

import { useEffect } from 'react';
import { recordStorefrontEvent, type StorefrontEventName } from '@/lib/storefront-analytics';

export function StorefrontEvent({ name, branchId, productId }: { name: StorefrontEventName; branchId?: string | null; productId?: string | null }) {
    useEffect(() => { recordStorefrontEvent(name, branchId, productId); }, [name, branchId, productId]);
    return null;
}
