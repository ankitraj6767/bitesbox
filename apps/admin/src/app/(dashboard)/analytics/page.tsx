import type { Metadata } from 'next';
import { Repeat, Search, ShoppingCart, TrendingUp, UsersRound } from 'lucide-react';
import { activeBranchId, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { StatCard } from '@/components/ui/stat-card';
import { Badge } from '@/components/ui/badge';
import { EmptyState, ErrorState } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR } from '@/components/ui/table';
import { RangePicker } from '@/features/dashboard/range-picker';
import { resolveRange, type RangeKey } from '@/features/dashboard/range';
import {
    OrdersByHourChart,
    PaymentMixChart,
    RevenueTrendChart,
    TopProductsChart,
} from '@/features/dashboard/overview-charts';
import { PERMISSIONS, type DashboardCharts } from '@bitesbox/shared-types';
import { money, percent } from '@/lib/utils';

export const metadata: Metadata = { title: 'Analytics' };
export const dynamic = 'force-dynamic';

export default async function AnalyticsPage({
    searchParams,
}: {
    searchParams: Promise<{ range?: string }>;
}) {
    const [session, params] = await Promise.all([
        requirePermission([PERMISSIONS.ANALYTICS_VIEW, PERMISSIONS.REPORT_VIEW]),
        searchParams,
    ]);

    const rangeKey = (params.range ?? '30d') as RangeKey;
    const { from, to, label } = resolveRange(rangeKey);
    const branchId = activeBranchId(session) ?? undefined;
    const supabase = await createSupabaseServerClient();

    const [chartsResult, customersResult] = await Promise.all([
        supabase.rpc('dashboard_charts', {
            p_branch_id: branchId,
            p_from: from,
            p_to: to,
            p_granularity: rangeKey === 'today' || rangeKey === 'yesterday' ? 'hour' : 'day',
        }),
        supabase.rpc('report_customers', { p_branch_id: branchId, p_from: from, p_to: to }),
    ]);

    if (chartsResult.error) {
        return (
            <>
                <PageHeader title="Analytics" />
                <Card>
                    <ErrorState title="Could not load analytics" message={chartsResult.error.message} />
                </Card>
            </>
        );
    }

    const charts = chartsResult.data as unknown as DashboardCharts;
    const customers = customersResult.data as unknown as {
        segments: Record<string, number>;
        repeat_rate: number;
        signups_trend: Array<{ date: string; signups: number }>;
        top_customers: Array<{
            user_id: string;
            name: string | null;
            phone: string | null;
            orders: number;
            lifetime_value: number;
            average_order_value: number;
            last_order_at: string | null;
        }>;
        abandoned_carts: { count: number; value: number };
    } | null;

    const mix = charts.customer_mix ?? { new: 0, returning: 0 };
    const totalCustomersInPeriod = mix.new + mix.returning;

    return (
        <>
            <PageHeader
                title="Analytics"
                description={`${label} · demand patterns, product performance and customer behaviour`}
                actions={<RangePicker value={rangeKey} />}
            />

            <section aria-label="Customer analytics" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard
                    label="Repeat rate"
                    value={percent(customers?.repeat_rate ?? 0)}
                    icon={Repeat}
                    tone={(customers?.repeat_rate ?? 0) >= 30 ? 'positive' : 'caution'}
                    hint="Customers with more than one order"
                />
                <StatCard
                    label="New vs returning"
                    value={
                        totalCustomersInPeriod > 0
                            ? `${Math.round((mix.returning / totalCustomersInPeriod) * 100)}% returning`
                            : '—'
                    }
                    icon={UsersRound}
                    hint={`${mix.new} new · ${mix.returning} returning`}
                />
                <StatCard
                    label="High-value customers"
                    value={(customers?.segments.high_value ?? 0).toLocaleString('en-IN')}
                    icon={TrendingUp}
                    tone="brand"
                />
                <StatCard
                    label="Abandoned carts"
                    value={(customers?.abandoned_carts.count ?? 0).toLocaleString('en-IN')}
                    icon={ShoppingCart}
                    tone={(customers?.abandoned_carts.count ?? 0) > 0 ? 'caution' : 'neutral'}
                    hint={money(customers?.abandoned_carts.value ?? 0)}
                />
            </section>

            <section aria-label="Trends" className="mt-5 grid gap-4 xl:grid-cols-2">
                <RevenueTrendChart data={charts.revenue_trend} />
                <OrdersByHourChart data={charts.orders_by_hour} />
                <TopProductsChart data={charts.top_products} />
                <PaymentMixChart data={charts.payment_methods} />
            </section>

            <section aria-label="Tables" className="mt-5 grid gap-4 xl:grid-cols-2">
                <Card>
                    <CardToolbar title="Top categories" description="Revenue by menu category" />
                    <CardContent className="p-0">
                        {charts.top_categories.length === 0 ? (
                            <EmptyState title="No sales in this period" />
                        ) : (
                            <TableWrap className="rounded-none border-0">
                                <Table>
                                    <THead>
                                        <TR className="hover:bg-transparent">
                                            <TH>Category</TH>
                                            <TH numeric>Units</TH>
                                            <TH numeric>Revenue</TH>
                                        </TR>
                                    </THead>
                                    <TBody>
                                        {charts.top_categories.map((category) => (
                                            <TR key={category.category_id}>
                                                <TD className="text-[13px]">{category.category_name}</TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {category.units}
                                                </TD>
                                                <TD numeric className="text-[13px] font-semibold">
                                                    {money(category.revenue)}
                                                </TD>
                                            </TR>
                                        ))}
                                    </TBody>
                                </Table>
                            </TableWrap>
                        )}
                    </CardContent>
                </Card>

                <Card>
                    <CardToolbar
                        title="Delivery performance"
                        description="Per rider: volume, speed and punctuality"
                    />
                    <CardContent className="p-0">
                        {charts.delivery_performance.length === 0 ? (
                            <EmptyState title="No completed deliveries in this period" />
                        ) : (
                            <TableWrap className="rounded-none border-0">
                                <Table>
                                    <THead>
                                        <TR className="hover:bg-transparent">
                                            <TH>Rider</TH>
                                            <TH numeric>Deliveries</TH>
                                            <TH numeric>Avg time</TH>
                                            <TH numeric>On time</TH>
                                        </TR>
                                    </THead>
                                    <TBody>
                                        {charts.delivery_performance.map((rider) => (
                                            <TR key={rider.delivery_partner_id}>
                                                <TD className="text-[13px]">{rider.name}</TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {rider.deliveries}
                                                </TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {rider.avg_minutes}m
                                                </TD>
                                                <TD numeric>
                                                    <Badge tone={rider.on_time_rate >= 90 ? 'positive' : 'caution'}>
                                                        {percent(rider.on_time_rate, 0)}
                                                    </Badge>
                                                </TD>
                                            </TR>
                                        ))}
                                    </TBody>
                                </Table>
                            </TableWrap>
                        )}
                    </CardContent>
                </Card>

                <Card>
                    <CardToolbar title="Coupon performance" description="Usage and discount cost" />
                    <CardContent className="p-0">
                        {charts.coupon_usage.length === 0 ? (
                            <EmptyState title="No coupons redeemed in this period" />
                        ) : (
                            <TableWrap className="rounded-none border-0">
                                <Table>
                                    <THead>
                                        <TR className="hover:bg-transparent">
                                            <TH>Code</TH>
                                            <TH numeric>Uses</TH>
                                            <TH numeric>Discount</TH>
                                            <TH numeric>Order value</TH>
                                        </TR>
                                    </THead>
                                    <TBody>
                                        {charts.coupon_usage.map((coupon) => (
                                            <TR key={coupon.code}>
                                                <TD className="font-mono text-[12.5px] font-semibold">{coupon.code}</TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {coupon.uses}
                                                </TD>
                                                <TD numeric className="text-[13px] font-semibold text-caution">
                                                    {money(coupon.discount_given)}
                                                </TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {money(coupon.revenue_influenced)}
                                                </TD>
                                            </TR>
                                        ))}
                                    </TBody>
                                </Table>
                            </TableWrap>
                        )}
                    </CardContent>
                </Card>

                <Card>
                    <CardToolbar
                        title="Searches with no results"
                        description="What customers wanted but could not find — a menu-gap signal"
                    />
                    <CardContent className="p-0">
                        {charts.zero_result_searches.length === 0 ? (
                            <EmptyState
                                icon={Search}
                                title="Every search found something"
                                description="No empty-handed searches in this period."
                            />
                        ) : (
                            <TableWrap className="rounded-none border-0">
                                <Table>
                                    <THead>
                                        <TR className="hover:bg-transparent">
                                            <TH>Search term</TH>
                                            <TH numeric>Times searched</TH>
                                        </TR>
                                    </THead>
                                    <TBody>
                                        {charts.zero_result_searches.map((row) => (
                                            <TR key={row.query}>
                                                <TD className="text-[13px]">{row.query}</TD>
                                                <TD numeric>
                                                    <Badge tone="caution" className="tnum">
                                                        {row.count}
                                                    </Badge>
                                                </TD>
                                            </TR>
                                        ))}
                                    </TBody>
                                </Table>
                            </TableWrap>
                        )}
                    </CardContent>
                </Card>
            </section>

            {customers && customers.top_customers.length > 0 ? (
                <Card className="mt-5">
                    <CardToolbar title="Most valuable customers" description="By lifetime value" />
                    <CardContent className="p-0">
                        <TableWrap className="rounded-none border-0">
                            <Table>
                                <THead>
                                    <TR className="hover:bg-transparent">
                                        <TH>Customer</TH>
                                        <TH>Phone</TH>
                                        <TH numeric>Orders</TH>
                                        <TH numeric>Lifetime value</TH>
                                        <TH numeric>Average order</TH>
                                    </TR>
                                </THead>
                                <TBody>
                                    {customers.top_customers.slice(0, 15).map((customer) => (
                                        <TR key={customer.user_id}>
                                            <TD className="text-[13px] font-medium">{customer.name ?? 'Customer'}</TD>
                                            <TD className="text-[12.5px] text-ink-muted">{customer.phone ?? '—'}</TD>
                                            <TD numeric className="text-[12.5px]">
                                                {customer.orders}
                                            </TD>
                                            <TD numeric className="text-[13px] font-semibold">
                                                {money(customer.lifetime_value)}
                                            </TD>
                                            <TD numeric className="text-[12.5px]">
                                                {money(customer.average_order_value)}
                                            </TD>
                                        </TR>
                                    ))}
                                </TBody>
                            </Table>
                        </TableWrap>
                    </CardContent>
                </Card>
            ) : null}
        </>
    );
}
