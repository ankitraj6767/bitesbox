'use client';

import * as React from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Check, ReceiptText, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge, refundStatusTone } from '@/components/ui/badge';
import { EmptyState } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import {
    Dialog,
    DialogBody,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/overlays';
import { Field, Textarea } from '@/components/ui/form-controls';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import { dateTime, money, humanise } from '@/lib/utils';
import type { RefundStatus, RefundKind, RefundReason, RefundDestination } from '@bitesbox/shared-types';

export interface RefundRow {
    id: string;
    order_id: string;
    status: RefundStatus;
    kind: RefundKind;
    reason: RefundReason;
    reason_note: string | null;
    destination: RefundDestination;
    amount: number;
    amount_processed: number;
    created_at: string;
    completed_at: string | null;
    requested_by: string | null;
    orders: { order_number: string; customer_name: string | null; grand_total: number } | null;
    requester: { full_name: string | null } | null;
}

/**
 * Approval queue. `approve_refund` enforces the four-eyes rule server-side, so
 * a requester attempting to approve their own large refund is rejected there —
 * the UI simply surfaces the message.
 */
export function RefundQueue({ refunds, canApprove }: { refunds: RefundRow[]; canApprove: boolean }) {
    const router = useRouter();
    const [rejectFor, setRejectFor] = React.useState<RefundRow | null>(null);
    const [note, setNote] = React.useState('');

    const approve = useMutation({
        mutationFn: async (refundId: string) => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('approve_refund', { p_refund_id: refundId });
            if (error) throw error;
            return data as { requires_gateway_call?: boolean; amount?: number } | null;
        },
        onSuccess: (data) => {
            toast.success(
                data?.requires_gateway_call
                    ? `Approved. ${money(data.amount ?? 0, true)} is being sent to the original payment method.`
                    : 'Refund approved and credited.',
            );
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const reject = useMutation({
        mutationFn: async ({ refundId, reason }: { refundId: string; reason: string }) => {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase.rpc('reject_refund', {
                p_refund_id: refundId,
                p_note: reason,
            });
            if (error) throw error;
        },
        onSuccess: () => {
            toast.success('Refund rejected');
            setRejectFor(null);
            setNote('');
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    return (
        <>
            <TableWrap>
                <Table>
                    <THead>
                        <TR className="hover:bg-transparent">
                            <TH>Order</TH>
                            <TH>Customer</TH>
                            <TH>Reason</TH>
                            <TH>Refund to</TH>
                            <TH numeric>Amount</TH>
                            <TH>Status</TH>
                            <TH>Requested</TH>
                            {canApprove ? <TH className="w-40" /> : null}
                        </TR>
                    </THead>
                    <TBody>
                        {refunds.length === 0 ? (
                            <TableMessageRow colSpan={canApprove ? 8 : 7}>
                                <EmptyState
                                    icon={ReceiptText}
                                    title="Nothing waiting"
                                    description="Refund requests appear here for approval."
                                />
                            </TableMessageRow>
                        ) : (
                            refunds.map((refund) => {
                                const pending =
                                    refund.status === 'REQUESTED' || refund.status === 'APPROVAL_PENDING';

                                return (
                                    <TR key={refund.id}>
                                        <TD>
                                            <Link
                                                href={`/orders/${refund.order_id}`}
                                                className="font-mono text-[12.5px] font-semibold text-ink hover:text-brand-600"
                                            >
                                                {refund.orders?.order_number ?? '—'}
                                            </Link>
                                            <span className="block text-[11.5px] text-ink-muted">
                                                {humanise(refund.kind)}
                                            </span>
                                        </TD>

                                        <TD className="max-w-40 truncate text-[13px]">
                                            {refund.orders?.customer_name ?? 'Customer'}
                                        </TD>

                                        <TD>
                                            <span className="block text-[12.5px]">{humanise(refund.reason)}</span>
                                            {refund.reason_note ? (
                                                <span className="block max-w-56 truncate text-[11.5px] text-ink-muted">
                                                    {refund.reason_note}
                                                </span>
                                            ) : null}
                                        </TD>

                                        <TD className="text-[12.5px]">
                                            {refund.destination === 'WALLET_CREDIT' ? 'Wallet' : 'Original method'}
                                        </TD>

                                        <TD numeric>
                                            <span className="text-[13px] font-semibold">{money(refund.amount, true)}</span>
                                            {refund.orders ? (
                                                <span className="block text-[11.5px] text-ink-muted">
                                                    of {money(refund.orders.grand_total)}
                                                </span>
                                            ) : null}
                                        </TD>

                                        <TD>
                                            <Badge tone={refundStatusTone(refund.status)}>{humanise(refund.status)}</Badge>
                                        </TD>

                                        <TD className="text-[12.5px] whitespace-nowrap text-ink-muted">
                                            {dateTime(refund.created_at)}
                                            {refund.requester?.full_name ? (
                                                <span className="block text-[11.5px]">by {refund.requester.full_name}</span>
                                            ) : null}
                                        </TD>

                                        {canApprove ? (
                                            <TD>
                                                {pending ? (
                                                    <div className="flex gap-1.5">
                                                        <Button
                                                            size="sm"
                                                            variant="success"
                                                            loading={approve.isPending && approve.variables === refund.id}
                                                            onClick={() => approve.mutate(refund.id)}
                                                        >
                                                            <Check />
                                                            Approve
                                                        </Button>
                                                        <Button
                                                            size="sm"
                                                            variant="outlineDestructive"
                                                            onClick={() => setRejectFor(refund)}
                                                            aria-label="Reject refund"
                                                        >
                                                            <X />
                                                        </Button>
                                                    </div>
                                                ) : (
                                                    <span className="text-[12px] text-ink-muted">
                                                        {refund.completed_at ? dateTime(refund.completed_at) : '—'}
                                                    </span>
                                                )}
                                            </TD>
                                        ) : null}
                                    </TR>
                                );
                            })
                        )}
                    </TBody>
                </Table>
            </TableWrap>

            <Dialog open={rejectFor !== null} onOpenChange={(open) => !open && setRejectFor(null)}>
                <DialogContent size="sm">
                    <DialogHeader>
                        <DialogTitle>Reject this refund</DialogTitle>
                        <DialogDescription>
                            {rejectFor
                                ? `${money(rejectFor.amount, true)} for order ${rejectFor.orders?.order_number ?? ''}. The reason is stored in the audit log.`
                                : ''}
                        </DialogDescription>
                    </DialogHeader>

                    <DialogBody>
                        <Field label="Why is this being rejected?" required>
                            <Textarea
                                value={note}
                                onChange={(event) => setNote(event.target.value)}
                                placeholder="Delivery photo shows the full order was handed over."
                                autoFocus
                            />
                        </Field>
                    </DialogBody>

                    <DialogFooter>
                        <Button variant="secondary" onClick={() => setRejectFor(null)}>
                            Cancel
                        </Button>
                        <Button
                            variant="destructive"
                            loading={reject.isPending}
                            disabled={!note.trim()}
                            onClick={() =>
                                rejectFor && reject.mutate({ refundId: rejectFor.id, reason: note.trim() })
                            }
                        >
                            Reject refund
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    );
}
