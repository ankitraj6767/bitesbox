'use client';

import { useState } from 'react';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { messages, type Locale } from '@/lib/site';
import { siteUrl } from '@/lib/site';

export function ReferralPanel({ locale, userId, code, inviteCode }: { locale: Locale; userId: string | null; code?: string; inviteCode?: string }) {
    const t = messages[locale];
    const [value, setValue] = useState(inviteCode ?? '');
    const [status, setStatus] = useState('');
    const [busy, setBusy] = useState(false);
    const shareUrl = code ? `${siteUrl}/r/${encodeURIComponent(code)}` : '';

    async function apply(event: React.FormEvent) {
        event.preventDefault(); setBusy(true); setStatus('');
        try {
            const { error } = await createSupabaseBrowserClient().rpc('attribute_referral', { p_code: value.trim() });
            if (error) throw error;
            setStatus(t.referralApplied);
        } catch { setStatus(t.referralInvalid); }
        finally { setBusy(false); }
    }

    async function share() {
        if (!shareUrl) return;
        try {
            if (navigator.share) {
                await navigator.share({ title: 'Bites Box invitation', url: shareUrl });
                setStatus(locale === 'hi' ? 'आमंत्रण साझा किया गया।' : 'Invitation shared.');
            } else {
                await navigator.clipboard.writeText(shareUrl);
                setStatus(t.copy);
            }
        } catch (error) {
            if (error instanceof DOMException && error.name === 'AbortError') return;
            setStatus(locale === 'hi' ? 'लिंक कॉपी नहीं हो सका।' : 'Could not share the link.');
        }
    }

    if (!userId) return <section className="panel"><h2>{t.referral}</h2><p>{t.signInRequired}</p><a className="primary-button" href={`/sign-in?ref=${encodeURIComponent(value || code || '')}&next=${encodeURIComponent('/referrals')}`}>{t.signIn}</a></section>;
    return <section className="panel">
        <h1>{t.referral}</h1>
        <p>{t.referralTerms}</p>
        {code ? <><label className="field">{locale === 'hi' ? 'आपका कोड' : 'Your code'}<input readOnly value={code} /></label>
            <button className="secondary-button" type="button" onClick={() => { void navigator.clipboard.writeText(shareUrl); setStatus(t.copy); }}>{t.copy}</button>
            <button className="secondary-button" type="button" onClick={() => void share()}>{locale === 'hi' ? 'आमंत्रण साझा करें' : 'Share invitation'}</button>
            <p className="muted">{locale === 'hi' ? 'आमंत्रण लिंक' : 'Invite link'}: <a href={shareUrl}>{shareUrl}</a></p></> : null}
        <form onSubmit={apply} className="coupon-row"><label className="field">{t.referral}<input value={value} onChange={(event) => setValue(event.target.value.toUpperCase())} maxLength={20} /></label><button className="primary-button" disabled={busy || !value.trim()}>{busy ? t.loading : t.apply}</button></form>
        {status ? <p role="status" className="status-message">{status}</p> : null}
    </section>;
}
