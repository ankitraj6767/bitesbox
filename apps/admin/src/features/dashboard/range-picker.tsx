'use client';

import * as React from 'react';
import { useRouter, useSearchParams, usePathname } from 'next/navigation';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/form-controls';
import { RANGE_OPTIONS, type RangeKey } from './range';

export function RangePicker({ value }: { value: RangeKey }) {
    const router = useRouter();
    const pathname = usePathname();
    const searchParams = useSearchParams();

    const onChange = (next: string) => {
        const params = new URLSearchParams(searchParams.toString());
        params.set('range', next);
        router.push(`${pathname}?${params.toString()}`);
    };

    return (
        <Select value={value} onValueChange={onChange}>
            <SelectTrigger className="h-8 w-40 text-[13px]" aria-label="Date range">
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
    );
}
