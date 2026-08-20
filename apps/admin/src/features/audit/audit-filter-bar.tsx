'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/form-controls';

const ACTIONS = [
    { value: 'all', label: 'All actions' },
    { value: 'REFUND_REQUEST', label: 'Refund requested' },
    { value: 'REFUND_APPROVE', label: 'Refund approved' },
    { value: 'REFUND_REJECT', label: 'Refund rejected' },
    { value: 'ORDER_CANCEL', label: 'Order cancelled' },
    { value: 'ORDER_STATUS_OVERRIDE', label: 'Order status overridden' },
    { value: 'MANUAL_DELIVERY_OVERRIDE', label: 'Delivery overridden' },
    { value: 'RIDER_ASSIGN', label: 'Rider assigned' },
    { value: 'RIDER_REASSIGN', label: 'Rider reassigned' },
    { value: 'PRICE_CHANGE', label: 'Price changed' },
    { value: 'SETTINGS_CHANGE', label: 'Settings changed' },
    { value: 'FEATURE_FLAG_CHANGE', label: 'Feature flag changed' },
    { value: 'ROLE_ASSIGN', label: 'Role assigned' },
    { value: 'CUSTOMER_BLOCK', label: 'Customer blocked' },
    { value: 'RIDER_SUSPEND', label: 'Rider suspended' },
    { value: 'WALLET_ADJUSTMENT', label: 'Wallet adjusted' },
];

const ENTITIES = [
    { value: 'all', label: 'All records' },
    { value: 'order', label: 'Orders' },
    { value: 'refund', label: 'Refunds' },
    { value: 'product', label: 'Products' },
    { value: 'coupon', label: 'Coupons' },
    { value: 'settings', label: 'Settings' },
    { value: 'feature_flag', label: 'Feature flags' },
    { value: 'user_role', label: 'Roles' },
    { value: 'profile', label: 'Customers' },
    { value: 'delivery_partner', label: 'Delivery partners' },
    { value: 'delivery_zone', label: 'Delivery zones' },
    { value: 'branch', label: 'Branch' },
];

export function AuditFilterBar({ action, entity }: { action: string; entity: string }) {
    const router = useRouter();
    const pathname = usePathname();
    const searchParams = useSearchParams();

    const update = (patch: Record<string, string>) => {
        const params = new URLSearchParams(searchParams.toString());
        Object.entries(patch).forEach(([key, value]) => {
            if (!value || value === 'all') params.delete(key);
            else params.set(key, value);
        });
        params.delete('page');
        router.push(`${pathname}?${params.toString()}`);
    };

    return (
        <div className="mb-4 flex flex-wrap items-center gap-2">
            <Select value={action} onValueChange={(value) => update({ action: value })}>
                <SelectTrigger className="w-56" aria-label="Filter by action">
                    <SelectValue />
                </SelectTrigger>
                <SelectContent>
                    {ACTIONS.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                            {option.label}
                        </SelectItem>
                    ))}
                </SelectContent>
            </Select>

            <Select value={entity} onValueChange={(value) => update({ entity: value })}>
                <SelectTrigger className="w-48" aria-label="Filter by record type">
                    <SelectValue />
                </SelectTrigger>
                <SelectContent>
                    {ENTITIES.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                            {option.label}
                        </SelectItem>
                    ))}
                </SelectContent>
            </Select>

            {action !== 'all' || entity !== 'all' ? (
                <Button variant="ghost" size="sm" onClick={() => router.push(pathname)}>
                    <X />
                    Clear
                </Button>
            ) : null}
        </div>
    );
}
