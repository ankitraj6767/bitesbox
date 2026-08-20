import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Ban, Coins, Heart, ShoppingBag, Star, Ticket, Wallet } from 'lucide-react';
import { requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { StatCard } from '@/components/ui/stat-card';
import { Badge, OrderStatusBadge } from '@/components/ui/badge';
import { EmptyState, InlineNotice } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR } from '@/components/ui/table';
import { CustomerAdminActions } from '@/features/customers/customer-admin-actions';
import { PERMISSIONS, type OrderStatus } from '@bitesbox/shared-types';
import { dateOnly, dateTime, money, percent, humanise, initials } from '@/lib/utils';

export const dynamic = 'force-dynamic';

interface CustomerDetail {
    profile: {
        id: string;
        full_name: string | null;
        phone: string | null;
        email: string | null;
        status: string;
        blocked_reason: string | null;
        preferred_language: string;
        marketing_opt_in: boolean;
        referral_code: string | null;
        created_at: string;
        last_seen_at: string | null;
        internal_notes: string | null;
    };
    metrics: Record<string, number | string | null>;
    wallet: { balance: number; is_frozen: boolean };
    loyalty: { points_balance: number; tier: string };
    addresses: Array<{
        id: string;
        label: string;
        address_line1: string;
        address_line2: string | null;
        landmark: string | null;
        area: string | null;
        city: string;
        postal_code: string | null;
        is_default: boolean;
        is_serviceable: boolean | null;
        distance_km: number | null;
    }>;
    recent_orders: Array<{
        id: string;
        order_number: string;
        status: OrderStatus;
        grand_total: number;
        unit_count: number;
        payment_mode: string;
        created_at: string;
        refunded_amount: number;
    }>;
    favourite_products: Array<{ product_id: string; product_name: string; times_ordered: number }>;
    support_tickets: Array<{
        id: string;
        ticket_number: string;
        category: string;
        status: string;
        priority: string;
        created_at: string;
    }>;
    reviews: Array<{
        id: string;
        overall_rating: number;
        food_rating: number;
        delivery_rating: number | null;
        comment: string | null;
        created_at: string;
    }>;
    coupon_usage: Array<{ code: string; discount_amount: number; created_at: string }>;
}

export async function generateMetadata({
    params,
}: {
    params: Promise<{ id: string }>;
}): Promise<Metadata> {
    const { id } = await params;
    const supabase = await createSupabaseServerClient();
    const { data } = await supabase.from('profiles').select('full_name').eq('id', id).maybeSingle();
    return { title: data?.full_name ?? 'Customer' };
}

export default async function CustomerDetailPage({ params }: { params: Promise<{ id: string }> }) {
    const [session, { id }] = await Promise.all([
        requirePermission(PERMISSIONS.CUSTOMER_VIEW),
        params,
    ]);

    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase.rpc('customer_detail', { p_user_id: id });

    if (error || !data) notFound();

    const detail = data as unknown as CustomerDetail;
    const { profile, metrics, wallet, loyalty } = detail;
    const name = profile.full_name ?? 'Unnamed customer';

    return (
        <>
            <PageHeader
                breadcrumbs={[{ label: 'Customers', href: '/customers' }, { label: name }]}
                title={
                    <span className="flex flex-wrap items-center gap-2.5">
                        <span className="flex size-9 items-center justify-center rounded-full bg-brand-600 text-[13px] font-semibold text-white">
                            {initials(name)}
                        </span>
                        {name}
                        {profile.status !== 'ACTIVE' ? (
                            <Badge tone="critical" dot>
                                {humanise(profile.status)}
                            </Badge>
                        ) : null}
                    </span>
                }
                description={`${profile.phone ?? 'No phone'}${profile.email ? ` · ${profile.email}` : ''} · Joined ${dateOnly(profile.created_at)}`}
                actions={
                    <CustomerAdminActions
                        customerId={profile.id}
                        customerName={name}
                        isBlocked={profile.status === 'BLOCKED'}
                        permissions={session.permissions ?? []}
                    />
                }
            />

            {profile.status === 'BLOCKED' ? (
                <InlineNotice tone="critical" className="mb-4">
                    <span className="font-semibold">This customer is blocked.</span>
                    {profile.blocked_reason ? ` ${profile.blocked_reason}` : ''}
                </InlineNotice>
            ) : null}

            <section aria-label="Customer metrics" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard
                    label="Lifetime value"
                    value={money(Number(metrics.lifetime_value ?? 0))}
                    icon={Coins}
                    tone="brand"
                />
                <StatCard
                    label="Completed orders"
                    value={String(metrics.completed_orders ?? 0)}
                    icon={ShoppingBag}
                    hint={`${metrics.cancelled_orders ?? 0} cancelled`}
                />
                <StatCard
                    label="Average order"
                    value={money(Number(metrics.average_order_value ?? 0))}
                    icon={Heart}
                />
                <StatCard
                    label="Cancellation rate"
                    value={percent(Number(metrics.cancellation_rate ?? 0))}
                    icon={Ban}
                    tone={Number(metrics.cancellation_rate ?? 0) > 20 ? 'critical' : 'neutral'}
                    hint={
                        metrics.days_since_last_order !== null
                            ? `Last order ${metrics.days_since_last_order} day(s) ago`
                            : 'Never ordered'
                    }
                />
            </section>

            <div className="mt-4 grid gap-4 xl:grid-cols-[minmax(0,1fr)_340px]">
                <div className="space-y-4">
                    {/* Orders */}
                    <Card>
                        <CardToolbar
                            title="Recent orders"
                            description="Most recent 20 orders"
                            action={
                                <Link
                                    href={`/orders?q=${encodeURIComponent(profile.phone ?? '')}`}
                                    className="text-[13px] font-medium text-brand-600 hover:underline"
                                >
                                    See all
                                </Link>
                            }
                        />
                        <CardContent className="p-0">
                            {detail.recent_orders.length === 0 ? (
                                <EmptyState
                                    icon={ShoppingBag}
                                    title="No orders yet"
                                    description="This customer has signed up but not ordered."
                                />
                            ) : (
                                <TableWrap className="rounded-none border-0">
                                    <Table>
                                        <THead>
                                            <TR className="hover:bg-transparent">
                                                <TH>Order</TH>
                                                <TH>Status</TH>
                                                <TH numeric>Items</TH>
                                                <TH numeric>Total</TH>
                                                <TH>Placed</TH>
                                            </TR>
                                        </THead>
                                        <TBody>
                                            {detail.recent_orders.map((order) => (
                                                <TR key={order.id}>
                                                    <TD>
                                                        <Link
                                                            href={`/orders/${order.id}`}
                                                            className="font-mono text-[12.5px] font-semibold hover:text-brand-600"
                                                        >
                                                            {order.order_number}
                                                        </Link>
                                                    </TD>
                                                    <TD>
                                                        <OrderStatusBadge status={order.status} />
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
                                                        {dateTime(order.created_at)}
                                                    </TD>
                                                </TR>
                                            ))}
                                        </TBody>
                                    </Table>
                                </TableWrap>
                            )}
                        </CardContent>
                    </Card>

                    {/* Reviews */}
                    {detail.reviews.length > 0 ? (
                        <Card>
                            <CardToolbar title="Reviews left" />
                            <CardContent className="space-y-2">
                                {detail.reviews.map((review) => (
                                    <div
                                        key={review.id}
                                        className="rounded-[var(--radius-control)] border border-hairline px-3 py-2.5"
                                    >
                                        <div className="flex items-center gap-1">
                                            {Array.from({ length: 5 }).map((_, index) => (
                                                <Star
                                                    key={index}
                                                    className={
                                                        index < review.overall_rating
                                                            ? 'size-3.5 fill-turmeric-500 text-turmeric-500'
                                                            : 'size-3.5 text-hairline'
                                                    }
                                                    aria-hidden
                                                />
                                            ))}
                                            <span className="ml-1.5 text-[11.5px] text-ink-muted">
                                                {dateTime(review.created_at)}
                                            </span>
                                        </div>
                                        {review.comment ? (
                                            <p className="mt-1.5 text-[13px] leading-relaxed text-ink">“{review.comment}”</p>
                                        ) : null}
                                    </div>
                                ))}
                            </CardContent>
                        </Card>
                    ) : null}

                    {/* Support */}
                    {detail.support_tickets.length > 0 ? (
                        <Card>
                            <CardToolbar title="Support history" />
                            <CardContent className="space-y-2">
                                {detail.support_tickets.map((ticket) => (
                                    <Link
                                        key={ticket.id}
                                        href={`/support/${ticket.id}`}
                                        className="flex items-center gap-2.5 rounded-[var(--radius-control)] border border-hairline px-3 py-2 transition-colors hover:bg-surface-muted"
                                    >
                                        <Ticket className="size-3.5 shrink-0 text-ink-muted" aria-hidden />
                                        <span className="min-w-0 flex-1">
                                            <span className="block truncate text-[13px] font-medium text-ink">
                                                {humanise(ticket.category)}
                                            </span>
                                            <span className="block text-[11.5px] text-ink-muted">
                                                {ticket.ticket_number} · {dateTime(ticket.created_at)}
                                            </span>
                                        </span>
                                        <Badge
                                            tone={
                                                ['RESOLVED', 'CLOSED'].includes(ticket.status)
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

                <div className="space-y-4">
                    {/* Wallet & loyalty */}
                    <Card>
                        <CardToolbar title="Wallet & loyalty" />
                        <CardContent className="space-y-3">
                            <div className="flex items-center justify-between gap-3">
                                <span className="flex items-center gap-2 text-[13px] text-ink-muted">
                                    <Wallet className="size-4" aria-hidden />
                                    Wallet balance
                                </span>
                                <span className="tnum text-[15px] font-semibold text-ink">
                                    {money(wallet.balance, true)}
                                </span>
                            </div>
                            {wallet.is_frozen ? <Badge tone="critical">Wallet frozen</Badge> : null}

                            <div className="flex items-center justify-between gap-3 border-t border-hairline pt-3">
                                <span className="flex items-center gap-2 text-[13px] text-ink-muted">
                                    <Star className="size-4" aria-hidden />
                                    Loyalty points
                                </span>
                                <span className="tnum text-[15px] font-semibold text-ink">
                                    {loyalty.points_balance}
                                </span>
                            </div>
                            <Badge tone="brand">{humanise(loyalty.tier)} tier</Badge>
                        </CardContent>
                    </Card>

                    {/* Addresses */}
                    <Card>
                        <CardToolbar title="Saved addresses" description={`${detail.addresses.length} saved`} />
                        <CardContent className="space-y-2">
                            {detail.addresses.length === 0 ? (
                                <p className="text-[13px] text-ink-muted">No saved addresses.</p>
                            ) : (
                                detail.addresses.map((address) => (
                                    <div
                                        key={address.id}
                                        className="rounded-[var(--radius-control)] border border-hairline px-3 py-2"
                                    >
                                        <div className="flex items-center gap-2">
                                            <Badge tone="neutral" className="px-1.5 py-0">
                                                {humanise(address.label)}
                                            </Badge>
                                            {address.is_default ? (
                                                <Badge tone="brand" className="px-1.5 py-0">
                                                    Default
                                                </Badge>
                                            ) : null}
                                            {address.is_serviceable === false ? (
                                                <Badge tone="critical" className="px-1.5 py-0">
                                                    Not serviceable
                                                </Badge>
                                            ) : null}
                                        </div>
                                        <p className="mt-1.5 text-[12.5px] leading-relaxed text-ink">
                                            {address.address_line1}
                                            {address.address_line2 ? `, ${address.address_line2}` : ''}
                                        </p>
                                        <p className="text-[11.5px] text-ink-muted">
                                            {[address.area, address.city, address.postal_code].filter(Boolean).join(', ')}
                                            {address.distance_km !== null ? ` · ${address.distance_km.toFixed(1)} km` : ''}
                                        </p>
                                    </div>
                                ))
                            )}
                        </CardContent>
                    </Card>

                    {/* Favourites */}
                    {detail.favourite_products.length > 0 ? (
                        <Card>
                            <CardToolbar title="Usual order" description="Most frequently ordered dishes" />
                            <CardContent>
                                <ul className="space-y-1.5">
                                    {detail.favourite_products.map((item) => (
                                        <li
                                            key={item.product_id}
                                            className="flex items-center justify-between gap-3 text-[13px]"
                                        >
                                            <span className="truncate text-ink">{item.product_name}</span>
                                            <Badge tone="neutral" className="tnum shrink-0">
                                                {item.times_ordered}×
                                            </Badge>
                                        </li>
                                    ))}
                                </ul>
                            </CardContent>
                        </Card>
                    ) : null}

                    {/* Coupons */}
                    {detail.coupon_usage.length > 0 ? (
                        <Card>
                            <CardToolbar title="Offers used" />
                            <CardContent>
                                <ul className="space-y-1.5">
                                    {detail.coupon_usage.map((usage, index) => (
                                        <li
                                            key={`${usage.code}-${index}`}
                                            className="flex items-center justify-between gap-3 text-[12.5px]"
                                        >
                                            <span className="font-mono font-medium text-ink">{usage.code}</span>
                                            <span className="tnum text-positive">
                                                − {money(usage.discount_amount, true)}
                                            </span>
                                        </li>
                                    ))}
                                </ul>
                            </CardContent>
                        </Card>
                    ) : null}

                    {/* Preferences */}
                    <Card>
                        <CardToolbar title="Preferences" />
                        <CardContent className="space-y-2 text-[12.5px]">
                            <div className="flex items-center justify-between">
                                <span className="text-ink-muted">Language</span>
                                <span className="font-medium text-ink">
                                    {profile.preferred_language === 'hi' ? 'Hindi' : 'English'}
                                </span>
                            </div>
                            <div className="flex items-center justify-between">
                                <span className="text-ink-muted">Marketing</span>
                                <Badge tone={profile.marketing_opt_in ? 'positive' : 'neutral'}>
                                    {profile.marketing_opt_in ? 'Opted in' : 'Opted out'}
                                </Badge>
                            </div>
                            {profile.referral_code ? (
                                <div className="flex items-center justify-between">
                                    <span className="text-ink-muted">Referral code</span>
                                    <span className="font-mono font-medium text-ink">{profile.referral_code}</span>
                                </div>
                            ) : null}
                            {profile.internal_notes ? (
                                <div className="border-t border-hairline pt-2">
                                    <p className="text-[11.5px] font-semibold tracking-wide text-ink-muted uppercase">
                                        Internal note
                                    </p>
                                    <p className="mt-1 text-[12.5px] leading-relaxed text-ink">{profile.internal_notes}</p>
                                </div>
                            ) : null}
                        </CardContent>
                    </Card>
                </div>
            </div>
        </>
    );
}
