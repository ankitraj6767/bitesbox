'use client';

import * as React from 'react';
import { Bike, MapPin, Star, TriangleAlert } from 'lucide-react';
import {
    Dialog,
    DialogBody,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/overlays';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { EmptyState } from '@/components/ui/states';
import { cn, relativeTime } from '@/lib/utils';
import { useOrderActions } from './order-actions';
import type { AvailableRider } from '@bitesbox/shared-types';

/**
 * Manual dispatch. Riders arrive pre-ranked by the database
 * (`available_riders`): fewest active deliveries, then proximity, then rating.
 * The same score will drive automatic assignment later, so operators build
 * intuition for it now.
 */
export function AssignRiderDialog({
    open,
    onOpenChange,
    orderId,
    orderNumber,
    currentRiderName,
    riders,
}: {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    orderId: string | null;
    orderNumber: string | null;
    currentRiderName?: string | null;
    riders: AvailableRider[];
}) {
    const { assignRider } = useOrderActions();
    const [selected, setSelected] = React.useState<string | null>(null);

    React.useEffect(() => {
        if (open) setSelected(null);
    }, [open, orderId]);

    const submit = async () => {
        if (!orderId || !selected) return;
        await assignRider.mutateAsync({ orderId, deliveryPartnerId: selected });
        onOpenChange(false);
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent size="md">
                <DialogHeader>
                    <DialogTitle>
                        {currentRiderName ? 'Reassign delivery partner' : 'Assign a delivery partner'}
                    </DialogTitle>
                    <DialogDescription>
                        {orderNumber ? `Order ${orderNumber}. ` : ''}
                        {currentRiderName
                            ? `Currently with ${currentRiderName}. Reassigning is recorded in the audit log.`
                            : 'Ordered by workload, then distance from the kitchen, then rating.'}
                    </DialogDescription>
                </DialogHeader>

                <DialogBody className="max-h-80 overflow-y-auto scroll-slim p-0">
                    {riders.length === 0 ? (
                        <EmptyState
                            icon={TriangleAlert}
                            title="No delivery partner is free"
                            description="Every active rider is at capacity or offline. Ask someone to come online, or hold the order until one frees up."
                        />
                    ) : (
                        <ul className="divide-y divide-hairline">
                            {riders.map((rider) => {
                                const isSelected = selected === rider.delivery_partner_id;
                                const atCapacity = rider.active_load >= rider.max_concurrent_orders;

                                return (
                                    <li key={rider.delivery_partner_id}>
                                        <button
                                            type="button"
                                            disabled={atCapacity}
                                            onClick={() => setSelected(rider.delivery_partner_id)}
                                            className={cn(
                                                'flex w-full items-center gap-3 px-5 py-3 text-left transition-colors',
                                                isSelected ? 'bg-brand-50' : 'hover:bg-surface-muted',
                                                atCapacity && 'cursor-not-allowed opacity-50',
                                            )}
                                            aria-pressed={isSelected}
                                        >
                                            <span
                                                className={cn(
                                                    'flex size-9 shrink-0 items-center justify-center rounded-full',
                                                    isSelected ? 'bg-brand-600 text-white' : 'bg-surface-muted text-ink-muted',
                                                )}
                                            >
                                                <Bike className="size-4" aria-hidden />
                                            </span>

                                            <span className="min-w-0 flex-1">
                                                <span className="flex items-center gap-2">
                                                    <span className="truncate text-[13.5px] font-medium text-ink">
                                                        {rider.full_name}
                                                    </span>
                                                    <Badge
                                                        tone={rider.duty_state === 'AVAILABLE' ? 'positive' : 'caution'}
                                                        className="shrink-0"
                                                    >
                                                        {rider.duty_state === 'AVAILABLE' ? 'Free' : 'Busy'}
                                                    </Badge>
                                                </span>
                                                <span className="mt-0.5 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-[12px] text-ink-muted">
                                                    <span>
                                                        {rider.active_load}/{rider.max_concurrent_orders} active
                                                    </span>
                                                    {rider.distance_to_store_km !== null ? (
                                                        <span className="inline-flex items-center gap-1">
                                                            <MapPin className="size-3" aria-hidden />
                                                            {rider.distance_to_store_km.toFixed(1)} km away
                                                        </span>
                                                    ) : (
                                                        <span className="text-caution">No recent location</span>
                                                    )}
                                                    {rider.rating_average > 0 ? (
                                                        <span className="inline-flex items-center gap-1">
                                                            <Star className="size-3" aria-hidden />
                                                            {rider.rating_average.toFixed(1)}
                                                        </span>
                                                    ) : null}
                                                    {rider.last_location_at ? (
                                                        <span>seen {relativeTime(rider.last_location_at)}</span>
                                                    ) : null}
                                                </span>
                                            </span>

                                            <span className="tnum shrink-0 text-[11.5px] text-ink-muted">
                                                score {Math.round(rider.score)}
                                            </span>
                                        </button>
                                    </li>
                                );
                            })}
                        </ul>
                    )}
                </DialogBody>

                <DialogFooter>
                    <Button variant="secondary" onClick={() => onOpenChange(false)}>
                        Cancel
                    </Button>
                    <Button onClick={submit} loading={assignRider.isPending} disabled={!selected}>
                        {currentRiderName ? 'Reassign' : 'Assign'}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
