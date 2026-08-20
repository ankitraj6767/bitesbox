'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Eye, EyeOff, Flag, MessageSquareReply } from 'lucide-react';
import { Button } from '@/components/ui/button';
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
    DropdownMenuTrigger,
} from '@/components/ui/overlays';
import { Field, Textarea } from '@/components/ui/form-controls';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';

interface ModerationInput {
    status?: 'PUBLISHED' | 'HIDDEN' | 'FLAGGED' | 'PENDING_MODERATION';
    response?: string;
    internalNote?: string;
    flaggedReason?: string;
}

/**
 * Moderates a review through `moderate_review`.
 *
 * This used to update the `reviews` table directly. That worked, but it recorded
 * neither who hid a review nor why — and hiding a customer's complaint is exactly
 * the kind of action an operator may later be asked to justify. The RPC writes the
 * moderator, the timestamp and an audit entry, and the table's UPDATE grant has
 * been withdrawn so this is now the only way in.
 */
export function ReviewModeration({
    reviewId,
    status,
    hasResponse,
}: {
    reviewId: string;
    status: string;
    hasResponse: boolean;
}) {
    const router = useRouter();
    const [replyOpen, setReplyOpen] = React.useState(false);
    const [reply, setReply] = React.useState('');

    const moderate = useMutation({
        mutationFn: async (input: ModerationInput) => {
            const supabase = createSupabaseBrowserClient();

            // Omitted rather than nulled: the RPC's defaults mean "leave unchanged",
            // and the generated argument types are non-nullable.
            const { error } = await supabase.rpc('moderate_review', {
                p_review_id: reviewId,
                ...(input.status ? { p_status: input.status } : {}),
                ...(input.response ? { p_response: input.response } : {}),
                ...(input.internalNote ? { p_internal_note: input.internalNote } : {}),
                ...(input.flaggedReason ? { p_flagged_reason: input.flaggedReason } : {}),
            });

            if (error) throw error;
        },
        onSuccess: () => {
            toast.success('Review updated');
            setReplyOpen(false);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    return (
        <>
            <DropdownMenu>
                <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="sm" aria-label="Moderate review">
                        Moderate
                    </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent>
                    <DropdownMenuItem onSelect={() => setReplyOpen(true)}>
                        <MessageSquareReply />
                        {hasResponse ? 'Edit public reply' : 'Reply publicly'}
                    </DropdownMenuItem>

                    {status !== 'HIDDEN' ? (
                        <DropdownMenuItem onSelect={() => moderate.mutate({ status: 'HIDDEN' })}>
                            <EyeOff />
                            Hide from customers
                        </DropdownMenuItem>
                    ) : (
                        <DropdownMenuItem onSelect={() => moderate.mutate({ status: 'PUBLISHED' })}>
                            <Eye />
                            Publish again
                        </DropdownMenuItem>
                    )}

                    {status !== 'FLAGGED' ? (
                        <DropdownMenuItem
                            onSelect={() =>
                                moderate.mutate({
                                    status: 'FLAGGED',
                                    flaggedReason: 'Flagged for internal review',
                                })
                            }
                        >
                            <Flag />
                            Flag for review
                        </DropdownMenuItem>
                    ) : null}
                </DropdownMenuContent>
            </DropdownMenu>

            <Dialog open={replyOpen} onOpenChange={setReplyOpen}>
                <DialogContent size="sm">
                    <DialogHeader>
                        <DialogTitle>Reply to this review</DialogTitle>
                        <DialogDescription>
                            Your reply appears publicly beneath the review in the customer app, with
                            your name recorded against it internally.
                        </DialogDescription>
                    </DialogHeader>
                    <DialogBody>
                        <Field label="Reply">
                            <Textarea
                                value={reply}
                                onChange={(event) => setReply(event.target.value)}
                                placeholder="Thank you for the feedback — we have spoken to the kitchen about the spice level."
                                autoFocus
                            />
                        </Field>
                    </DialogBody>
                    <DialogFooter>
                        <Button variant="secondary" onClick={() => setReplyOpen(false)}>
                            Cancel
                        </Button>
                        <Button
                            loading={moderate.isPending}
                            disabled={!reply.trim()}
                            onClick={() =>
                                moderate.mutate({
                                    response: reply.trim(),
                                    // Replying to a hidden review implies making it visible again.
                                    status: status === 'HIDDEN' ? 'PUBLISHED' : undefined,
                                })
                            }
                        >
                            Publish reply
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    );
}
