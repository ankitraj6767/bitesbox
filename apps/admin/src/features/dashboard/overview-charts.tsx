'use client';

import * as React from 'react';
import {
    Area,
    AreaChart,
    Bar,
    BarChart,
    CartesianGrid,
    Cell,
    Pie,
    PieChart,
    ResponsiveContainer,
    Tooltip as ChartTooltip,
    XAxis,
    YAxis,
} from 'recharts';
import { format, parseISO } from 'date-fns';
import { Card, CardToolbar, CardContent } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/states';
import { compactNumber, money, humanise } from '@/lib/utils';
import type { DashboardCharts } from '@bitesbox/shared-types';

const BRAND = '#c1121f';
const HERB = '#1b4332';
const TURMERIC = '#f0a202';
const INK_MUTED = '#6b625c';
const HAIRLINE = '#ece5dd';

const PIE_COLOURS = [BRAND, HERB, TURMERIC, '#1d4ed8', '#7c3aed', '#0891b2', '#be185d'];

const axisProps = {
    stroke: INK_MUTED,
    fontSize: 11,
    tickLine: false,
    axisLine: false,
} as const;

function ChartFrame({
    title,
    description,
    action,
    isEmpty,
    emptyLabel,
    children,
    height = 260,
}: {
    title: string;
    description?: string;
    action?: React.ReactNode;
    isEmpty: boolean;
    emptyLabel: string;
    children: React.ReactNode;
    height?: number;
}) {
    return (
        <Card>
            <CardToolbar title={title} description={description} action={action} />
            <CardContent>
                {isEmpty ? (
                    <EmptyState title={emptyLabel} description="Data appears here once orders start coming in." />
                ) : (
                    <div style={{ height }} className="w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            {children as React.ReactElement}
                        </ResponsiveContainer>
                    </div>
                )}
            </CardContent>
        </Card>
    );
}

function TooltipCard({
    active,
    payload,
    label,
    formatter,
}: {
    active?: boolean;
    payload?: Array<{ name?: string; value?: number | string; color?: string; dataKey?: string }>;
    label?: string | number;
    formatter?: (value: number | string, key?: string) => string;
}) {
    if (!active || !payload?.length) return null;

    return (
        <div className="rounded-[var(--radius-control)] border border-hairline bg-surface px-3 py-2 shadow-[var(--shadow-raised)]">
            {label !== undefined ? (
                <p className="mb-1 text-[12px] font-semibold text-ink">{label}</p>
            ) : null}
            <ul className="space-y-0.5">
                {payload.map((entry, index) => (
                    <li key={index} className="flex items-center gap-2 text-[12.5px]">
                        <span
                            className="size-2 shrink-0 rounded-full"
                            style={{ backgroundColor: entry.color }}
                            aria-hidden
                        />
                        <span className="text-ink-muted">{humanise(entry.name ?? '')}</span>
                        <span className="tnum ml-auto font-medium text-ink">
                            {formatter && entry.value !== undefined
                                ? formatter(entry.value, entry.dataKey)
                                : entry.value}
                        </span>
                    </li>
                ))}
            </ul>
        </div>
    );
}

export function RevenueTrendChart({ data }: { data: DashboardCharts['revenue_trend'] }) {
    const [metric, setMetric] = React.useState<'net_sales' | 'orders'>('net_sales');

    const series = data.map((point) => ({
        ...point,
        label: safeFormat(point.bucket, 'd MMM'),
    }));

    return (
        <ChartFrame
            title="Revenue trend"
            description="Net sales after refunds, by day"
            isEmpty={series.every((point) => point.orders === 0)}
            emptyLabel="No revenue in this period"
            action={
                <div className="inline-flex rounded-[var(--radius-control)] bg-surface-muted p-0.5">
                    {(['net_sales', 'orders'] as const).map((option) => (
                        <button
                            key={option}
                            type="button"
                            onClick={() => setMetric(option)}
                            className={
                                metric === option
                                    ? 'rounded-md bg-surface px-2.5 py-1 text-[12px] font-medium text-ink shadow-xs'
                                    : 'rounded-md px-2.5 py-1 text-[12px] font-medium text-ink-muted'
                            }
                        >
                            {option === 'net_sales' ? 'Revenue' : 'Orders'}
                        </button>
                    ))}
                </div>
            }
        >
            <AreaChart data={series} margin={{ top: 8, right: 8, left: -12, bottom: 0 }}>
                <defs>
                    <linearGradient id="revenueFill" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={BRAND} stopOpacity={0.22} />
                        <stop offset="100%" stopColor={BRAND} stopOpacity={0} />
                    </linearGradient>
                </defs>
                <CartesianGrid stroke={HAIRLINE} vertical={false} />
                <XAxis dataKey="label" {...axisProps} />
                <YAxis
                    {...axisProps}
                    tickFormatter={(value: number) =>
                        metric === 'net_sales' ? `₹${compactNumber(value)}` : compactNumber(value)
                    }
                />
                <ChartTooltip
                    content={
                        <TooltipCard
                            formatter={(value) =>
                                metric === 'net_sales' ? money(Number(value), true) : String(value)
                            }
                        />
                    }
                />
                <Area
                    type="monotone"
                    dataKey={metric}
                    name={metric === 'net_sales' ? 'Net sales' : 'Orders'}
                    stroke={BRAND}
                    strokeWidth={2}
                    fill="url(#revenueFill)"
                    dot={false}
                    activeDot={{ r: 4, strokeWidth: 0 }}
                />
            </AreaChart>
        </ChartFrame>
    );
}

export function OrdersByHourChart({ data }: { data: DashboardCharts['orders_by_hour'] }) {
    const series = data.map((point) => ({
        ...point,
        label: `${point.hour.toString().padStart(2, '0')}:00`,
    }));

    return (
        <ChartFrame
            title="Orders by hour"
            description="When the kitchen gets busy"
            isEmpty={series.every((point) => point.orders === 0)}
            emptyLabel="No orders yet"
        >
            <BarChart data={series} margin={{ top: 8, right: 8, left: -16, bottom: 0 }}>
                <CartesianGrid stroke={HAIRLINE} vertical={false} />
                <XAxis dataKey="label" {...axisProps} interval={2} />
                <YAxis {...axisProps} allowDecimals={false} />
                <ChartTooltip content={<TooltipCard />} cursor={{ fill: 'rgba(26,22,20,0.04)' }} />
                <Bar dataKey="orders" name="Orders" fill={HERB} radius={[4, 4, 0, 0]} maxBarSize={22} />
            </BarChart>
        </ChartFrame>
    );
}

export function PaymentMixChart({ data }: { data: DashboardCharts['payment_methods'] }) {
    return (
        <ChartFrame
            title="Payment methods"
            description="How customers paid"
            isEmpty={data.length === 0}
            emptyLabel="No payments yet"
            height={240}
        >
            <PieChart>
                <Pie
                    data={data}
                    dataKey="count"
                    nameKey="method"
                    innerRadius={52}
                    outerRadius={86}
                    paddingAngle={2}
                    strokeWidth={0}
                >
                    {data.map((entry, index) => (
                        <Cell key={entry.method} fill={PIE_COLOURS[index % PIE_COLOURS.length]} />
                    ))}
                </Pie>
                <ChartTooltip content={<TooltipCard formatter={(value) => `${value} orders`} />} />
            </PieChart>
        </ChartFrame>
    );
}

export function TopProductsChart({ data }: { data: DashboardCharts['top_products'] }) {
    const series = data.slice(0, 8).map((item) => ({
        ...item,
        label: item.product_name.length > 22 ? `${item.product_name.slice(0, 21)}…` : item.product_name,
    }));

    return (
        <ChartFrame
            title="Top dishes"
            description="Units sold in this period"
            isEmpty={series.length === 0}
            emptyLabel="No dishes sold yet"
            height={Math.max(240, series.length * 34)}
        >
            <BarChart data={series} layout="vertical" margin={{ top: 4, right: 16, left: 8, bottom: 4 }}>
                <CartesianGrid stroke={HAIRLINE} horizontal={false} />
                <XAxis type="number" {...axisProps} allowDecimals={false} />
                <YAxis type="category" dataKey="label" {...axisProps} width={140} />
                <ChartTooltip
                    content={<TooltipCard formatter={(value, key) => (key === 'revenue' ? money(Number(value)) : String(value))} />}
                    cursor={{ fill: 'rgba(26,22,20,0.04)' }}
                />
                <Bar dataKey="units" name="Units" fill={TURMERIC} radius={[0, 4, 4, 0]} maxBarSize={18} />
            </BarChart>
        </ChartFrame>
    );
}

function safeFormat(value: string, pattern: string): string {
    try {
        return format(parseISO(value), pattern);
    } catch {
        return value;
    }
}
