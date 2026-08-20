import type { Metadata } from 'next';
import Link from 'next/link';
import {
    AlertTriangle,
    Bike,
    CircleDollarSign,
    Clock,
    IndianRupee,
    PackageCheck,
    ReceiptText,
    ShoppingBag,
    Timer,
    UserPlus,
    UtensilsCrossed,
} from 'lucide-react';
import { requirePermission, activeBranchId } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { StatCard } from '@/components/ui/stat-card';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ErrorState, InlineNotice } from '@/components/ui/states';
import {
    OrdersByHourChart,
    PaymentMixChart,
    RevenueTrendChart,
    TopProductsChart,
} from '@/features/dashboard/overview-charts';
import { PERMISSIONS, type DashboardCharts, type DashboardOverview } from '@bitesbox/shared-types';
import { money, percent, humanise } from '@/lib/utils';
import { RangePicker } from '@/features/dashboard/range-picker';
import { resolveRange, type RangeKey } from '@/features/dashboard/range';

export const metadata: Metadata = { title: 'Overview' };

// Always fresh: this is the screen an owner leaves open during service.
export const dynamic = 'force-dynamic';

export default async function OverviewPage({
    searchParams,
}: {
    searchParams: Promise<{ range?: string }>;
}) {
    const [session, params] = await Promise.all([
        requirePermission([PERMISSIONS.ANALYTICS_VIEW, PERMISSIONS.ORDER_VIEW]),
        searchParams,
    ]);

    const rangeKey = (params.range ?? 'today') as RangeKey;
    const { from, to, label } = resolveRange(rangeKey);
    const branchId = activeBranchId(session) ?? undefined;
    const supabase = await createSupabaseServerClient();

    const [overviewResult, chartsResult] = await Promise.all([
        supabase.rpc('dashboard_overview', {
            p_branch_id: branchId,
            p_from: from,
            p_to: to,
        }),
        supabase.rpc('dashboard_charts', {
            p_branch_id: branchId,
            p_from: from,
            p_to: to,
            p_granularity: rangeKey === 'today' || rangeKey === 'yesterday' ? 'hour' : 'day',
        }),
    ]);

    if (overviewResult.error) {
        return (
            <>
                <PageHeader title="Overview" />
                <Card>
                    <ErrorState
                        title="Could not load the dashboard"
                        message={overviewResult.error.message}
                    />
                </Card>
            </>
        );
    }

    const overview = overviewResult.data as unknown as DashboardOverview;
    const charts = (chartsResult.data as unknown as DashboardCharts | null) ?? {
        revenue_trend: [],
        orders_by_hour: [],
        order_status_breakdown: [],
        payment_methods: [],
        top_products: [],
        top_categories: [],
        customer_mix: { new: 0, returning: 0 },
        cancellation_reasons: [],
        coupon_usage: [],
        delivery_performance: [],
        zero_result_searches: [],
    };

    const current = overview.current;
    const live = overview.live;
    const num = (key: string) => Number(current[key] ?? 0);

    const alerts: string[] = [];
    if (live.out_of_stock_items > 0) {
        alerts.push(`${live.out_of_stock_items} menu item(s) are marked out of stock.`);
    }
    if (live.pending_refunds > 0) {
        alerts.push(`${live.pending_refunds} refund(s) are waiting for approval.`);
    }
    if (live.available_riders === 0 && live.out_for_delivery > 0) {
        alerts.push('No delivery partners are free while orders are out for delivery.');
    }

    return (
        <>
            <PageHeader
                title="Overview"
                description={`${label} · ${overview.range.timezone.replace('_', ' ')}`}
                actions={
                    <>
                        <RangePicker value={rangeKey} />
                        <Button asChild variant="secondary" size="sm">
                            <Link href="/operations">Live operations</Link>
                        </Button>
                    </>
                }
            />

            {alerts.length > 0 ? (
                <div className="mb-5 space-y-2">
                    {alerts.map((message) => (
                        <InlineNotice key={message} tone="caution">
                            {message}
                        </InlineNotice>
                    ))}
                </div>
            ) : null}

            {/* ── Headline money ── */}
            <section aria-label="Key metrics" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard
                    label="Net sales"
                    value={money(num('net_sales'))}
                    delta={overview.deltas.net_sales}
                    icon={IndianRupee}
                    tone="brand"
                    hint={`${money(num('gross_sales'))} gross`}
                />
                <StatCard
                    label="Orders"
                    value={num('orders').toLocaleString('en-IN')}
                    delta={overview.deltas.orders}
                    icon={ShoppingBag}
                    hint={`${num('delivered_orders')} delivered`}
                />
                <StatCard
                    label="Average order value"
                    value={money(num('average_order_value'))}
                    delta={overview.deltas.average_order_value}
                    icon={CircleDollarSign}
                    hint={`${num('units_sold')} items sold`}
                />
                <StatCard
                    label="New customers"
                    value={num('new_customers').toLocaleString('en-IN')}
                    icon={UserPlus}
                    tone="positive"
                    hint={`${num('returning_customers')} returning`}
                />
            </section>

            {/* ── Live service ── */}
            <section aria-label="Live service" className="mt-5">
                <Card>
                    <CardToolbar
                        title="Right now"
                        description="Live counters straight from the kitchen and dispatch"
                        action={
                            <Button asChild variant="ghost" size="sm">
                                <Link href="/operations">Open command centre</Link>
                            </Button>
                        }
                    />
                    <CardContent className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
                        <LiveTile icon={UtensilsCrossed} label="Preparing" value={live.preparing} tone="info" />
                        <LiveTile icon={PackageCheck} label="Ready" value={live.ready} tone="caution" />
                        <LiveTile icon={Bike} label="Out for delivery" value={live.out_for_delivery} tone="info" />
                        <LiveTile icon={Bike} label="Riders free" value={live.available_riders} tone={live.available_riders > 0 ? 'positive' : 'critical'} />
                        <LiveTile icon={ReceiptText} label="Refunds pending" value={live.pending_refunds} tone={live.pending_refunds > 0 ? 'caution' : 'neutral'} />
                        <LiveTile icon={AlertTriangle} label="Open tickets" value={live.open_tickets} tone={live.open_tickets > 0 ? 'caution' : 'neutral'} />
                    </CardContent>
                </Card>
            </section>

            {/* ── Operational quality ── */}
            <section aria-label="Service quality" className="mt-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard
                    label="Avg preparation"
                    value={`${num('avg_prep_minutes')} min`}
                    icon={Timer}
                    hint="Accepted → ready"
                />
                <StatCard
                    label="Avg delivery"
                    value={`${num('avg_delivery_minutes')} min`}
                    icon={Clock}
                    hint="Picked up → delivered"
                />
                <StatCard
                    label="On-time rate"
                    value={current.on_time_rate === null ? '—' : percent(num('on_time_rate'))}
                    icon={PackageCheck}
                    tone={num('on_time_rate') >= 90 ? 'positive' : 'caution'}
                    hint="Delivered within promise"
                />
                <StatCard
                    label="Cancellation rate"
                    value={percent(num('cancellation_rate'))}
                    icon={AlertTriangle}
                    tone={num('cancellation_rate') > 5 ? 'critical' : 'neutral'}
                    invertDelta
                    hint={`${num('cancelled_orders')} cancelled`}
                />
            </section>

            {/* ── Charts ── */}
            <section aria-label="Trends" className="mt-5 grid gap-4 xl:grid-cols-2">
                <RevenueTrendChart data={charts.revenue_trend} />
                <OrdersByHourChart data={charts.orders_by_hour} />
                <TopProductsChart data={charts.top_products} />
                <PaymentMixChart data={charts.payment_methods} />
            </section>

            {/* ── Money detail ── */}
            <section aria-label="Money breakdown" className="mt-5 grid gap-4 lg:grid-cols-2">
                <Card>
                    <CardToolbar title="Money breakdown" description="Where the revenue came from and went" />
                    <CardContent>
                        <dl className="divide-y divide-hairline">
                            <MoneyRow label="Gross sales" value={money(num('gross_sales'), true)} />
                            <MoneyRow label="Discounts given" value={`− ${money(num('discounts'), true)}`} tone="caution" />
                            <MoneyRow label="Refunds" value={`− ${money(num('refunds'), true)}`} tone="critical" />
                            <MoneyRow label="Delivery fees collected" value={money(num('delivery_fees'), true)} />
                            <MoneyRow label="Packaging charges" value={money(num('packaging_charges'), true)} />
                            <MoneyRow label="Tips to riders" value={money(num('tips'), true)} />
                            <MoneyRow label="GST collected" value={money(num('tax_collected'), true)} />
                            <MoneyRow label="Net sales" value={money(num('net_sales'), true)} emphasis />
                        </dl>
                    </CardContent>
                </Card>

                <Card>
                    <CardToolbar
                        title="Order mix"
                        description="Fulfilment, payment and cancellation split"
                    />
                    <CardContent className="space-y-4">
                        <div className="grid grid-cols-2 gap-3">
                            <SplitTile label="Delivery" value={num('orders') - num('pickup_orders')} total={num('orders')} />
                            <SplitTile label="Self pickup" value={num('pickup_orders')} total={num('orders')} />
                            <SplitTile label="Paid online" value={num('online_orders')} total={num('orders')} />
                            <SplitTile label="Cash on delivery" value={num('cod_orders')} total={num('orders')} />
                        </div>

                        {charts.cancellation_reasons.length > 0 ? (
                            <div>
                                <p className="mb-2 text-[12.5px] font-medium text-ink-muted">Why orders were cancelled</p>
                                <ul className="space-y-1.5">
                                    {charts.cancellation_reasons.slice(0, 5).map((reason) => (
                                        <li key={reason.reason} className="flex items-center justify-between gap-3 text-[13px]">
                                            <span className="truncate text-ink">{humanise(reason.reason)}</span>
                                            <Badge tone="neutral" className="tnum shrink-0">
                                                {reason.count}
                                            </Badge>
                                        </li>
                                    ))}
                                </ul>
                            </div>
                        ) : null}

                        {num('payment_failures') > 0 ? (
                            <InlineNotice tone="caution">
                                {num('payment_failures')} payment attempt(s) failed in this period. Check{' '}
                                <Link href="/payments" className="underline">
                                    Payments
                                </Link>{' '}
                                for details.
                            </InlineNotice>
                        ) : null}
                    </CardContent>
                </Card>
            </section>
        </>
    );
}

function LiveTile({
    icon: Icon,
    label,
    value,
    tone,
}: {
    icon: React.ComponentType<{ className?: string }>;
    label: string;
    value: number;
    tone: 'neutral' | 'positive' | 'caution' | 'critical' | 'info';
}) {
    const tones = {
        neutral: 'text-ink-muted bg-surface-muted',
        positive: 'text-positive bg-positive-soft',
        caution: 'text-caution bg-caution-soft',
        critical: 'text-critical bg-critical-soft',
        info: 'text-info bg-info-soft',
    } as const;

    return (
        <div className="rounded-[var(--radius-control)] border border-hairline p-3">
            <span className={`flex size-7 items-center justify-center rounded-lg ${tones[tone]}`}>
                <Icon className="size-3.5" />
            </span>
            <p className="tnum mt-2 font-display text-xl leading-none font-semibold text-ink">{value}</p>
            <p className="mt-1 text-[12px] text-ink-muted">{label}</p>
        </div>
    );
}

function MoneyRow({
    label,
    value,
    tone = 'neutral',
    emphasis = false,
}: {
    label: string;
    value: string;
    tone?: 'neutral' | 'caution' | 'critical';
    emphasis?: boolean;
}) {
    const tones = {
        neutral: 'text-ink',
        caution: 'text-caution',
        critical: 'text-critical',
    } as const;

    return (
        <div className="flex items-center justify-between gap-4 py-2.5">
            <dt className={emphasis ? 'text-[13.5px] font-semibold text-ink' : 'text-[13px] text-ink-muted'}>
                {label}
            </dt>
            <dd
                className={`tnum text-[13.5px] ${emphasis ? 'font-semibold text-ink' : `font-medium ${tones[tone]}`}`}
            >
                {value}
            </dd>
        </div>
    );
}

function SplitTile({ label, value, total }: { label: string; value: number; total: number }) {
    const share = total > 0 ? Math.round((value / total) * 100) : 0;

    return (
        <div className="rounded-[var(--radius-control)] border border-hairline p-3">
            <p className="text-[12px] text-ink-muted">{label}</p>
            <p className="tnum mt-1 font-display text-lg leading-none font-semibold text-ink">{value}</p>
            <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-surface-muted" role="presentation">
                <div className="h-full rounded-full bg-brand-500" style={{ width: `${share}%` }} />
            </div>
            <p className="tnum mt-1 text-[11.5px] text-ink-muted">{share}% of orders</p>
        </div>
    );
}
