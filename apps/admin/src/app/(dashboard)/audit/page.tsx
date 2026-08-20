import type { Metadata } from 'next';
import { FileClock, ShieldAlert } from 'lucide-react';
import { requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { EmptyState, ErrorState } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { AuditFilterBar } from '@/features/audit/audit-filter-bar';
import { PERMISSIONS, type AuditAction } from '@bitesbox/shared-types';
import { dateTime, humanise } from '@/lib/utils';
import Link from 'next/link';

export const metadata: Metadata = { title: 'Audit log' };
export const dynamic = 'force-dynamic';

const PAGE_SIZE = 50;

const SENSITIVE_ACTIONS: AuditAction[] = [
    'REFUND_APPROVE',
    'REFUND_REJECT',
    'ORDER_STATUS_OVERRIDE',
    'MANUAL_DELIVERY_OVERRIDE',
    'PRICE_CHANGE',
    'SETTINGS_CHANGE',
    'ROLE_ASSIGN',
    'ROLE_REVOKE',
    'PERMISSION_GRANT',
    'CUSTOMER_BLOCK',
    'RIDER_SUSPEND',
    'WALLET_ADJUSTMENT',
    'FEATURE_FLAG_CHANGE',
];

export default async function AuditPage({
    searchParams,
}: {
    searchParams: Promise<{ action?: string; entity?: string; page?: string }>;
}) {
    const [, params] = await Promise.all([requirePermission(PERMISSIONS.AUDIT_VIEW), searchParams]);

    const action = params.action ?? 'all';
    const entity = params.entity ?? 'all';
    const page = Math.max(1, Number(params.page ?? '1') || 1);

    const supabase = await createSupabaseServerClient();

    const { data, error } = await supabase.rpc('audit_trail', {
        p_entity_type: entity === 'all' ? undefined : entity,
        p_action: action === 'all' ? undefined : (action as AuditAction),
        p_limit: PAGE_SIZE,
        p_offset: (page - 1) * PAGE_SIZE,
    });

    const rows = data ?? [];
    const total = Number(rows[0]?.total_count ?? 0);
    const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));

    return (
        <>
            <PageHeader
                title="Audit log"
                description="Append-only record of every sensitive action. Not even an owner can edit history."
            />

            <AuditFilterBar action={action} entity={entity} />

            <Card>
                <CardToolbar
                    title="Recent activity"
                    description={`${total.toLocaleString('en-IN')} recorded action${total === 1 ? '' : 's'}`}
                />
                <CardContent className="p-0">
                    <TableWrap className="rounded-none border-0">
                        <Table>
                            <THead>
                                <TR className="hover:bg-transparent">
                                    <TH>When</TH>
                                    <TH>Who</TH>
                                    <TH>Action</TH>
                                    <TH>Entity</TH>
                                    <TH>Changed</TH>
                                    <TH>Reason</TH>
                                </TR>
                            </THead>
                            <TBody>
                                {error ? (
                                    <TableMessageRow colSpan={6}>
                                        <ErrorState title="Could not load the audit log" message={error.message} />
                                    </TableMessageRow>
                                ) : rows.length === 0 ? (
                                    <TableMessageRow colSpan={6}>
                                        <EmptyState
                                            icon={FileClock}
                                            title="Nothing recorded yet"
                                            description="Sensitive actions appear here as soon as they happen."
                                        />
                                    </TableMessageRow>
                                ) : (
                                    rows.map((row) => {
                                        const sensitive = SENSITIVE_ACTIONS.includes(row.action);

                                        return (
                                            <TR key={row.id}>
                                                <TD className="text-[12.5px] whitespace-nowrap text-ink-muted">
                                                    {dateTime(row.created_at)}
                                                </TD>

                                                <TD>
                                                    <span className="block max-w-36 truncate text-[13px] font-medium text-ink">
                                                        {row.actor_name ?? humanise(row.actor_kind)}
                                                    </span>
                                                    {row.actor_role ? (
                                                        <span className="block text-[11px] text-ink-muted">
                                                            {humanise(row.actor_role)}
                                                        </span>
                                                    ) : null}
                                                </TD>

                                                <TD>
                                                    <Badge tone={sensitive ? 'critical' : 'neutral'}>
                                                        {sensitive ? <ShieldAlert className="size-2.5" aria-hidden /> : null}
                                                        {humanise(row.action)}
                                                    </Badge>
                                                </TD>

                                                <TD>
                                                    <span className="block text-[12.5px] text-ink">
                                                        {humanise(row.entity_type)}
                                                    </span>
                                                    {row.entity_label ? (
                                                        <span className="block max-w-40 truncate text-[11.5px] text-ink-muted">
                                                            {row.entity_label}
                                                        </span>
                                                    ) : null}
                                                </TD>

                                                <TD>
                                                    {row.changed_fields && row.changed_fields.length > 0 ? (
                                                        <span className="flex flex-wrap gap-1">
                                                            {row.changed_fields.slice(0, 4).map((field) => (
                                                                <span
                                                                    key={field}
                                                                    className="rounded bg-surface-muted px-1.5 py-0.5 font-mono text-[11px] text-ink-muted"
                                                                >
                                                                    {field}
                                                                </span>
                                                            ))}
                                                            {row.changed_fields.length > 4 ? (
                                                                <span className="text-[11px] text-ink-muted">
                                                                    +{row.changed_fields.length - 4}
                                                                </span>
                                                            ) : null}
                                                        </span>
                                                    ) : (
                                                        <span className="text-[12px] text-ink-muted">—</span>
                                                    )}
                                                </TD>

                                                <TD className="max-w-56 text-[12px] text-ink-muted">
                                                    {row.reason ?? '—'}
                                                </TD>
                                            </TR>
                                        );
                                    })
                                )}
                            </TBody>
                        </Table>
                    </TableWrap>
                </CardContent>
            </Card>

            {pageCount > 1 ? (
                <nav
                    aria-label="Pagination"
                    className="mt-4 flex items-center justify-between gap-3 text-[13px] text-ink-muted"
                >
                    <p className="tnum">
                        Page {page} of {pageCount}
                    </p>
                    <div className="flex gap-2">
                        <Button asChild variant="secondary" size="sm" disabled={page <= 1}>
                            <Link href={`/audit?${buildQuery(params, page - 1)}`}>Previous</Link>
                        </Button>
                        <Button asChild variant="secondary" size="sm" disabled={page >= pageCount}>
                            <Link href={`/audit?${buildQuery(params, page + 1)}`}>Next</Link>
                        </Button>
                    </div>
                </nav>
            ) : null}
        </>
    );
}

function buildQuery(params: Record<string, string | undefined>, page: number): string {
    const search = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
        if (value && key !== 'page') search.set(key, value);
    });
    if (page > 1) search.set('page', String(page));
    return search.toString();
}
