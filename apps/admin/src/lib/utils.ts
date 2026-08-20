import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';
import { formatDistanceToNowStrict, format, isToday, isYesterday } from 'date-fns';

export function cn(...inputs: ClassValue[]) {
    return twMerge(clsx(inputs));
}

/** ₹1,234 / ₹1,234.50 — Indian digit grouping. */
export function money(amount: number | null | undefined, decimals = false): string {
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        minimumFractionDigits: decimals ? 2 : 0,
        maximumFractionDigits: decimals ? 2 : 0,
    }).format(amount ?? 0);
}

export function compactNumber(value: number | null | undefined): string {
    return new Intl.NumberFormat('en-IN', { notation: 'compact', maximumFractionDigits: 1 }).format(
        value ?? 0,
    );
}

export function percent(value: number | null | undefined, decimals = 1): string {
    if (value === null || value === undefined) return '—';
    return `${value.toFixed(decimals)}%`;
}

/** "2:34 PM", "Yesterday 8:01 PM", "12 Aug, 8:01 PM" */
export function dateTime(value: string | Date | null | undefined): string {
    if (!value) return '—';
    const date = typeof value === 'string' ? new Date(value) : value;
    if (Number.isNaN(date.getTime())) return '—';

    if (isToday(date)) return format(date, 'h:mm a');
    if (isYesterday(date)) return `Yesterday ${format(date, 'h:mm a')}`;
    return format(date, 'd MMM, h:mm a');
}

export function dateOnly(value: string | Date | null | undefined): string {
    if (!value) return '—';
    const date = typeof value === 'string' ? new Date(value) : value;
    if (Number.isNaN(date.getTime())) return '—';
    return format(date, 'd MMM yyyy');
}

/** "4 min ago" */
export function relativeTime(value: string | Date | null | undefined): string {
    if (!value) return '—';
    const date = typeof value === 'string' ? new Date(value) : value;
    if (Number.isNaN(date.getTime())) return '—';
    return `${formatDistanceToNowStrict(date)} ago`;
}

/** mm:ss for kitchen and dispatch timers, h m past an hour. */
export function elapsed(seconds: number | null | undefined): string {
    const total = Math.max(0, Math.floor(seconds ?? 0));
    const mins = Math.floor(total / 60);
    if (mins < 60) return `${mins}:${(total % 60).toString().padStart(2, '0')}`;
    return `${Math.floor(mins / 60)}h ${mins % 60}m`;
}

/** ORDER_PLACED → Order placed */
export function humanise(value: string | null | undefined): string {
    if (!value) return '—';
    const spaced = value.replace(/_/g, ' ').toLowerCase();
    return spaced.charAt(0).toUpperCase() + spaced.slice(1);
}

export function initials(name: string | null | undefined): string {
    if (!name) return '—';
    return name
        .trim()
        .split(/\s+/)
        .slice(0, 2)
        .map((part) => part.charAt(0).toUpperCase())
        .join('');
}

/** Public storage object → CDN URL. */
export function storageUrl(path: string | null | undefined, bucket = 'menu-images'): string | null {
    if (!path) return null;
    if (path.startsWith('http')) return path;

    const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
    if (!base) return null;

    // Seeded paths already include the bucket prefix (e.g. "menu-images/...").
    const [maybeBucket, ...rest] = path.split('/');
    const knownBuckets = ['menu-images', 'banners', 'brand-assets', 'staff-photos'];
    const resolvedBucket = maybeBucket && knownBuckets.includes(maybeBucket) ? maybeBucket : bucket;
    const objectPath = maybeBucket && knownBuckets.includes(maybeBucket) ? rest.join('/') : path;

    return `${base}/storage/v1/object/public/${resolvedBucket}/${objectPath}`;
}

export function csvEscape(value: unknown): string {
    if (value === null || value === undefined) return '';
    const text = String(value);
    return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/** Builds a CSV blob from rows for the report export buttons. */
export function toCsv(rows: Array<Record<string, unknown>>, columns?: string[]): string {
    if (rows.length === 0) return '';
    const keys = columns ?? Object.keys(rows[0]!);
    const header = keys.join(',');
    const body = rows.map((row) => keys.map((key) => csvEscape(row[key])).join(',')).join('\n');
    return `${header}\n${body}`;
}

export function downloadCsv(filename: string, csv: string) {
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.click();
    URL.revokeObjectURL(url);
}
