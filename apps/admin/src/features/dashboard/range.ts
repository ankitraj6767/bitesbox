export type RangeKey = 'today' | 'yesterday' | '7d' | '30d' | '90d' | 'mtd';

export const RANGE_OPTIONS: Array<{ value: RangeKey; label: string }> = [
    { value: 'today', label: 'Today' },
    { value: 'yesterday', label: 'Yesterday' },
    { value: '7d', label: 'Last 7 days' },
    { value: '30d', label: 'Last 30 days' },
    { value: '90d', label: 'Last 90 days' },
    { value: 'mtd', label: 'This month' },
];

/** Resolves a range key into ISO bounds for server-side reporting queries. */
export function resolveRange(key: RangeKey): { from: string; to: string; label: string } {
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const option = RANGE_OPTIONS.find((item) => item.value === key) ?? RANGE_OPTIONS[0]!;

    switch (key) {
        case 'yesterday': {
            const start = new Date(startOfToday);
            start.setDate(start.getDate() - 1);
            return { from: start.toISOString(), to: startOfToday.toISOString(), label: option.label };
        }
        case '7d': {
            const start = new Date(startOfToday);
            start.setDate(start.getDate() - 6);
            return { from: start.toISOString(), to: now.toISOString(), label: option.label };
        }
        case '30d': {
            const start = new Date(startOfToday);
            start.setDate(start.getDate() - 29);
            return { from: start.toISOString(), to: now.toISOString(), label: option.label };
        }
        case '90d': {
            const start = new Date(startOfToday);
            start.setDate(start.getDate() - 89);
            return { from: start.toISOString(), to: now.toISOString(), label: option.label };
        }
        case 'mtd': {
            const start = new Date(now.getFullYear(), now.getMonth(), 1);
            return { from: start.toISOString(), to: now.toISOString(), label: option.label };
        }
        case 'today':
        default:
            return { from: startOfToday.toISOString(), to: now.toISOString(), label: 'Today' };
    }
}
