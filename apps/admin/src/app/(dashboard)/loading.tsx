import { Skeleton } from '@/components/ui/states';

/** Streaming skeleton so navigation feels instant even on a slow connection. */
export default function DashboardLoading() {
    return (
        <div aria-busy="true" aria-live="polite">
            <span className="sr-only">Loading…</span>

            <div className="mb-6 space-y-2">
                <Skeleton className="h-7 w-56" />
                <Skeleton className="h-4 w-80" />
            </div>

            <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                {Array.from({ length: 4 }).map((_, index) => (
                    <Skeleton key={index} className="h-28 rounded-[var(--radius-card)]" />
                ))}
            </div>

            <Skeleton className="mt-5 h-72 rounded-[var(--radius-card)]" />
            <Skeleton className="mt-4 h-56 rounded-[var(--radius-card)]" />
        </div>
    );
}
