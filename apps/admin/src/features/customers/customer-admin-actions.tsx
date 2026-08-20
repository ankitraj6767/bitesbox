'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Ban, CircleCheck, Gift, MoreHorizontal, NotebookPen } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
    ConfirmDialog,
    Dialog,
    DialogBody,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from '@/components/ui/overlays';
import { Field, Input, Textarea } from '@/components/ui/form-controls';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import { money } from '@/lib/utils';

/**
 * Blocking a customer and issuing credit both move money or access, so both go
 * through the audited `admin-operation` Edge Function rather than a direct table
 * write from the browser.
 */
export function CustomerAdminActions({
    customerId,
    customerName,
    isBlocked,
    permissions,
}: {
    customerId: string;
    customerName: string;
    isBlocked: boolean;
    permissions: string[];
}) {
    const router = useRouter();
    const [blockOpen, setBlockOpen] = React.useState(false);
    const [creditOpen, setCreditOpen] = React.useState(false);
    const [noteOpen, setNoteOpen] = React.useState(false);
    const [reason, setReason] = React.useState('');
    const [amount, setAmount] = React.useState('100');
    const [creditNote, setCreditNote] = React.useState('');
    const [note, setNote] = React.useState('');

    const can = (code: string) => permissions.includes(code);

    const invokeAdmin = async (operation: string, payload: Record<string, unknown>) => {
        const supabase = createSupabaseBrowserClient();
        const { data, error } = await supabase.functions.invoke('admin-operation', {
            body: { operation, ...payload },
        });

        if (error) {
            // Edge Functions return the machine-readable code inside the body.
            const context = (error as { context?: { body?: unknown } }).context;
            throw context?.body ?? error;
        }
        return data;
    };

    const block = useMutation({
        mutationFn: () =>
            invokeAdmin(isBlocked ? 'unblock_customer' : 'block_customer', {
                user_id: customerId,
                reason: reason.trim() || undefined,
            }),
        onSuccess: () => {
            toast.success(isBlocked ? 'Customer unblocked' : 'Customer blocked');
            setBlockOpen(false);
            setReason('');
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const credit = useMutation({
        mutationFn: () =>
            invokeAdmin('credit_wallet', {
                user_id: customerId,
                amount: Number(amount),
                description: creditNote.trim() || 'Goodwill credit from Bites Box support',
            }),
        onSuccess: () => {
            toast.success(`${money(Number(amount), true)} credited to the wallet`);
            setCreditOpen(false);
            setCreditNote('');
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const saveNote = useMutation({
        mutationFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase
                .from('profiles')
                .update({ internal_notes: note })
                .eq('id', customerId);
            if (error) throw error;
        },
        onSuccess: () => {
            toast.success('Note saved');
            setNoteOpen(false);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    return (
        <>
            <div className="flex items-center gap-2">
                {can('customer.credit') ? (
                    <Button variant="secondary" size="sm" onClick={() => setCreditOpen(true)}>
                        <Gift />
                        Issue credit
                    </Button>
                ) : null}

                <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="icon" aria-label="Customer actions">
                            <MoreHorizontal />
                        </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent>
                        {can('customer.update') ? (
                            <DropdownMenuItem onSelect={() => setNoteOpen(true)}>
                                <NotebookPen />
                                Internal note
                            </DropdownMenuItem>
                        ) : null}

                        {can('customer.block') ? (
                            <>
                                <DropdownMenuSeparator />
                                <DropdownMenuItem destructive={!isBlocked} onSelect={() => setBlockOpen(true)}>
                                    {isBlocked ? <CircleCheck /> : <Ban />}
                                    {isBlocked ? 'Unblock customer' : 'Block customer'}
                                </DropdownMenuItem>
                            </>
                        ) : null}
                    </DropdownMenuContent>
                </DropdownMenu>
            </div>

            <ConfirmDialog
                open={blockOpen}
                onOpenChange={setBlockOpen}
                title={isBlocked ? `Unblock ${customerName}?` : `Block ${customerName}?`}
                description={
                    isBlocked
                        ? 'They will be able to place orders again immediately.'
                        : 'They will not be able to place any further orders. Existing orders are unaffected. This is recorded in the audit log.'
                }
                confirmLabel={isBlocked ? 'Unblock' : 'Block customer'}
                destructive={!isBlocked}
                loading={block.isPending}
                onConfirm={() => block.mutate()}
            >
                {!isBlocked ? (
                    <Field label="Reason" required hint="Stored on the account and in the audit log.">
                        <Textarea
                            value={reason}
                            onChange={(event) => setReason(event.target.value)}
                            placeholder="Repeated fraudulent cash-on-delivery orders."
                            autoFocus
                        />
                    </Field>
                ) : null}
            </ConfirmDialog>

            <Dialog open={creditOpen} onOpenChange={setCreditOpen}>
                <DialogContent size="sm">
                    <DialogHeader>
                        <DialogTitle>Issue wallet credit</DialogTitle>
                        <DialogDescription>
                            Credit lands in the customer&apos;s Bites Box wallet immediately and appears on their
                            statement. It is posted to the wallet ledger, never as a bare balance change.
                        </DialogDescription>
                    </DialogHeader>

                    <DialogBody className="space-y-4">
                        <Field label="Amount" required>
                            <Input
                                type="number"
                                min={1}
                                max={5000}
                                value={amount}
                                onChange={(event) => setAmount(event.target.value)}
                                className="tnum"
                                autoFocus
                            />
                        </Field>
                        <Field label="Reason" hint="Shown to the customer on their wallet statement.">
                            <Textarea
                                value={creditNote}
                                onChange={(event) => setCreditNote(event.target.value)}
                                placeholder="Apologies for the late delivery on order BB-BKP01-260815-00042."
                            />
                        </Field>
                    </DialogBody>

                    <DialogFooter>
                        <Button variant="secondary" onClick={() => setCreditOpen(false)}>
                            Cancel
                        </Button>
                        <Button
                            loading={credit.isPending}
                            disabled={!amount || Number(amount) <= 0}
                            onClick={() => credit.mutate()}
                        >
                            Credit {money(Number(amount) || 0, true)}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            <Dialog open={noteOpen} onOpenChange={setNoteOpen}>
                <DialogContent size="sm">
                    <DialogHeader>
                        <DialogTitle>Internal note</DialogTitle>
                        <DialogDescription>Visible to staff only.</DialogDescription>
                    </DialogHeader>
                    <DialogBody>
                        <Field label="Note">
                            <Textarea
                                value={note}
                                onChange={(event) => setNote(event.target.value)}
                                placeholder="Prefers deliveries after 8 PM. Always calls to confirm."
                                autoFocus
                            />
                        </Field>
                    </DialogBody>
                    <DialogFooter>
                        <Button variant="secondary" onClick={() => setNoteOpen(false)}>
                            Cancel
                        </Button>
                        <Button loading={saveNote.isPending} onClick={() => saveNote.mutate()}>
                            Save note
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    );
}
