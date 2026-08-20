'use client';

import * as React from 'react';
import { Download, FileSpreadsheet } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { dateTime, money, humanise, downloadCsv, toCsv } from '@/lib/utils';

export interface SalesRow {
    order_id: string;
    order_number: string;
    placed_at: string;
    status: string;
    fulfilment_type: string;
    customer_name: string | null;
    customer_phone: string | null;
    item_count: number;
    unit_count: number;
    items_subtotal: number;
    total_discount: number;
    coupon_code: string | null;
    taxable_amount: number;
    cgst_amount: number;
    sgst_amount: number;
    tax_amount: number;
    packaging_charge: number;
    delivery_fee: number;
    tip_amount: number;
    grand_total: number;
    refunded_amount: number;
    net_amount: number;
    payment_mode: string;
    payment_method: string | null;
    zone_name: string | null;
    rider_name: string | null;
}

/**
 * Sales register with CSV export. The export mirrors exactly what is on screen,
 * so a finance handover never depends on a second query giving the same answer.
 */
export function SalesRegister({ rows, canExport }: { rows: SalesRow[]; canExport: boolean }) {
    const totals = React.useMemo(
        () =>
            rows.reduce(
                (sum, row) => ({
                    gross: sum.gross + Number(row.grand_total),
                    net: sum.net + Number(row.net_amount),
                    tax: sum.tax + Number(row.tax_amount),
                    discount: sum.discount + Number(row.total_discount),
                    delivery: sum.delivery + Number(row.delivery_fee),
                    refunded: sum.refunded + Number(row.refunded_amount),
                }),
                { gross: 0, net: 0, tax: 0, discount: 0, delivery: 0, refunded: 0 },
            ),
        [rows],
    );

    const exportCsv = () => {
        const csv = toCsv(
            rows.map((row) => ({
                order_number: row.order_number,
                placed_at: row.placed_at,
                status: row.status,
                fulfilment: row.fulfilment_type,
                customer: row.customer_name ?? '',
                phone: row.customer_phone ?? '',
                items: row.unit_count,
                subtotal: row.items_subtotal,
                discount: row.total_discount,
                coupon: row.coupon_code ?? '',
                taxable: row.taxable_amount,
                cgst: row.cgst_amount,
                sgst: row.sgst_amount,
                tax_total: row.tax_amount,
                packaging: row.packaging_charge,
                delivery_fee: row.delivery_fee,
                tip: row.tip_amount,
                grand_total: row.grand_total,
                refunded: row.refunded_amount,
                net: row.net_amount,
                payment_mode: row.payment_mode,
                payment_method: row.payment_method ?? '',
                zone: row.zone_name ?? '',
                rider: row.rider_name ?? '',
            })),
        );

        downloadCsv(`bitesbox-sales-${new Date().toISOString().slice(0, 10)}.csv`, csv);
    };

    return (
        <Card>
            <CardToolbar
                title="Sales register"
                description={`${rows.length} order${rows.length === 1 ? '' : 's'} · net ${money(totals.net)}`}
                action={
                    canExport && rows.length > 0 ? (
                        <Button variant="secondary" size="sm" onClick={exportCsv}>
                            <Download />
                            Export CSV
                        </Button>
                    ) : null
                }
            />
            <CardContent className="p-0">
                <TableWrap className="rounded-none border-0">
                    <Table>
                        <THead>
                            <TR className="hover:bg-transparent">
                                <TH>Order</TH>
                                <TH>Customer</TH>
                                <TH numeric>Subtotal</TH>
                                <TH numeric>Discount</TH>
                                <TH numeric>GST</TH>
                                <TH numeric>Delivery</TH>
                                <TH numeric>Total</TH>
                                <TH numeric>Refunded</TH>
                                <TH numeric>Net</TH>
                                <TH>Payment</TH>
                                <TH>Placed</TH>
                            </TR>
                        </THead>
                        <TBody>
                            {rows.length === 0 ? (
                                <TableMessageRow colSpan={11}>
                                    <EmptyState
                                        icon={FileSpreadsheet}
                                        title="No orders in this period"
                                        description="Choose a wider date range."
                                    />
                                </TableMessageRow>
                            ) : (
                                rows.map((row) => (
                                    <TR key={row.order_id}>
                                        <TD className="font-mono text-[12px] font-semibold whitespace-nowrap">
                                            {row.order_number}
                                            <span className="block text-[11px] font-normal text-ink-muted">
                                                {humanise(row.status)}
                                            </span>
                                        </TD>
                                        <TD className="max-w-32 truncate text-[12.5px]">{row.customer_name ?? '—'}</TD>
                                        <TD numeric className="text-[12.5px]">
                                            {money(row.items_subtotal, true)}
                                        </TD>
                                        <TD numeric className="text-[12.5px] text-positive">
                                            {Number(row.total_discount) > 0 ? `−${money(row.total_discount, true)}` : '—'}
                                        </TD>
                                        <TD numeric className="text-[12.5px]">
                                            {money(row.tax_amount, true)}
                                        </TD>
                                        <TD numeric className="text-[12.5px]">
                                            {money(row.delivery_fee, true)}
                                        </TD>
                                        <TD numeric className="text-[13px] font-semibold">
                                            {money(row.grand_total, true)}
                                        </TD>
                                        <TD numeric className="text-[12.5px] text-critical">
                                            {Number(row.refunded_amount) > 0 ? `−${money(row.refunded_amount, true)}` : '—'}
                                        </TD>
                                        <TD numeric className="text-[13px] font-semibold">
                                            {money(row.net_amount, true)}
                                        </TD>
                                        <TD className="text-[12px]">
                                            {row.payment_method ? humanise(row.payment_method) : humanise(row.payment_mode)}
                                        </TD>
                                        <TD className="text-[12px] whitespace-nowrap text-ink-muted">
                                            {dateTime(row.placed_at)}
                                        </TD>
                                    </TR>
                                ))
                            )}
                        </TBody>
                        {rows.length > 0 ? (
                            <tfoot className="border-t-2 border-hairline bg-surface-muted/60">
                                <TR className="hover:bg-transparent">
                                    <TD className="text-[12.5px] font-semibold" colSpan={2}>
                                        Totals
                                    </TD>
                                    <TD numeric className="text-[12.5px] font-semibold">
                                        {money(rows.reduce((s, r) => s + Number(r.items_subtotal), 0), true)}
                                    </TD>
                                    <TD numeric className="text-[12.5px] font-semibold text-positive">
                                        −{money(totals.discount, true)}
                                    </TD>
                                    <TD numeric className="text-[12.5px] font-semibold">
                                        {money(totals.tax, true)}
                                    </TD>
                                    <TD numeric className="text-[12.5px] font-semibold">
                                        {money(totals.delivery, true)}
                                    </TD>
                                    <TD numeric className="text-[13px] font-semibold">
                                        {money(totals.gross, true)}
                                    </TD>
                                    <TD numeric className="text-[12.5px] font-semibold text-critical">
                                        −{money(totals.refunded, true)}
                                    </TD>
                                    <TD numeric className="text-[13px] font-semibold">
                                        {money(totals.net, true)}
                                    </TD>
                                    <TD colSpan={2} />
                                </TR>
                            </tfoot>
                        ) : null}
                    </Table>
                </TableWrap>
            </CardContent>
        </Card>
    );
}
