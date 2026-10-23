'use client';

import * as React from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Heart, ShoppingBag, Store, TicketPercent } from 'lucide-react';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { messages, type Locale } from '@/lib/site';
import type { Outlet } from '@/lib/storefront-context';

export function StorefrontHeader({
    outlets,
    outletId,
    outletName,
    locale,
    userId,
}: {
    outlets: Outlet[];
    outletId: string;
    outletName: string;
    locale: Locale;
    userId: string | null;
}) {
    const router = useRouter();
    const text = messages[locale];
    const [notice, setNotice] = React.useState('');

    async function changeOutlet(nextId: string) {
        setNotice('');
        const nextOutlet = outlets.find((item) => item.id === nextId);
        if (!nextOutlet) return;
        const supabase = createSupabaseBrowserClient();
        if (userId) {
            const { data: addresses } = await supabase.from('addresses').select('latitude,longitude').eq('is_default', true).is('deleted_at', null).limit(1);
            const address = addresses?.[0];
            if (address) {
                const { data: result, error } = await supabase.rpc('check_serviceability', {
                    p_latitude: Number(address.latitude), p_longitude: Number(address.longitude), p_branch_id: nextId, p_order_amount: 0,
                });
                const serviceability = result as { serviceable?: boolean; message?: string } | null;
                if (error || serviceability?.serviceable !== true) {
                    const supportsPickup = nextOutlet.service_mode.includes('PICKUP') || nextOutlet.service_mode === 'BOTH';
                    if (!supportsPickup) {
                        setNotice(serviceability?.message ?? text.outOfAreaMessage);
                        return;
                    }
                }
            }
            const { error } = await supabase.rpc('set_preferred_branch', { p_branch_id: nextId });
            if (error) { setNotice(error.message); return; }
        }
        const response = await fetch('/api/customer-preferences', {
            method: 'POST', headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ branchId: nextId, locale }),
        });
        if (response.ok) { setNotice(text.currentOutletCart); router.refresh(); }
    }

    async function changeLocale(nextLocale: Locale) {
        if (userId) {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase.rpc('update_my_profile', { p_preferred_language: nextLocale });
            if (error) return;
        }
        const response = await fetch('/api/customer-preferences', {
            method: 'POST', headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ branchId: outletId, locale: nextLocale }),
        });
        if (response.ok) router.refresh();
    }

    return (
        <header className="site-header">
            <div className="header-top">
                <Link className="brand" href="/" aria-label="Bites Box home"><span className="brand-mark" aria-hidden>BB</span><span>Bites Box</span></Link>
                {outlets.length > 1 ? (
                    <label className="outlet-select"><Store size={16} aria-hidden /><span className="sr-only">{text.outlet}</span>
                        <select value={outletId} onChange={(event) => void changeOutlet(event.target.value)} aria-label={text.selectedOutlet}>
                            {outlets.map((outlet) => <option key={outlet.id} value={outlet.id}>{outlet.name} · {outlet.city}</option>)}
                        </select>
                    </label>
                ) : outlets[0] ? (
                    <span className="outlet-label"><Store size={16} aria-hidden />{outletName}</span>
                ) : null}
                <form action="/" className="search-form" role="search">
                    <label className="sr-only" htmlFor="menu-search">{text.search}</label>
                    <input id="menu-search" name="q" placeholder={text.search} />
                    <button type="submit" aria-label={text.search}>⌕</button>
                </form>
                <nav aria-label="Customer navigation" className="main-nav">
                    <Link href="/menu">{text.menu}</Link>
                    <Link href="/offers" aria-label={text.offers}><TicketPercent size={18} /> <span className="nav-label">{text.offers}</span></Link>
                    <Link href="/favorites" aria-label={text.favorites}><Heart size={18} /> <span className="nav-label">{text.favorites}</span></Link>
                    <Link href="/cart" aria-label={text.cart}><ShoppingBag size={18} /> <span className="nav-label">{text.cart}</span></Link>
                    <Link href={userId ? '/account' : '/sign-in'}>{text.account}</Link>
                </nav>
                <label className="language-select"><span className="sr-only">Language</span>
                    <select value={locale} onChange={(event) => void changeLocale(event.target.value as Locale)} aria-label={locale === 'hi' ? 'भाषा' : 'Language'}>
                        <option value="en">EN</option><option value="hi">हिन्दी</option>
                    </select>
                </label>
            </div>
            {notice ? <p className="header-notice" role="status">{notice}</p> : null}
        </header>
    );
}
