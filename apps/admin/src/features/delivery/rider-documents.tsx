'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation, useQuery } from '@tanstack/react-query';
import { toast } from 'sonner';
import {
    Check,
    ExternalLink,
    FileText,
    FileWarning,
    ShieldCheck,
    TriangleAlert,
    X,
} from 'lucide-react';
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
import { Field, Textarea } from '@/components/ui/form-controls';
import { Badge } from '@/components/ui/badge';
import { EmptyState, ErrorState, InlineNotice, LoadingBlock } from '@/components/ui/states';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import { dateOnly, humanise, relativeTime } from '@/lib/utils';

/**
 * Rider document review.
 *
 * The backend has had `review_rider_document` for a while, but nothing could reach
 * it: the dashboard's only rider action was "Approve rider", which the server
 * refuses until every required document is approved. So the button always failed
 * and there was no way to make it succeed. This is the missing half.
 *
 * The checklist comes from `rider_onboarding(id)` rather than being assembled from
 * the documents table, because "required" lives in a non-public setting and
 * deriving it here would drift from `app.required_rider_documents()` the first time
 * an outlet changes what it demands.
 */

type DocumentStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'EXPIRED';

interface RiderDocument {
    id: string;
    document_type: string;
    status: DocumentStatus;
    document_number: string | null;
    issued_on: string | null;
    expires_on: string | null;
    storage_path: string;
    rejection_reason: string | null;
    reviewed_at: string | null;
    reviewed_by_name: string | null;
    is_required: boolean;
    is_expired: boolean;
    created_at: string;
}

interface RiderOnboarding {
    delivery_partner_id: string;
    full_name: string;
    partner_code: string | null;
    onboarding_status: string;
    required_documents: string[];
    documents: RiderDocument[];
    outstanding: string[];
    awaiting_review_count: number;
    ready_to_activate: boolean;
}

function statusTone(status: DocumentStatus) {
    switch (status) {
        case 'APPROVED':
            return 'positive' as const;
        case 'PENDING':
            return 'caution' as const;
        default:
            return 'critical' as const;
    }
}

export function RiderDocumentsButton({
    riderId,
    riderName,
    approvedCount,
    totalCount,
    canReview,
}: {
    riderId: string;
    riderName: string;
    approvedCount: number;
    totalCount: number;
    canReview: boolean;
}) {
    const [open, setOpen] = React.useState(false);

    const label = totalCount === 0 ? 'No documents' : `${approvedCount}/${totalCount} approved`;

    return (
        <>
            <button
                type="button"
                onClick={() => setOpen(true)}
                className="rounded-sm text-left text-[12.5px] text-ink-muted underline decoration-dotted underline-offset-2 transition-colors hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-600"
                aria-label={`Review documents for ${riderName}`}
            >
                {label}
            </button>

            {open ? (
                <RiderDocumentsDialog
                    riderId={riderId}
                    riderName={riderName}
                    canReview={canReview}
                    open={open}
                    onOpenChange={setOpen}
                />
            ) : null}
        </>
    );
}

function RiderDocumentsDialog({
    riderId,
    riderName,
    canReview,
    open,
    onOpenChange,
}: {
    riderId: string;
    riderName: string;
    canReview: boolean;
    open: boolean;
    onOpenChange: (next: boolean) => void;
}) {
    const router = useRouter();
    const [rejecting, setRejecting] = React.useState<string | null>(null);
    const [reason, setReason] = React.useState('');

    const onboarding = useQuery<RiderOnboarding>({
        queryKey: ['rider-onboarding', riderId],
        queryFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('rider_onboarding', {
                p_delivery_partner_id: riderId,
            });
            if (error) throw error;
            return data as unknown as RiderOnboarding;
        },
    });

    const review = useMutation({
        mutationFn: async (input: { documentId: string; approve: boolean; reason?: string }) => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('review_rider_document', {
                p_document_id: input.documentId,
                p_approve: input.approve,
                ...(input.reason ? { p_rejection_reason: input.reason } : {}),
            });
            if (error) throw error;
            return data as unknown as { onboarding_status: string; ready_to_activate: boolean };
        },
        onSuccess: (result, input) => {
            toast.success(
                input.approve ? 'Document approved' : 'Document rejected',
                result.ready_to_activate
                    ? { description: `${riderName} can now be activated.` }
                    : undefined,
            );
            setRejecting(null);
            setReason('');
            void onboarding.refetch();
            // The rider row on the page behind shows onboarding status and counts.
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const data = onboarding.data;

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent size="lg">
                <DialogHeader>
                    <DialogTitle>Documents · {riderName}</DialogTitle>
                    <DialogDescription>
                        {canReview
                            ? 'Approve each required document before activating the rider. A rejection needs a reason, which is sent to them.'
                            : 'You can view these documents but not review them. Reviewing needs the rider approval permission.'}
                    </DialogDescription>
                </DialogHeader>

                <DialogBody>
                    {onboarding.isPending ? (
                        <LoadingBlock label="Loading documents" />
                    ) : onboarding.isError ? (
                        <ErrorState
                            title="Could not load documents"
                            message={errorMessage(onboarding.error)}
                        />
                    ) : !data ? null : (
                        <div className="space-y-4">
                            {data.ready_to_activate && data.onboarding_status !== 'ACTIVE' ? (
                                <InlineNotice tone="positive">
                                    Every required document is approved. {riderName} can be activated
                                    from the Approve action.
                                </InlineNotice>
                            ) : data.outstanding.length > 0 ? (
                                <InlineNotice tone="caution">
                                    Still needed from {riderName.split(' ')[0]}:{' '}
                                    {data.outstanding.map((type) => humanise(type)).join(', ')}.
                                </InlineNotice>
                            ) : null}

                            {data.documents.length === 0 ? (
                                <EmptyState
                                    icon={FileWarning}
                                    title="Nothing submitted yet"
                                    description="The rider uploads these from the Bites Box app. Until they do, there is nothing to review."
                                />
                            ) : (
                                <ul className="space-y-2.5">
                                    {data.documents.map((doc) => (
                                        <li
                                            key={doc.id}
                                            className="rounded-lg border border-hairline bg-surface p-3"
                                        >
                                            <div className="flex flex-wrap items-start justify-between gap-3">
                                                <div className="min-w-0">
                                                    <div className="flex flex-wrap items-center gap-2">
                                                        <span className="text-[13.5px] font-medium text-ink">
                                                            {humanise(doc.document_type)}
                                                        </span>
                                                        {doc.is_required ? null : (
                                                            <Badge tone="neutral">Optional</Badge>
                                                        )}
                                                        <Badge tone={statusTone(doc.status)}>
                                                            {humanise(doc.status)}
                                                        </Badge>
                                                        {doc.is_expired ? (
                                                            <Badge tone="critical">Expired</Badge>
                                                        ) : null}
                                                    </div>

                                                    <p className="mt-1 text-[11.5px] text-ink-muted">
                                                        {doc.document_number ?? 'No number given'}
                                                        {doc.issued_on
                                                            ? ` · issued ${dateOnly(doc.issued_on)}`
                                                            : ''}
                                                        {doc.expires_on
                                                            ? ` · expires ${dateOnly(doc.expires_on)}`
                                                            : ''}
                                                    </p>

                                                    {doc.reviewed_at ? (
                                                        <p className="mt-0.5 text-[11.5px] text-ink-muted">
                                                            Reviewed {relativeTime(doc.reviewed_at)}
                                                            {doc.reviewed_by_name
                                                                ? ` by ${doc.reviewed_by_name}`
                                                                : ''}
                                                        </p>
                                                    ) : null}

                                                    {doc.rejection_reason ? (
                                                        <p className="mt-1 text-[11.5px] text-critical">
                                                            {doc.rejection_reason}
                                                        </p>
                                                    ) : null}
                                                </div>

                                                <div className="flex shrink-0 items-center gap-1.5">
                                                    <DocumentLink
                                                        storagePath={doc.storage_path}
                                                        label={humanise(doc.document_type)}
                                                    />

                                                    {canReview && doc.status !== 'APPROVED' ? (
                                                        <Button
                                                            size="sm"
                                                            loading={
                                                                review.isPending &&
                                                                review.variables?.documentId === doc.id &&
                                                                review.variables?.approve === true
                                                            }
                                                            onClick={() =>
                                                                review.mutate({
                                                                    documentId: doc.id,
                                                                    approve: true,
                                                                })
                                                            }
                                                        >
                                                            <Check />
                                                            Approve
                                                        </Button>
                                                    ) : null}

                                                    {canReview && doc.status !== 'REJECTED' ? (
                                                        <Button
                                                            size="sm"
                                                            variant="secondary"
                                                            onClick={() => {
                                                                setRejecting(doc.id);
                                                                setReason('');
                                                            }}
                                                        >
                                                            <X />
                                                            Reject
                                                        </Button>
                                                    ) : null}
                                                </div>
                                            </div>

                                            {rejecting === doc.id ? (
                                                <div className="mt-3 border-t border-hairline pt-3">
                                                    <Field
                                                        label="Why is this not acceptable?"
                                                        required
                                                        hint="Sent to the rider so they know what to re-upload."
                                                    >
                                                        <Textarea
                                                            value={reason}
                                                            onChange={(event) =>
                                                                setReason(event.target.value)
                                                            }
                                                            placeholder="The photo is too blurred to read the licence number."
                                                            autoFocus
                                                        />
                                                    </Field>
                                                    <div className="mt-2 flex justify-end gap-2">
                                                        <Button
                                                            variant="ghost"
                                                            size="sm"
                                                            onClick={() => setRejecting(null)}
                                                        >
                                                            Cancel
                                                        </Button>
                                                        <Button
                                                            size="sm"
                                                            variant="destructive"
                                                            disabled={!reason.trim()}
                                                            loading={review.isPending}
                                                            onClick={() =>
                                                                review.mutate({
                                                                    documentId: doc.id,
                                                                    approve: false,
                                                                    reason: reason.trim(),
                                                                })
                                                            }
                                                        >
                                                            Reject document
                                                        </Button>
                                                    </div>
                                                </div>
                                            ) : null}
                                        </li>
                                    ))}
                                </ul>
                            )}

                            <p className="flex items-start gap-1.5 text-[11.5px] text-ink-muted">
                                <ShieldCheck className="mt-px size-3.5 shrink-0" aria-hidden />
                                These are identity documents in a private bucket. Every view is a
                                signed link that expires in two minutes, and every decision is
                                written to the audit log against your name.
                            </p>
                        </div>
                    )}
                </DialogBody>

                <DialogFooter>
                    <Button variant="secondary" onClick={() => onOpenChange(false)}>
                        Close
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}

/**
 * Signs a URL on click rather than up front.
 *
 * Pre-signing every row would put a live link to somebody's Aadhaar in the page
 * source whether or not the reviewer ever looks at it. Two minutes is enough to
 * open a tab and not much use if the URL leaks.
 */
function DocumentLink({ storagePath, label }: { storagePath: string; label: string }) {
    const sign = useMutation({
        mutationFn: async () => {
            const supabase = createSupabaseBrowserClient();

            // Older rows carried the bucket name in the path. Tolerate both shapes so
            // a historical document is still viewable.
            const objectPath = storagePath.replace(/^rider-documents\//, '');

            const { data, error } = await supabase.storage
                .from('rider-documents')
                .createSignedUrl(objectPath, 120);

            if (error) throw error;
            return data.signedUrl;
        },
        onSuccess: (url) => window.open(url, '_blank', 'noopener,noreferrer'),
        onError: (error) =>
            toast.error('Could not open the document', { description: errorMessage(error) }),
    });

    return (
        <Button
            variant="ghost"
            size="sm"
            loading={sign.isPending}
            onClick={() => sign.mutate()}
            aria-label={`Open ${label}`}
        >
            {sign.isError ? <TriangleAlert /> : <FileText />}
            View
            <ExternalLink className="size-3 opacity-60" aria-hidden />
        </Button>
    );
}
