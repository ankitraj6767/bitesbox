import type { Metadata } from 'next';
import Link from 'next/link';
import { UsersRound } from 'lucide-react';
import { requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { StatCard } from '@/components/ui/stat-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { EmptyState, ErrorState } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { CustomerFilterBar } from '@/features/customers/customer-filter-bar';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { dateOnly, money, relativeTime, initials } from '@/lib/utils';

export const metadata: Metadata = { title: 'Customers' };
export const dynamic = 'force-dynamic';

const PAGE_SIZE = 25;

export default async function CustomersPage({
    searchParams,
}: {
    searchParams: Promise<{ q?: string; segment?: string; sort?: string; page?: string }>;
}) {
    const [, params] = await Promise.all([
        requirePermission(PERMISSIONS.CUSTOMER_VIEW),
        searchParams,
    ]);

    const search = params.q ?? '';
    const segment = params.segment ?? 'all';
    const sort = params.sort ?? 'recent';
    const page = Math.max(1, Number(params.page ?? '1') || 1);

    const supabase = await createSupabaseServerClient();

    let query = supabase
        .from('profiles')
        .select(
            `id, full_name, phone, email, status, created_at, last_order_at, first_order_at,
       total_orders, completed_orders, cancelled_orders, lifetime_value, average_order_value,
       marketing_opt_in`,
            { count: 'exact' },
        )
        .is('deleted_at', null)
        .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

    if (search) {
        const escaped = search.replace(/[%,]/g, '');
        query = query.or(`full_name.ilike.%${escaped}%,phone.ilike.%${escaped}%,email.ilike.%${escaped}%`);
    }

    const thirtyDaysAgo = new Date(Date.now() - 30 * 86_400_000).toISOString();

    switch (segment) {
        case 'new':
            query = query.eq('completed_orders', 0);
            break;
        case 'repeat':
            query = query.gt('completed_orders', 1);
            break;
        case 'high_value':
            query = query.gte('lifetime_value', 5000);
            break;
        case 'inactive':
            query = query.gt('completed_orders', 0).lt('last_order_at', thirtyDaysAgo);
            break;
        case 'blocked':
            query = query.eq('status', 'BLOCKED');
            break;
    }

    switch (sort) {
        case 'value':
            query = query.order('lifetime_value', { ascending: false });
            break;
        case 'orders':
            query = query.order('completed_orders', { ascending: false });
            break;
        case 'newest':
            query = query.order('created_at', { ascending: false });
            break;
        default:
            query = query.order('last_order_at', { ascending: false, nullsFirst: false });
    }

    const { data: customers, count, error } = await query;
    const total = count ?? 0;
    const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));

    const [{ count: repeatCount }, { count: highValueCount }, { count: inactiveCount }] =
        await Promise.all([
            supabase
                .from('profiles')
                .select('id', { count: 'exact', head: true })
                .is('deleted_at', null)
                .gt('completed_orders', 1),
            supabase
                .from('profiles')
                .select('id', { count: 'exact', head: true })
                .is('deleted_at', null)
                .gte('lifetime_value', 5000),
            supabase
                .from('profiles')
                .select('id', { count: 'exact', head: true })
                .is('deleted_at', null)
                .gt('completed_orders', 0)
                .lt('last_order_at', thirtyDaysAgo),
        ]);

    return (
        <>
            <PageHeader
                title="Customers"
                description={`${total.toLocaleString('en-IN')} customer${total === 1 ? '' : 's'} match these filters.`}
            />

            <section aria-label="Customer segments" className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard label="Total customers" value={total.toLocaleString('en-IN')} icon={UsersRound} />
                <StatCard label="Repeat customers" value={(repeatCount ?? 0).toLocaleString('en-IN')} tone="positive" />
                <StatCard label="High value" value={(highValueCount ?? 0).toLocaleString('en-IN')} tone="brand" hint="₹5,000+ lifetime" />
                <StatCard label="Gone quiet" value={(inactiveCount ?? 0).toLocaleString('en-IN')} tone="caution" hint="No order in 30 days" />
            </section>

            <CustomerFilterBar search={search} segment={segment} sort={sort} />

            <TableWrap>
                <Table>
                    <THead>
                        <TR className="hover:bg-transparent">
                            <TH>Customer</TH>
                            <TH>Contact</TH>
                            <TH numeric>Orders</TH>
                            <TH numeric>Lifetime value</TH>
                            <TH numeric>Avg order</TH>
                            <TH>Last order</TH>
                            <TH>Joined</TH>
                            <TH className="w-16" />
                        </TR>
                    </THead>
                    <TBody>
                        {error ? (
                            <TableMessageRow colSpan={8}>
                                <ErrorState title="Could not load customers" message={error.message} />
                            </TableMessageRow>
                        ) : !customers || customers.length === 0 ? (
                            <TableMessageRow colSpan={8}>
                                <EmptyState
                                    icon={UsersRound}
                                    title="No customers match"
                                    description="Try a different search or segment."
                                />
                            </TableMessageRow>
                        ) : (
                            customers.map((customer) => (
                                <TR key={customer.id}>
                                    <TD>
                                        <div className="flex items-center gap-2.5">
                                            <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-surface-muted text-[11.5px] font-semibold text-ink-muted">
                                                {initials(customer.full_name ?? customer.phone)}
                                            </span>
                                            <div className="min-w-0">
                                                <Link
                                                    href={`/customers/${customer.id}`}
                                                    className="block max-w-44 truncate text-[13.5px] font-medium text-ink hover:text-brand-600"
                                                >
                                                    {customer.full_name ?? 'Unnamed customer'}
                                                </Link>
                                                {customer.status !== 'ACTIVE' ? (
                                                    <Badge tone="critical" className="mt-0.5 px-1.5 py-0">
                                                        {customer.status}
                                                    </Badge>
                                                ) : customer.completed_orders === 0 ? (
                                                    <span className="block text-[11.5px] text-ink-muted">Yet to order</span>
                                                ) : null}
                                            </div>
                                        </div>
                                    </TD>

                                    <TD>
                                        <span className="block text-[12.5px]">{customer.phone ?? '—'}</span>
                                        {customer.email ? (
                                            <span className="block max-w-40 truncate text-[11.5px] text-ink-muted">
                                                {customer.email}
                                            </span>
                                        ) : null}
                                    </TD>

                                    <TD numeric>
                                        <span className="text-[13px] font-semibold">{customer.completed_orders}</span>
                                        {customer.cancelled_orders > 0 ? (
                                            <span className="block text-[11.5px] text-critical">
                                                {customer.cancelled_orders} cancelled
                                            </span>
                                        ) : null}
                                    </TD>

                                    <TD numeric className="text-[13px] font-semibold">
                                        {money(customer.lifetime_value)}
                                    </TD>

                                    <TD numeric className="text-[12.5px] text-ink-muted">
                                        {money(customer.average_order_value)}
                                    </TD>

                                    <TD className="text-[12.5px] whitespace-nowrap text-ink-muted">
                                        {customer.last_order_at ? relativeTime(customer.last_order_at) : '—'}
                                    </TD>

                                    <TD className="text-[12.5px] whitespace-nowrap text-ink-muted">
                                        {dateOnly(customer.created_at)}
                                    </TD>

                                    <TD>
                                        <Button asChild variant="ghost" size="sm">
                                            <Link href={`/customers/${customer.id}`}>Open</Link>
                                        </Button>
                                    </TD>
                                </TR>
                            ))
                        )}
                    </TBody>
                </Table>
            </TableWrap>

            {pageCount > 1 ? (
                <nav aria-label="Pagination" className="mt-4 flex items-center justify-between gap-3 text-[13px] text-ink-muted">
                    <p className="tnum">
                        Page {page} of {pageCount}
                    </p>
                    <div className="flex gap-2">
                        <Button asChild variant="secondary" size="sm" disabled={page <= 1}>
                            <Link href={pageHref(params, page - 1)}>Previous</Link>
                        </Button>
                        <Button asChild variant="secondary" size="sm" disabled={page >= pageCount}>
                            <Link href={pageHref(params, page + 1)}>Next</Link>
                        </Button>
                    </div>
                </nav>
            ) : null}
        </>
    );
}

function pageHref(params: Record<string, string | undefined>, page: number): string {
    const search = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
        if (value && key !== 'page') search.set(key, value);
    });
    if (page > 1) search.set('page', String(page));
    const query = search.toString();
    return query ? `/customers?${query}` : '/customers';
}
