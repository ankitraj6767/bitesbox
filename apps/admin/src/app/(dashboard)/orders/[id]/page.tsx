import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import {
    Bike,
    CreditCard,
    MapPin,
    Phone,
    Star,
    Ticket,
    Timer,
    UserRound,
} from 'lucide-react';
import { activeBranchId, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Badge, FoodTypeMark, OrderStatusBadge, refundStatusTone } from '@/components/ui/badge';
import { InlineNotice } from '@/components/ui/states';
import { OrderActionsBar } from '@/features/orders/order-actions-bar';
import { OrderTimeline } from '@/features/orders/order-timeline';
import { PERMISSIONS, type OrderDetail } from '@bitesbox/shared-types';
import { dateTime, elapsed, money, humanise } from '@/lib/utils';

export const dynamic = 'force-dynamic';

export async function generateMetadata({
    params,
}: {
    params: Promise<{ id: string }>;
}): Promise<Metadata> {
    const { id } = await params;
    const supabase = await createSupabaseServerClient();
    const { data } = await supabase.from('orders').select('order_number').eq('id', id).maybeSingle();

    return { title: data?.order_number ?? 'Order' };
}

export default async function OrderDetailPage({ params }: { params: Promise<{ id: string }> }) {
    const [session, { id }] = await Promise.all([
        requirePermission(PERMISSIONS.ORDER_VIEW),
        params,
    ]);

    const supabase = await createSupabaseServerClient();

    const [detailResult, eligibilityResult] = await Promise.all([
        supabase.rpc('order_detail', { p_order_id: id }),
        supabase.rpc('refund_eligibility', { p_order_id: id }),
    ]);

    if (detailResult.error || !detailResult.data) {
        notFound();
    }

    const order = detailResult.data as unknown as OrderDetail;
    const eligibility = eligibilityResult.data as unknown as {
        refundable_amount: number;
        gateway_refund_possible: boolean;
    } | null;

    const refundable = eligibility?.refundable_amount ?? 0;
    const totals = order.totals;
    const permissions = session.permissions ?? [];

    return (
        <>
            <PageHeader
                breadcrumbs={[{ label: 'Orders', href: '/orders' }, { label: order.order_number }]}
                title={
                    <span className="flex flex-wrap items-center gap-2.5">
                        <span className="font-mono">{order.order_number}</span>
                        <OrderStatusBadge status={order.status} />
                        {order.timing === 'SCHEDULED' ? <Badge tone="brand">Scheduled</Badge> : null}
                        {order.customer.is_first_order ? <Badge tone="positive">First order</Badge> : null}
                    </span>
                }
                description={`Placed ${dateTime(order.timing_info ? undefined : order.timeline[0]?.created_at)} · ${order.fulfilment_type === 'PICKUP' ? 'Self pickup' : 'Delivery'
                    } · ${order.item_count} line${order.item_count === 1 ? '' : 's'}`}
                actions={
                    <OrderActionsBar
                        order={order}
                        refundable={refundable}
                        gatewayRefundPossible={eligibility?.gateway_refund_possible ?? false}
                        permissions={permissions}
                        branchId={activeBranchId(session)}
                    />
                }
            />

            {order.cancellation ? (
                <InlineNotice tone="critical" className="mb-4">
                    <span className="font-semibold">
                        {humanise(order.cancellation.actor)} cancelled this order
                    </span>
                    {order.cancellation.reason ? ` · ${humanise(order.cancellation.reason)}` : ''}
                    {order.cancellation.note ? ` — ${order.cancellation.note}` : ''}
                </InlineNotice>
            ) : null}

            {order.status === 'PENDING_PAYMENT' ? (
                <InlineNotice tone="caution" className="mb-4">
                    Awaiting payment. The order has not reached the kitchen and will expire automatically if
                    payment is not completed.
                </InlineNotice>
            ) : null}

            {totals.refunded_amount > 0 ? (
                <InlineNotice tone="info" className="mb-4">
                    {money(totals.refunded_amount, true)} has been refunded on this order.
                </InlineNotice>
            ) : null}

            <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_360px]">
                {/* ── Left column ── */}
                <div className="space-y-4">
                    {/* Items */}
                    <Card>
                        <CardToolbar
                            title="Items"
                            description="Snapshot taken when the order was placed"
                        />
                        <CardContent className="p-0">
                            <ul className="divide-y divide-hairline">
                                {order.items.map((item) => (
                                    <li
                                        key={item.id}
                                        className={item.is_cancelled ? 'bg-critical-soft/40 px-5 py-3' : 'px-5 py-3'}
                                    >
                                        <div className="flex items-start gap-3">
                                            <span className="tnum mt-0.5 shrink-0 rounded bg-surface-muted px-1.5 py-0.5 text-[12px] font-semibold text-ink">
                                                {item.quantity}×
                                            </span>

                                            <div className="min-w-0 flex-1">
                                                <p className="flex items-center gap-1.5 text-[13.5px] font-medium text-ink">
                                                    <FoodTypeMark type={item.food_type} />
                                                    <span className="truncate">{item.product_name}</span>
                                                </p>

                                                {item.variant_name ? (
                                                    <p className="mt-0.5 text-[12.5px] text-ink-muted">
                                                        {item.variant_option_group ?? 'Option'}: {item.variant_name}
                                                    </p>
                                                ) : null}

                                                {item.modifiers.length > 0 ? (
                                                    <ul className="mt-1 space-y-0.5">
                                                        {item.modifiers.map((modifier, index) => (
                                                            <li key={index} className="text-[12.5px] text-ink-muted">
                                                                + {modifier.modifier_name}
                                                                {modifier.quantity > 1 ? ` ×${modifier.quantity}` : ''}
                                                                {modifier.total_price > 0 ? (
                                                                    <span className="tnum"> ({money(modifier.total_price, true)})</span>
                                                                ) : null}
                                                            </li>
                                                        ))}
                                                    </ul>
                                                ) : null}

                                                {item.special_instructions ? (
                                                    <p className="mt-1.5 rounded-md bg-caution-soft px-2 py-1 text-[12.5px] font-medium text-caution">
                                                        “{item.special_instructions}”
                                                    </p>
                                                ) : null}

                                                {item.is_cancelled ? (
                                                    <Badge tone="critical" className="mt-1.5">
                                                        Removed by kitchen
                                                    </Badge>
                                                ) : null}
                                                {item.refunded_quantity > 0 ? (
                                                    <Badge tone="caution" className="mt-1.5">
                                                        {item.refunded_quantity} refunded
                                                    </Badge>
                                                ) : null}
                                            </div>

                                            <div className="shrink-0 text-right">
                                                <p className="tnum text-[13.5px] font-semibold text-ink">
                                                    {money(item.net_amount, true)}
                                                </p>
                                                {item.allocated_discount > 0 ? (
                                                    <p className="tnum text-[11.5px] text-positive">
                                                        − {money(item.allocated_discount, true)}
                                                    </p>
                                                ) : null}
                                            </div>
                                        </div>
                                    </li>
                                ))}
                            </ul>

                            {order.customer_note ? (
                                <div className="border-t border-hairline px-5 py-3">
                                    <p className="text-[11.5px] font-semibold tracking-wide text-ink-muted uppercase">
                                        Customer instructions
                                    </p>
                                    <p className="mt-1 text-[13px] text-ink">{order.customer_note}</p>
                                </div>
                            ) : null}
                        </CardContent>
                    </Card>

                    {/* Bill */}
                    <Card>
                        <CardToolbar title="Bill" description="Every value computed server-side" />
                        <CardContent>
                            <dl className="divide-y divide-hairline">
                                <BillRow label="Item subtotal" value={money(totals.items_subtotal, true)} />
                                {totals.coupon_discount > 0 ? (
                                    <BillRow
                                        label={`Coupon${totals.coupon_code ? ` · ${totals.coupon_code}` : ''}`}
                                        value={`− ${money(totals.coupon_discount, true)}`}
                                        tone="positive"
                                    />
                                ) : null}
                                {totals.promotion_discount > 0 ? (
                                    <BillRow
                                        label="Promotion"
                                        value={`− ${money(totals.promotion_discount, true)}`}
                                        tone="positive"
                                    />
                                ) : null}
                                {totals.packaging_charge > 0 ? (
                                    <BillRow label="Packaging" value={money(totals.packaging_charge, true)} />
                                ) : null}
                                <BillRow
                                    label="Delivery fee"
                                    value={
                                        totals.delivery_fee_waived > 0 && totals.delivery_fee === 0
                                            ? 'Free'
                                            : money(totals.delivery_fee, true)
                                    }
                                    tone={totals.delivery_fee === 0 ? 'positive' : 'neutral'}
                                />
                                {totals.service_fee > 0 ? (
                                    <BillRow label="Service fee" value={money(totals.service_fee, true)} />
                                ) : null}
                                {totals.tip_amount > 0 ? (
                                    <BillRow label="Tip for delivery partner" value={money(totals.tip_amount, true)} />
                                ) : null}
                                <BillRow
                                    label={`GST (CGST ${money(totals.cgst_amount, true)} + SGST ${money(totals.sgst_amount, true)})`}
                                    value={money(totals.tax_amount, true)}
                                    hint="Included in item prices"
                                />
                                {totals.round_off !== 0 ? (
                                    <BillRow label="Round off" value={money(totals.round_off, true)} />
                                ) : null}
                                {totals.wallet_applied > 0 ? (
                                    <BillRow
                                        label="Paid from wallet"
                                        value={`− ${money(totals.wallet_applied, true)}`}
                                        tone="positive"
                                    />
                                ) : null}
                                {totals.loyalty_discount > 0 ? (
                                    <BillRow
                                        label={`Loyalty (${totals.loyalty_points_redeemed} points)`}
                                        value={`− ${money(totals.loyalty_discount, true)}`}
                                        tone="positive"
                                    />
                                ) : null}
                                <BillRow label="Grand total" value={money(totals.grand_total, true)} emphasis />
                                {totals.refunded_amount > 0 ? (
                                    <BillRow
                                        label="Refunded"
                                        value={`− ${money(totals.refunded_amount, true)}`}
                                        tone="critical"
                                    />
                                ) : null}
                            </dl>
                        </CardContent>
                    </Card>

                    {/* Timeline */}
                    <Card>
                        <CardToolbar
                            title="Timeline"
                            description="Append-only history — the customer sees the same sequence"
                        />
                        <CardContent>
                            <OrderTimeline entries={order.timeline} />
                        </CardContent>
                    </Card>

                    {/* Internal notes */}
                    {order.internal_notes.length > 0 ? (
                        <Card>
                            <CardToolbar title="Internal notes" description="Staff only" />
                            <CardContent className="space-y-2">
                                {order.internal_notes.map((note) => (
                                    <div
                                        key={note.id}
                                        className="rounded-[var(--radius-control)] border border-hairline bg-surface-muted/50 px-3 py-2"
                                    >
                                        <p className="text-[13px] text-ink">{note.note}</p>
                                        <p className="mt-1 text-[11.5px] text-ink-muted">
                                            {note.author ?? 'System'} · {dateTime(note.created_at)}
                                        </p>
                                    </div>
                                ))}
                            </CardContent>
                        </Card>
                    ) : null}
                </div>

                {/* ── Right column ── */}
                <div className="space-y-4">
                    {/* Customer */}
                    <Card>
                        <CardToolbar title="Customer" />
                        <CardContent className="space-y-3">
                            <div className="flex items-start gap-3">
                                <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink-muted">
                                    <UserRound className="size-4" aria-hidden />
                                </span>
                                <div className="min-w-0">
                                    <Link
                                        href={`/customers/${order.customer.user_id}`}
                                        className="block truncate text-[13.5px] font-medium text-ink hover:text-brand-600"
                                    >
                                        {order.customer.name ?? 'Customer'}
                                    </Link>
                                    {order.customer.phone ? (
                                        <a
                                            href={`tel:${order.customer.phone}`}
                                            className="inline-flex items-center gap-1 text-[12.5px] text-ink-muted hover:text-ink"
                                        >
                                            <Phone className="size-3" aria-hidden />
                                            {order.customer.phone}
                                        </a>
                                    ) : null}
                                </div>
                            </div>

                            {order.fulfilment_type === 'DELIVERY' ? (
                                <div className="flex items-start gap-3 border-t border-hairline pt-3">
                                    <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink-muted">
                                        <MapPin className="size-4" aria-hidden />
                                    </span>
                                    <div className="min-w-0 text-[12.5px] leading-relaxed text-ink">
                                        <p>{order.delivery.address_line1}</p>
                                        {order.delivery.address_line2 ? <p>{order.delivery.address_line2}</p> : null}
                                        {order.delivery.landmark ? (
                                            <p className="text-ink-muted">Near {order.delivery.landmark}</p>
                                        ) : null}
                                        <p className="text-ink-muted">
                                            {[order.delivery.area, order.delivery.city, order.delivery.postal_code]
                                                .filter(Boolean)
                                                .join(', ')}
                                        </p>
                                        {order.delivery.zone_name ? (
                                            <p className="mt-1 text-ink-muted">
                                                {order.delivery.zone_name}
                                                {order.delivery.distance_km !== null
                                                    ? ` · ${order.delivery.distance_km.toFixed(1)} km`
                                                    : ''}
                                            </p>
                                        ) : null}
                                        {order.delivery.instructions ? (
                                            <p className="mt-1.5 rounded-md bg-surface-muted px-2 py-1 text-ink-muted">
                                                {order.delivery.instructions}
                                            </p>
                                        ) : null}
                                        {order.delivery.latitude && order.delivery.longitude ? (
                                            <a
                                                href={`https://maps.google.com/?q=${order.delivery.latitude},${order.delivery.longitude}`}
                                                target="_blank"
                                                rel="noreferrer noopener"
                                                className="mt-1.5 inline-block font-medium text-brand-600 hover:underline"
                                            >
                                                Open in Maps
                                            </a>
                                        ) : null}
                                    </div>
                                </div>
                            ) : (
                                <div className="border-t border-hairline pt-3 text-[12.5px] text-ink-muted">
                                    Self pickup from the outlet.
                                </div>
                            )}
                        </CardContent>
                    </Card>

                    {/* Payment */}
                    <Card>
                        <CardToolbar title="Payment" />
                        <CardContent className="space-y-2 text-[12.5px]">
                            <Row
                                icon={CreditCard}
                                label="Mode"
                                value={
                                    order.payment.mode === 'COD' || order.payment.mode === 'SPLIT_WALLET_COD'
                                        ? 'Cash on delivery'
                                        : 'Paid online'
                                }
                            />
                            <Row label="Status" value={humanise(order.payment.status)} />
                            {order.payment.method ? (
                                <Row label="Method" value={humanise(order.payment.method)} />
                            ) : null}
                            {order.payment.cod_status ? (
                                <Row label="Cash" value={humanise(order.payment.cod_status)} />
                            ) : null}
                            {order.payment.paid_at ? (
                                <Row label="Paid at" value={dateTime(order.payment.paid_at)} />
                            ) : null}
                            {order.payment.provider_payment_id ? (
                                <Row
                                    label="Gateway reference"
                                    value={<span className="font-mono text-[11.5px]">{order.payment.provider_payment_id}</span>}
                                />
                            ) : null}
                        </CardContent>
                    </Card>

                    {/* Rider */}
                    {order.rider ? (
                        <Card>
                            <CardToolbar title="Delivery partner" />
                            <CardContent className="space-y-2 text-[12.5px]">
                                <div className="flex items-start gap-3">
                                    <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink-muted">
                                        <Bike className="size-4" aria-hidden />
                                    </span>
                                    <div className="min-w-0">
                                        <p className="truncate text-[13.5px] font-medium text-ink">{order.rider.name}</p>
                                        <a
                                            href={`tel:${order.rider.phone}`}
                                            className="text-[12.5px] text-ink-muted hover:text-ink"
                                        >
                                            {order.rider.phone}
                                        </a>
                                        <p className="mt-0.5 text-[11.5px] text-ink-muted">
                                            {order.rider.vehicle_type ? humanise(order.rider.vehicle_type) : ''}
                                            {order.rider.vehicle_number ? ` · ${order.rider.vehicle_number}` : ''}
                                        </p>
                                    </div>
                                </div>

                                <Row label="Assignment" value={humanise(order.rider.assignment_status)} />

                                {order.rider.live_location ? (
                                    <>
                                        <Row
                                            label="Live position"
                                            value={
                                                order.rider.live_location.is_fresh ? (
                                                    <Badge tone="positive" dot>
                                                        Tracking
                                                    </Badge>
                                                ) : (
                                                    <Badge tone="caution">Stale fix</Badge>
                                                )
                                            }
                                        />
                                        {order.rider.live_location.eta_minutes !== null ? (
                                            <Row label="ETA" value={`${order.rider.live_location.eta_minutes} min`} />
                                        ) : null}
                                        <a
                                            href={`https://maps.google.com/?q=${order.rider.live_location.latitude},${order.rider.live_location.longitude}`}
                                            target="_blank"
                                            rel="noreferrer noopener"
                                            className="inline-block font-medium text-brand-600 hover:underline"
                                        >
                                            See rider on the map
                                        </a>
                                    </>
                                ) : null}
                            </CardContent>
                        </Card>
                    ) : null}

                    {/* Timing */}
                    <Card>
                        <CardToolbar title="Timing" />
                        <CardContent className="space-y-2 text-[12.5px]">
                            {order.timeline.length > 0 ? (
                                <Row
                                    icon={Timer}
                                    label="Total elapsed"
                                    value={elapsed(
                                        (new Date().getTime() -
                                            new Date(order.timeline[0]!.created_at).getTime()) /
                                        1000,
                                    )}
                                />
                            ) : null}
                            {order.scheduled_for ? (
                                <Row label="Scheduled for" value={dateTime(order.scheduled_for)} />
                            ) : null}
                        </CardContent>
                    </Card>

                    {/* Refunds */}
                    {order.refunds.length > 0 ? (
                        <Card>
                            <CardToolbar title="Refunds" />
                            <CardContent className="space-y-2">
                                {order.refunds.map((refund) => (
                                    <div
                                        key={refund.id}
                                        className="rounded-[var(--radius-control)] border border-hairline px-3 py-2"
                                    >
                                        <div className="flex items-center justify-between gap-2">
                                            <span className="tnum text-[13px] font-semibold text-ink">
                                                {money(refund.amount, true)}
                                            </span>
                                            <Badge tone={refundStatusTone(refund.status)}>{humanise(refund.status)}</Badge>
                                        </div>
                                        <p className="mt-1 text-[11.5px] text-ink-muted">
                                            {humanise(refund.reason)} · {humanise(refund.destination)}
                                        </p>
                                        <p className="text-[11.5px] text-ink-muted">{dateTime(refund.created_at)}</p>
                                    </div>
                                ))}
                            </CardContent>
                        </Card>
                    ) : null}

                    {/* Review */}
                    {order.review ? (
                        <Card>
                            <CardToolbar title="Customer rating" />
                            <CardContent className="space-y-1.5 text-[12.5px]">
                                <div className="flex items-center gap-1">
                                    {Array.from({ length: 5 }).map((_, index) => (
                                        <Star
                                            key={index}
                                            className={
                                                index < order.review!.overall_rating
                                                    ? 'size-3.5 fill-turmeric-500 text-turmeric-500'
                                                    : 'size-3.5 text-hairline'
                                            }
                                            aria-hidden
                                        />
                                    ))}
                                    <span className="ml-1 text-ink-muted">
                                        {order.review.overall_rating}/5 overall
                                    </span>
                                </div>
                                <p className="text-ink-muted">
                                    Food {order.review.food_rating}/5
                                    {order.review.delivery_rating
                                        ? ` · Delivery ${order.review.delivery_rating}/5`
                                        : ''}
                                </p>
                                {order.review.comment ? (
                                    <p className="rounded-md bg-surface-muted px-2 py-1.5 text-ink">
                                        “{order.review.comment}”
                                    </p>
                                ) : null}
                            </CardContent>
                        </Card>
                    ) : null}

                    {/* Support */}
                    {order.support_tickets.length > 0 ? (
                        <Card>
                            <CardToolbar title="Support tickets" />
                            <CardContent className="space-y-2">
                                {order.support_tickets.map((ticket) => (
                                    <Link
                                        key={ticket.id}
                                        href={`/support/${ticket.id}`}
                                        className="flex items-center gap-2 rounded-[var(--radius-control)] border border-hairline px-3 py-2 transition-colors hover:bg-surface-muted"
                                    >
                                        <Ticket className="size-3.5 shrink-0 text-ink-muted" aria-hidden />
                                        <span className="min-w-0 flex-1">
                                            <span className="block truncate text-[12.5px] font-medium text-ink">
                                                {humanise(ticket.category)}
                                            </span>
                                            <span className="block text-[11.5px] text-ink-muted">
                                                {ticket.ticket_number}
                                            </span>
                                        </span>
                                        <Badge
                                            tone={
                                                ticket.status === 'RESOLVED' || ticket.status === 'CLOSED'
                                                    ? 'positive'
                                                    : ticket.priority === 'URGENT'
                                                        ? 'critical'
                                                        : 'caution'
                                            }
                                        >
                                            {humanise(ticket.status)}
                                        </Badge>
                                    </Link>
                                ))}
                            </CardContent>
                        </Card>
                    ) : null}
                </div>
            </div>
        </>
    );
}

function BillRow({
    label,
    value,
    tone = 'neutral',
    emphasis = false,
    hint,
}: {
    label: string;
    value: string;
    tone?: 'neutral' | 'positive' | 'critical';
    emphasis?: boolean;
    hint?: string;
}) {
    const tones = {
        neutral: 'text-ink',
        positive: 'text-positive',
        critical: 'text-critical',
    } as const;

    return (
        <div className="flex items-start justify-between gap-4 py-2">
            <dt className={emphasis ? 'text-[13.5px] font-semibold text-ink' : 'text-[13px] text-ink-muted'}>
                {label}
                {hint ? <span className="mt-0.5 block text-[11.5px] text-ink-muted">{hint}</span> : null}
            </dt>
            <dd
                className={`tnum shrink-0 text-[13.5px] ${emphasis ? 'font-semibold text-ink' : `font-medium ${tones[tone]}`
                    }`}
            >
                {value}
            </dd>
        </div>
    );
}

function Row({
    icon: Icon,
    label,
    value,
}: {
    icon?: React.ComponentType<{ className?: string }>;
    label: string;
    value: React.ReactNode;
}) {
    return (
        <div className="flex items-center justify-between gap-3">
            <span className="flex items-center gap-1.5 text-ink-muted">
                {Icon ? <Icon className="size-3.5" aria-hidden /> : null}
                {label}
            </span>
            <span className="min-w-0 truncate text-right font-medium text-ink">{value}</span>
        </div>
    );
}
