import type { Metadata } from 'next';
import { AlertCircle, CheckCircle2, Clock, IndianRupee } from 'lucide-react';
import { hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card } from '@/components/ui/card';
import { StatCard } from '@/components/ui/stat-card';
import { ErrorState } from '@/components/ui/states';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/overlays';
import { RefundQueue, type RefundRow } from '@/features/refunds/refund-queue';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { money } from '@/lib/utils';

export const metadata: Metadata = { title: 'Refunds' };
export const dynamic = 'force-dynamic';

const SELECT = `id, order_id, status, kind, reason, reason_note, destination, amount,
  amount_processed, created_at, completed_at, requested_by,
  orders!inner(order_number, customer_name, grand_total),
  requester:profiles!refunds_requester_profile_fkey(full_name)`;

export default async function RefundsPage() {
    const session = await requirePermission(PERMISSIONS.REFUND_VIEW);
    const supabase = await createSupabaseServerClient();
    const canApprove = hasPermission(session, [PERMISSIONS.REFUND_APPROVE, PERMISSIONS.REFUND_REJECT]);

    const [pendingResult, processingResult, completedResult] = await Promise.all([
        supabase
            .from('refunds')
            .select(SELECT)
            .in('status', ['REQUESTED', 'APPROVAL_PENDING'])
            .order('created_at', { ascending: true }),
        supabase
            .from('refunds')
            .select(SELECT)
            .in('status', ['APPROVED', 'PROCESSING'])
            .order('created_at', { ascending: false }),
        supabase
            .from('refunds')
            .select(SELECT)
            .in('status', ['COMPLETED', 'REJECTED', 'FAILED'])
            .order('created_at', { ascending: false })
            .limit(100),
    ]);

    const error = pendingResult.error ?? processingResult.error ?? completedResult.error;

    if (error) {
        return (
            <>
                <PageHeader title="Refunds" />
                <Card>
                    <ErrorState title="Could not load refunds" message={error.message} />
                </Card>
            </>
        );
    }

    const pending = (pendingResult.data ?? []) as unknown as RefundRow[];
    const processing = (processingResult.data ?? []) as unknown as RefundRow[];
    const completed = (completedResult.data ?? []) as unknown as RefundRow[];

    const pendingValue = pending.reduce((sum, refund) => sum + Number(refund.amount), 0);
    const completedValue = completed
        .filter((refund) => refund.status === 'COMPLETED')
        .reduce((sum, refund) => sum + Number(refund.amount_processed), 0);
    const failedCount = completed.filter((refund) => refund.status === 'FAILED').length;

    return (
        <>
            <PageHeader
                title="Refunds"
                description="Approve, reject and track money going back to customers. Every decision is audited."
            />

            <section aria-label="Refund summary" className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard
                    label="Awaiting approval"
                    value={pending.length}
                    icon={Clock}
                    tone={pending.length > 0 ? 'caution' : 'neutral'}
                    hint={money(pendingValue)}
                />
                <StatCard label="In progress" value={processing.length} icon={IndianRupee} tone="brand" />
                <StatCard
                    label="Completed (recent)"
                    value={money(completedValue)}
                    icon={CheckCircle2}
                    tone="positive"
                />
                <StatCard
                    label="Failed"
                    value={failedCount}
                    icon={AlertCircle}
                    tone={failedCount > 0 ? 'critical' : 'neutral'}
                    hint={failedCount > 0 ? 'Needs manual follow-up' : 'Nothing failed'}
                />
            </section>

            <Tabs defaultValue="pending">
                <TabsList>
                    <TabsTrigger value="pending">
                        Awaiting approval
                        {pending.length > 0 ? (
                            <span className="tnum ml-1 rounded-full bg-caution-soft px-1.5 text-[11px] font-semibold text-caution">
                                {pending.length}
                            </span>
                        ) : null}
                    </TabsTrigger>
                    <TabsTrigger value="processing">In progress</TabsTrigger>
                    <TabsTrigger value="history">History</TabsTrigger>
                </TabsList>

                <TabsContent value="pending">
                    <RefundQueue refunds={pending} canApprove={canApprove} />
                </TabsContent>

                <TabsContent value="processing">
                    <RefundQueue refunds={processing} canApprove={false} />
                </TabsContent>

                <TabsContent value="history">
                    <RefundQueue refunds={completed} canApprove={false} />
                </TabsContent>
            </Tabs>
        </>
    );
}
