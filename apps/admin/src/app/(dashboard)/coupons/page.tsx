import type { Metadata } from 'next';
import Link from 'next/link';
import { BadgePercent, Plus } from 'lucide-react';
import { hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { StatCard } from '@/components/ui/stat-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { EmptyState, ErrorState } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { CouponToggle } from '@/features/coupons/coupon-toggle';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { dateOnly, money, humanise } from '@/lib/utils';

export const metadata: Metadata = { title: 'Coupons' };
export const dynamic = 'force-dynamic';

export default async function CouponsPage() {
    const session = await requirePermission(PERMISSIONS.COUPON_VIEW);
    const supabase = await createSupabaseServerClient();
    const canEdit = hasPermission(session, [PERMISSIONS.COUPON_CREATE, PERMISSIONS.COUPON_UPDATE]);

    const [couponsResult, redemptionsResult] = await Promise.all([
        supabase
            .from('coupons')
            .select(
                `id, code, title, description, is_visible, discount_kind, discount_value,
         max_discount_amount, min_order_amount, max_total_uses, max_uses_per_customer,
         total_used, audience, first_order_only, starts_at, ends_at, is_active,
         valid_from_time, valid_to_time, valid_days_of_week, created_at`,
            )
            .is('deleted_at', null)
            .order('is_active', { ascending: false })
            .order('created_at', { ascending: false }),
        supabase
            .from('coupon_redemptions')
            .select('coupon_id, discount_amount, order_amount, created_at')
            .gte('created_at', new Date(Date.now() - 30 * 86_400_000).toISOString()),
    ]);

    if (couponsResult.error) {
        return (
            <>
                <PageHeader title="Coupons" />
                <Card>
                    <ErrorState title="Could not load coupons" message={couponsResult.error.message} />
                </Card>
            </>
        );
    }

    const coupons = couponsResult.data ?? [];
    const redemptions = redemptionsResult.data ?? [];

    const now = Date.now();
    const live = coupons.filter(
        (coupon) =>
            coupon.is_active &&
            new Date(coupon.starts_at).getTime() <= now &&
            (!coupon.ends_at || new Date(coupon.ends_at).getTime() > now),
    );

    const discountGiven = redemptions.reduce((sum, row) => sum + Number(row.discount_amount), 0);
    const revenueInfluenced = redemptions.reduce((sum, row) => sum + Number(row.order_amount), 0);

    return (
        <>
            <PageHeader
                title="Coupons"
                description="Code-driven offers. Every rule is validated server-side at checkout."
                actions={
                    canEdit ? (
                        <Button asChild size="sm">
                            <Link href="/coupons/new">
                                <Plus />
                                New coupon
                            </Link>
                        </Button>
                    ) : null
                }
            />

            <section aria-label="Coupon summary" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard label="Live coupons" value={live.length} icon={BadgePercent} tone="brand" />
                <StatCard label="Total coupons" value={coupons.length} hint={`${coupons.length - live.length} inactive or scheduled`} />
                <StatCard label="Redemptions (30d)" value={redemptions.length} tone="positive" />
                <StatCard
                    label="Discount given (30d)"
                    value={money(discountGiven)}
                    tone="caution"
                    hint={`on ${money(revenueInfluenced)} of orders`}
                />
            </section>

            <Card className="mt-5">
                <CardToolbar title="All coupons" />
                <CardContent className="p-0">
                    <TableWrap className="rounded-none border-0">
                        <Table>
                            <THead>
                                <TR className="hover:bg-transparent">
                                    <TH>Code</TH>
                                    <TH>Offer</TH>
                                    <TH>Audience</TH>
                                    <TH numeric>Min order</TH>
                                    <TH numeric>Used</TH>
                                    <TH>Window</TH>
                                    <TH>State</TH>
                                    {canEdit ? <TH className="w-24" /> : null}
                                </TR>
                            </THead>
                            <TBody>
                                {coupons.length === 0 ? (
                                    <TableMessageRow colSpan={canEdit ? 8 : 7}>
                                        <EmptyState
                                            icon={BadgePercent}
                                            title="No coupons yet"
                                            description="Create a coupon to start running code-driven offers."
                                        />
                                    </TableMessageRow>
                                ) : (
                                    coupons.map((coupon) => {
                                        const isLive =
                                            coupon.is_active &&
                                            new Date(coupon.starts_at).getTime() <= now &&
                                            (!coupon.ends_at || new Date(coupon.ends_at).getTime() > now);
                                        const expired = coupon.ends_at && new Date(coupon.ends_at).getTime() <= now;
                                        const exhausted =
                                            coupon.max_total_uses !== null && coupon.total_used >= coupon.max_total_uses;

                                        return (
                                            <TR key={coupon.id}>
                                                <TD>
                                                    <span className="font-mono text-[12.5px] font-semibold text-ink">
                                                        {coupon.code}
                                                    </span>
                                                    {!coupon.is_visible ? (
                                                        <Badge tone="neutral" className="mt-0.5 block w-fit px-1.5 py-0">
                                                            Hidden
                                                        </Badge>
                                                    ) : null}
                                                </TD>

                                                <TD>
                                                    <span className="block max-w-56 truncate text-[13px] font-medium text-ink">
                                                        {coupon.title}
                                                    </span>
                                                    <span className="block text-[11.5px] text-ink-muted">
                                                        {coupon.discount_kind === 'PERCENTAGE'
                                                            ? `${coupon.discount_value}% off${coupon.max_discount_amount
                                                                ? ` up to ${money(coupon.max_discount_amount)}`
                                                                : ''
                                                            }`
                                                            : coupon.discount_kind === 'FLAT'
                                                                ? `${money(coupon.discount_value)} off`
                                                                : humanise(coupon.discount_kind)}
                                                    </span>
                                                </TD>

                                                <TD>
                                                    <span className="text-[12.5px]">
                                                        {coupon.first_order_only ? 'First order' : humanise(coupon.audience)}
                                                    </span>
                                                    <span className="block text-[11px] text-ink-muted">
                                                        {coupon.max_uses_per_customer}× per customer
                                                    </span>
                                                </TD>

                                                <TD numeric className="text-[12.5px]">
                                                    {coupon.min_order_amount > 0 ? money(coupon.min_order_amount) : '—'}
                                                </TD>

                                                <TD numeric>
                                                    <span className="text-[13px] font-semibold">{coupon.total_used}</span>
                                                    {coupon.max_total_uses ? (
                                                        <span className="block text-[11px] text-ink-muted">
                                                            of {coupon.max_total_uses}
                                                        </span>
                                                    ) : null}
                                                </TD>

                                                <TD className="text-[11.5px] whitespace-nowrap text-ink-muted">
                                                    {dateOnly(coupon.starts_at)}
                                                    {coupon.ends_at ? ` → ${dateOnly(coupon.ends_at)}` : ' → open'}
                                                    {coupon.valid_from_time ? (
                                                        <span className="block">
                                                            {coupon.valid_from_time.slice(0, 5)}–{coupon.valid_to_time?.slice(0, 5)}
                                                        </span>
                                                    ) : null}
                                                </TD>

                                                <TD>
                                                    {exhausted ? (
                                                        <Badge tone="neutral">Fully claimed</Badge>
                                                    ) : expired ? (
                                                        <Badge tone="neutral">Expired</Badge>
                                                    ) : isLive ? (
                                                        <Badge tone="positive" dot>
                                                            Live
                                                        </Badge>
                                                    ) : coupon.is_active ? (
                                                        <Badge tone="info">Scheduled</Badge>
                                                    ) : (
                                                        <Badge tone="neutral">Paused</Badge>
                                                    )}
                                                </TD>

                                                {canEdit ? (
                                                    <TD>
                                                        <CouponToggle couponId={coupon.id} isActive={coupon.is_active} code={coupon.code} />
                                                    </TD>
                                                ) : null}
                                            </TR>
                                        );
                                    })
                                )}
                            </TBody>
                        </Table>
                    </TableWrap>
                </CardContent>
            </Card>
        </>
    );
}
