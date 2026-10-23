'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { guestCartImportKey, readGuestCart, writeGuestCart, type GuestCartLine } from '@/lib/guest-cart';
import { messages, type Locale } from '@/lib/site';
import { recordStorefrontEvent } from '@/lib/storefront-analytics';

interface CartLine {
    cart_item_id: string; product_id: string; product_name: string; quantity: number; unit_price: number;
    net_amount: number; image_path?: string | null; is_available: boolean; variant_name?: string | null;
}
interface CheckoutQuote {
    lines: CartLine[]; item_count: number; unit_count: number; is_valid: boolean; issues?: Array<{ code?: string; message?: string; severity?: string }>;
    totals: Record<string, number>; branch?: { accepting_orders?: boolean; status_note?: string }; cart_id?: string | null;
}
interface SavedAddress { id: string; label: string; address_line1: string; area?: string | null; city: string; state: string; latitude: number; longitude: number; is_default: boolean; }

declare global {
    interface Window {
        Razorpay?: new (options: Record<string, unknown>) => { open(): void; on(name: string, callback: (event: unknown) => void): void };
    }
}

function currency(value: number, locale: Locale) {
    return new Intl.NumberFormat(locale === 'hi' ? 'hi-IN' : 'en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 }).format(Number(value || 0));
}

async function loadRazorpay() {
    if (window.Razorpay) return;
    await new Promise<void>((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://checkout.razorpay.com/v1/checkout.js'; script.async = true;
        script.onload = () => resolve(); script.onerror = () => reject(new Error('Payment checkout could not be loaded.'));
        document.body.appendChild(script);
    });
}

export function CartPanel({ branchId, locale, userId }: { branchId: string; locale: Locale; userId: string | null }) {
    const t = messages[locale];
    const router = useRouter();
    const idempotency = useRef<string | null>(null);
    const [guestLines, setGuestLines] = useState<GuestCartLine[]>([]);
    const [quote, setQuote] = useState<CheckoutQuote | null>(null);
    const [addresses, setAddresses] = useState<SavedAddress[]>([]);
    const [addressId, setAddressId] = useState('');
    const [fulfilment, setFulfilment] = useState<'DELIVERY' | 'PICKUP'>('DELIVERY');
    const [paymentMode, setPaymentMode] = useState<'ONLINE' | 'COD'>('ONLINE');
    const [useWallet, setUseWallet] = useState(false);
    const [coupon, setCoupon] = useState('');
    const [deliveryState, setDeliveryState] = useState('');
    const [busy, setBusy] = useState(false);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [orderId, setOrderId] = useState('');
    const [address, setAddress] = useState({ line: '', area: '', city: '', state: '', postal: '', lat: '', lng: '' });

    const refresh = useCallback(async () => {
        if (!userId) return;
        const result = await createSupabaseBrowserClient().rpc('calculate_checkout', { p_branch_id: branchId, p_payment_mode: paymentMode });
        if (result.error) throw result.error;
        setQuote(result.data as unknown as CheckoutQuote);
    }, [branchId, paymentMode, userId]);

    useEffect(() => {
        if (!userId) {
            const update = () => setGuestLines(readGuestCart(branchId));
            update(); setLoading(false);
            window.addEventListener('bb-guest-cart-changed', update);
            window.addEventListener('storage', update);
            return () => { window.removeEventListener('bb-guest-cart-changed', update); window.removeEventListener('storage', update); };
        }
        let alive = true;
        const supabase = createSupabaseBrowserClient();
        setGuestLines(readGuestCart(branchId));
        Promise.all([
            supabase.from('addresses').select('id,label,address_line1,area,city,state,latitude,longitude,is_default').is('deleted_at', null).order('is_default', { ascending: false }),
            supabase.rpc('calculate_checkout', { p_branch_id: branchId, p_payment_mode: paymentMode }),
        ]).then(([addressResult, quoteResult]) => {
            if (!alive) return;
            if (addressResult.error) throw addressResult.error;
            if (quoteResult.error) throw quoteResult.error;
            const rows = (addressResult.data ?? []) as SavedAddress[];
            setAddresses(rows);
            const initialAddress = rows.find((item) => item.is_default) ?? rows[0];
            if (initialAddress) setAddressId((current) => current || initialAddress.id);
            setQuote(quoteResult.data as unknown as CheckoutQuote);
            const quote = quoteResult.data as unknown as CheckoutQuote;
            if (quote.unit_count > 0 && !sessionStorage.getItem(`bb_checkout_started_${branchId}`)) {
                sessionStorage.setItem(`bb_checkout_started_${branchId}`, '1');
                recordStorefrontEvent('CHECKOUT_START', branchId);
            }
            setLoading(false);
        }).catch(() => { if (alive) { setError(t.retry); setLoading(false); } });
        return () => { alive = false; };
    }, [branchId, paymentMode, t.retry, userId]);

    async function refreshOptions(extra: Record<string, unknown> = {}) {
        setBusy(true); setError('');
        try {
            const supabase = createSupabaseBrowserClient();
            const { data, error: optionError } = await supabase.rpc('cart_set_options', {
                p_branch_id: branchId, p_fulfilment_type: fulfilment,
                p_address_id: fulfilment === 'DELIVERY' ? (addressId || null) : null,
                p_use_wallet: useWallet, ...extra,
            });
            if (optionError) throw optionError;
            setQuote(data as unknown as CheckoutQuote);
        } catch { setError(t.retry); } finally { setBusy(false); }
    }

    async function importSavedCart() {
        setBusy(true); setError('');
        try {
            const lines = readGuestCart(branchId);
            if (!lines.length) { setGuestLines([]); return; }
            const { error: importError } = await createSupabaseBrowserClient().rpc('import_guest_cart', {
                p_idempotency_key: guestCartImportKey(branchId),
                p_branch_id: branchId,
                p_lines: lines.map((line) => ({
                    product_id: line.productId,
                    variant_id: line.variantId ?? null,
                    quantity: line.quantity,
                    modifiers: line.modifiers,
                    special_instructions: line.specialInstructions || null,
                })),
            });
            if (importError) throw importError;
            writeGuestCart(branchId, []);
            setGuestLines([]);
            await refresh();
        } catch { setError(t.unavailableItem); } finally { setBusy(false); }
    }

    async function removeLine(id: string) {
        setBusy(true); setError('');
        try {
            const { data, error: removeError } = await createSupabaseBrowserClient().rpc('cart_remove_item', { p_cart_item_id: id });
            if (removeError) throw removeError;
            setQuote(data as unknown as CheckoutQuote);
        } catch { setError(t.retry); } finally { setBusy(false); }
    }

    async function addAddress(event: React.FormEvent<HTMLFormElement>) {
        event.preventDefault(); setBusy(true); setError(''); setDeliveryState('');
        try {
            const lat = Number(address.lat); const lng = Number(address.lng);
            if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) throw new Error(t.locationError);
            const supabase = createSupabaseBrowserClient();
            const { data, error: saveError } = await supabase.rpc('upsert_address', {
                p_address_line1: address.line, p_area: address.area || null, p_city: address.city, p_state: address.state,
                p_postal_code: address.postal || null, p_latitude: lat, p_longitude: lng, p_location_source: 'MANUAL', p_is_default: addresses.length === 0,
            });
            if (saveError) throw saveError;
            const saved = data as { address?: SavedAddress; serviceability?: { serviceable?: boolean; message?: string } };
            if (!saved.address?.id) throw new Error(t.retry);
            const nextAddresses = [saved.address, ...addresses]; setAddresses(nextAddresses); setAddressId(saved.address.id);
            const check = await supabase.rpc('check_serviceability', { p_latitude: lat, p_longitude: lng, p_branch_id: branchId, p_order_amount: 0 });
            if (check.error) throw check.error;
            const service = check.data as { serviceable?: boolean; message?: string };
            setDeliveryState(service.serviceable ? t.available : (service.message ?? t.outOfAreaMessage));
            await refreshOptions({ p_address_id: saved.address.id, p_fulfilment_type: 'DELIVERY' });
        } catch (cause) { setError(cause instanceof Error ? cause.message : t.retry); } finally { setBusy(false); }
    }

    function useCurrentLocation() {
        if (!navigator.geolocation) { setError(t.locationError); return; }
        setBusy(true); setError('');
        navigator.geolocation.getCurrentPosition((position) => {
            setAddress((current) => ({ ...current, lat: String(position.coords.latitude), lng: String(position.coords.longitude) }));
            setBusy(false);
        }, () => { setError(t.locationError); setBusy(false); }, { enableHighAccuracy: false, timeout: 10000, maximumAge: 60000 });
    }

    async function applyCoupon() {
        setBusy(true); setError('');
        try {
            const { data, error: couponError } = await createSupabaseBrowserClient().rpc('apply_coupon', { p_code: coupon.trim(), p_branch_id: branchId });
            if (couponError) throw couponError;
            setQuote(data as unknown as CheckoutQuote);
        } catch { setError(t.retry); } finally { setBusy(false); }
    }

    async function placeOrder() {
        setBusy(true); setError(''); idempotency.current ??= crypto.randomUUID();
        try {
            const supabase = createSupabaseBrowserClient();
            // Refresh from the server before placing; create-order will price again
            // inside its own transaction and ignores browser totals.
            await refresh();
            const { data: result, error: orderError } = await supabase.functions.invoke('create-order', {
                body: { idempotency_key: idempotency.current, payment_mode: paymentMode, branch_id: branchId, channel: 'WEB' },
            });
            if (orderError) throw orderError;
            const order = result?.order as { order_id: string; requires_payment?: boolean } | undefined;
            if (!order?.order_id) throw new Error(t.retry);
            setOrderId(order.order_id);
            idempotency.current = null;
            if (!order.requires_payment) { recordStorefrontEvent('CHECKOUT_COMPLETED', branchId); router.push(`/order/${order.order_id}`); return; }

            const { data: session, error: paymentError } = await supabase.functions.invoke('create-payment', { body: { order_id: order.order_id } });
            if (paymentError) { router.push(`/order/${order.order_id}?payment=pending`); return; }
            await loadRazorpay();
            const payment = session?.payment as { provider_order_id: string; amount: number; currency: string };
            const checkout = session?.checkout as { key_id: string; name: string; description: string; theme_color: string; prefill: Record<string, string> };
            const modal = new window.Razorpay!({
                key: checkout.key_id, order_id: payment.provider_order_id, amount: payment.amount, currency: payment.currency,
                name: checkout.name, description: checkout.description, theme: { color: checkout.theme_color }, prefill: checkout.prefill,
                handler: async (response: unknown) => {
                    const values = response as { razorpay_order_id: string; razorpay_payment_id: string; razorpay_signature: string };
                    const { error: verifyError } = await supabase.functions.invoke('verify-payment', { body: { order_id: order.order_id, ...values } });
                    if (!verifyError) recordStorefrontEvent('CHECKOUT_COMPLETED', branchId);
                    router.push(verifyError ? `/order/${order.order_id}?payment=pending` : `/order/${order.order_id}`);
                },
                modal: { ondismiss: () => router.push(`/order/${order.order_id}?payment=pending`) },
            });
            modal.open();
        } catch { setError(t.retry); } finally { setBusy(false); }
    }

    if (loading) return <p role="status">{t.loading}</p>;
    if (!userId) return <section className="panel">
        <h1>{t.cart}</h1>
        {!guestLines.length ? <p>{t.emptyCart}</p> : <>
            <p className="status-message">{t.guestCart}</p>
            <ul className="cart-lines">{guestLines.map((line, index) => <li key={`${line.productId}-${index}`}>
                <div><strong>{line.name}</strong>{line.variantName ? <small> · {line.variantName}</small> : null}<small> × {line.quantity}</small></div>
                <button type="button" className="text-button" onClick={() => { const next = guestLines.filter((_, row) => row !== index); writeGuestCart(branchId, next); setGuestLines(next); }}>{t.remove}</button>
            </li>)}</ul>
            <p className="muted">{t.priceChecked}</p>
            <Link className="primary-button" href={`/sign-in?next=${encodeURIComponent('/cart')}`}>{t.continueCheckout}</Link>
        </>}
    </section>;

    if (loading) return <p role="status">{t.loading}</p>;
    const lines = quote?.lines ?? [];
    const totals = quote?.totals ?? {};
    return <main className="page">
        {guestLines.length ? <section className="panel" aria-labelledby="saved-cart-title">
            <h2 id="saved-cart-title">{t.savedCartTitle}</h2>
            <p className="muted">{t.savedCartDescription}</p>
            <ul className="cart-lines">{guestLines.map((line, index) => <li key={`${line.productId}-${index}`}>
                <div><strong>{line.name}</strong>{line.variantName ? <small> · {line.variantName}</small> : null}<small> × {line.quantity}</small></div>
            </li>)}</ul>
            <button type="button" className="secondary-button" disabled={busy} onClick={() => void importSavedCart()}>{busy ? t.loading : t.importSavedCart}</button>
        </section> : null}
        <h1>{t.cart}</h1>
        <p className="muted">{t.orderingFrom}: {branchId}. {t.currentOutletCart}</p>
        {!lines.length ? <section className="panel empty-cart"><p>{t.emptyCart}</p><Link className="primary-button" href="/menu">{t.backMenu}</Link></section> : <div className="two-column">
            <section>
                <ul className="cart-lines">{lines.map((line) => <li key={line.cart_item_id}>
                    <div><strong>{line.product_name}</strong>{line.variant_name ? <small> · {line.variant_name}</small> : null}<small> × {line.quantity}</small>{!line.is_available ? <small className="error-text"> · {t.unavailable}</small> : null}</div>
                    <strong>{currency(line.net_amount, locale)}</strong>
                    <button type="button" className="text-button" disabled={busy} onClick={() => void removeLine(line.cart_item_id)}>{t.remove}</button>
                </li>)}</ul>
                <div className="panel checkout-options">
                    <label className="field">{t.deliveryMode}<select value={fulfilment} onChange={(event) => { setFulfilment(event.target.value as 'DELIVERY' | 'PICKUP'); void refreshOptions({ p_fulfilment_type: event.target.value, p_address_id: event.target.value === 'PICKUP' ? null : (addressId || null) }); }}>
                        <option value="DELIVERY">{t.delivery}</option><option value="PICKUP">{t.pickup}</option>
                    </select></label>
                    {fulfilment === 'DELIVERY' ? <>
                        {addresses.length ? <label className="field">{t.deliveryAddress}<select value={addressId} onChange={(event) => { setAddressId(event.target.value); void refreshOptions({ p_fulfilment_type: 'DELIVERY', p_address_id: event.target.value }); }}>
                            <option value="">{t.addAddress}</option>{addresses.map((item) => <option key={item.id} value={item.id}>{item.label} · {item.address_line1}, {item.city}</option>)}
                        </select></label> : null}
                        <form onSubmit={addAddress} className="address-form">
                            <h3>{t.addAddress}</h3>
                            <label className="field">{t.addressLine}<input required value={address.line} onChange={(event) => setAddress({ ...address, line: event.target.value })} /></label>
                            <div className="form-grid"><label className="field">{t.area}<input value={address.area} onChange={(event) => setAddress({ ...address, area: event.target.value })} /></label><label className="field">{t.postalCode}<input inputMode="numeric" value={address.postal} onChange={(event) => setAddress({ ...address, postal: event.target.value })} /></label></div>
                            <div className="form-grid"><label className="field">{t.city}<input required value={address.city} onChange={(event) => setAddress({ ...address, city: event.target.value })} /></label><label className="field">{t.state}<input required value={address.state} onChange={(event) => setAddress({ ...address, state: event.target.value })} /></label></div>
                            <button className="secondary-button" type="button" onClick={useCurrentLocation}>{t.useLocation}</button>
                            <p className="muted">{t.privacyMessage}</p>
                            <div className="form-grid"><label className="field">{t.latitude}<input required inputMode="decimal" value={address.lat} onChange={(event) => setAddress({ ...address, lat: event.target.value })} /></label><label className="field">{t.longitude}<input required inputMode="decimal" value={address.lng} onChange={(event) => setAddress({ ...address, lng: event.target.value })} /></label></div>
                            <button className="secondary-button" disabled={busy}>{t.save}</button>
                        </form>
                        {deliveryState ? <p className="status-message" role="status">{deliveryState}</p> : null}
                    </> : null}
                    <form className="coupon-row" onSubmit={(event) => { event.preventDefault(); void applyCoupon(); }}><label className="field">{t.couponCode}<input value={coupon} onChange={(event) => setCoupon(event.target.value)} /></label><button className="secondary-button" disabled={busy || !coupon.trim()}>{t.applyCoupon}</button></form>
                    <label className="check-row"><input type="checkbox" checked={useWallet} onChange={(event) => { setUseWallet(event.target.checked); void refreshOptions({ p_use_wallet: event.target.checked }); }} />{t.wallet}</label>
                    <label className="field">{t.paymentMethod}<select value={paymentMode} onChange={(event) => setPaymentMode(event.target.value as 'ONLINE' | 'COD')}><option value="ONLINE">{t.onlinePayment}</option><option value="COD">{t.cashPayment}</option></select></label>
                    <p className="muted">{t.paymentDisclaimer}</p>
                </div>
            </section>
            <aside className="panel bill-summary">
                <h2>{t.checkout}</h2>
                <p>{t.subtotal}<strong>{currency(totals.items_subtotal ?? 0, locale)}</strong></p>
                <p>{t.discount}<strong>−{currency(totals.total_discount ?? 0, locale)}</strong></p>
                <p>{t.tax}<strong>{currency(totals.tax_amount ?? 0, locale)}</strong></p>
                <p>{t.deliveryFee}<strong>{currency(totals.delivery_fee ?? 0, locale)}</strong></p>
                <hr /><p className="bill-total">{t.total}<strong>{currency(totals.payable_amount ?? totals.grand_total ?? 0, locale)}</strong></p>
                {quote?.branch?.accepting_orders === false ? <p className="status-message">{quote.branch.status_note ?? t.closedReason}</p> : null}
                {quote?.issues?.filter((issue) => issue.severity === 'BLOCKING').map((issue, index) => <p className="status-message" role="status" key={`${issue.code}-${index}`}>{issue.message}</p>)}
                {error ? <p className="status-message" role="alert">{error}</p> : null}
                <button className="primary-button full-width" disabled={busy || !quote?.is_valid || !lines.length} onClick={() => void placeOrder()}>{busy ? t.loading : t.placeOrder}</button>
                {orderId ? <p><Link href={`/order/${orderId}`}>{t.orderTracking}</Link></p> : null}
                <p className="muted">{t.priceChecked}</p>
            </aside>
        </div>}
    </main>;
}
