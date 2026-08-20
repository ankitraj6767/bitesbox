import * as React from 'react';
import { AlertTriangle, Inbox, Loader2, WifiOff } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from './button';

/**
 * Every screen in the dashboard uses these four states. Having them in one file
 * keeps loading, empty and error presentation consistent everywhere.
 */

export function Skeleton({ className, ...props }: React.ComponentProps<'div'>) {
    return (
        <div
            aria-hidden
            className={cn('animate-[var(--animate-shimmer)] rounded-md bg-surface-muted', className)}
            {...props}
        />
    );
}

export function LoadingBlock({ label = 'Loading', className }: { label?: string; className?: string }) {
    return (
        <div
            role="status"
            aria-live="polite"
            className={cn('flex flex-col items-center justify-center gap-3 py-12 text-ink-muted', className)}
        >
            <Loader2 className="size-5 animate-spin" aria-hidden />
            <p className="text-[13px]">{label}…</p>
        </div>
    );
}

export function EmptyState({
    icon: Icon = Inbox,
    title,
    description,
    action,
    className,
}: {
    icon?: React.ComponentType<{ className?: string }>;
    title: string;
    description?: string;
    action?: React.ReactNode;
    className?: string;
}) {
    return (
        <div className={cn('flex flex-col items-center justify-center gap-3 px-6 py-14 text-center', className)}>
            <span className="flex size-11 items-center justify-center rounded-full bg-surface-muted text-ink-muted">
                <Icon className="size-5" />
            </span>
            <div className="max-w-sm">
                <p className="font-display text-[15px] font-semibold text-ink">{title}</p>
                {description ? (
                    <p className="mt-1 text-[13px] leading-relaxed text-ink-muted text-balance">{description}</p>
                ) : null}
            </div>
            {action}
        </div>
    );
}

export function ErrorState({
    title = 'Could not load this',
    message,
    onRetry,
    offline = false,
    className,
}: {
    title?: string;
    message?: string;
    onRetry?: () => void;
    offline?: boolean;
    className?: string;
}) {
    const Icon = offline ? WifiOff : AlertTriangle;

    return (
        <div
            role="alert"
            className={cn('flex flex-col items-center justify-center gap-3 px-6 py-14 text-center', className)}
        >
            <span className="flex size-11 items-center justify-center rounded-full bg-critical-soft text-critical">
                <Icon className="size-5" />
            </span>
            <div className="max-w-sm">
                <p className="font-display text-[15px] font-semibold text-ink">{title}</p>
                {message ? (
                    <p className="mt-1 text-[13px] leading-relaxed text-ink-muted text-balance">{message}</p>
                ) : null}
            </div>
            {onRetry ? (
                <Button variant="secondary" size="sm" onClick={onRetry}>
                    Try again
                </Button>
            ) : null}
        </div>
    );
}

/** Small inline banner for warnings that do not block the screen. */
export function InlineNotice({
    tone = 'caution',
    children,
    className,
}: {
    tone?: 'caution' | 'critical' | 'info' | 'positive';
    children: React.ReactNode;
    className?: string;
}) {
    const tones = {
        caution: 'border-caution/25 bg-caution-soft text-caution',
        critical: 'border-critical/20 bg-critical-soft text-critical',
        info: 'border-info/20 bg-info-soft text-info',
        positive: 'border-positive/20 bg-positive-soft text-positive',
    } as const;

    return (
        <div
            className={cn(
                'flex items-start gap-2 rounded-[var(--radius-control)] border px-3 py-2 text-[13px] font-medium',
                tones[tone],
                className,
            )}
        >
            <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
            <div className="min-w-0">{children}</div>
        </div>
    );
}
