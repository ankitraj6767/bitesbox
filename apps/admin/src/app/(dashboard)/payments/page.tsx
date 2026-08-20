import type { Metadata } from 'next';
import Link from 'next/link';
import { AlertTriangle, Banknote, CreditCard, Percent, ShieldCheck } from 'lucide-react';
import { activeBranchId, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { StatCard } from '@/components/ui/stat-card';
import { Badge, PaymentStatusBadge } from '@/components/ui/badge';
import { EmptyState, ErrorState, InlineNotice } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { RangePicker } from '@/features/dashboard/range-picker';
import { resolveRange, type RangeKey } from '@/features/dashboard/range';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { dateTime, money, percent, humanise } from '@/lib/utils';

export const metadata: Metadata = { title: 'Payments' };
export const dynamic = 'force-dynamic';

export default async function PaymentsPage({
    searchParams,
}: {
    searchParams: Promise<{ range?: string }>;
}) {
    const [session, params] = await Promise.all([
        requirePermission(PERMISSIONS.PAYMENT_VIEW),
        searchParams,
    ]);

    const rangeKey = (params.range ?? '7d') as RangeKey;
    const { from, to, label } = resolveRange(rangeKey);
    const branchId = activeBranchId(session);
    const supabase = await createSupabaseServerClient();

    const [reportResult, paymentsResult, unreconciledResult, codResult] = await Promise.all([
        supabase.rpc('report_payments', { p_branch_id: branchId ?? undefined, p_from: from, p_to: to }),
        supabase
            .from('payments')
            .select(
                `id, order_id, status, mode, method, amount, amount_captured, amount_refunded,
         gateway_fee, gateway_tax, provider_payment_id, vpa, card_last4, card_network, bank_name,
         failure_code, failure_reason, created_at, captured_at, reconciled_at,
         verified_by_callback, verified_by_webhook,
         orders!inner(order_number, customer_name)`,
            )
            .gte('created_at', from)
            .lte('created_at', to)
            .order('created_at', { ascending: false })
            .limit(60),
        supabase
            .from('payments')
            .select('id, order_id, amount, status, created_at, captured_at, verified_by_callback, verified_by_webhook, orders!inner(order_number)')
            .eq('status', 'CAPTURED')
            .is('reconciled_at', null)
            .order('created_at', { ascending: false })
            .limit(20),
        supabase
            .from('cod_collections')
            .select(
                `id, order_id, expected_amount, collected_amount, status, collected_at, settled_at,
         discrepancy_amount, delivery_partners(full_name), orders!inner(order_number)`,
            )
            .eq('status', 'COD_COLLECTED')
            .is('settled_at', null)
            .order('collected_at', { ascending: false })
            .limit(30),
    ]);

    if (reportResult.error) {
        return (
            <>
                <PageHeader title="Payments" />
                <Card>
                    <ErrorState title="Could not load payments" message={reportResult.error.message} />
                </Card>
            </>
        );
    }

    const report = reportResult.data as unknown as {
        summary: Record<string, number>;
        cod: Record<string, number>;
        failure_reasons: Array<{ code: string; count: number }>;
        refunds: Record<string, unknown>;
    };

    const payments = paymentsResult.data ?? [];
    const unreconciled = unreconciledResult.data ?? [];
    const cod = codResult.data ?? [];
    const summary = report.summary ?? {};

    return (
        <>
            <PageHeader
                title="Payments"
                description={`${label} · gateway captures, cash collection and reconciliation`}
                actions={<RangePicker value={rangeKey} />}
            />

            <section aria-label="Payment summary" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard
                    label="Captured"
                    value={money(Number(summary.amount_captured ?? 0))}
                    icon={CreditCard}
                    tone="positive"
                    hint={`${summary.captured ?? 0} payments`}
                />
                <StatCard
                    label="Net settlement"
                    value={money(Number(summary.net_settlement ?? 0))}
                    icon={ShieldCheck}
                    hint={`after ${money(Number(summary.gateway_fees ?? 0))} fees`}
                />
                <StatCard
                    label="Failure rate"
                    value={percent(Number(summary.failure_rate ?? 0))}
                    icon={Percent}
                    tone={Number(summary.failure_rate ?? 0) > 10 ? 'critical' : 'neutral'}
                    invertDelta
                    hint={`${summary.failed ?? 0} failed attempts`}
                />
                <StatCard
                    label="Cash to settle"
                    value={money(Number(report.cod?.unsettled ?? 0))}
                    icon={Banknote}
                    tone={Number(report.cod?.unsettled ?? 0) > 0 ? 'caution' : 'neutral'}
                    hint={`${cod.length} collection${cod.length === 1 ? '' : 's'}`}
                />
            </section>

            {unreconciled.length > 0 ? (
                <InlineNotice tone="caution" className="mt-5">
                    {unreconciled.length} captured payment{unreconciled.length === 1 ? '' : 's'} have only one
                    verification path (callback or webhook, not both). The reconciliation job retries these
                    automatically — investigate if they persist.
                </InlineNotice>
            ) : null}

            {/* ── COD to settle ── */}
            {cod.length > 0 ? (
                <Card className="mt-5">
                    <CardToolbar
                        title="Cash awaiting settlement"
                        description="Money delivery partners are holding until they hand it to the branch"
                    />
                    <CardContent className="p-0">
                        <TableWrap className="rounded-none border-0">
                            <Table>
                                <THead>
                                    <TR className="hover:bg-transparent">
                                        <TH>Order</TH>
                                        <TH>Delivery partner</TH>
                                        <TH numeric>Expected</TH>
                                        <TH numeric>Collected</TH>
                                        <TH numeric>Difference</TH>
                                        <TH>Collected at</TH>
                                    </TR>
                                </THead>
                                <TBody>
                                    {cod.map((row) => (
                                        <TR key={row.id}>
                                            <TD>
                                                <Link
                                                    href={`/orders/${row.order_id}`}
                                                    className="font-mono text-[12.5px] font-semibold hover:text-brand-600"
                                                >
                                                    {row.orders?.order_number}
                                                </Link>
                                            </TD>
                                            <TD className="text-[13px]">{row.delivery_partners?.full_name ?? '—'}</TD>
                                            <TD numeric className="text-[13px]">
                                                {money(row.expected_amount, true)}
                                            </TD>
                                            <TD numeric className="text-[13px] font-semibold">
                                                {money(row.collected_amount, true)}
                                            </TD>
                                            <TD numeric>
                                                {Number(row.discrepancy_amount) === 0 ? (
                                                    <span className="text-[12.5px] text-ink-muted">—</span>
                                                ) : (
                                                    <Badge tone={Number(row.discrepancy_amount) > 0 ? 'caution' : 'critical'}>
                                                        {money(Number(row.discrepancy_amount), true)}
                                                    </Badge>
                                                )}
                                            </TD>
                                            <TD className="text-[12.5px] whitespace-nowrap text-ink-muted">
                                                {dateTime(row.collected_at)}
                                            </TD>
                                        </TR>
                                    ))}
                                </TBody>
                            </Table>
                        </TableWrap>
                    </CardContent>
                </Card>
            ) : null}

            {/* ── Payment attempts ── */}
            <Card className="mt-5">
                <CardToolbar
                    title="Payment attempts"
                    description="Most recent 60 attempts, including failures"
                />
                <CardContent className="p-0">
                    <TableWrap className="rounded-none border-0">
                        <Table>
                            <THead>
                                <TR className="hover:bg-transparent">
                                    <TH>Order</TH>
                                    <TH>Method</TH>
                                    <TH numeric>Amount</TH>
                                    <TH>Status</TH>
                                    <TH>Verification</TH>
                                    <TH>Reference</TH>
                                    <TH>When</TH>
                                </TR>
                            </THead>
                            <TBody>
                                {payments.length === 0 ? (
                                    <TableMessageRow colSpan={7}>
                                        <EmptyState
                                            icon={CreditCard}
                                            title="No payment attempts in this period"
                                            description="Try a wider date range."
                                        />
                                    </TableMessageRow>
                                ) : (
                                    payments.map((payment) => (
                                        <TR key={payment.id}>
                                            <TD>
                                                <Link
                                                    href={`/orders/${payment.order_id}`}
                                                    className="font-mono text-[12.5px] font-semibold hover:text-brand-600"
                                                >
                                                    {payment.orders?.order_number}
                                                </Link>
                                                <span className="block max-w-32 truncate text-[11.5px] text-ink-muted">
                                                    {payment.orders?.customer_name ?? ''}
                                                </span>
                                            </TD>

                                            <TD>
                                                <span className="block text-[12.5px]">
                                                    {payment.method ? humanise(payment.method) : humanise(payment.mode)}
                                                </span>
                                                <span className="block text-[11.5px] text-ink-muted">
                                                    {payment.vpa ??
                                                        (payment.card_last4
                                                            ? `${payment.card_network ?? 'Card'} ···· ${payment.card_last4}`
                                                            : (payment.bank_name ?? ''))}
                                                </span>
                                            </TD>

                                            <TD numeric>
                                                <span className="text-[13px] font-semibold">
                                                    {money(payment.amount_captured || payment.amount, true)}
                                                </span>
                                                {Number(payment.amount_refunded) > 0 ? (
                                                    <span className="block text-[11.5px] text-critical">
                                                        − {money(payment.amount_refunded, true)}
                                                    </span>
                                                ) : null}
                                            </TD>

                                            <TD>
                                                <PaymentStatusBadge status={payment.status} />
                                                {payment.failure_code ? (
                                                    <span className="mt-0.5 block max-w-40 truncate text-[11px] text-critical">
                                                        {payment.failure_reason ?? payment.failure_code}
                                                    </span>
                                                ) : null}
                                            </TD>

                                            <TD>
                                                {payment.status === 'CAPTURED' ? (
                                                    payment.verified_by_callback && payment.verified_by_webhook ? (
                                                        <Badge tone="positive">Reconciled</Badge>
                                                    ) : (
                                                        <Badge tone="caution">
                                                            {payment.verified_by_webhook ? 'Webhook only' : 'Callback only'}
                                                        </Badge>
                                                    )
                                                ) : (
                                                    <span className="text-[12px] text-ink-muted">—</span>
                                                )}
                                            </TD>

                                            <TD className="max-w-40 truncate font-mono text-[11.5px] text-ink-muted">
                                                {payment.provider_payment_id ?? '—'}
                                            </TD>

                                            <TD className="text-[12.5px] whitespace-nowrap text-ink-muted">
                                                {dateTime(payment.captured_at ?? payment.created_at)}
                                            </TD>
                                        </TR>
                                    ))
                                )}
                            </TBody>
                        </Table>
                    </TableWrap>
                </CardContent>
            </Card>

            {/* ── Failure reasons ── */}
            {report.failure_reasons?.length > 0 ? (
                <Card className="mt-5">
                    <CardToolbar
                        title="Why payments failed"
                        description="Gateway failure codes in this period"
                    />
                    <CardContent>
                        <ul className="space-y-1.5">
                            {report.failure_reasons.map((reason) => (
                                <li key={reason.code} className="flex items-center justify-between gap-3 text-[13px]">
                                    <span className="flex items-center gap-2 truncate">
                                        <AlertTriangle className="size-3.5 shrink-0 text-caution" aria-hidden />
                                        <span className="font-mono text-[12px]">{reason.code}</span>
                                    </span>
                                    <Badge tone="neutral" className="tnum shrink-0">
                                        {reason.count}
                                    </Badge>
                                </li>
                            ))}
                        </ul>
                    </CardContent>
                </Card>
            ) : null}
        </>
    );
}
