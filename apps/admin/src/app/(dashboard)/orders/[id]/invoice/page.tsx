import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent } from '@/components/ui/card';
import { PrintButton } from '@/features/orders/print-button';
import { PERMISSIONS, type OrderInvoice } from '@bitesbox/shared-types';
import { dateTime, money } from '@/lib/utils';

export const metadata: Metadata = { title: 'Invoice' };
export const dynamic = 'force-dynamic';

export default async function InvoicePage({ params }: { params: Promise<{ id: string }> }) {
    const [, { id }] = await Promise.all([requirePermission(PERMISSIONS.ORDER_VIEW), params]);

    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase.rpc('order_invoice', { p_order_id: id });

    if (error || !data) notFound();

    const invoice = data as unknown as OrderInvoice;
    const totals = invoice.totals as Record<string, number>;

    return (
        <>
            <PageHeader
                breadcrumbs={[
                    { label: 'Orders', href: '/orders' },
                    { label: invoice.order_number, href: `/orders/${id}` },
                    { label: 'Invoice' },
                ]}
                title={invoice.invoice_number}
                description={`Issued ${dateTime(invoice.invoice_date)}`}
                actions={<PrintButton />}
            />

            {/* Print styles keep the invoice to one clean page. */}
            <style>{`
        @media print {
          body { background: #fff; }
          header, aside, nav, [data-print-hide] { display: none !important; }
          main { padding: 0 !important; }
          .invoice-sheet { border: 0 !important; box-shadow: none !important; }
        }
      `}</style>

            <Card className="invoice-sheet mx-auto max-w-3xl">
                <CardContent className="p-8">
                    {/* Header */}
                    <div className="flex flex-wrap items-start justify-between gap-6 border-b border-hairline pb-6">
                        <div>
                            <h2 className="font-display text-xl font-semibold tracking-tight text-ink">
                                {invoice.restaurant.legal_name}
                            </h2>
                            <p className="mt-1 max-w-xs text-[12.5px] leading-relaxed text-ink-muted">
                                {invoice.restaurant.address}
                            </p>
                            <p className="mt-1 text-[12.5px] text-ink-muted">
                                {invoice.restaurant.phone}
                                {invoice.restaurant.email ? ` · ${invoice.restaurant.email}` : ''}
                            </p>
                            {invoice.restaurant.gstin ? (
                                <p className="mt-1 font-mono text-[12px] text-ink">GSTIN {invoice.restaurant.gstin}</p>
                            ) : null}
                            {invoice.restaurant.fssai ? (
                                <p className="font-mono text-[12px] text-ink-muted">FSSAI {invoice.restaurant.fssai}</p>
                            ) : null}
                        </div>

                        <div className="text-right">
                            <p className="text-[11.5px] font-semibold tracking-wider text-ink-muted uppercase">
                                Tax invoice
                            </p>
                            <p className="mt-1 font-mono text-[15px] font-semibold text-ink">
                                {invoice.invoice_number}
                            </p>
                            <p className="mt-1 text-[12.5px] text-ink-muted">{dateTime(invoice.invoice_date)}</p>
                        </div>
                    </div>

                    {/* Customer */}
                    <div className="border-b border-hairline py-5">
                        <p className="text-[11.5px] font-semibold tracking-wider text-ink-muted uppercase">
                            Billed to
                        </p>
                        <p className="mt-1 text-[13.5px] font-medium text-ink">{invoice.customer.name ?? 'Customer'}</p>
                        <p className="text-[12.5px] text-ink-muted">{invoice.customer.phone ?? ''}</p>
                        <p className="mt-1 max-w-md text-[12.5px] leading-relaxed text-ink-muted">
                            {invoice.customer.address}
                        </p>
                    </div>

                    {/* Items */}
                    <table className="mt-5 w-full text-[12.5px]">
                        <thead>
                            <tr className="border-b border-hairline text-left">
                                <th className="py-2 font-semibold text-ink-muted">Item</th>
                                <th className="py-2 text-center font-semibold text-ink-muted">HSN</th>
                                <th className="py-2 text-right font-semibold text-ink-muted">Qty</th>
                                <th className="py-2 text-right font-semibold text-ink-muted">Rate</th>
                                <th className="py-2 text-right font-semibold text-ink-muted">Taxable</th>
                                <th className="py-2 text-right font-semibold text-ink-muted">GST</th>
                                <th className="py-2 text-right font-semibold text-ink-muted">Amount</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-hairline">
                            {invoice.items.map((item, index) => (
                                <tr key={index} className={item.is_cancelled ? 'text-ink-muted line-through' : ''}>
                                    <td className="py-2.5 pr-3">
                                        <span className="block font-medium text-ink">{item.name}</span>
                                        {item.modifiers.length > 0 ? (
                                            <span className="block text-[11.5px] text-ink-muted">
                                                {item.modifiers.join(', ')}
                                            </span>
                                        ) : null}
                                    </td>
                                    <td className="py-2.5 text-center font-mono text-[11.5px] text-ink-muted">
                                        {item.hsn_sac_code ?? '—'}
                                    </td>
                                    <td className="tnum py-2.5 text-right">{item.quantity}</td>
                                    <td className="tnum py-2.5 text-right">{money(item.unit_price, true)}</td>
                                    <td className="tnum py-2.5 text-right">{money(item.taxable_amount, true)}</td>
                                    <td className="tnum py-2.5 text-right">
                                        {money(item.tax_amount, true)}
                                        <span className="block text-[11px] text-ink-muted">
                                            {(Number(item.tax_rate) * 100).toFixed(0)}%
                                        </span>
                                    </td>
                                    <td className="tnum py-2.5 text-right font-semibold text-ink">
                                        {money(item.net_amount, true)}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>

                    {/* Totals */}
                    <div className="mt-5 flex justify-end">
                        <dl className="w-full max-w-xs space-y-1.5 text-[12.5px]">
                            <Row label="Subtotal" value={money(totals.items_subtotal ?? 0, true)} />
                            {Number(totals.discount ?? 0) > 0 ? (
                                <Row
                                    label={`Discount${invoice.totals.coupon_code ? ` (${invoice.totals.coupon_code})` : ''}`}
                                    value={`− ${money(Number(totals.discount), true)}`}
                                />
                            ) : null}
                            <Row label="Taxable value" value={money(totals.taxable_amount ?? 0, true)} />
                            <Row label="CGST" value={money(totals.cgst ?? 0, true)} />
                            <Row label="SGST" value={money(totals.sgst ?? 0, true)} />
                            {Number(totals.packaging_charge ?? 0) > 0 ? (
                                <Row label="Packaging" value={money(Number(totals.packaging_charge), true)} />
                            ) : null}
                            {Number(totals.delivery_fee ?? 0) > 0 ? (
                                <Row label="Delivery fee" value={money(Number(totals.delivery_fee), true)} />
                            ) : null}
                            {Number(totals.tip ?? 0) > 0 ? (
                                <Row label="Tip" value={money(Number(totals.tip), true)} />
                            ) : null}
                            {Number(totals.round_off ?? 0) !== 0 ? (
                                <Row label="Round off" value={money(Number(totals.round_off), true)} />
                            ) : null}
                            <div className="flex items-center justify-between border-t border-hairline pt-2">
                                <dt className="text-[13.5px] font-semibold text-ink">Total</dt>
                                <dd className="tnum text-[15px] font-semibold text-ink">
                                    {money(totals.grand_total ?? 0, true)}
                                </dd>
                            </div>
                            {Number(totals.refunded ?? 0) > 0 ? (
                                <Row label="Refunded" value={`− ${money(Number(totals.refunded), true)}`} />
                            ) : null}
                        </dl>
                    </div>

                    {/* Payment */}
                    <div className="mt-6 border-t border-hairline pt-4 text-[12.5px] text-ink-muted">
                        <p>
                            Paid via{' '}
                            <span className="font-medium text-ink">
                                {invoice.payment.mode === 'COD' ? 'cash on delivery' : 'online payment'}
                            </span>
                            {invoice.payment.paid_at ? ` on ${dateTime(invoice.payment.paid_at)}` : ''}
                            {invoice.payment.reference ? (
                                <>
                                    {' '}
                                    · reference <span className="font-mono">{invoice.payment.reference}</span>
                                </>
                            ) : null}
                        </p>
                        {invoice.tax_note ? <p className="mt-1">{invoice.tax_note}</p> : null}
                        {invoice.footer_note ? (
                            <p className="mt-3 text-[13px] font-medium text-ink">{invoice.footer_note}</p>
                        ) : null}
                    </div>
                </CardContent>
            </Card>
        </>
    );
}

function Row({ label, value }: { label: string; value: string }) {
    return (
        <div className="flex items-center justify-between">
            <dt className="text-ink-muted">{label}</dt>
            <dd className="tnum font-medium text-ink">{value}</dd>
        </div>
    );
}
