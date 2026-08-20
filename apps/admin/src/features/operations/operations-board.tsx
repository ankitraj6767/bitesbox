'use client';

import * as React from 'react';
import Link from 'next/link';
import {
    Bike,
    Check,
    ChefHat,
    Clock,
    IndianRupee,
    MapPin,
    PackageCheck,
    Phone,
    RefreshCw,
    Wifi,
    WifiOff,
    X,
} from 'lucide-react';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge, OrderStatusBadge } from '@/components/ui/badge';
import { MiniStat } from '@/components/ui/stat-card';
import { EmptyState, ErrorState, InlineNotice, Skeleton } from '@/components/ui/states';
import { Tooltip } from '@/components/ui/overlays';
import { cn, elapsed, money, humanise, relativeTime } from '@/lib/utils';
import { useLiveOperations } from './use-live-operations';
import { useOrderActions } from './order-actions';
import { AssignRiderDialog } from './assign-rider-dialog';
import { RejectOrderDialog } from './reject-order-dialog';
import {
    OPERATIONS_COLUMNS,
    type OperationsColumn,
    type OperationsOrderCard,
} from '@bitesbox/shared-types';

const COLUMN_LABELS: Record<OperationsColumn, string> = {
    NEW: 'New',
    ACCEPTED: 'Accepted',
    PREPARING: 'Preparing',
    READY: 'Ready',
    RIDER_ASSIGNED: 'With rider',
    OUT_FOR_DELIVERY: 'Out for delivery',
    DELIVERED: 'Delivered',
};

const COLUMN_ACCENT: Record<OperationsColumn, string> = {
    NEW: 'bg-brand-500',
    ACCEPTED: 'bg-info',
    PREPARING: 'bg-turmeric-500',
    READY: 'bg-caution',
    RIDER_ASSIGNED: 'bg-info',
    OUT_FOR_DELIVERY: 'bg-herb-500',
    DELIVERED: 'bg-positive',
};

export function OperationsBoard({
    branchId,
    canAssign,
    canOperate,
    canCancel,
}: {
    branchId: string | null;
    canAssign: boolean;
    canOperate: boolean;
    canCancel: boolean;
}) {
    const { data, isPending, isError, error, refetch, isFetching, connected, lastEventAt } =
        useLiveOperations(branchId);

    const [assignFor, setAssignFor] = React.useState<OperationsOrderCard | null>(null);
    const [rejectFor, setRejectFor] = React.useState<{
        order: OperationsOrderCard;
        mode: 'reject' | 'cancel';
    } | null>(null);

    if (isPending) {
        return (
            <div className="grid gap-3 lg:grid-cols-3 xl:grid-cols-4">
                {Array.from({ length: 4 }).map((_, index) => (
                    <Card key={index} className="p-4">
                        <Skeleton className="h-4 w-24" />
                        <Skeleton className="mt-4 h-24 w-full" />
                        <Skeleton className="mt-2 h-24 w-full" />
                    </Card>
                ))}
            </div>
        );
    }

    if (isError || !data) {
        return (
            <Card>
                <ErrorState
                    title="Could not load live operations"
                    message={error instanceof Error ? error.message : undefined}
                    onRetry={() => void refetch()}
                />
            </Card>
        );
    }

    const columns = data.columns ?? {};
    const alerts = data.alerts ?? [];

    return (
        <>
            {/* ── Live strip ── */}
            <div className="mb-4 flex flex-wrap items-center gap-3">
                <div className="grid flex-1 grid-cols-2 gap-2 sm:grid-cols-4">
                    <MiniStat label="Active orders" value={data.stats.active_orders} />
                    <MiniStat
                        label="Delayed"
                        value={data.stats.delayed_orders}
                        tone={data.stats.delayed_orders > 0 ? 'critical' : 'positive'}
                    />
                    <MiniStat label="Riders online" value={data.stats.online_riders} tone="info" />
                    <MiniStat
                        label="Awaiting payment"
                        value={data.stats.unpaid_orders}
                        tone={data.stats.unpaid_orders > 0 ? 'caution' : 'neutral'}
                    />
                </div>

                <div className="flex items-center gap-2">
                    <Tooltip
                        content={
                            connected
                                ? `Live. ${lastEventAt ? `Last update ${relativeTime(lastEventAt)}` : 'Waiting for changes.'}`
                                : 'Realtime disconnected — falling back to polling every 20 seconds.'
                        }
                    >
                        <span
                            className={cn(
                                'inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11.5px] font-semibold',
                                connected
                                    ? 'border-positive/20 bg-positive-soft text-positive'
                                    : 'border-caution/25 bg-caution-soft text-caution',
                            )}
                        >
                            {connected ? <Wifi className="size-3" aria-hidden /> : <WifiOff className="size-3" aria-hidden />}
                            {connected ? 'Live' : 'Polling'}
                        </span>
                    </Tooltip>

                    <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => void refetch()}
                        loading={isFetching}
                        aria-label="Refresh board"
                    >
                        <RefreshCw />
                        Refresh
                    </Button>
                </div>
            </div>

            {/* ── Alerts ── */}
            {alerts.length > 0 ? (
                <div className="mb-4 space-y-2">
                    {alerts.slice(0, 5).map((alert, index) => (
                        <InlineNotice
                            key={`${alert.type}-${alert.order_number ?? alert.ticket_number ?? index}`}
                            tone={alert.severity === '1' ? 'critical' : 'caution'}
                        >
                            <span className="flex flex-wrap items-center gap-2">
                                <span className="font-semibold">{humanise(alert.type)}</span>
                                <span className="font-normal">{alert.message}</span>
                                {alert.order_id ? (
                                    <Link
                                        href={`/orders/${alert.order_id}`}
                                        className="font-semibold underline underline-offset-2"
                                    >
                                        Open order
                                    </Link>
                                ) : null}
                            </span>
                        </InlineNotice>
                    ))}
                </div>
            ) : null}

            {/* ── Board ── */}
            <div className="scroll-slim -mx-4 flex gap-3 overflow-x-auto px-4 pb-2 lg:mx-0 lg:px-0">
                {OPERATIONS_COLUMNS.map((column) => {
                    const orders = columns[column] ?? [];

                    return (
                        <section
                            key={column}
                            aria-label={COLUMN_LABELS[column]}
                            className="flex w-[286px] shrink-0 flex-col rounded-[var(--radius-card)] border border-hairline bg-surface-muted/40"
                        >
                            <header className="flex items-center gap-2 px-3 py-2.5">
                                <span className={cn('size-2 rounded-full', COLUMN_ACCENT[column])} aria-hidden />
                                <h3 className="text-[12.5px] font-semibold text-ink">{COLUMN_LABELS[column]}</h3>
                                <span className="tnum ml-auto rounded-full bg-surface px-1.5 text-[11.5px] font-semibold text-ink-muted">
                                    {orders.length}
                                </span>
                            </header>

                            <div className="scroll-slim flex max-h-[calc(100dvh-19rem)] flex-1 flex-col gap-2 overflow-y-auto px-2 pb-2">
                                {orders.length === 0 ? (
                                    <p className="px-2 py-6 text-center text-[12.5px] text-ink-muted">Nothing here</p>
                                ) : (
                                    orders.map((order) => (
                                        <OrderCard
                                            key={order.id}
                                            order={order}
                                            column={column}
                                            canAssign={canAssign}
                                            canOperate={canOperate}
                                            canCancel={canCancel}
                                            onAssign={() => setAssignFor(order)}
                                            onReject={(mode) => setRejectFor({ order, mode })}
                                        />
                                    ))
                                )}
                            </div>
                        </section>
                    );
                })}
            </div>

            {/* ── Rider roster ── */}
            <Card className="mt-5">
                <CardToolbar
                    title="Delivery partners on duty"
                    description="Ranked exactly as the dispatch dialog ranks them"
                    action={
                        <Button asChild variant="ghost" size="sm">
                            <Link href="/delivery">Manage riders</Link>
                        </Button>
                    }
                />
                <CardContent>
                    {data.riders.length === 0 ? (
                        <EmptyState
                            icon={Bike}
                            title="No delivery partner is online"
                            description="Ask a rider to go online in the Bites Box app before the next order is ready."
                        />
                    ) : (
                        <ul className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
                            {data.riders.map((rider) => (
                                <li
                                    key={rider.delivery_partner_id}
                                    className="flex items-center gap-3 rounded-[var(--radius-control)] border border-hairline bg-surface px-3 py-2.5"
                                >
                                    <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink-muted">
                                        <Bike className="size-4" aria-hidden />
                                    </span>
                                    <div className="min-w-0 flex-1">
                                        <p className="truncate text-[13px] font-medium text-ink">{rider.full_name}</p>
                                        <p className="truncate text-[11.5px] text-ink-muted">
                                            {rider.active_load}/{rider.max_concurrent_orders} active
                                            {rider.distance_to_store_km !== null
                                                ? ` · ${rider.distance_to_store_km.toFixed(1)} km away`
                                                : ' · location unknown'}
                                        </p>
                                    </div>
                                    <Badge tone={rider.duty_state === 'AVAILABLE' ? 'positive' : 'caution'} className="shrink-0">
                                        {rider.duty_state === 'AVAILABLE' ? 'Free' : 'Busy'}
                                    </Badge>
                                </li>
                            ))}
                        </ul>
                    )}
                </CardContent>
            </Card>

            <AssignRiderDialog
                open={assignFor !== null}
                onOpenChange={(open) => !open && setAssignFor(null)}
                orderId={assignFor?.id ?? null}
                orderNumber={assignFor?.order_number ?? null}
                currentRiderName={assignFor?.rider_name}
                riders={data.riders}
            />

            <RejectOrderDialog
                open={rejectFor !== null}
                onOpenChange={(open) => !open && setRejectFor(null)}
                mode={rejectFor?.mode ?? 'reject'}
                orderId={rejectFor?.order.id ?? null}
                orderNumber={rejectFor?.order.order_number ?? null}
                refundableAmount={rejectFor?.order.grand_total ?? 0}
                isPaid={rejectFor?.order.payment_status === 'CAPTURED'}
            />
        </>
    );
}

function OrderCard({
    order,
    column,
    canAssign,
    canOperate,
    canCancel,
    onAssign,
    onReject,
}: {
    order: OperationsOrderCard;
    column: OperationsColumn;
    canAssign: boolean;
    canOperate: boolean;
    canCancel: boolean;
    onAssign: () => void;
    onReject: (mode: 'reject' | 'cancel') => void;
}) {
    const { accept, startPreparing, markReady } = useOrderActions();
    const busy = accept.isPending || startPreparing.isPending || markReady.isPending;

    const isCod = order.payment_mode === 'COD' || order.payment_mode === 'SPLIT_WALLET_COD';
    const unpaid = order.payment_status !== 'CAPTURED';

    return (
        <article
            className={cn(
                'rounded-[var(--radius-control)] border bg-surface p-3 shadow-xs transition-shadow hover:shadow-[var(--shadow-card)]',
                order.is_delayed ? 'border-critical/35' : 'border-hairline',
            )}
        >
            <div className="flex items-start justify-between gap-2">
                <Link
                    href={`/orders/${order.id}`}
                    className="min-w-0 font-mono text-[12.5px] font-semibold text-ink hover:text-brand-600"
                >
                    {order.order_number.replace('BB-BKP01-', '')}
                </Link>

                <span
                    className={cn(
                        'tnum inline-flex shrink-0 items-center gap-1 rounded-full px-1.5 py-0.5 text-[11px] font-semibold',
                        order.is_delayed ? 'bg-critical-soft text-critical' : 'bg-surface-muted text-ink-muted',
                    )}
                >
                    <Clock className="size-3" aria-hidden />
                    {elapsed(order.elapsed_seconds)}
                </span>
            </div>

            <p className="mt-1.5 truncate text-[13px] font-medium text-ink">
                {order.customer_name ?? 'Customer'}
            </p>

            <div className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-[11.5px] text-ink-muted">
                <span className="inline-flex items-center gap-1">
                    <PackageCheck className="size-3" aria-hidden />
                    {order.unit_count} item{order.unit_count === 1 ? '' : 's'}
                </span>
                <span className="tnum inline-flex items-center gap-0.5">
                    <IndianRupee className="size-3" aria-hidden />
                    {money(order.grand_total).replace('₹', '')}
                </span>
                {order.fulfilment_type === 'PICKUP' ? (
                    <Badge tone="brand" className="px-1.5 py-0">
                        Pickup
                    </Badge>
                ) : order.area ? (
                    <span className="inline-flex min-w-0 items-center gap-1">
                        <MapPin className="size-3 shrink-0" aria-hidden />
                        <span className="truncate">{order.area}</span>
                    </span>
                ) : null}
            </div>

            <div className="mt-2 flex flex-wrap items-center gap-1.5">
                {isCod ? (
                    <Badge tone="caution" className="px-1.5 py-0">
                        COD
                    </Badge>
                ) : unpaid ? (
                    <Badge tone="critical" className="px-1.5 py-0">
                        Unpaid
                    </Badge>
                ) : (
                    <Badge tone="positive" className="px-1.5 py-0">
                        Paid
                    </Badge>
                )}

                {order.rider_name ? (
                    <Badge tone="info" className="max-w-full px-1.5 py-0">
                        <Bike className="size-2.5" aria-hidden />
                        <span className="truncate">{order.rider_name.split(' ')[0]}</span>
                    </Badge>
                ) : null}

                {column === 'DELIVERED' ? <OrderStatusBadge status={order.status} /> : null}
            </div>

            {/* Stage-appropriate actions only, so the board never offers an illegal move. */}
            {canOperate || canAssign || canCancel ? (
                <div className="mt-2.5 flex flex-wrap gap-1.5 border-t border-hairline pt-2.5">
                    {column === 'NEW' && canOperate ? (
                        <>
                            <Button
                                size="sm"
                                className="flex-1"
                                loading={accept.isPending}
                                disabled={busy}
                                onClick={() => accept.mutate({ orderId: order.id })}
                            >
                                <Check />
                                Accept
                            </Button>
                            {canCancel ? (
                                <Button
                                    size="sm"
                                    variant="outlineDestructive"
                                    onClick={() => onReject('reject')}
                                    aria-label={`Reject ${order.order_number}`}
                                >
                                    <X />
                                </Button>
                            ) : null}
                        </>
                    ) : null}

                    {column === 'ACCEPTED' && canOperate ? (
                        <Button
                            size="sm"
                            variant="secondary"
                            className="flex-1"
                            loading={startPreparing.isPending}
                            disabled={busy}
                            onClick={() => startPreparing.mutate(order.id)}
                        >
                            <ChefHat />
                            Start preparing
                        </Button>
                    ) : null}

                    {column === 'PREPARING' && canOperate ? (
                        <Button
                            size="sm"
                            variant="secondary"
                            className="flex-1"
                            loading={markReady.isPending}
                            disabled={busy}
                            onClick={() => markReady.mutate(order.id)}
                        >
                            <PackageCheck />
                            Mark ready
                        </Button>
                    ) : null}

                    {column === 'READY' && order.fulfilment_type === 'DELIVERY' && canAssign ? (
                        <Button size="sm" variant="secondary" className="flex-1" onClick={onAssign}>
                            <Bike />
                            Assign rider
                        </Button>
                    ) : null}

                    {(column === 'RIDER_ASSIGNED' || column === 'OUT_FOR_DELIVERY') && canAssign ? (
                        <Button size="sm" variant="ghost" className="flex-1" onClick={onAssign}>
                            <Bike />
                            Reassign
                        </Button>
                    ) : null}

                    {order.customer_phone ? (
                        <Button asChild size="sm" variant="ghost" aria-label="Call customer">
                            <a href={`tel:${order.customer_phone}`}>
                                <Phone />
                            </a>
                        </Button>
                    ) : null}
                </div>
            ) : null}
        </article>
    );
}
