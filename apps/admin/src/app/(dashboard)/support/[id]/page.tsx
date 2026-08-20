import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ReceiptText, UserRound } from 'lucide-react';
import { hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { InlineNotice } from '@/components/ui/states';
import { TicketConversation, type TicketMessage } from '@/features/support/ticket-conversation';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { dateTime, money, humanise } from '@/lib/utils';

export const dynamic = 'force-dynamic';

export async function generateMetadata({
    params,
}: {
    params: Promise<{ id: string }>;
}): Promise<Metadata> {
    const { id } = await params;
    const supabase = await createSupabaseServerClient();
    const { data } = await supabase
        .from('support_tickets')
        .select('ticket_number')
        .eq('id', id)
        .maybeSingle();
    return { title: data?.ticket_number ?? 'Ticket' };
}

export default async function TicketPage({ params }: { params: Promise<{ id: string }> }) {
    const [session, { id }] = await Promise.all([
        requirePermission(PERMISSIONS.SUPPORT_VIEW),
        params,
    ]);

    const supabase = await createSupabaseServerClient();

    const [ticketResult, messagesResult] = await Promise.all([
        supabase
            .from('support_tickets')
            .select(
                `id, ticket_number, category, subject, description, status, priority,
         created_at, first_response_due_at, first_response_at, resolved_at, resolution_note,
         satisfaction_rating, wallet_credit_amount, order_id, refund_id,
         profiles!support_tickets_user_profile_fkey(id, full_name, phone, email, completed_orders, lifetime_value),
         orders(id, order_number, status, grand_total, refunded_amount),
         refunds(id, amount, status, destination)`,
            )
            .eq('id', id)
            .maybeSingle(),
        supabase
            .from('support_messages')
            .select('id, author_kind, body, is_internal, created_at, author:profiles!support_messages_author_profile_fkey(full_name)')
            .eq('ticket_id', id)
            .order('created_at'),
    ]);

    if (ticketResult.error || !ticketResult.data) notFound();

    const ticket = ticketResult.data;
    const messages = (messagesResult.data ?? []) as unknown as TicketMessage[];
    const customer = ticket.profiles;

    const overdue =
        !ticket.first_response_at &&
        ticket.first_response_due_at &&
        new Date(ticket.first_response_due_at).getTime() < Date.now();

    return (
        <>
            <PageHeader
                breadcrumbs={[{ label: 'Support', href: '/support' }, { label: ticket.ticket_number }]}
                title={
                    <span className="flex flex-wrap items-center gap-2.5">
                        {humanise(ticket.category)}
                        <Badge tone={ticket.priority === 'URGENT' ? 'critical' : 'caution'}>
                            {humanise(ticket.priority)}
                        </Badge>
                        <Badge tone={['RESOLVED', 'CLOSED'].includes(ticket.status) ? 'positive' : 'info'}>
                            {humanise(ticket.status)}
                        </Badge>
                    </span>
                }
                description={`${ticket.ticket_number} · opened ${dateTime(ticket.created_at)}`}
            />

            {overdue ? (
                <InlineNotice tone="critical" className="mb-4">
                    This ticket has passed its first-response target of{' '}
                    {dateTime(ticket.first_response_due_at)}. Reply as soon as possible.
                </InlineNotice>
            ) : null}

            <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_320px]">
                <div className="space-y-4">
                    <Card>
                        <CardToolbar title={ticket.subject} />
                        <CardContent>
                            <p className="text-[13.5px] leading-relaxed whitespace-pre-wrap text-ink">
                                {ticket.description}
                            </p>
                        </CardContent>
                    </Card>

                    <TicketConversation
                        ticketId={ticket.id}
                        status={ticket.status}
                        messages={messages}
                        canRespond={hasPermission(session, PERMISSIONS.SUPPORT_RESPOND)}
                        canClose={hasPermission(session, PERMISSIONS.SUPPORT_CLOSE)}
                    />

                    {ticket.resolution_note ? (
                        <Card>
                            <CardToolbar title="Resolution" description={dateTime(ticket.resolved_at)} />
                            <CardContent>
                                <p className="text-[13.5px] leading-relaxed text-ink">{ticket.resolution_note}</p>
                                {ticket.satisfaction_rating ? (
                                    <p className="mt-2 text-[12.5px] text-ink-muted">
                                        Customer rated this resolution {ticket.satisfaction_rating}/5.
                                    </p>
                                ) : null}
                            </CardContent>
                        </Card>
                    ) : null}
                </div>

                <div className="space-y-4">
                    <Card>
                        <CardToolbar title="Customer" />
                        <CardContent className="space-y-2 text-[12.5px]">
                            <div className="flex items-start gap-2.5">
                                <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink-muted">
                                    <UserRound className="size-4" aria-hidden />
                                </span>
                                <div className="min-w-0">
                                    {customer ? (
                                        <Link
                                            href={`/customers/${customer.id}`}
                                            className="block truncate text-[13.5px] font-medium text-ink hover:text-brand-600"
                                        >
                                            {customer.full_name ?? 'Customer'}
                                        </Link>
                                    ) : null}
                                    <a
                                        href={`tel:${customer?.phone ?? ''}`}
                                        className="text-ink-muted hover:text-ink"
                                    >
                                        {customer?.phone ?? '—'}
                                    </a>
                                </div>
                            </div>

                            <div className="flex items-center justify-between border-t border-hairline pt-2">
                                <span className="text-ink-muted">Orders</span>
                                <span className="font-medium text-ink">{customer?.completed_orders ?? 0}</span>
                            </div>
                            <div className="flex items-center justify-between">
                                <span className="text-ink-muted">Lifetime value</span>
                                <span className="tnum font-medium text-ink">
                                    {money(Number(customer?.lifetime_value ?? 0))}
                                </span>
                            </div>
                        </CardContent>
                    </Card>

                    {ticket.orders ? (
                        <Card>
                            <CardToolbar title="Related order" />
                            <CardContent className="space-y-2 text-[12.5px]">
                                <Link
                                    href={`/orders/${ticket.orders.id}`}
                                    className="block font-mono text-[13px] font-semibold text-ink hover:text-brand-600"
                                >
                                    {ticket.orders.order_number}
                                </Link>
                                <div className="flex items-center justify-between">
                                    <span className="text-ink-muted">Status</span>
                                    <span className="font-medium text-ink">{humanise(ticket.orders.status)}</span>
                                </div>
                                <div className="flex items-center justify-between">
                                    <span className="text-ink-muted">Total</span>
                                    <span className="tnum font-medium text-ink">
                                        {money(ticket.orders.grand_total, true)}
                                    </span>
                                </div>
                                {Number(ticket.orders.refunded_amount) > 0 ? (
                                    <div className="flex items-center justify-between">
                                        <span className="text-ink-muted">Refunded</span>
                                        <span className="tnum font-medium text-critical">
                                            {money(ticket.orders.refunded_amount, true)}
                                        </span>
                                    </div>
                                ) : null}
                            </CardContent>
                        </Card>
                    ) : null}

                    {ticket.refunds ? (
                        <Card>
                            <CardToolbar title="Refund raised" />
                            <CardContent className="space-y-1.5 text-[12.5px]">
                                <div className="flex items-center justify-between">
                                    <span className="flex items-center gap-1.5 text-ink-muted">
                                        <ReceiptText className="size-3.5" aria-hidden />
                                        Amount
                                    </span>
                                    <span className="tnum font-semibold text-ink">
                                        {money(ticket.refunds.amount, true)}
                                    </span>
                                </div>
                                <div className="flex items-center justify-between">
                                    <span className="text-ink-muted">Status</span>
                                    <Badge tone={ticket.refunds.status === 'COMPLETED' ? 'positive' : 'caution'}>
                                        {humanise(ticket.refunds.status)}
                                    </Badge>
                                </div>
                                <div className="flex items-center justify-between">
                                    <span className="text-ink-muted">To</span>
                                    <span className="font-medium text-ink">
                                        {humanise(ticket.refunds.destination)}
                                    </span>
                                </div>
                            </CardContent>
                        </Card>
                    ) : null}
                </div>
            </div>
        </>
    );
}
