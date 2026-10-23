'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { messages, type Locale } from '@/lib/site';

interface OrderPayload {
    id: string; order_number: string; status: string;
    payment?: { status?: string; mode?: string };
    totals?: { grand_total?: number; currency_code?: string };
    items?: Array<{ product_name: string; quantity: number; net_amount: number }>;
    timeline?: Array<{ to_status: string; label: string; created_at: string }>;
}

const hindiStatus: Record<string, string> = {
    PENDING_PAYMENT: 'भुगतान बाकी', PAYMENT_CONFIRMED: 'भुगतान की पुष्टि', ORDER_PLACED: 'ऑर्डर मिला', STORE_ACCEPTED: 'रेस्तरां ने स्वीकार किया', PREPARING: 'तैयार हो रहा है', READY_FOR_PICKUP: 'पिकअप के लिए तैयार', RIDER_ASSIGNED: 'डिलीवरी पार्टनर तय हुआ', PICKED_UP: 'ऑर्डर पिकअप हुआ', OUT_FOR_DELIVERY: 'डिलीवरी के लिए निकला', DELIVERED: 'डिलीवर हुआ', COMPLETED: 'पूरा हुआ', CUSTOMER_CANCELLED: 'रद्द हुआ', ADMIN_CANCELLED: 'रद्द हुआ', STORE_REJECTED: 'रेस्तरां ने स्वीकार नहीं किया', PAYMENT_FAILED: 'भुगतान विफल',
};

export function OrderTracker({ orderId, locale }: { orderId: string; locale: Locale }) {
    const t = messages[locale];
    const search = useSearchParams();
    const [order, setOrder] = useState<OrderPayload | null>(null);
    const [error, setError] = useState(false);
    const pendingPayment = search.get('payment') === 'pending';

    useEffect(() => {
        let active = true;
        const load = async () => {
            const { data, error: loadError } = await createSupabaseBrowserClient().rpc('order_detail', { p_order_id: orderId });
            if (!active) return;
            if (loadError || !data) { setError(true); return; }
            setOrder(data as unknown as OrderPayload); setError(false);
        };
        void load();
        const timer = window.setInterval(() => void load(), 12000);
        return () => { active = false; window.clearInterval(timer); };
    }, [orderId]);

    if (error) return <section className="panel"><p role="alert">{t.orderNotFound}</p><Link className="primary-button" href="/sign-in">{t.signIn}</Link></section>;
    if (!order) return <p role="status">{t.loading}</p>;
    const status = locale === 'hi' ? (hindiStatus[order.status] ?? order.status) : order.status.replaceAll('_', ' ').toLowerCase();
    return <section className="panel order-tracking">
        <p className="eyebrow">{t.orderTracking}</p>
        <h1>{t.orderNumber} · {order.order_number}</h1>
        {pendingPayment ? <p className="status-message" role="status">{t.paymentPending}</p> : null}
        <p>{t.currentStatus}: <strong>{status}</strong></p>
        <p>{t.paymentMethod}: <strong>{order.payment?.status ?? '—'}</strong></p>
        <p>{t.total}: <strong>{new Intl.NumberFormat(locale === 'hi' ? 'hi-IN' : 'en-IN', { style: 'currency', currency: order.totals?.currency_code ?? 'INR' }).format(Number(order.totals?.grand_total ?? 0))}</strong></p>
        <ol className="order-items">{(order.items ?? []).map((item, index) => <li key={`${item.product_name}-${index}`}><span>{item.product_name} × {item.quantity}</span></li>)}</ol>
        {order.timeline?.length ? <ol className="order-timeline">{order.timeline.map((item, index) => <li key={`${item.to_status}-${index}`}><span>{locale === 'hi' ? (hindiStatus[item.to_status] ?? item.label) : item.label}</span><time dateTime={item.created_at}>{new Intl.DateTimeFormat(locale === 'hi' ? 'hi-IN' : 'en-IN', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(item.created_at))}</time></li>)}</ol> : null}
        <Link className="secondary-button" href="/menu">{t.backMenu}</Link>
    </section>;
}
