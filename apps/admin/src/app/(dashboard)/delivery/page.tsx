import type { Metadata } from 'next';
import { Bike, FileWarning, Star, Wallet } from 'lucide-react';
import { activeBranchId, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { StatCard } from '@/components/ui/stat-card';
import { Badge } from '@/components/ui/badge';
import { EmptyState, ErrorState, InlineNotice } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { RiderActions } from '@/features/delivery/rider-actions';
import { RiderDocumentsButton } from '@/features/delivery/rider-documents';
import { PERMISSIONS, type RiderOnboardingStatus, type RiderDutyState } from '@bitesbox/shared-types';
import { dateOnly, money, relativeTime, humanise } from '@/lib/utils';

export const metadata: Metadata = { title: 'Delivery partners' };
export const dynamic = 'force-dynamic';

function onboardingTone(status: RiderOnboardingStatus) {
    switch (status) {
        case 'ACTIVE':
            return 'positive' as const;
        case 'VERIFIED':
        case 'DOCUMENTS_SUBMITTED':
            return 'info' as const;
        case 'PENDING':
            return 'caution' as const;
        default:
            return 'critical' as const;
    }
}

function dutyTone(state: RiderDutyState) {
    switch (state) {
        case 'AVAILABLE':
            return 'positive' as const;
        case 'BUSY':
            return 'caution' as const;
        case 'ON_BREAK':
            return 'info' as const;
        default:
            return 'neutral' as const;
    }
}

export default async function DeliveryPage() {
    const session = await requirePermission([PERMISSIONS.RIDER_VIEW, PERMISSIONS.DELIVERY_VIEW]);
    const supabase = await createSupabaseServerClient();
    const branchId = activeBranchId(session);

    let ridersQuery = supabase
        .from('delivery_partners')
        .select(
            `id, user_id, partner_code, full_name, phone, photo_path, vehicle_type, vehicle_number,
       onboarding_status, duty_state, is_salaried, max_concurrent_orders,
       total_deliveries, successful_deliveries, failed_deliveries, rejected_assignments,
       rating_average, rating_count, cash_in_hand, last_online_at, last_delivery_at,
       approved_at, suspended_reason, created_at,
       delivery_partner_documents(id, document_type, status, expires_on)`,
        )
        .is('deleted_at', null)
        .order('onboarding_status')
        .order('full_name');

    if (branchId) ridersQuery = ridersQuery.eq('branch_id', branchId);

    const { data: riders, error } = await ridersQuery;

    if (error) {
        return (
            <>
                <PageHeader title="Delivery partners" />
                <Card>
                    <ErrorState title="Could not load delivery partners" message={error.message} />
                </Card>
            </>
        );
    }

    const list = riders ?? [];
    const active = list.filter((rider) => rider.onboarding_status === 'ACTIVE');
    const online = active.filter((rider) => rider.duty_state !== 'OFFLINE');
    const awaiting = list.filter((rider) =>
        ['PENDING', 'DOCUMENTS_SUBMITTED', 'VERIFIED'].includes(rider.onboarding_status),
    );
    const cashHeld = active.reduce((sum, rider) => sum + Number(rider.cash_in_hand), 0);

    // The queue that actually needs a human: uploaded but not yet looked at.
    const docsAwaitingReview = list.reduce(
        (sum, rider) =>
            sum + (rider.delivery_partner_documents ?? []).filter((doc) => doc.status === 'PENDING').length,
        0,
    );

    const expiringDocs = list.flatMap((rider) =>
        (rider.delivery_partner_documents ?? [])
            .filter((doc) => {
                if (!doc.expires_on) return false;
                const days = (new Date(doc.expires_on).getTime() - Date.now()) / 86_400_000;
                return days < 30;
            })
            .map((doc) => ({ rider: rider.full_name, ...doc })),
    );

    return (
        <>
            <PageHeader
                title="Delivery partners"
                description="Onboarding, documents, duty state and cash held by each rider."
            />

            <section aria-label="Rider summary" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard label="Active riders" value={active.length} icon={Bike} tone="positive" />
                <StatCard
                    label="On duty now"
                    value={online.length}
                    icon={Bike}
                    tone={online.length === 0 ? 'critical' : 'brand'}
                    hint={`${active.filter((r) => r.duty_state === 'AVAILABLE').length} free`}
                />
                <StatCard
                    label="Awaiting approval"
                    value={awaiting.length}
                    icon={FileWarning}
                    tone={awaiting.length > 0 ? 'caution' : 'neutral'}
                    hint={
                        docsAwaitingReview > 0
                            ? `${docsAwaitingReview} document${docsAwaitingReview === 1 ? '' : 's'} to review`
                            : undefined
                    }
                />
                <StatCard
                    label="Cash held by riders"
                    value={money(cashHeld)}
                    icon={Wallet}
                    tone={cashHeld > 0 ? 'caution' : 'neutral'}
                    hint="Settle at end of shift"
                />
            </section>

            {expiringDocs.length > 0 ? (
                <InlineNotice tone="caution" className="mt-5">
                    {expiringDocs.length} document{expiringDocs.length === 1 ? '' : 's'} expiring within 30
                    days:{' '}
                    {expiringDocs
                        .slice(0, 3)
                        .map((doc) => `${doc.rider} (${humanise(doc.document_type)})`)
                        .join(', ')}
                    {expiringDocs.length > 3 ? ` and ${expiringDocs.length - 3} more` : ''}.
                </InlineNotice>
            ) : null}

            <Card className="mt-5">
                <CardToolbar
                    title="All delivery partners"
                    description={`${list.length} record${list.length === 1 ? '' : 's'}`}
                />
                <CardContent className="p-0">
                    <TableWrap className="rounded-none border-0">
                        <Table>
                            <THead>
                                <TR className="hover:bg-transparent">
                                    <TH>Partner</TH>
                                    <TH>Vehicle</TH>
                                    <TH>Onboarding</TH>
                                    <TH>Duty</TH>
                                    <TH numeric>Deliveries</TH>
                                    <TH>Rating</TH>
                                    <TH numeric>Cash held</TH>
                                    <TH>Documents</TH>
                                    <TH className="w-32" />
                                </TR>
                            </THead>
                            <TBody>
                                {list.length === 0 ? (
                                    <TableMessageRow colSpan={9}>
                                        <EmptyState
                                            icon={Bike}
                                            title="No delivery partners yet"
                                            description="Riders appear here once they sign up in the Bites Box app."
                                        />
                                    </TableMessageRow>
                                ) : (
                                    list.map((rider) => {
                                        const docs = rider.delivery_partner_documents ?? [];
                                        const approvedDocs = docs.filter((doc) => doc.status === 'APPROVED').length;
                                        const pendingDocs = docs.filter((doc) => doc.status === 'PENDING').length;
                                        const successRate =
                                            rider.total_deliveries > 0
                                                ? Math.round((rider.successful_deliveries / rider.total_deliveries) * 100)
                                                : null;

                                        return (
                                            <TR key={rider.id}>
                                                <TD>
                                                    <div className="flex items-center gap-2.5">
                                                        <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink-muted">
                                                            <Bike className="size-3.5" aria-hidden />
                                                        </span>
                                                        <div className="min-w-0">
                                                            <p className="max-w-40 truncate text-[13.5px] font-medium text-ink">
                                                                {rider.full_name}
                                                            </p>
                                                            <p className="text-[11.5px] text-ink-muted">
                                                                {rider.partner_code ?? '—'} · {rider.phone}
                                                            </p>
                                                        </div>
                                                    </div>
                                                </TD>

                                                <TD>
                                                    <span className="block text-[12.5px]">{humanise(rider.vehicle_type)}</span>
                                                    <span className="block text-[11.5px] text-ink-muted">
                                                        {rider.vehicle_number ?? 'No number'}
                                                    </span>
                                                </TD>

                                                <TD>
                                                    <Badge tone={onboardingTone(rider.onboarding_status)}>
                                                        {humanise(rider.onboarding_status)}
                                                    </Badge>
                                                    {rider.suspended_reason ? (
                                                        <span className="mt-0.5 block max-w-36 truncate text-[11px] text-critical">
                                                            {rider.suspended_reason}
                                                        </span>
                                                    ) : null}
                                                </TD>

                                                <TD>
                                                    <Badge tone={dutyTone(rider.duty_state)} dot>
                                                        {humanise(rider.duty_state)}
                                                    </Badge>
                                                    {rider.last_online_at ? (
                                                        <span className="mt-0.5 block text-[11px] text-ink-muted">
                                                            {relativeTime(rider.last_online_at)}
                                                        </span>
                                                    ) : null}
                                                </TD>

                                                <TD numeric>
                                                    <span className="text-[13px] font-semibold">{rider.total_deliveries}</span>
                                                    {successRate !== null ? (
                                                        <span className="block text-[11.5px] text-ink-muted">
                                                            {successRate}% success
                                                        </span>
                                                    ) : null}
                                                </TD>

                                                <TD>
                                                    {rider.rating_count > 0 ? (
                                                        <span className="inline-flex items-center gap-1 text-[12.5px]">
                                                            <Star className="size-3 fill-turmeric-500 text-turmeric-500" aria-hidden />
                                                            {rider.rating_average.toFixed(1)}
                                                            <span className="text-ink-muted">({rider.rating_count})</span>
                                                        </span>
                                                    ) : (
                                                        <span className="text-[12.5px] text-ink-muted">—</span>
                                                    )}
                                                </TD>

                                                <TD numeric>
                                                    {Number(rider.cash_in_hand) > 0 ? (
                                                        <span className="text-[13px] font-semibold text-caution">
                                                            {money(rider.cash_in_hand)}
                                                        </span>
                                                    ) : (
                                                        <span className="text-[12.5px] text-ink-muted">—</span>
                                                    )}
                                                </TD>

                                                <TD>
                                                    <RiderDocumentsButton
                                                        riderId={rider.id}
                                                        riderName={rider.full_name}
                                                        approvedCount={approvedDocs}
                                                        totalCount={docs.length}
                                                        canReview={(session.permissions ?? []).includes(
                                                            PERMISSIONS.RIDER_APPROVE,
                                                        )}
                                                    />
                                                    {pendingDocs > 0 ? (
                                                        <span className="block text-[11px] text-caution">
                                                            {pendingDocs} awaiting review
                                                        </span>
                                                    ) : rider.approved_at ? (
                                                        <span className="block text-[11px] text-ink-muted">
                                                            since {dateOnly(rider.approved_at)}
                                                        </span>
                                                    ) : null}
                                                </TD>

                                                <TD>
                                                    <RiderActions
                                                        riderId={rider.id}
                                                        riderName={rider.full_name}
                                                        status={rider.onboarding_status}
                                                        permissions={session.permissions ?? []}
                                                    />
                                                </TD>
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
