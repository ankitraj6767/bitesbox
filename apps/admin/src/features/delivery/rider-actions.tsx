'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { BadgeCheck, Ban, MoreHorizontal, RotateCcw } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
    ConfirmDialog,
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from '@/components/ui/overlays';
import { Field, Textarea } from '@/components/ui/form-controls';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import type { RiderOnboardingStatus } from '@bitesbox/shared-types';

/**
 * Approving a rider lets them accept real deliveries, so it runs through the
 * audited `admin-operation` function which also verifies their documents are
 * approved before activating them.
 */
export function RiderActions({
    riderId,
    riderName,
    status,
    permissions,
}: {
    riderId: string;
    riderName: string;
    status: RiderOnboardingStatus;
    permissions: string[];
}) {
    const router = useRouter();
    const [approveOpen, setApproveOpen] = React.useState(false);
    const [suspendOpen, setSuspendOpen] = React.useState(false);
    const [reason, setReason] = React.useState('');

    const canApprove = permissions.includes('rider.approve');
    const canSuspend = permissions.includes('rider.suspend');

    const call = async (operation: string, payload: Record<string, unknown>) => {
        const supabase = createSupabaseBrowserClient();
        const { data, error } = await supabase.functions.invoke('admin-operation', {
            body: { operation, ...payload },
        });
        if (error) {
            const context = (error as { context?: { body?: unknown } }).context;
            throw context?.body ?? error;
        }
        return data;
    };

    const approve = useMutation({
        mutationFn: () => call('approve_rider', { delivery_partner_id: riderId }),
        onSuccess: () => {
            toast.success(`${riderName} can now accept deliveries`);
            setApproveOpen(false);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const suspend = useMutation({
        mutationFn: () =>
            call('suspend_rider', { delivery_partner_id: riderId, reason: reason.trim() || undefined }),
        onSuccess: () => {
            toast.success(`${riderName} suspended`);
            setSuspendOpen(false);
            setReason('');
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const reinstate = useMutation({
        mutationFn: () => call('approve_rider', { delivery_partner_id: riderId }),
        onSuccess: () => {
            toast.success(`${riderName} reinstated`);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const needsApproval = ['PENDING', 'DOCUMENTS_SUBMITTED', 'VERIFIED'].includes(status);
    const isSuspended = status === 'SUSPENDED' || status === 'REJECTED';

    if (!canApprove && !canSuspend) return null;

    return (
        <>
            <div className="flex items-center gap-1.5">
                {needsApproval && canApprove ? (
                    <Button size="sm" onClick={() => setApproveOpen(true)}>
                        <BadgeCheck />
                        Approve
                    </Button>
                ) : null}

                {isSuspended && canApprove ? (
                    <Button
                        size="sm"
                        variant="secondary"
                        loading={reinstate.isPending}
                        onClick={() => reinstate.mutate()}
                    >
                        <RotateCcw />
                        Reinstate
                    </Button>
                ) : null}

                {status === 'ACTIVE' && canSuspend ? (
                    <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="iconSm" aria-label={`Actions for ${riderName}`}>
                                <MoreHorizontal />
                            </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent>
                            <DropdownMenuSeparator />
                            <DropdownMenuItem destructive onSelect={() => setSuspendOpen(true)}>
                                <Ban />
                                Suspend rider
                            </DropdownMenuItem>
                        </DropdownMenuContent>
                    </DropdownMenu>
                ) : null}
            </div>

            <ConfirmDialog
                open={approveOpen}
                onOpenChange={setApproveOpen}
                title={`Approve ${riderName}?`}
                description="They will be able to go online and accept deliveries. All submitted documents must be approved first — the server checks this."
                confirmLabel="Approve rider"
                loading={approve.isPending}
                onConfirm={() => approve.mutate()}
            />

            <ConfirmDialog
                open={suspendOpen}
                onOpenChange={setSuspendOpen}
                title={`Suspend ${riderName}?`}
                description="They will be taken offline and cannot accept new deliveries. Active deliveries must be completed or reassigned first."
                confirmLabel="Suspend rider"
                destructive
                loading={suspend.isPending}
                onConfirm={() => suspend.mutate()}
            >
                <Field label="Reason" required hint="Recorded in the audit log.">
                    <Textarea
                        value={reason}
                        onChange={(event) => setReason(event.target.value)}
                        placeholder="Repeated late deliveries and unreachable on phone."
                        autoFocus
                    />
                </Field>
            </ConfirmDialog>
        </>
    );
}
