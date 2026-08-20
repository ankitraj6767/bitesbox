'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation, useQuery } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Ban, Send, Users } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/ui/overlays';
import { InlineNotice } from '@/components/ui/states';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';

interface AudienceSize {
    audience: number;
    reachable: number;
    opted_out: number;
}

interface SendResult {
    targeted: number;
    queued: number;
    changed: boolean;
    delivery?: { sent: number; failed: number; skipped: number };
}

/**
 * Sends a campaign.
 *
 * The audience is resolved server-side by `launch_campaign`: the browser never
 * receives a customer list, and marketing opt-outs are applied in the database
 * rather than trusted from here. The dry run below asks the same function how many
 * people it would reach, so an operator sees the number *before* committing to an
 * action that cannot be undone.
 */
export function CampaignLauncher({
    campaignId,
    campaignName,
    status,
    segment,
    canSend,
}: {
    campaignId: string;
    campaignName: string;
    status: string;
    segment: string;
    canSend: boolean;
}) {
    const router = useRouter();
    const [confirmOpen, setConfirmOpen] = React.useState(false);
    const [cancelOpen, setCancelOpen] = React.useState(false);
    const [result, setResult] = React.useState<SendResult | null>(null);

    const alreadySent = status === 'COMPLETED' || status === 'RUNNING';
    const cancellable = status === 'SCHEDULED' || status === 'DRAFT' || status === 'PAUSED';

    // Only asked for while the send is actually on the table, so opening the list of
    // campaigns does not fan out a count query per row.
    const audience = useQuery<AudienceSize>({
        queryKey: ['campaign-audience', campaignId],
        enabled: confirmOpen && canSend,
        staleTime: 30_000,
        queryFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('campaign_audience_size', {
                p_campaign_id: campaignId,
            });

            if (error) throw error;
            // The RPC returns jsonb, which the generated types widen to Json.
            return data as unknown as AudienceSize;
        },
    });

    const send = useMutation({
        mutationFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.functions.invoke('send-notification', {
                body: { campaign_id: campaignId },
            });

            if (error) {
                const context = (error as { context?: { body?: unknown } }).context;
                throw context?.body ?? error;
            }

            return data as SendResult;
        },
        onSuccess: (data) => {
            setResult(data);

            if (data.changed) {
                toast.success(
                    `Queued ${data.queued} notification(s) for ${data.targeted} customers`,
                );
            } else {
                toast.info('This campaign had already been sent.');
            }

            setConfirmOpen(false);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const cancel = useMutation({
        mutationFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase.rpc('cancel_campaign', {
                p_campaign_id: campaignId,
                p_reason: 'Cancelled from the dashboard',
            });

            if (error) throw error;
        },
        onSuccess: () => {
            toast.success('Campaign cancelled. Anything unsent has been withdrawn.');
            setCancelOpen(false);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    return (
        <>
            <div className="flex items-center gap-2">
                {canSend && !alreadySent ? (
                    <Button size="sm" onClick={() => setConfirmOpen(true)}>
                        <Send />
                        Send now
                    </Button>
                ) : null}

                {canSend && cancellable ? (
                    <Button variant="ghost" size="sm" onClick={() => setCancelOpen(true)}>
                        <Ban />
                        Cancel
                    </Button>
                ) : null}
            </div>

            {result ? (
                <InlineNotice tone={result.changed ? 'positive' : 'info'} className="mt-2">
                    Queued {result.queued} notification(s) across {result.targeted} customers.
                    {result.delivery
                        ? ` ${result.delivery.sent} sent immediately; the rest continues in the background.`
                        : ' Delivery continues in the background.'}
                </InlineNotice>
            ) : null}

            <ConfirmDialog
                open={confirmOpen}
                onOpenChange={setConfirmOpen}
                title={`Send “${campaignName}” now?`}
                description={
                    <span className="flex flex-col gap-2">
                        <span className="flex items-start gap-2">
                            <Users className="mt-0.5 size-4 shrink-0" aria-hidden />
                            <span>
                                This sends to the{' '}
                                <strong>{segment.replace(/_/g, ' ').toLowerCase()}</strong> segment.
                                Sending cannot be undone.
                            </span>
                        </span>

                        {audience.isLoading ? (
                            <span className="text-muted-foreground text-sm">
                                Counting the audience…
                            </span>
                        ) : null}

                        {audience.data ? (
                            <span className="text-sm">
                                <strong>{audience.data.reachable}</strong> of{' '}
                                {audience.data.audience} customers will receive it.
                                {audience.data.opted_out > 0
                                    ? ` ${audience.data.opted_out} have opted out of marketing and are skipped automatically.`
                                    : ''}
                            </span>
                        ) : null}

                        {audience.isError ? (
                            <span className="text-destructive text-sm">
                                Could not count the audience: {errorMessage(audience.error)}
                            </span>
                        ) : null}
                    </span>
                }
                confirmLabel="Send campaign"
                confirmText="SEND"
                destructive
                loading={send.isPending}
                onConfirm={() => send.mutate()}
            />

            <ConfirmDialog
                open={cancelOpen}
                onOpenChange={setCancelOpen}
                title={`Cancel “${campaignName}”?`}
                description="Anything still queued and unsent is withdrawn. Notifications that have already gone out cannot be recalled."
                confirmLabel="Cancel campaign"
                destructive
                loading={cancel.isPending}
                onConfirm={() => cancel.mutate()}
            />
        </>
    );
}
