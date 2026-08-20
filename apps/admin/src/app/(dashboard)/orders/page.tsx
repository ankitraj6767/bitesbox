import type { Metadata } from 'next';
import Link from 'next/link';
import { ClipboardList } from 'lucide-react';
import { requirePermission, activeBranchId } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Badge, OrderStatusBadge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { EmptyState, ErrorState } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { OrdersFilterBar } from '@/features/orders/orders-filter-bar';
import { PERMISSIONS, type OrderStatus } from '@bitesbox/shared-types';
import { dateTime, money, humanise } from '@/lib/utils';

export const metadata: Metadata = { title: 'Orders' };
export const dynamic = 'force-dynamic';

const PAGE_SIZE = 25;

const STATUS_SETS: Record<string, OrderStatus[]> = {
    active: [
        'PAYMENT_CONFIRMED',
        'ORDER_PLACED',
        'STORE_ACCEPTED',
        'PREPARING',
        'READY_FOR_PICKUP',
        'RIDER_ASSIGNED',
        'RIDER_ARRIVED_STORE',
        'PICKED_UP',
        'OUT_FOR_DELIVERY',
        'RIDER_ARRIVED_CUSTOMER',
    ],
    new: ['ORDER_PLACED'],
    kitchen: ['STORE_ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP'],
    delivery: ['RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'RIDER_ARRIVED_CUSTOMER'],
    completed: ['DELIVERED', 'COMPLETED'],
    cancelled: ['CUSTOMER_CANCELLED', 'ADMIN_CANCELLED', 'STORE_REJECTED', 'DELIVERY_FAILED'],
    refunded: ['REFUND_PENDING', 'PARTIALLY_REFUNDED', 'REFUNDED'],
    unpaid: ['PENDING_PAYMENT', 'PAYMENT_FAILED'],
};

function rangeStart(range: string): string | null {
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    switch (range) {
        case 'today':
            return startOfToday.toISOString();
        case '7d': {
            const date = new Date(startOfToday);
            date.setDate(date.getDate() - 6);
            return date.toISOString();
        }
        case '30d': {
            const date = new Date(startOfToday);
            date.setDate(date.getDate() - 29);
            return date.toISOString();
        }
        default:
            return null;
    }
}

export default async function OrdersPage({
    searchParams,
}: {
    searchParams: Promise<{
        status?: string;
        payment?: string;
        fulfilment?: string;
        range?: string;
        q?: string;
        page?: string;
    }>;
}) {
    const [session, params] = await Promise.all([
        requirePermission(PERMISSIONS.ORDER_VIEW),
        searchParams,
    ]);

    const status = params.status ?? 'all';
    const payment = params.payment ?? 'all';
    const fulfilment = params.fulfilment ?? 'all';
    const range = params.range ?? 'today';
    const search = params.q ?? '';
    const page = Math.max(1, Number(params.page ?? '1') || 1);

    const supabase = await createSupabaseServerClient();
    const branchId = activeBranchId(session);

    let query = supabase
        .from('orders')
        .select(
            `id, order_number, status, fulfilment_type, payment_mode, payment_status,
       customer_name, customer_phone, delivery_area, delivery_city,
       item_count, unit_count, grand_total, refunded_amount,
       created_at, placed_at, promised_at, delivered_at, is_delayed, coupon_code`,
            { count: 'exact' },
        )
        .order('created_at', { ascending: false })
        .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

    if (branchId) query = query.eq('branch_id', branchId);

    const statusSet = STATUS_SETS[status];
    if (statusSet) query = query.in('status', statusSet);

    if (payment === 'COD') query = query.in('payment_mode', ['COD', 'SPLIT_WALLET_COD']);
    else if (payment === 'ONLINE') query = query.eq('payment_mode', 'ONLINE');

    if (fulfilment !== 'all') query = query.eq('fulfilment_type', fulfilment as 'DELIVERY' | 'PICKUP');

    const from = rangeStart(range);
    if (from) query = query.gte('created_at', from);

    if (search) {
        const escaped = search.replace(/[%,]/g, '');
        query = query.or(
            `order_number.ilike.%${escaped}%,customer_name.ilike.%${escaped}%,customer_phone.ilike.%${escaped}%`,
        );
    }

    const { data: orders, count, error } = await query;
    const total = count ?? 0;
    const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));

    return (
        <>
            <PageHeader
                title="Orders"
                description={
                    error ? undefined : `${total.toLocaleString('en-IN')} order${total === 1 ? '' : 's'} match these filters.`
                }
            />

            <OrdersFilterBar
                status={status}
                payment={payment}
                fulfilment={fulfilment}
                range={range}
                search={search}
            />

            <TableWrap>
                <Table>
                    <THead>
                        <TR className="hover:bg-transparent">
                            <TH>Order</TH>
                            <TH>Customer</TH>
                            <TH>Status</TH>
                            <TH>Fulfilment</TH>
                            <TH>Payment</TH>
                            <TH numeric>Items</TH>
                            <TH numeric>Total</TH>
                            <TH>Placed</TH>
                            <TH className="w-16" />
                        </TR>
                    </THead>
                    <TBody>
                        {error ? (
                            <TableMessageRow colSpan={9}>
                                <ErrorState title="Could not load orders" message={error.message} />
                            </TableMessageRow>
                        ) : !orders || orders.length === 0 ? (
                            <TableMessageRow colSpan={9}>
                                <EmptyState
                                    icon={ClipboardList}
                                    title="No orders match these filters"
                                    description="Try widening the date range or clearing the filters."
                                />
                            </TableMessageRow>
                        ) : (
                            orders.map((order) => (
                                <TR key={order.id}>
                                    <TD>
                                        <Link
                                            href={`/orders/${order.id}`}
                                            className="font-mono text-[12.5px] font-semibold text-ink hover:text-brand-600"
                                        >
                                            {order.order_number}
                                        </Link>
                                        {order.coupon_code ? (
                                            <span className="mt-0.5 block text-[11.5px] text-ink-muted">
                                                {order.coupon_code}
                                            </span>
                                        ) : null}
                                    </TD>

                                    <TD>
                                        <span className="block max-w-40 truncate text-[13px] font-medium">
                                            {order.customer_name ?? 'Customer'}
                                        </span>
                                        <span className="block text-[11.5px] text-ink-muted">
                                            {order.customer_phone ?? '—'}
                                        </span>
                                    </TD>

                                    <TD>
                                        <div className="flex flex-col items-start gap-1">
                                            <OrderStatusBadge status={order.status} />
                                            {order.is_delayed ? (
                                                <Badge tone="critical" className="px-1.5 py-0">
                                                    Delayed
                                                </Badge>
                                            ) : null}
                                        </div>
                                    </TD>

                                    <TD>
                                        <span className="text-[12.5px]">
                                            {order.fulfilment_type === 'PICKUP' ? 'Self pickup' : 'Delivery'}
                                        </span>
                                        {order.delivery_area ? (
                                            <span className="block max-w-32 truncate text-[11.5px] text-ink-muted">
                                                {order.delivery_area}
                                            </span>
                                        ) : null}
                                    </TD>

                                    <TD>
                                        <span className="block text-[12.5px]">
                                            {order.payment_mode === 'COD' || order.payment_mode === 'SPLIT_WALLET_COD'
                                                ? 'Cash'
                                                : 'Online'}
                                        </span>
                                        <span className="block text-[11.5px] text-ink-muted">
                                            {humanise(order.payment_status)}
                                        </span>
                                    </TD>

                                    <TD numeric className="text-[12.5px]">
                                        {order.unit_count}
                                    </TD>

                                    <TD numeric>
                                        <span className="text-[13px] font-semibold">{money(order.grand_total)}</span>
                                        {order.refunded_amount > 0 ? (
                                            <span className="block text-[11.5px] text-critical">
                                                − {money(order.refunded_amount)}
                                            </span>
                                        ) : null}
                                    </TD>

                                    <TD className="text-[12.5px] whitespace-nowrap text-ink-muted">
                                        {dateTime(order.placed_at ?? order.created_at)}
                                    </TD>

                                    <TD>
                                        <Button asChild variant="ghost" size="sm">
                                            <Link href={`/orders/${order.id}`}>Open</Link>
                                        </Button>
                                    </TD>
                                </TR>
                            ))
                        )}
                    </TBody>
                </Table>
            </TableWrap>

            {pageCount > 1 ? (
                <nav
                    aria-label="Pagination"
                    className="mt-4 flex items-center justify-between gap-3 text-[13px] text-ink-muted"
                >
                    <p className="tnum">
                        Page {page} of {pageCount}
                    </p>
                    <div className="flex gap-2">
                        <Button asChild variant="secondary" size="sm" disabled={page <= 1}>
                            <Link href={buildPageHref(params, page - 1)} aria-disabled={page <= 1}>
                                Previous
                            </Link>
                        </Button>
                        <Button asChild variant="secondary" size="sm" disabled={page >= pageCount}>
                            <Link href={buildPageHref(params, page + 1)} aria-disabled={page >= pageCount}>
                                Next
                            </Link>
                        </Button>
                    </div>
                </nav>
            ) : null}
        </>
    );
}

function buildPageHref(params: Record<string, string | undefined>, page: number): string {
    const search = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
        if (value && key !== 'page') search.set(key, value);
    });
    if (page > 1) search.set('page', String(page));
    const query = search.toString();
    return query ? `/orders?${query}` : '/orders';
}
