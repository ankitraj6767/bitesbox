'use client';

import * as React from 'react';
import { AlertTriangle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';

/**
 * Route-level error boundary. Shows the operator something actionable instead of
 * a blank screen, and keeps the sidebar usable so they can carry on working.
 */
export default function DashboardError({
    error,
    reset,
}: {
    error: Error & { digest?: string };
    reset: () => void;
}) {
    React.useEffect(() => {
        // Sentry (or any configured reporter) picks this up in production.
        console.error('Dashboard route error', error);
    }, [error]);

    return (
        <Card className="mx-auto max-w-lg p-8 text-center">
            <span className="mx-auto flex size-12 items-center justify-center rounded-full bg-critical-soft text-critical">
                <AlertTriangle className="size-6" aria-hidden />
            </span>

            <h1 className="mt-5 font-display text-lg font-semibold tracking-tight text-ink">
                This screen hit a problem
            </h1>
            <p className="mt-2 text-[13.5px] leading-relaxed text-ink-muted text-balance">
                Nothing has been lost. Try again, and if it keeps happening send this reference to whoever
                maintains the platform.
            </p>

            {error.digest ? (
                <p className="mt-3 font-mono text-[11.5px] text-ink-muted">reference {error.digest}</p>
            ) : null}

            <div className="mt-6 flex items-center justify-center gap-2">
                <Button onClick={reset}>Try again</Button>
                <Button variant="secondary" onClick={() => window.location.reload()}>
                    Reload the page
                </Button>
            </div>
        </Card>
    );
}
