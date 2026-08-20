import * as React from 'react';
import { cn } from '@/lib/utils';

export function Card({ className, ...props }: React.ComponentProps<'div'>) {
    return (
        <div
            className={cn(
                'rounded-[var(--radius-card)] border border-hairline bg-surface shadow-[var(--shadow-card)]',
                className,
            )}
            {...props}
        />
    );
}

export function CardHeader({ className, ...props }: React.ComponentProps<'div'>) {
    return (
        <div
            className={cn('flex flex-col gap-1 px-5 pt-5 pb-3', className)}
            {...props}
        />
    );
}

export function CardTitle({ className, ...props }: React.ComponentProps<'h3'>) {
    return (
        <h3
            className={cn('font-display text-[15px] font-semibold tracking-tight text-ink', className)}
            {...props}
        />
    );
}

export function CardDescription({ className, ...props }: React.ComponentProps<'p'>) {
    return <p className={cn('text-[13px] leading-relaxed text-ink-muted', className)} {...props} />;
}

export function CardContent({ className, ...props }: React.ComponentProps<'div'>) {
    return <div className={cn('px-5 pb-5', className)} {...props} />;
}

export function CardFooter({ className, ...props }: React.ComponentProps<'div'>) {
    return (
        <div
            className={cn('flex items-center gap-2 border-t border-hairline px-5 py-3.5', className)}
            {...props}
        />
    );
}

/** Header row with an action slot on the right. */
export function CardToolbar({
    title,
    description,
    action,
    className,
}: {
    title: React.ReactNode;
    description?: React.ReactNode;
    action?: React.ReactNode;
    className?: string;
}) {
    return (
        <div className={cn('flex items-start justify-between gap-4 px-5 pt-5 pb-3', className)}>
            <div className="min-w-0">
                <CardTitle>{title}</CardTitle>
                {description ? <CardDescription className="mt-0.5">{description}</CardDescription> : null}
            </div>
            {action ? <div className="flex shrink-0 items-center gap-2">{action}</div> : null}
        </div>
    );
}
