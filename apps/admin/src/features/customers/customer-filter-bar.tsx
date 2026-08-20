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

const SEGMENTS = [
    { value: 'all', label: 'All customers' },
    { value: 'new', label: 'Yet to order' },
    { value: 'repeat', label: 'Repeat customers' },
    { value: 'high_value', label: 'High value' },
    { value: 'inactive', label: 'Gone quiet (30d)' },
    { value: 'blocked', label: 'Blocked' },
];

const SORTS = [
    { value: 'recent', label: 'Recently ordered' },
    { value: 'value', label: 'Lifetime value' },
    { value: 'orders', label: 'Order count' },
    { value: 'newest', label: 'Newest sign-ups' },
];

export function CustomerFilterBar({
    search,
    segment,
    sort,
}: {
    search: string;
    segment: string;
    sort: string;
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

    React.useEffect(() => {
        if (term === search) return;
        const timer = setTimeout(() => update({ q: term.trim() || null }), 350);
        return () => clearTimeout(timer);
    }, [term, search, update]);

    const active = segment !== 'all' || sort !== 'recent' || search;

    return (
        <div className="mb-4 flex flex-wrap items-center gap-2">
            <div className="min-w-56 flex-1">
                <SearchInput
                    value={term}
                    onChange={(event) => setTerm(event.target.value)}
                    placeholder="Name, phone or email"
                    aria-label="Search customers"
                />
            </div>

            <Select value={segment} onValueChange={(value) => update({ segment: value })}>
                <SelectTrigger className="w-48" aria-label="Segment">
                    <SelectValue />
                </SelectTrigger>
                <SelectContent>
                    {SEGMENTS.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                            {option.label}
                        </SelectItem>
                    ))}
                </SelectContent>
            </Select>

            <Select value={sort} onValueChange={(value) => update({ sort: value })}>
                <SelectTrigger className="w-44" aria-label="Sort by">
                    <SelectValue />
                </SelectTrigger>
                <SelectContent>
                    {SORTS.map((option) => (
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
