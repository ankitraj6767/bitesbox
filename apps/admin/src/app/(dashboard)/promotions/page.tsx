import type { Metadata } from 'next';
import Link from 'next/link';
import { Megaphone, Pencil, Plus } from 'lucide-react';
import { hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { EmptyState, ErrorState, InlineNotice } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { PromotionToggle } from '@/features/promotions/promotion-toggle';
import { SoftDeleteAction } from '@/components/ui/soft-delete-action';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { dateOnly, money } from '@/lib/utils';

export const metadata: Metadata = { title: 'Promotions' };
export const dynamic = 'force-dynamic';

const DAY_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export default async function PromotionsPage() {
    const session = await requirePermission([PERMISSIONS.COUPON_VIEW, PERMISSIONS.PROMOTION_MANAGE]);
    const supabase = await createSupabaseServerClient();
    const canManage = hasPermission(session, PERMISSIONS.PROMOTION_MANAGE);

    const { data: promotions, error } = await supabase
        .from('promotions')
        .select(
            `id, name, headline, description, badge_text, trigger, discount_kind, discount_value,
       max_discount_amount, min_order_amount, eligible_category_ids, eligible_fulfilment,
       valid_days_of_week, valid_from_time, valid_to_time, priority, stacks_with_coupon,
       starts_at, ends_at, is_active`,
        )
        .is('deleted_at', null)
        .order('priority', { ascending: false });

    if (error) {
        return (
            <>
                <PageHeader title="Promotions" />
                <Card>
                    <ErrorState title="Could not load promotions" message={error.message} />
                </Card>
            </>
        );
    }

    const list = promotions ?? [];
    const now = Date.now();

    return (
        <>
            <PageHeader
                title="Promotions"
                description="Offers that apply automatically, with no code for the customer to remember."
                actions={
                    canManage ? (
                        <Button asChild size="sm">
                            <Link href="/promotions/new"><Plus /> New promotion</Link>
                        </Button>
                    ) : null
                }
            />

            <InlineNotice tone="info" className="mb-4">
                When several promotions could apply, the pricing engine picks the one worth most to the
                customer. A promotion that does not stack yields to a better coupon automatically.
            </InlineNotice>

            <Card>
                <CardToolbar title="All promotions" description={`${list.length} configured`} />
                <CardContent className="p-0">
                    <TableWrap className="rounded-none border-0">
                        <Table>
                            <THead>
                                <TR className="hover:bg-transparent">
                                    <TH>Promotion</TH>
                                    <TH>Discount</TH>
                                    <TH numeric>Min order</TH>
                                    <TH>When</TH>
                                    <TH numeric>Priority</TH>
                                    <TH>Stacks</TH>
                                    <TH>State</TH>
                                    {canManage ? <TH className="w-28" /> : null}
                                </TR>
                            </THead>
                            <TBody>
                                {list.length === 0 ? (
                                    <TableMessageRow colSpan={canManage ? 8 : 7}>
                                        <EmptyState
                                            icon={Megaphone}
                                            title="No promotions yet"
                                            description="Automatic offers such as “15% off Chinese, 3–6 PM” appear here."
                                        />
                                    </TableMessageRow>
                                ) : (
                                    list.map((promotion) => {
                                        const live =
                                            promotion.is_active &&
                                            new Date(promotion.starts_at).getTime() <= now &&
                                            (!promotion.ends_at || new Date(promotion.ends_at).getTime() > now);

                                        const days = promotion.valid_days_of_week ?? [];
                                        const allDays = days.length === 7;

                                        return (
                                            <TR key={promotion.id}>
                                                <TD>
                                                    <span className="flex items-center gap-2">
                                                        <span className="max-w-56 truncate text-[13.5px] font-medium text-ink">
                                                            {promotion.headline}
                                                        </span>
                                                        {promotion.badge_text ? (
                                                            <Badge tone="brand" className="px-1.5 py-0">
                                                                {promotion.badge_text}
                                                            </Badge>
                                                        ) : null}
                                                    </span>
                                                    <span className="block max-w-64 truncate text-[11.5px] text-ink-muted">
                                                        {promotion.name}
                                                    </span>
                                                </TD>

                                                <TD className="text-[12.5px]">
                                                    {promotion.discount_kind === 'FREE_DELIVERY'
                                                        ? 'Free delivery'
                                                        : promotion.discount_kind === 'FLAT'
                                                            ? `${money(promotion.discount_value)} off`
                                                            : `${promotion.discount_value}% off`}
                                                    {promotion.max_discount_amount ? (
                                                        <span className="block text-[11px] text-ink-muted">
                                                            up to {money(promotion.max_discount_amount)}
                                                        </span>
                                                    ) : null}
                                                </TD>

                                                <TD numeric className="text-[12.5px]">
                                                    {promotion.min_order_amount > 0 ? money(promotion.min_order_amount) : '—'}
                                                </TD>

                                                <TD className="text-[11.5px] text-ink-muted">
                                                    {allDays ? 'Every day' : days.map((day) => DAY_LABELS[day]).join(', ')}
                                                    {promotion.valid_from_time ? (
                                                        <span className="block">
                                                            {promotion.valid_from_time.slice(0, 5)}–
                                                            {promotion.valid_to_time?.slice(0, 5)}
                                                        </span>
                                                    ) : null}
                                                    <span className="block">
                                                        {dateOnly(promotion.starts_at)}
                                                        {promotion.ends_at ? ` → ${dateOnly(promotion.ends_at)}` : ' → open'}
                                                    </span>
                                                </TD>

                                                <TD numeric className="tnum text-[12.5px]">
                                                    {promotion.priority}
                                                </TD>

                                                <TD>
                                                    <Badge tone={promotion.stacks_with_coupon ? 'positive' : 'neutral'}>
                                                        {promotion.stacks_with_coupon ? 'With coupons' : 'Exclusive'}
                                                    </Badge>
                                                </TD>

                                                <TD>
                                                    {live ? (
                                                        <Badge tone="positive" dot>
                                                            Live
                                                        </Badge>
                                                    ) : promotion.is_active ? (
                                                        <Badge tone="info">Scheduled</Badge>
                                                    ) : (
                                                        <Badge tone="neutral">Paused</Badge>
                                                    )}
                                                </TD>

                                                {canManage ? (
                                                    <TD>
                                                        <div className="flex items-center gap-1">
                                                            <Button asChild variant="ghost" size="icon" aria-label={`Edit ${promotion.name}`}>
                                                                <Link href={`/promotions/${promotion.id}/edit`}><Pencil /></Link>
                                                            </Button>
                                                            <PromotionToggle
                                                                promotionId={promotion.id}
                                                                isActive={promotion.is_active}
                                                                name={promotion.name}
                                                            />
                                                            <SoftDeleteAction table="promotions" id={promotion.id} label={promotion.name} />
                                                        </div>
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
