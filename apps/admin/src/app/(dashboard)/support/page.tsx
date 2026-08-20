import type { Metadata } from 'next';
import Link from 'next/link';
import { AlarmClock, LifeBuoy, MessageSquare } from 'lucide-react';
import { requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card } from '@/components/ui/card';
import { StatCard } from '@/components/ui/stat-card';
import { Badge } from '@/components/ui/badge';
import { EmptyState, ErrorState } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/overlays';
import { PERMISSIONS, type TicketPriority, type TicketStatus } from '@bitesbox/shared-types';
import { dateTime, relativeTime, humanise } from '@/lib/utils';

export const metadata: Metadata = { title: 'Support' };
export const dynamic = 'force-dynamic';

const SELECT = `id, ticket_number, category, subject, status, priority, created_at,
  last_message_at, first_response_due_at, first_response_at, resolved_at,
  order_id, assigned_to, satisfaction_rating,
  profiles!support_tickets_user_profile_fkey(full_name, phone),
  orders(order_number)`;

function priorityTone(priority: TicketPriority) {
    switch (priority) {
        case 'URGENT':
            return 'critical' as const;
        case 'HIGH':
            return 'caution' as const;
        case 'NORMAL':
            return 'info' as const;
        default:
            return 'neutral' as const;
    }
}

function statusTone(status: TicketStatus) {
    switch (status) {
        case 'RESOLVED':
        case 'CLOSED':
            return 'positive' as const;
        case 'ESCALATED':
            return 'critical' as const;
        case 'WAITING_ON_CUSTOMER':
            return 'neutral' as const;
        default:
            return 'caution' as const;
    }
}

export default async function SupportPage() {
    await requirePermission(PERMISSIONS.SUPPORT_VIEW);
    const supabase = await createSupabaseServerClient();

    const [openResult, resolvedResult] = await Promise.all([
        supabase
            .from('support_tickets')
            .select(SELECT)
            .in('status', ['OPEN', 'IN_PROGRESS', 'ESCALATED', 'WAITING_ON_CUSTOMER'])
            .order('priority')
            .order('created_at', { ascending: true }),
        supabase
            .from('support_tickets')
            .select(SELECT)
            .in('status', ['RESOLVED', 'CLOSED'])
            .order('resolved_at', { ascending: false })
            .limit(100),
    ]);

    if (openResult.error) {
        return (
            <>
                <PageHeader title="Support" />
                <Card>
                    <ErrorState title="Could not load tickets" message={openResult.error.message} />
                </Card>
            </>
        );
    }

    const open = openResult.data ?? [];
    const resolved = resolvedResult.data ?? [];

    const breached = open.filter(
        (ticket) =>
            !ticket.first_response_at &&
            ticket.first_response_due_at &&
            new Date(ticket.first_response_due_at).getTime() < Date.now(),
    );
    const urgent = open.filter((ticket) => ticket.priority === 'URGENT');
    const unassigned = open.filter((ticket) => !ticket.assigned_to);

    return (
        <>
            <PageHeader
                title="Support"
                description="Customer issues, ordered by urgency. First response targets are set from the category."
            />

            <section aria-label="Support summary" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard label="Open tickets" value={open.length} icon={LifeBuoy} tone={open.length > 0 ? 'caution' : 'positive'} />
                <StatCard label="Urgent" value={urgent.length} icon={AlarmClock} tone={urgent.length > 0 ? 'critical' : 'neutral'} />
                <StatCard label="Past first-response target" value={breached.length} tone={breached.length > 0 ? 'critical' : 'positive'} />
                <StatCard label="Unassigned" value={unassigned.length} tone={unassigned.length > 0 ? 'caution' : 'neutral'} />
            </section>

            <Tabs defaultValue="open" className="mt-5">
                <TabsList>
                    <TabsTrigger value="open">
                        Open
                        {open.length > 0 ? (
                            <span className="tnum ml-1 rounded-full bg-caution-soft px-1.5 text-[11px] font-semibold text-caution">
                                {open.length}
                            </span>
                        ) : null}
                    </TabsTrigger>
                    <TabsTrigger value="resolved">Resolved</TabsTrigger>
                </TabsList>

                <TabsContent value="open">
                    <TicketTable tickets={open} showSla />
                </TabsContent>
                <TabsContent value="resolved">
                    <TicketTable tickets={resolved} showSla={false} />
                </TabsContent>
            </Tabs>
        </>
    );
}

type TicketRow = {
    id: string;
    ticket_number: string;
    category: string;
    subject: string;
    status: TicketStatus;
    priority: TicketPriority;
    created_at: string;
    last_message_at: string;
    first_response_due_at: string | null;
    first_response_at: string | null;
    resolved_at: string | null;
    order_id: string | null;
    assigned_to: string | null;
    satisfaction_rating: number | null;
    profiles: { full_name: string | null; phone: string | null } | null;
    orders: { order_number: string } | null;
};

function TicketTable({ tickets, showSla }: { tickets: TicketRow[]; showSla: boolean }) {
    return (
        <TableWrap>
            <Table>
                <THead>
                    <TR className="hover:bg-transparent">
                        <TH>Ticket</TH>
                        <TH>Customer</TH>
                        <TH>Issue</TH>
                        <TH>Order</TH>
                        <TH>Priority</TH>
                        <TH>Status</TH>
                        {showSla ? <TH>First response</TH> : <TH>Resolved</TH>}
                        <TH className="w-16" />
                    </TR>
                </THead>
                <TBody>
                    {tickets.length === 0 ? (
                        <TableMessageRow colSpan={8}>
                            <EmptyState
                                icon={MessageSquare}
                                title={showSla ? 'No open tickets' : 'No resolved tickets yet'}
                                description={showSla ? 'Every customer issue has been handled.' : undefined}
                            />
                        </TableMessageRow>
                    ) : (
                        tickets.map((ticket) => {
                            const overdue =
                                showSla &&
                                !ticket.first_response_at &&
                                ticket.first_response_due_at &&
                                new Date(ticket.first_response_due_at).getTime() < Date.now();

                            return (
                                <TR key={ticket.id}>
                                    <TD>
                                        <Link
                                            href={`/support/${ticket.id}`}
                                            className="font-mono text-[12.5px] font-semibold text-ink hover:text-brand-600"
                                        >
                                            {ticket.ticket_number}
                                        </Link>
                                        <span className="block text-[11.5px] text-ink-muted">
                                            {relativeTime(ticket.created_at)}
                                        </span>
                                    </TD>

                                    <TD>
                                        <span className="block max-w-36 truncate text-[13px] font-medium">
                                            {ticket.profiles?.full_name ?? 'Customer'}
                                        </span>
                                        <span className="block text-[11.5px] text-ink-muted">
                                            {ticket.profiles?.phone ?? '—'}
                                        </span>
                                    </TD>

                                    <TD>
                                        <span className="block text-[12.5px] font-medium text-ink">
                                            {humanise(ticket.category)}
                                        </span>
                                        <span className="block max-w-64 truncate text-[11.5px] text-ink-muted">
                                            {ticket.subject}
                                        </span>
                                    </TD>

                                    <TD>
                                        {ticket.order_id ? (
                                            <Link
                                                href={`/orders/${ticket.order_id}`}
                                                className="font-mono text-[11.5px] hover:text-brand-600"
                                            >
                                                {ticket.orders?.order_number ?? 'Order'}
                                            </Link>
                                        ) : (
                                            <span className="text-[12px] text-ink-muted">—</span>
                                        )}
                                    </TD>

                                    <TD>
                                        <Badge tone={priorityTone(ticket.priority)}>{humanise(ticket.priority)}</Badge>
                                    </TD>

                                    <TD>
                                        <Badge tone={statusTone(ticket.status)}>{humanise(ticket.status)}</Badge>
                                    </TD>

                                    <TD className="text-[12px] whitespace-nowrap">
                                        {showSla ? (
                                            ticket.first_response_at ? (
                                                <span className="text-positive">Answered</span>
                                            ) : overdue ? (
                                                <span className="font-semibold text-critical">Overdue</span>
                                            ) : (
                                                <span className="text-ink-muted">
                                                    due {dateTime(ticket.first_response_due_at)}
                                                </span>
                                            )
                                        ) : (
                                            <span className="text-ink-muted">{dateTime(ticket.resolved_at)}</span>
                                        )}
                                    </TD>

                                    <TD>
                                        <Link
                                            href={`/support/${ticket.id}`}
                                            className="text-[12.5px] font-medium text-brand-600 hover:underline"
                                        >
                                            Open
                                        </Link>
                                    </TD>
                                </TR>
                            );
                        })
                    )}
                </TBody>
            </Table>
        </TableWrap>
    );
}
