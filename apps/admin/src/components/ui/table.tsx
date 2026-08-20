import * as React from 'react';
import { cn } from '@/lib/utils';

export function TableWrap({ className, ...props }: React.ComponentProps<'div'>) {
    return (
        <div
            className={cn(
                'scroll-slim w-full overflow-x-auto rounded-[var(--radius-card)] border border-hairline bg-surface',
                className,
            )}
            {...props}
        />
    );
}

export function Table({ className, ...props }: React.ComponentProps<'table'>) {
    return <table className={cn('w-full caption-bottom text-sm', className)} {...props} />;
}

export function THead({ className, ...props }: React.ComponentProps<'thead'>) {
    return (
        <thead
            className={cn('border-b border-hairline bg-surface-muted/60', className)}
            {...props}
        />
    );
}

export function TBody({ className, ...props }: React.ComponentProps<'tbody'>) {
    return <tbody className={cn('divide-y divide-hairline', className)} {...props} />;
}

export function TR({ className, ...props }: React.ComponentProps<'tr'>) {
    return <tr className={cn('transition-colors hover:bg-surface-muted/50', className)} {...props} />;
}

export function TH({
    className,
    numeric,
    ...props
}: React.ComponentProps<'th'> & { numeric?: boolean }) {
    return (
        <th
            scope="col"
            className={cn(
                'px-4 py-2.5 text-left text-[11.5px] font-semibold tracking-wider text-ink-muted uppercase',
                numeric && 'text-right',
                className,
            )}
            {...props}
        />
    );
}

export function TD({
    className,
    numeric,
    ...props
}: React.ComponentProps<'td'> & { numeric?: boolean }) {
    return (
        <td
            className={cn('px-4 py-3 align-middle text-ink', numeric && 'tnum text-right', className)}
            {...props}
        />
    );
}

/** Full-width row used for loading, empty and error states inside a table. */
export function TableMessageRow({
    colSpan,
    children,
}: {
    colSpan: number;
    children: React.ReactNode;
}) {
    return (
        <tr>
            <td colSpan={colSpan} className="px-4 py-14">
                {children}
            </td>
        </tr>
    );
}
