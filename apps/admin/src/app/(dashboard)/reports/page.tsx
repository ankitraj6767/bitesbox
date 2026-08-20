import type { Metadata } from 'next';
import { FileSpreadsheet, Landmark, Package, Receipt } from 'lucide-react';
import { activeBranchId, hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { StatCard } from '@/components/ui/stat-card';
import { Badge } from '@/components/ui/badge';
import { ErrorState, InlineNotice } from '@/components/ui/states';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/overlays';
import { Table, TableWrap, TBody, TD, TH, THead, TR } from '@/components/ui/table';
import { RangePicker } from '@/features/dashboard/range-picker';
import { resolveRange, type RangeKey } from '@/features/dashboard/range';
import { SalesRegister, type SalesRow } from '@/features/reports/sales-register';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { money } from '@/lib/utils';

export const metadata: Metadata = { title: 'Reports' };
export const dynamic = 'force-dynamic';

export default async function ReportsPage({
    searchParams,
}: {
    searchParams: Promise<{ range?: string }>;
}) {
    const [session, params] = await Promise.all([
        requirePermission([PERMISSIONS.REPORT_VIEW, PERMISSIONS.FINANCE_VIEW]),
        searchParams,
    ]);

    const rangeKey = (params.range ?? '30d') as RangeKey;
    const { from, to, label } = resolveRange(rangeKey);
    const branchId = activeBranchId(session) ?? undefined;
    const canExport = hasPermission(session, PERMISSIONS.REPORT_EXPORT);
    const canSeeFinance = hasPermission(session, PERMISSIONS.FINANCE_VIEW);

    const supabase = await createSupabaseServerClient();

    const [salesResult, taxResult, productsResult] = await Promise.all([
        supabase.rpc('report_sales', {
            p_branch_id: branchId,
            p_from: from,
            p_to: to,
            p_limit: 500,
        }),
        canSeeFinance
            ? supabase.rpc('report_tax_summary', { p_branch_id: branchId, p_from: from, p_to: to })
            : Promise.resolve({ data: null, error: null }),
        supabase.rpc('report_products', { p_branch_id: branchId, p_from: from, p_to: to }),
    ]);

    if (salesResult.error) {
        return (
            <>
                <PageHeader title="Reports" />
                <Card>
                    <ErrorState title="Could not load reports" message={salesResult.error.message} />
                </Card>
            </>
        );
    }

    const sales = (salesResult.data ?? []) as unknown as SalesRow[];
    const products = productsResult.data ?? [];
    const tax = taxResult.data as unknown as {
        totals: Record<string, number>;
        by_rate: Array<{
            tax_rate: number;
            hsn_sac_code: string | null;
            taxable_amount: number;
            cgst: number;
            sgst: number;
            total_tax: number;
        }>;
        branch: { name: string; gstin: string | null; address: string };
    } | null;

    const netSales = sales.reduce((sum, row) => sum + Number(row.net_amount), 0);
    const unitsSold = products.reduce((sum, row) => sum + Number(row.units_sold), 0);

    return (
        <>
            <PageHeader
                title="Reports"
                description={`${label} · sales register, GST summary and product performance`}
                actions={<RangePicker value={rangeKey} />}
            />

            <section aria-label="Report summary" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard label="Orders" value={sales.length} icon={FileSpreadsheet} />
                <StatCard label="Net sales" value={money(netSales)} icon={Receipt} tone="brand" />
                <StatCard
                    label="GST collected"
                    value={money(Number(tax?.totals.total_tax ?? 0))}
                    icon={Landmark}
                    hint={canSeeFinance ? 'CGST + SGST' : 'Finance access required'}
                />
                <StatCard label="Units sold" value={unitsSold.toLocaleString('en-IN')} icon={Package} />
            </section>

            {!canExport ? (
                <InlineNotice tone="info" className="mt-5">
                    Exporting report data needs the Export reports permission.
                </InlineNotice>
            ) : null}

            <Tabs defaultValue="sales" className="mt-5">
                <TabsList>
                    <TabsTrigger value="sales">Sales register</TabsTrigger>
                    {canSeeFinance ? <TabsTrigger value="gst">GST summary</TabsTrigger> : null}
                    <TabsTrigger value="products">Product performance</TabsTrigger>
                </TabsList>

                <TabsContent value="sales">
                    <SalesRegister rows={sales} canExport={canExport} />
                </TabsContent>

                {canSeeFinance && tax ? (
                    <TabsContent value="gst" className="space-y-4">
                        <Card>
                            <CardToolbar
                                title="GST summary"
                                description={`${tax.branch.name}${tax.branch.gstin ? ` · GSTIN ${tax.branch.gstin}` : ''}`}
                            />
                            <CardContent>
                                <dl className="grid gap-x-8 gap-y-2 sm:grid-cols-2">
                                    <SummaryRow label="Orders" value={String(tax.totals.orders ?? 0)} />
                                    <SummaryRow label="Taxable value" value={money(Number(tax.totals.taxable_amount ?? 0), true)} />
                                    <SummaryRow label="CGST" value={money(Number(tax.totals.cgst ?? 0), true)} />
                                    <SummaryRow label="SGST" value={money(Number(tax.totals.sgst ?? 0), true)} />
                                    <SummaryRow label="Total GST" value={money(Number(tax.totals.total_tax ?? 0), true)} emphasis />
                                    <SummaryRow label="Gross sales" value={money(Number(tax.totals.gross_sales ?? 0), true)} />
                                    <SummaryRow label="Refunds" value={money(Number(tax.totals.refunds ?? 0), true)} />
                                </dl>
                            </CardContent>
                        </Card>

                        <Card>
                            <CardToolbar title="By tax rate" description="Grouped by GST rate and HSN/SAC code" />
                            <CardContent className="p-0">
                                <TableWrap className="rounded-none border-0">
                                    <Table>
                                        <THead>
                                            <TR className="hover:bg-transparent">
                                                <TH>Rate</TH>
                                                <TH>HSN/SAC</TH>
                                                <TH numeric>Taxable value</TH>
                                                <TH numeric>CGST</TH>
                                                <TH numeric>SGST</TH>
                                                <TH numeric>Total tax</TH>
                                            </TR>
                                        </THead>
                                        <TBody>
                                            {tax.by_rate.map((row, index) => (
                                                <TR key={`${row.tax_rate}-${row.hsn_sac_code ?? index}`}>
                                                    <TD>
                                                        <Badge tone="neutral">{(Number(row.tax_rate) * 100).toFixed(0)}%</Badge>
                                                    </TD>
                                                    <TD className="font-mono text-[12px] text-ink-muted">
                                                        {row.hsn_sac_code ?? '—'}
                                                    </TD>
                                                    <TD numeric className="text-[12.5px]">
                                                        {money(row.taxable_amount, true)}
                                                    </TD>
                                                    <TD numeric className="text-[12.5px]">
                                                        {money(row.cgst, true)}
                                                    </TD>
                                                    <TD numeric className="text-[12.5px]">
                                                        {money(row.sgst, true)}
                                                    </TD>
                                                    <TD numeric className="text-[13px] font-semibold">
                                                        {money(row.total_tax, true)}
                                                    </TD>
                                                </TR>
                                            ))}
                                        </TBody>
                                    </Table>
                                </TableWrap>
                            </CardContent>
                        </Card>
                    </TabsContent>
                ) : null}

                <TabsContent value="products">
                    <Card>
                        <CardToolbar
                            title="Product performance"
                            description="Every dish, including those that sold nothing"
                        />
                        <CardContent className="p-0">
                            <TableWrap className="rounded-none border-0">
                                <Table>
                                    <THead>
                                        <TR className="hover:bg-transparent">
                                            <TH>Dish</TH>
                                            <TH>Category</TH>
                                            <TH numeric>Units</TH>
                                            <TH numeric>Orders</TH>
                                            <TH numeric>Gross</TH>
                                            <TH numeric>Discount</TH>
                                            <TH numeric>Net</TH>
                                            <TH numeric>Refunded units</TH>
                                            <TH>State</TH>
                                        </TR>
                                    </THead>
                                    <TBody>
                                        {products.map((product) => (
                                            <TR key={product.product_id}>
                                                <TD className="max-w-56 truncate text-[13px] font-medium">
                                                    {product.product_name}
                                                </TD>
                                                <TD className="text-[12.5px] text-ink-muted">{product.category_name}</TD>
                                                <TD numeric className="text-[13px] font-semibold">
                                                    {product.units_sold}
                                                </TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {Number(product.orders_count)}
                                                </TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {money(product.gross_revenue)}
                                                </TD>
                                                <TD numeric className="text-[12.5px] text-positive">
                                                    {Number(product.discount_given) > 0
                                                        ? `−${money(product.discount_given)}`
                                                        : '—'}
                                                </TD>
                                                <TD numeric className="text-[13px] font-semibold">
                                                    {money(product.net_revenue)}
                                                </TD>
                                                <TD numeric className="text-[12.5px] text-critical">
                                                    {product.refunded_units > 0 ? product.refunded_units : '—'}
                                                </TD>
                                                <TD>
                                                    <Badge tone={product.is_available ? 'positive' : 'critical'}>
                                                        {product.is_available ? 'Available' : 'Unavailable'}
                                                    </Badge>
                                                </TD>
                                            </TR>
                                        ))}
                                    </TBody>
                                </Table>
                            </TableWrap>
                        </CardContent>
                    </Card>
                </TabsContent>
            </Tabs>
        </>
    );
}

function SummaryRow({
    label,
    value,
    emphasis = false,
}: {
    label: string;
    value: string;
    emphasis?: boolean;
}) {
    return (
        <div className="flex items-center justify-between gap-4 border-b border-hairline py-2 last:border-0">
            <dt className={emphasis ? 'text-[13px] font-semibold text-ink' : 'text-[13px] text-ink-muted'}>
                {label}
            </dt>
            <dd className={`tnum text-[13px] ${emphasis ? 'font-semibold text-ink' : 'font-medium text-ink'}`}>
                {value}
            </dd>
        </div>
    );
}
