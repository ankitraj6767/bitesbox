import * as React from 'react';
import Link from 'next/link';
import { ChevronRight } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface Breadcrumb {
    label: string;
    href?: string;
}

export function PageHeader({
    title,
    description,
    breadcrumbs,
    actions,
    className,
}: {
    title: React.ReactNode;
    description?: React.ReactNode;
    breadcrumbs?: Breadcrumb[];
    actions?: React.ReactNode;
    className?: string;
}) {
    return (
        <div className={cn('mb-5 flex flex-col gap-3 lg:mb-6', className)}>
            {breadcrumbs && breadcrumbs.length > 0 ? (
                <nav aria-label="Breadcrumb">
                    <ol className="flex items-center gap-1 text-[12.5px] text-ink-muted">
                        {breadcrumbs.map((crumb, index) => (
                            <li key={`${crumb.label}-${index}`} className="flex items-center gap-1">
                                {index > 0 ? <ChevronRight className="size-3.5 text-hairline" aria-hidden /> : null}
                                {crumb.href ? (
                                    <Link href={crumb.href} className="transition-colors hover:text-ink">
                                        {crumb.label}
                                    </Link>
                                ) : (
                                    <span className="text-ink">{crumb.label}</span>
                                )}
                            </li>
                        ))}
                    </ol>
                </nav>
            ) : null}

            <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                    <h1 className="font-display text-[22px] leading-tight font-semibold tracking-tight text-ink">
                        {title}
                    </h1>
                    {description ? (
                        <p className="mt-1 max-w-2xl text-[13.5px] leading-relaxed text-ink-muted text-balance">
                            {description}
                        </p>
                    ) : null}
                </div>
                {actions ? <div className="flex shrink-0 flex-wrap items-center gap-2">{actions}</div> : null}
            </div>
        </div>
    );
}
