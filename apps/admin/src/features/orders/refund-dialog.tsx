'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import {
    Dialog,
    DialogBody,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/overlays';
import {
    Field,
    Input,
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
    Textarea,
} from '@/components/ui/form-controls';
import { InlineNotice } from '@/components/ui/states';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import { money } from '@/lib/utils';
import type { OrderDetail, RefundDestination, RefundKind, RefundReason } from '@bitesbox/shared-types';

const REASONS: Array<{ value: RefundReason; label: string }> = [
    { value: 'MISSING_ITEM', label: 'Item missing from the order' },
    { value: 'WRONG_ITEM', label: 'Wrong item delivered' },
    { value: 'QUALITY_ISSUE', label: 'Food quality issue' },
    { value: 'LATE_DELIVERY', label: 'Delivered too late' },
    { value: 'DELIVERY_FAILURE', label: 'Delivery failed' },
    { value: 'RESTAURANT_CANCELLED', label: 'Restaurant cancelled' },
    { value: 'ITEM_UNAVAILABLE', label: 'Item unavailable' },
    { value: 'CUSTOMER_CANCELLATION', label: 'Customer cancelled' },
    { value: 'PAYMENT_ISSUE', label: 'Payment issue' },
    { value: 'DUPLICATE_PAYMENT', label: 'Duplicate payment' },
    { value: 'GOODWILL', label: 'Goodwill gesture' },
    { value: 'MANUAL_ADJUSTMENT', label: 'Manual adjustment' },
];

/**
 * Raise a refund.
 *
 * The amount is only ever a *request*: `request_refund` re-derives what is
 * actually refundable, applies the requester's role limit and decides whether
 * approval is needed. The dialog shows the server's ceiling so operators are not
 * surprised.
 */
export function RefundDialog({
    open,
    onOpenChange,
    order,
    refundable,
    gatewayRefundPossible,
}: {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    order: OrderDetail;
    refundable: number;
    gatewayRefundPossible: boolean;
}) {
    const router = useRouter();
    const [kind, setKind] = React.useState<RefundKind>('FULL_REFUND');
    const [reason, setReason] = React.useState<RefundReason>('QUALITY_ISSUE');
    const [destination, setDestination] = React.useState<RefundDestination>(
        gatewayRefundPossible ? 'ORIGINAL_PAYMENT_METHOD' : 'WALLET_CREDIT',
    );
    const [amount, setAmount] = React.useState('');
    const [note, setNote] = React.useState('');
    const [items, setItems] = React.useState<Record<string, number>>({});

    React.useEffect(() => {
        if (!open) return;
        setKind('FULL_REFUND');
        setAmount(String(refundable));
        setNote('');
        setItems({});
        setDestination(gatewayRefundPossible ? 'ORIGINAL_PAYMENT_METHOD' : 'WALLET_CREDIT');
    }, [open, refundable, gatewayRefundPossible]);

    const itemTotal = React.useMemo(() => {
        return order.items.reduce((sum, item) => {
            const qty = items[item.id] ?? 0;
            if (qty <= 0) return sum;
            const unit = item.quantity > 0 ? item.net_amount / item.quantity : 0;
            return sum + unit * qty;
        }, 0);
    }, [items, order.items]);

    const requested =
        kind === 'FULL_REFUND' ? refundable : kind === 'ITEM_REFUND' ? itemTotal : Number(amount || 0);

    const overLimit = requested > refundable + 0.001;
    const invalid = requested <= 0 || overLimit;

    const mutation = useMutation({
        mutationFn: async () => {
            const supabase = createSupabaseBrowserClient();

            const payload = Object.entries(items)
                .filter(([, qty]) => qty > 0)
                .map(([orderItemId, qty]) => ({ order_item_id: orderItemId, quantity: qty }));

            const { data, error } = await supabase.rpc('request_refund', {
                p_order_id: order.id,
                p_kind: kind,
                p_reason: reason,
                p_amount: kind === 'PARTIAL_REFUND' ? Number(amount) : undefined,
                p_destination: destination,
                p_reason_note: note.trim() || undefined,
                p_items: kind === 'ITEM_REFUND' ? payload : undefined,
                // Stable key: a double submit returns the original refund instead of a second one.
                p_idempotency_key: `admin:${order.id}:${kind}:${requested.toFixed(2)}`,
            });

            if (error) throw error;
            return data as {
                refund_id: string;
                status: string;
                auto_approved: boolean;
                requires_gateway_call: boolean;
                amount: number;
            };
        },
        onSuccess: (data) => {
            toast.success(
                data.auto_approved
                    ? `Refund of ${money(data.amount, true)} approved and processing`
                    : `Refund of ${money(data.amount, true)} raised — awaiting approval`,
            );
            onOpenChange(false);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent size="lg">
                <DialogHeader>
                    <DialogTitle>Refund order {order.order_number}</DialogTitle>
                    <DialogDescription>
                        {money(refundable, true)} of {money(order.totals.grand_total, true)} can still be
                        refunded. Every refund is recorded in the audit log.
                    </DialogDescription>
                </DialogHeader>

                <DialogBody className="space-y-4">
                    {refundable <= 0 ? (
                        <InlineNotice tone="critical">
                            This order has already been fully refunded, or a refund is in progress.
                        </InlineNotice>
                    ) : null}

                    <Field label="Refund type" required>
                        <Select value={kind} onValueChange={(value) => setKind(value as RefundKind)}>
                            <SelectTrigger>
                                <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="FULL_REFUND">Full refund — {money(refundable, true)}</SelectItem>
                                <SelectItem value="ITEM_REFUND">Specific items</SelectItem>
                                <SelectItem value="PARTIAL_REFUND">Custom amount</SelectItem>
                            </SelectContent>
                        </Select>
                    </Field>

                    {kind === 'ITEM_REFUND' ? (
                        <div className="rounded-[var(--radius-control)] border border-hairline">
                            <p className="border-b border-hairline px-3 py-2 text-[12.5px] font-medium text-ink-muted">
                                Choose the items to refund
                            </p>
                            <ul className="divide-y divide-hairline">
                                {order.items.map((item) => {
                                    const remaining = item.quantity - item.refunded_quantity;
                                    const unit = item.quantity > 0 ? item.net_amount / item.quantity : 0;

                                    return (
                                        <li key={item.id} className="flex items-center gap-3 px-3 py-2.5">
                                            <div className="min-w-0 flex-1">
                                                <p className="truncate text-[13px] font-medium text-ink">
                                                    {item.product_name}
                                                    {item.variant_name ? (
                                                        <span className="text-ink-muted"> · {item.variant_name}</span>
                                                    ) : null}
                                                </p>
                                                <p className="text-[11.5px] text-ink-muted">
                                                    {money(unit, true)} each · {remaining} of {item.quantity} refundable
                                                </p>
                                            </div>
                                            <Input
                                                type="number"
                                                min={0}
                                                max={remaining}
                                                value={items[item.id] ?? 0}
                                                disabled={remaining <= 0}
                                                onChange={(event) =>
                                                    setItems((current) => ({
                                                        ...current,
                                                        [item.id]: Math.max(0, Math.min(remaining, Number(event.target.value))),
                                                    }))
                                                }
                                                className="tnum w-20 shrink-0 text-right"
                                                aria-label={`Quantity to refund for ${item.product_name}`}
                                            />
                                        </li>
                                    );
                                })}
                            </ul>
                            <p className="tnum border-t border-hairline px-3 py-2 text-right text-[13px] font-semibold text-ink">
                                {money(itemTotal, true)}
                            </p>
                        </div>
                    ) : null}

                    {kind === 'PARTIAL_REFUND' ? (
                        <Field
                            label="Amount"
                            required
                            error={overLimit ? `Cannot exceed ${money(refundable, true)}` : null}
                            hint={`Up to ${money(refundable, true)}`}
                        >
                            <Input
                                type="number"
                                min={1}
                                max={refundable}
                                step="0.01"
                                value={amount}
                                onChange={(event) => setAmount(event.target.value)}
                                aria-invalid={overLimit}
                                className="tnum"
                            />
                        </Field>
                    ) : null}

                    <div className="grid gap-4 sm:grid-cols-2">
                        <Field label="Reason" required>
                            <Select value={reason} onValueChange={(value) => setReason(value as RefundReason)}>
                                <SelectTrigger>
                                    <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                    {REASONS.map((option) => (
                                        <SelectItem key={option.value} value={option.value}>
                                            {option.label}
                                        </SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                        </Field>

                        <Field
                            label="Refund to"
                            required
                            hint={
                                gatewayRefundPossible
                                    ? 'Gateway refunds take 3–5 working days. Wallet credit is instant.'
                                    : 'This order was paid in cash, so only wallet credit is possible.'
                            }
                        >
                            <Select
                                value={destination}
                                onValueChange={(value) => setDestination(value as RefundDestination)}
                            >
                                <SelectTrigger>
                                    <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                    {gatewayRefundPossible ? (
                                        <SelectItem value="ORIGINAL_PAYMENT_METHOD">Original payment method</SelectItem>
                                    ) : null}
                                    <SelectItem value="WALLET_CREDIT">Bites Box wallet</SelectItem>
                                </SelectContent>
                            </Select>
                        </Field>
                    </div>

                    <Field label="Internal note" hint="Why this refund was granted. Visible to staff only.">
                        <Textarea
                            value={note}
                            onChange={(event) => setNote(event.target.value)}
                            placeholder="Customer sent a photo — biryani was cold on arrival."
                            maxLength={300}
                        />
                    </Field>

                    <div className="rounded-[var(--radius-control)] bg-surface-muted px-3 py-2.5">
                        <p className="flex items-center justify-between text-[13px]">
                            <span className="text-ink-muted">Refund amount</span>
                            <span className="tnum font-display text-base font-semibold text-ink">
                                {money(requested, true)}
                            </span>
                        </p>
                    </div>
                </DialogBody>

                <DialogFooter>
                    <Button variant="secondary" onClick={() => onOpenChange(false)} disabled={mutation.isPending}>
                        Cancel
                    </Button>
                    <Button
                        variant="destructive"
                        loading={mutation.isPending}
                        disabled={invalid || refundable <= 0}
                        onClick={() => mutation.mutate()}
                    >
                        Refund {money(requested, true)}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
