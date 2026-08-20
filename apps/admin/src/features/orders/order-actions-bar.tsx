'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import {
    Bike,
    Check,
    ChefHat,
    MoreHorizontal,
    NotebookPen,
    PackageCheck,
    Phone,
    ReceiptText,
    XCircle,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
    Dialog,
    DialogBody,
    DialogContent,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from '@/components/ui/overlays';
import { Field, Textarea } from '@/components/ui/form-controls';
import { useOrderActions } from '@/features/operations/order-actions';
import { AssignRiderDialog } from '@/features/operations/assign-rider-dialog';
import { RejectOrderDialog } from '@/features/operations/reject-order-dialog';
import { RefundDialog } from './refund-dialog';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { useQuery } from '@tanstack/react-query';
import type { AvailableRider, OrderDetail } from '@bitesbox/shared-types';

/**
 * Contextual action bar for a single order. Which buttons appear is driven by the
 * order's current status and the operator's permissions; the server still
 * validates every transition.
 */
export function OrderActionsBar({
    order,
    refundable,
    gatewayRefundPossible,
    permissions,
    branchId,
}: {
    order: OrderDetail;
    refundable: number;
    gatewayRefundPossible: boolean;
    permissions: string[];
    branchId: string | null;
}) {
    const router = useRouter();
    const { accept, startPreparing, markReady, addNote } = useOrderActions();

    const [assignOpen, setAssignOpen] = React.useState(false);
    const [refundOpen, setRefundOpen] = React.useState(false);
    const [noteOpen, setNoteOpen] = React.useState(false);
    const [note, setNote] = React.useState('');
    const [rejectMode, setRejectMode] = React.useState<'reject' | 'cancel' | null>(null);

    const can = (code: string) => permissions.includes(code);

    const { data: riders = [] } = useQuery<AvailableRider[]>({
        queryKey: ['available-riders', branchId],
        enabled: assignOpen,
        queryFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('available_riders', {
                p_branch_id: branchId ?? undefined,
                p_order_id: order.id,
            });
            if (error) throw error;
            return (data ?? []) as unknown as AvailableRider[];
        },
    });

    const status = order.status;
    const isDelivery = order.fulfilment_type === 'DELIVERY';
    const isPaid = order.payment.status === 'CAPTURED';

    const submitNote = async () => {
        if (!note.trim()) return;
        await addNote.mutateAsync({ orderId: order.id, note: note.trim() });
        setNote('');
        setNoteOpen(false);
        router.refresh();
    };

    return (
        <>
            <div className="flex flex-wrap items-center gap-2">
                {status === 'ORDER_PLACED' && can('order.accept') ? (
                    <Button loading={accept.isPending} onClick={() => accept.mutate({ orderId: order.id })}>
                        <Check />
                        Accept order
                    </Button>
                ) : null}

                {status === 'STORE_ACCEPTED' && can('order.prepare') ? (
                    <Button loading={startPreparing.isPending} onClick={() => startPreparing.mutate(order.id)}>
                        <ChefHat />
                        Start preparing
                    </Button>
                ) : null}

                {status === 'PREPARING' && can('order.ready') ? (
                    <Button loading={markReady.isPending} onClick={() => markReady.mutate(order.id)}>
                        <PackageCheck />
                        Mark ready
                    </Button>
                ) : null}

                {isDelivery &&
                    can('delivery.assign') &&
                    ['READY_FOR_PICKUP', 'STORE_ACCEPTED', 'PREPARING', 'RIDER_ASSIGNED', 'RIDER_ARRIVED_STORE'].includes(
                        status,
                    ) ? (
                    <Button variant="secondary" onClick={() => setAssignOpen(true)}>
                        <Bike />
                        {order.rider ? 'Reassign rider' : 'Assign rider'}
                    </Button>
                ) : null}

                {can('refund.create') && refundable > 0 && isPaid ? (
                    <Button variant="secondary" onClick={() => setRefundOpen(true)}>
                        <ReceiptText />
                        Refund
                    </Button>
                ) : null}

                {order.customer.phone ? (
                    <Button asChild variant="ghost">
                        <a href={`tel:${order.customer.phone}`}>
                            <Phone />
                            Call customer
                        </a>
                    </Button>
                ) : null}

                <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="icon" aria-label="More actions">
                            <MoreHorizontal />
                        </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent>
                        {can('order.note') ? (
                            <DropdownMenuItem onSelect={() => setNoteOpen(true)}>
                                <NotebookPen />
                                Add internal note
                            </DropdownMenuItem>
                        ) : null}

                        {order.rider?.phone ? (
                            <DropdownMenuItem asChild>
                                <a href={`tel:${order.rider.phone}`}>
                                    <Phone />
                                    Call delivery partner
                                </a>
                            </DropdownMenuItem>
                        ) : null}

                        {['DELIVERED', 'COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED'].includes(status) ? (
                            <DropdownMenuItem onSelect={() => router.push(`/orders/${order.id}/invoice`)}>
                                <ReceiptText />
                                View invoice
                            </DropdownMenuItem>
                        ) : null}

                        {can('order.reject') && status === 'ORDER_PLACED' ? (
                            <>
                                <DropdownMenuSeparator />
                                <DropdownMenuItem destructive onSelect={() => setRejectMode('reject')}>
                                    <XCircle />
                                    Reject order
                                </DropdownMenuItem>
                            </>
                        ) : null}

                        {can('order.cancel') && order.is_active && status !== 'ORDER_PLACED' ? (
                            <>
                                <DropdownMenuSeparator />
                                <DropdownMenuItem destructive onSelect={() => setRejectMode('cancel')}>
                                    <XCircle />
                                    Cancel order
                                </DropdownMenuItem>
                            </>
                        ) : null}
                    </DropdownMenuContent>
                </DropdownMenu>
            </div>

            <AssignRiderDialog
                open={assignOpen}
                onOpenChange={setAssignOpen}
                orderId={order.id}
                orderNumber={order.order_number}
                currentRiderName={order.rider?.name}
                riders={riders}
            />

            <RefundDialog
                open={refundOpen}
                onOpenChange={setRefundOpen}
                order={order}
                refundable={refundable}
                gatewayRefundPossible={gatewayRefundPossible}
            />

            <RejectOrderDialog
                open={rejectMode !== null}
                onOpenChange={(open) => !open && setRejectMode(null)}
                mode={rejectMode ?? 'reject'}
                orderId={order.id}
                orderNumber={order.order_number}
                refundableAmount={refundable}
                isPaid={isPaid}
            />

            <Dialog open={noteOpen} onOpenChange={setNoteOpen}>
                <DialogContent size="sm">
                    <DialogHeader>
                        <DialogTitle>Add an internal note</DialogTitle>
                    </DialogHeader>
                    <DialogBody>
                        <Field label="Note" hint="Staff only. The customer never sees this.">
                            <Textarea
                                value={note}
                                onChange={(event) => setNote(event.target.value)}
                                placeholder="Called the customer — they asked us to leave it with the guard."
                                autoFocus
                            />
                        </Field>
                    </DialogBody>
                    <DialogFooter>
                        <Button variant="secondary" onClick={() => setNoteOpen(false)}>
                            Cancel
                        </Button>
                        <Button loading={addNote.isPending} disabled={!note.trim()} onClick={submitNote}>
                            Save note
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    );
}
