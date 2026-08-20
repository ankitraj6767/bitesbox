import * as React from 'react';
import { Check, Circle, ShieldAlert } from 'lucide-react';
import { cn, dateTime, humanise } from '@/lib/utils';
import { Badge } from '@/components/ui/badge';
import type { OrderTimelineEntry } from '@bitesbox/shared-types';

/**
 * Append-only order history, rendered newest-last so it reads like a story.
 * Overrides are flagged because they mean someone bypassed the state machine.
 */
export function OrderTimeline({ entries }: { entries: OrderTimelineEntry[] }) {
    if (entries.length === 0) {
        return <p className="text-[13px] text-ink-muted">No status history yet.</p>;
    }

    return (
        <ol className="relative space-y-0">
            {entries.map((entry, index) => {
                const isLast = index === entries.length - 1;
                const failed = ['PAYMENT_FAILED', 'STORE_REJECTED', 'DELIVERY_FAILED'].includes(
                    entry.to_status,
                );
                const cancelled = ['CUSTOMER_CANCELLED', 'ADMIN_CANCELLED'].includes(entry.to_status);

                return (
                    <li key={`${entry.to_status}-${entry.created_at}-${index}`} className="flex gap-3">
                        {/* Rail */}
                        <div className="flex flex-col items-center">
                            <span
                                className={cn(
                                    'flex size-6 shrink-0 items-center justify-center rounded-full border-2 bg-surface',
                                    failed || cancelled
                                        ? 'border-critical text-critical'
                                        : isLast
                                            ? 'border-brand-600 text-brand-600'
                                            : 'border-positive text-positive',
                                )}
                            >
                                {failed || cancelled ? (
                                    <Circle className="size-2.5 fill-current" aria-hidden />
                                ) : isLast ? (
                                    <Circle className="size-2.5 fill-current" aria-hidden />
                                ) : (
                                    <Check className="size-3" aria-hidden />
                                )}
                            </span>
                            {!isLast ? <span className="w-0.5 flex-1 bg-hairline" aria-hidden /> : null}
                        </div>

                        <div className={cn('min-w-0 flex-1', isLast ? 'pb-0' : 'pb-4')}>
                            <div className="flex flex-wrap items-center gap-2">
                                <p className="text-[13.5px] font-medium text-ink">{entry.label}</p>
                                {entry.is_override ? (
                                    <Badge tone="critical" className="px-1.5 py-0">
                                        <ShieldAlert className="size-2.5" aria-hidden />
                                        Override
                                    </Badge>
                                ) : null}
                                {entry.actor_kind !== 'USER' ? (
                                    <Badge tone="neutral" className="px-1.5 py-0">
                                        {humanise(entry.actor_kind)}
                                    </Badge>
                                ) : null}
                            </div>

                            <p className="mt-0.5 text-[12px] text-ink-muted">
                                {dateTime(entry.created_at)}
                                {entry.actor_role ? ` · ${humanise(entry.actor_role)}` : ''}
                            </p>

                            {entry.note ? (
                                <p className="mt-1 rounded-md bg-surface-muted px-2 py-1.5 text-[12.5px] leading-relaxed text-ink-muted">
                                    {entry.note}
                                </p>
                            ) : null}
                        </div>
                    </li>
                );
            })}
        </ol>
    );
}
