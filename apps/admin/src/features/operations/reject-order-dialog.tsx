'use client';

import * as React from 'react';
import {
    Dialog,
    DialogBody,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/overlays';
import { Button } from '@/components/ui/button';
import {
    Field,
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
    Textarea,
} from '@/components/ui/form-controls';
import { InlineNotice } from '@/components/ui/states';
import { money } from '@/lib/utils';
import { useOrderActions } from './order-actions';
import type { CancellationReason } from '@bitesbox/shared-types';

const REJECT_REASONS: Array<{ value: CancellationReason; label: string }> = [
    { value: 'ITEM_UNAVAILABLE', label: 'An item is unavailable' },
    { value: 'KITCHEN_OVERLOADED', label: 'Kitchen is overloaded' },
    { value: 'RESTAURANT_CLOSED', label: 'Kitchen is closing' },
    { value: 'ADDRESS_WRONG', label: 'Delivery address is unusable' },
    { value: 'NO_DELIVERY_PARTNER', label: 'No delivery partner available' },
    { value: 'FRAUD_SUSPECTED', label: 'Suspected fraud' },
    { value: 'OTHER', label: 'Other' },
];

const CANCEL_REASONS: Array<{ value: CancellationReason; label: string }> = [
    ...REJECT_REASONS,
    { value: 'CUSTOMER_UNREACHABLE', label: 'Customer unreachable' },
    { value: 'DUPLICATE_ORDER', label: 'Duplicate order' },
    { value: 'WEATHER', label: 'Weather' },
];

/**
 * Rejecting or cancelling a paid order always creates a refund obligation, so
 * the dialog states the amount plainly before the operator commits.
 */
export function RejectOrderDialog({
    open,
    onOpenChange,
    mode,
    orderId,
    orderNumber,
    refundableAmount,
    isPaid,
}: {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    mode: 'reject' | 'cancel';
    orderId: string | null;
    orderNumber: string | null;
    refundableAmount: number;
    isPaid: boolean;
}) {
    const { reject, cancel } = useOrderActions();
    const [reason, setReason] = React.useState<CancellationReason>('ITEM_UNAVAILABLE');
    const [note, setNote] = React.useState('');

    React.useEffect(() => {
        if (open) {
            setReason(mode === 'reject' ? 'ITEM_UNAVAILABLE' : 'KITCHEN_OVERLOADED');
            setNote('');
        }
    }, [open, mode]);

    const pending = reject.isPending || cancel.isPending;
    const reasons = mode === 'reject' ? REJECT_REASONS : CANCEL_REASONS;

    const submit = async () => {
        if (!orderId) return;

        if (mode === 'reject') {
            await reject.mutateAsync({ orderId, reason, note: note.trim() || undefined });
        } else {
            await cancel.mutateAsync({ orderId, reason, note: note.trim() || undefined });
        }

        onOpenChange(false);
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent size="sm">
                <DialogHeader>
                    <DialogTitle>
                        {mode === 'reject' ? 'Reject this order' : 'Cancel this order'}
                    </DialogTitle>
                    <DialogDescription>
                        {orderNumber ? `Order ${orderNumber}. ` : ''}
                        The customer is notified immediately with the reason you choose.
                    </DialogDescription>
                </DialogHeader>

                <DialogBody className="space-y-4">
                    {isPaid && refundableAmount > 0 ? (
                        <InlineNotice tone="caution">
                            This order is paid. {money(refundableAmount, true)} will need refunding — raise it from
                            the order screen straight after.
                        </InlineNotice>
                    ) : null}

                    <Field label="Reason" required>
                        <Select value={reason} onValueChange={(value) => setReason(value as CancellationReason)}>
                            <SelectTrigger>
                                <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                                {reasons.map((option) => (
                                    <SelectItem key={option.value} value={option.value}>
                                        {option.label}
                                    </SelectItem>
                                ))}
                            </SelectContent>
                        </Select>
                    </Field>

                    <Field
                        label="Note for the customer"
                        hint="Optional. Appears in the cancellation message they receive."
                    >
                        <Textarea
                            value={note}
                            onChange={(event) => setNote(event.target.value)}
                            placeholder="Sorry — the mutton has finished for the evening."
                            maxLength={200}
                        />
                    </Field>
                </DialogBody>

                <DialogFooter>
                    <Button variant="secondary" onClick={() => onOpenChange(false)} disabled={pending}>
                        Keep the order
                    </Button>
                    <Button variant="destructive" onClick={submit} loading={pending}>
                        {mode === 'reject' ? 'Reject order' : 'Cancel order'}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
