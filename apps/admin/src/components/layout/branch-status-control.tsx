'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { ChevronDown, Pause, Play, PauseCircle, Flame } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
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
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from '@/components/ui/overlays';
import { Field, Select, SelectContent, SelectItem, SelectTrigger, SelectValue, Textarea } from '@/components/ui/form-controls';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import type { BranchOrderingState, BranchStatus, BranchClosureReason } from '@bitesbox/shared-types';

const CLOSURE_REASONS: Array<{ value: BranchClosureReason; label: string }> = [
    { value: 'TOO_BUSY', label: 'Kitchen too busy' },
    { value: 'KITCHEN_ISSUE', label: 'Kitchen issue' },
    { value: 'TECHNICAL_ISSUE', label: 'Technical issue' },
    { value: 'WEATHER', label: 'Weather' },
    { value: 'SCHEDULED_CLOSED', label: 'Closed for the day' },
    { value: 'HOLIDAY', label: 'Holiday' },
    { value: 'OTHER', label: 'Other' },
];

const RESUME_OPTIONS = [
    { value: '0', label: 'Until I reopen manually' },
    { value: '15', label: 'Reopen in 15 minutes' },
    { value: '30', label: 'Reopen in 30 minutes' },
    { value: '60', label: 'Reopen in 1 hour' },
];

/**
 * The single control that opens, pauses or closes the kitchen. Writes through
 * `set_branch_status`, which checks `branch.manage` and records the change in
 * `branch_status_log` for the audit trail.
 */
export function BranchStatusControl({ branch }: { branch: BranchOrderingState }) {
    const router = useRouter();
    const [dialogFor, setDialogFor] = React.useState<BranchStatus | null>(null);
    const [reason, setReason] = React.useState<BranchClosureReason>('TOO_BUSY');
    const [note, setNote] = React.useState('');
    const [resumeAfter, setResumeAfter] = React.useState('0');

    const mutation = useMutation({
        mutationFn: async (input: {
            status: BranchStatus;
            reason: BranchClosureReason | null;
            note: string | null;
            resumeAfterMinutes: number | null;
        }) => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('set_branch_status', {
                p_status: input.status,
                // Generated RPC types model defaulted arguments as optional, so an
                // omitted value must be `undefined` rather than `null`.
                p_reason: input.reason ?? undefined,
                p_note: input.note ?? undefined,
                p_branch_id: branch.branch_id,
                p_resume_after_minutes: input.resumeAfterMinutes ?? undefined,
            });

            if (error) throw error;
            return data;
        },
        onSuccess: (_data, input) => {
            toast.success(
                input.status === 'OPEN'
                    ? 'Kitchen is open and accepting orders'
                    : input.status === 'BUSY'
                        ? 'Marked as busy — customers will see a longer ETA'
                        : input.status === 'PAUSED'
                            ? 'New orders paused'
                            : 'Kitchen closed',
            );
            setDialogFor(null);
            setNote('');
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const openWithDialog = (status: BranchStatus) => {
        setDialogFor(status);
        setReason(status === 'BUSY' ? 'TOO_BUSY' : 'KITCHEN_ISSUE');
    };

    const statusTone =
        branch.accepting_orders && branch.status === 'OPEN'
            ? 'positive'
            : branch.status === 'BUSY'
                ? 'caution'
                : 'critical';

    const statusLabel =
        branch.status === 'OPEN' && branch.accepting_orders
            ? 'Accepting orders'
            : branch.status === 'BUSY'
                ? 'Busy'
                : branch.status === 'PAUSED'
                    ? 'Orders paused'
                    : 'Closed';

    return (
        <>
            <DropdownMenu>
                <DropdownMenuTrigger asChild>
                    <Button variant="secondary" size="sm" className="gap-2">
                        <Badge tone={statusTone} dot className="border-0 bg-transparent px-0 py-0">
                            {statusLabel}
                        </Badge>
                        <ChevronDown className="size-3.5 text-ink-muted" aria-hidden />
                    </Button>
                </DropdownMenuTrigger>

                <DropdownMenuContent className="w-64">
                    <DropdownMenuLabel>Kitchen status</DropdownMenuLabel>

                    <DropdownMenuItem
                        onSelect={() =>
                            mutation.mutate({ status: 'OPEN', reason: null, note: null, resumeAfterMinutes: null })
                        }
                        disabled={branch.status === 'OPEN' && branch.accepting_orders}
                    >
                        <Play />
                        Open &amp; accept orders
                    </DropdownMenuItem>

                    <DropdownMenuItem onSelect={() => openWithDialog('BUSY')}>
                        <Flame />
                        Mark busy (longer ETA)
                    </DropdownMenuItem>

                    <DropdownMenuItem onSelect={() => openWithDialog('PAUSED')}>
                        <PauseCircle />
                        Pause new orders
                    </DropdownMenuItem>

                    <DropdownMenuSeparator />

                    <DropdownMenuItem destructive onSelect={() => openWithDialog('CLOSED')}>
                        <Pause />
                        Close the kitchen
                    </DropdownMenuItem>

                    {!branch.within_hours && !branch.manual_override ? (
                        <>
                            <DropdownMenuSeparator />
                            <p className="px-2.5 py-2 text-[12px] leading-relaxed text-ink-muted">
                                Outside scheduled trading hours. Customers can still schedule orders for later.
                            </p>
                        </>
                    ) : null}
                </DropdownMenuContent>
            </DropdownMenu>

            <Dialog open={dialogFor !== null} onOpenChange={(open) => !open && setDialogFor(null)}>
                <DialogContent size="sm">
                    <DialogHeader>
                        <DialogTitle>
                            {dialogFor === 'BUSY'
                                ? 'Mark the kitchen busy'
                                : dialogFor === 'PAUSED'
                                    ? 'Pause new orders'
                                    : 'Close the kitchen'}
                        </DialogTitle>
                        <DialogDescription>
                            {dialogFor === 'BUSY'
                                ? 'Customers can still order. Preparation estimates get a buffer so promises stay realistic.'
                                : 'Customers will see this state immediately and cannot place new orders. Orders already in the kitchen are unaffected.'}
                        </DialogDescription>
                    </DialogHeader>

                    <DialogBody className="space-y-4">
                        <Field label="Reason" required>
                            <Select value={reason} onValueChange={(value) => setReason(value as BranchClosureReason)}>
                                <SelectTrigger>
                                    <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                    {CLOSURE_REASONS.map((option) => (
                                        <SelectItem key={option.value} value={option.value}>
                                            {option.label}
                                        </SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                        </Field>

                        {dialogFor !== 'BUSY' ? (
                            <Field label="Reopen automatically" hint="A scheduled job reopens the kitchen for you.">
                                <Select value={resumeAfter} onValueChange={setResumeAfter}>
                                    <SelectTrigger>
                                        <SelectValue />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {RESUME_OPTIONS.map((option) => (
                                            <SelectItem key={option.value} value={option.value}>
                                                {option.label}
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </Field>
                        ) : null}

                        <Field
                            label="Message for customers"
                            hint="Shown in the app. Keep it short and reassuring."
                        >
                            <Textarea
                                value={note}
                                onChange={(event) => setNote(event.target.value)}
                                placeholder="We are at full capacity right now. Please try again in a few minutes."
                                maxLength={160}
                            />
                        </Field>
                    </DialogBody>

                    <DialogFooter>
                        <Button variant="secondary" onClick={() => setDialogFor(null)}>
                            Cancel
                        </Button>
                        <Button
                            variant={dialogFor === 'CLOSED' ? 'destructive' : 'primary'}
                            loading={mutation.isPending}
                            onClick={() =>
                                dialogFor &&
                                mutation.mutate({
                                    status: dialogFor,
                                    reason,
                                    note: note.trim() || null,
                                    resumeAfterMinutes: resumeAfter === '0' ? null : Number(resumeAfter),
                                })
                            }
                        >
                            {dialogFor === 'BUSY' ? 'Mark busy' : dialogFor === 'PAUSED' ? 'Pause orders' : 'Close kitchen'}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    );
}
