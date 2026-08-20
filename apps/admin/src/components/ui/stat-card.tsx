import * as React from 'react';
import { ArrowDownRight, ArrowUpRight, Minus } from 'lucide-react';
import { cn, percent } from '@/lib/utils';
import { Card } from './card';
import { Tooltip } from './overlays';

export function StatCard({
    label,
    value,
    delta,
    deltaLabel = 'vs previous period',
    hint,
    icon: Icon,
    tone = 'neutral',
    /** For metrics where a rise is bad (cancellations, refunds, failures). */
    invertDelta = false,
    className,
}: {
    label: string;
    value: React.ReactNode;
    delta?: number | null;
    deltaLabel?: string;
    hint?: string;
    icon?: React.ComponentType<{ className?: string }>;
    tone?: 'neutral' | 'positive' | 'caution' | 'critical' | 'brand';
    invertDelta?: boolean;
    className?: string;
}) {
    const tones = {
        neutral: 'text-ink-muted bg-surface-muted',
        positive: 'text-positive bg-positive-soft',
        caution: 'text-caution bg-caution-soft',
        critical: 'text-critical bg-critical-soft',
        brand: 'text-brand-700 bg-brand-50',
    } as const;

    const hasDelta = delta !== null && delta !== undefined && Number.isFinite(delta);
    const rising = hasDelta && delta! > 0;
    const flat = hasDelta && delta === 0;
    const good = invertDelta ? !rising : rising;

    return (
        <Card className={cn('p-4', className)}>
            <div className="flex items-start justify-between gap-3">
                <p className="text-[12.5px] font-medium text-ink-muted">{label}</p>
                {Icon ? (
                    <span className={cn('flex size-7 shrink-0 items-center justify-center rounded-lg', tones[tone])}>
                        <Icon className="size-3.5" />
                    </span>
                ) : null}
            </div>

            <p className="tnum mt-2 font-display text-[26px] leading-none font-semibold tracking-tight text-ink">
                {value}
            </p>

            <div className="mt-2 flex items-center gap-1.5 text-[12px]">
                {hasDelta ? (
                    <Tooltip content={deltaLabel}>
                        <span
                            className={cn(
                                'inline-flex items-center gap-0.5 rounded-full px-1.5 py-0.5 font-semibold',
                                flat
                                    ? 'bg-surface-muted text-ink-muted'
                                    : good
                                        ? 'bg-positive-soft text-positive'
                                        : 'bg-critical-soft text-critical',
                            )}
                        >
                            {flat ? (
                                <Minus className="size-3" aria-hidden />
                            ) : rising ? (
                                <ArrowUpRight className="size-3" aria-hidden />
                            ) : (
                                <ArrowDownRight className="size-3" aria-hidden />
                            )}
                            {percent(Math.abs(delta!), 1)}
                        </span>
                    </Tooltip>
                ) : null}
                {hint ? <span className="truncate text-ink-muted">{hint}</span> : null}
            </div>
        </Card>
    );
}

/** Compact live counter used in the operations header strip. */
export function MiniStat({
    label,
    value,
    tone = 'neutral',
}: {
    label: string;
    value: React.ReactNode;
    tone?: 'neutral' | 'positive' | 'caution' | 'critical' | 'info';
}) {
    const tones = {
        neutral: 'text-ink',
        positive: 'text-positive',
        caution: 'text-caution',
        critical: 'text-critical',
        info: 'text-info',
    } as const;

    return (
        <div className="rounded-[var(--radius-control)] border border-hairline bg-surface px-3 py-2">
            <p className="text-[11px] font-medium tracking-wide text-ink-muted uppercase">{label}</p>
            <p className={cn('tnum mt-0.5 font-display text-lg leading-none font-semibold', tones[tone])}>
                {value}
            </p>
        </div>
    );
}
