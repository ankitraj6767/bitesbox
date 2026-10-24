import { Skeleton } from '@/components/ui/states';

/**
 * Public, non-personalized shell shown while the server verifies staff access.
 * It lets the browser paint immediately without exposing any page or role data.
 */
export function DashboardShellLoading() {
    return (
        <div aria-busy="true" aria-live="polite" className="flex min-h-dvh">
            <span className="sr-only">Loading the operations dashboard…</span>

            <aside className="hidden w-[262px] shrink-0 border-r border-hairline bg-surface px-3 py-4 lg:block" aria-hidden="true">
                <div className="mb-7 flex items-center gap-2.5 px-1">
                    <Skeleton className="size-8 rounded-lg" />
                    <div className="space-y-1.5">
                        <Skeleton className="h-3.5 w-24" />
                        <Skeleton className="h-3 w-32" />
                    </div>
                </div>
                {[4, 3, 4, 3].map((count, group) => (
                    <div className="mb-6 space-y-2" key={group}>
                        <Skeleton className="ml-2 h-2.5 w-16" />
                        {Array.from({ length: count }, (_, index) => (
                            <Skeleton className="h-9 rounded-md" key={index} />
                        ))}
                    </div>
                ))}
            </aside>

            <div className="flex min-w-0 flex-1 flex-col">
                <header className="flex h-14 shrink-0 items-center justify-between border-b border-hairline bg-surface px-4 lg:px-6" aria-hidden="true">
                    <Skeleton className="h-9 w-56 max-w-[48vw] rounded-full" />
                    <div className="flex items-center gap-3">
                        <Skeleton className="hidden h-9 w-36 rounded-full sm:block" />
                        <Skeleton className="size-9 rounded-full" />
                    </div>
                </header>
                <main id="main" className="min-w-0 flex-1 px-4 py-5 lg:px-6 lg:py-6">
                    <div className="mb-6 space-y-2" aria-hidden="true">
                        <Skeleton className="h-7 w-56" />
                        <Skeleton className="h-4 w-80 max-w-full" />
                    </div>
                    <div className="grid grid-cols-2 gap-3 lg:grid-cols-4" aria-hidden="true">
                        {Array.from({ length: 4 }, (_, index) => <Skeleton key={index} className="h-28 rounded-[var(--radius-card)]" />)}
                    </div>
                    <Skeleton className="mt-5 h-72 rounded-[var(--radius-card)]" aria-hidden="true" />
                </main>
            </div>
        </div>
    );
}
