'use client';

import * as React from 'react';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
    SearchInput,
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/form-controls';

const STATUS_GROUPS = [
    { value: 'all', label: 'All statuses' },
    { value: 'active', label: 'In progress' },
    { value: 'new', label: 'Awaiting acceptance' },
    { value: 'kitchen', label: 'In the kitchen' },
    { value: 'delivery', label: 'Out for delivery' },
    { value: 'completed', label: 'Completed' },
    { value: 'cancelled', label: 'Cancelled' },
    { value: 'refunded', label: 'Refunded' },
    { value: 'unpaid', label: 'Awaiting payment' },
];

const PAYMENT_OPTIONS = [
    { value: 'all', label: 'All payments' },
    { value: 'ONLINE', label: 'Paid online' },
    { value: 'COD', label: 'Cash on delivery' },
];

const FULFILMENT_OPTIONS = [
    { value: 'all', label: 'Delivery & pickup' },
    { value: 'DELIVERY', label: 'Delivery only' },
    { value: 'PICKUP', label: 'Pickup only' },
];

const RANGE_OPTIONS = [
    { value: 'today', label: 'Today' },
    { value: '7d', label: 'Last 7 days' },
    { value: '30d', label: 'Last 30 days' },
    { value: 'all', label: 'All time' },
];

/**
 * Filters live in the URL so an operator can bookmark "unpaid orders today" and
 * share it with the next shift.
 */
export function OrdersFilterBar({
    status,
    payment,
    fulfilment,
    range,
    search,
}: {
    status: string;
    payment: string;
    fulfilment: string;
    range: string;
    search: string;
}) {
    const router = useRouter();
    const pathname = usePathname();
    const searchParams = useSearchParams();
    const [term, setTerm] = React.useState(search);

    const update = React.useCallback(
        (patch: Record<string, string | null>) => {
            const params = new URLSearchParams(searchParams.toString());
            Object.entries(patch).forEach(([key, value]) => {
                if (!value || value === 'all') params.delete(key);
                else params.set(key, value);
            });
            params.delete('page');
            router.push(`${pathname}?${params.toString()}`);
        },
        [pathname, router, searchParams],
    );

    // Debounce typing so we do not issue a query per keystroke.
    React.useEffect(() => {
        if (term === search) return;
        const timer = setTimeout(() => update({ q: term.trim() || null }), 350);
        return () => clearTimeout(timer);
    }, [term, search, update]);

    const active =
        status !== 'all' || payment !== 'all' || fulfilment !== 'all' || range !== 'today' || search;

    return (
        <div className="mb-4 flex flex-wrap items-center gap-2">
            <div className="min-w-56 flex-1">
                <SearchInput
                    value={term}
                    onChange={(event) => setTerm(event.target.value)}
                    placeholder="Order number, customer name or phone"
                    aria-label="Search orders"
                />
            </div>

            <Select value={status} onValueChange={(value) => update({ status: value })}>
                <SelectTrigger className="w-44" aria-label="Status">
                    <SelectValue />
                </SelectTrigger>
                <SelectContent>
                    {STATUS_GROUPS.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                            {option.label}
                        </SelectItem>
                    ))}
                </SelectContent>
            </Select>

            <Select value={payment} onValueChange={(value) => update({ payment: value })}>
                <SelectTrigger className="w-40" aria-label="Payment mode">
                    <SelectValue />
                </SelectTrigger>
                <SelectContent>
                    {PAYMENT_OPTIONS.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                            {option.label}
                        </SelectItem>
                    ))}
                </SelectContent>
            </Select>

            <Select value={fulfilment} onValueChange={(value) => update({ fulfilment: value })}>
                <SelectTrigger className="w-40" aria-label="Fulfilment">
                    <SelectValue />
                </SelectTrigger>
                <SelectContent>
                    {FULFILMENT_OPTIONS.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                            {option.label}
                        </SelectItem>
                    ))}
                </SelectContent>
            </Select>

            <Select value={range} onValueChange={(value) => update({ range: value })}>
                <SelectTrigger className="w-36" aria-label="Date range">
                    <SelectValue />
                </SelectTrigger>
                <SelectContent>
                    {RANGE_OPTIONS.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                            {option.label}
                        </SelectItem>
                    ))}
                </SelectContent>
            </Select>

            {active ? (
                <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => {
                        setTerm('');
                        router.push(pathname);
                    }}
                >
                    <X />
                    Clear
                </Button>
            ) : null}
        </div>
    );
}
