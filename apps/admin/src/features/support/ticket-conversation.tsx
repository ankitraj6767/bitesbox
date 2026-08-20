'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { CheckCircle2, Lock, Send } from 'lucide-react';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Field, Textarea, Switch, Label } from '@/components/ui/form-controls';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import { cn, dateTime } from '@/lib/utils';
import type { TicketStatus } from '@bitesbox/shared-types';

export interface TicketMessage {
    id: string;
    author_kind: 'CUSTOMER' | 'AGENT' | 'SYSTEM';
    body: string;
    is_internal: boolean;
    created_at: string;
    author: { full_name: string | null } | null;
}

/**
 * Support conversation. Internal notes are visually distinct and RLS keeps them
 * out of the customer's view entirely — the app never fetches them for a
 * customer session.
 */
export function TicketConversation({
    ticketId,
    status,
    messages,
    canRespond,
    canClose,
}: {
    ticketId: string;
    status: TicketStatus;
    messages: TicketMessage[];
    canRespond: boolean;
    canClose: boolean;
}) {
    const router = useRouter();
    const [body, setBody] = React.useState('');
    const [internal, setInternal] = React.useState(false);

    const send = useMutation({
        mutationFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase.rpc('post_support_message', {
                p_ticket_id: ticketId,
                p_body: body.trim(),
                p_is_internal: internal,
            });
            if (error) throw error;
        },
        onSuccess: () => {
            toast.success(internal ? 'Internal note added' : 'Reply sent to the customer');
            setBody('');
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const resolve = useMutation({
        mutationFn: async (next: TicketStatus) => {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase
                .from('support_tickets')
                .update({
                    status: next,
                    ...(next === 'RESOLVED' || next === 'CLOSED'
                        ? { resolved_at: new Date().toISOString() }
                        : {}),
                    ...(next === 'CLOSED' ? { closed_at: new Date().toISOString() } : {}),
                })
                .eq('id', ticketId);
            if (error) throw error;
            return next;
        },
        onSuccess: (next) => {
            toast.success(next === 'RESOLVED' ? 'Ticket marked resolved' : 'Ticket closed');
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const isClosed = status === 'RESOLVED' || status === 'CLOSED';

    return (
        <Card>
            <CardToolbar
                title="Conversation"
                description={`${messages.filter((m) => !m.is_internal).length} message(s) with the customer`}
                action={
                    canClose && !isClosed ? (
                        <Button
                            variant="secondary"
                            size="sm"
                            loading={resolve.isPending}
                            onClick={() => resolve.mutate('RESOLVED')}
                        >
                            <CheckCircle2 />
                            Mark resolved
                        </Button>
                    ) : null
                }
            />

            <CardContent className="space-y-3">
                <ol className="space-y-3">
                    {messages.map((message) => {
                        const fromCustomer = message.author_kind === 'CUSTOMER';

                        return (
                            <li
                                key={message.id}
                                className={cn('flex', fromCustomer ? 'justify-start' : 'justify-end')}
                            >
                                <div
                                    className={cn(
                                        'max-w-[85%] rounded-[var(--radius-card)] px-3.5 py-2.5',
                                        message.is_internal
                                            ? 'border border-dashed border-caution/40 bg-caution-soft'
                                            : fromCustomer
                                                ? 'bg-surface-muted'
                                                : 'bg-brand-600 text-white',
                                    )}
                                >
                                    <div className="mb-1 flex items-center gap-2">
                                        <span
                                            className={cn(
                                                'text-[11.5px] font-semibold',
                                                message.is_internal
                                                    ? 'text-caution'
                                                    : fromCustomer
                                                        ? 'text-ink-muted'
                                                        : 'text-white/80',
                                            )}
                                        >
                                            {message.is_internal
                                                ? 'Internal note'
                                                : fromCustomer
                                                    ? 'Customer'
                                                    : (message.author?.full_name ?? 'Support')}
                                        </span>
                                        {message.is_internal ? (
                                            <Badge tone="caution" className="px-1.5 py-0">
                                                <Lock className="size-2.5" aria-hidden />
                                                Staff only
                                            </Badge>
                                        ) : null}
                                    </div>

                                    <p
                                        className={cn(
                                            'text-[13.5px] leading-relaxed whitespace-pre-wrap',
                                            message.is_internal ? 'text-ink' : fromCustomer ? 'text-ink' : 'text-white',
                                        )}
                                    >
                                        {message.body}
                                    </p>

                                    <p
                                        className={cn(
                                            'mt-1 text-[11px]',
                                            message.is_internal
                                                ? 'text-caution/80'
                                                : fromCustomer
                                                    ? 'text-ink-muted'
                                                    : 'text-white/70',
                                        )}
                                    >
                                        {dateTime(message.created_at)}
                                    </p>
                                </div>
                            </li>
                        );
                    })}
                </ol>

                {canRespond ? (
                    <div className="border-t border-hairline pt-3">
                        <Field
                            label={internal ? 'Internal note' : 'Reply to the customer'}
                            hint={
                                internal
                                    ? 'Only staff can read this. The customer is not notified.'
                                    : 'The customer receives a push notification with your reply.'
                            }
                        >
                            <Textarea
                                value={body}
                                onChange={(event) => setBody(event.target.value)}
                                placeholder={
                                    internal
                                        ? 'Checked the delivery photo — the dessert box is missing.'
                                        : 'Sorry about that. We have credited the full value of the missing item to your wallet.'
                                }
                                rows={3}
                            />
                        </Field>

                        <div className="mt-2.5 flex flex-wrap items-center justify-between gap-3">
                            <div className="flex items-center gap-2">
                                <Switch
                                    id="internal-toggle"
                                    checked={internal}
                                    onCheckedChange={setInternal}
                                    aria-label="Internal note only"
                                />
                                <Label htmlFor="internal-toggle" className="text-ink-muted">
                                    Internal note only
                                </Label>
                            </div>

                            <Button
                                loading={send.isPending}
                                disabled={!body.trim()}
                                onClick={() => send.mutate()}
                            >
                                <Send />
                                {internal ? 'Add note' : 'Send reply'}
                            </Button>
                        </div>
                    </div>
                ) : null}
            </CardContent>
        </Card>
    );
}
