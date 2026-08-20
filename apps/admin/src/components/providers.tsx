'use client';

import * as React from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'sonner';
import { TooltipProvider } from '@/components/ui/overlays';
import { normaliseError } from '@/lib/errors';
import { isRetryable } from '@bitesbox/shared-types';

/**
 * Retry only genuinely transient failures. A PERMISSION_DENIED or
 * ITEM_UNAVAILABLE will never succeed on retry, and hammering the API on a
 * shaky connection makes the dashboard feel slower, not more reliable.
 */
function shouldRetry(failureCount: number, error: unknown): boolean {
    if (failureCount >= 2) return false;
    return isRetryable(normaliseError(error).code);
}

export function Providers({ children }: { children: React.ReactNode }) {
    const [queryClient] = React.useState(
        () =>
            new QueryClient({
                defaultOptions: {
                    queries: {
                        staleTime: 30_000,
                        gcTime: 5 * 60_000,
                        refetchOnWindowFocus: true,
                        retry: shouldRetry,
                    },
                    mutations: {
                        retry: false,
                    },
                },
            }),
    );

    return (
        <QueryClientProvider client={queryClient}>
            <TooltipProvider delayDuration={250}>
                {children}
                <Toaster
                    position="bottom-right"
                    closeButton
                    richColors
                    toastOptions={{
                        classNames: {
                            toast:
                                'rounded-[var(--radius-control)] border border-hairline bg-surface text-ink shadow-[var(--shadow-raised)]',
                            description: 'text-ink-muted',
                        },
                    }}
                />
            </TooltipProvider>
        </QueryClientProvider>
    );
}
