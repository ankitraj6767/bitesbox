'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { messages, type Locale } from '@/lib/site';

function safeNext(value: string | null) {
    if (!value || !value.startsWith('/') || value.startsWith('//') || value.startsWith('/\\')) return '/account';
    return value;
}

export function PhoneSignInForm({ locale, next, referralCode }: { locale: Locale; next: string | null; referralCode: string | null }) {
    const t = messages[locale];
    const router = useRouter();
    const [phone, setPhone] = useState('');
    const [otp, setOtp] = useState('');
    const [sent, setSent] = useState(false);
    const [busy, setBusy] = useState(false);
    const [notice, setNotice] = useState('');
    const [error, setError] = useState('');

    async function sendCode(event: FormEvent) {
        event.preventDefault(); setBusy(true); setError(''); setNotice('');
        const cleaned = phone.replace(/[\s()-]/g, '');
        if (!/^\+[1-9]\d{7,14}$/.test(cleaned)) { setError(t.invalidPhone); setBusy(false); return; }
        const { error: authError } = await createSupabaseBrowserClient().auth.signInWithOtp({ phone: cleaned });
        if (authError) setError(t.retry);
        else { setPhone(cleaned); setSent(true); setNotice(t.otpSent); }
        setBusy(false);
    }

    async function verifyCode(event: FormEvent) {
        event.preventDefault(); setBusy(true); setError(''); setNotice('');
        if (!/^\d{4,8}$/.test(otp.trim())) { setError(t.invalidCode); setBusy(false); return; }
        try {
            const supabase = createSupabaseBrowserClient();
            const { error: verifyError } = await supabase.auth.verifyOtp({ phone, token: otp.trim(), type: 'sms' });
            if (verifyError) throw verifyError;

            if (locale === 'hi') await supabase.rpc('update_my_profile', { p_preferred_language: 'hi' });
            let referralPending = false;
            if (referralCode) {
                const { error: referralError } = await supabase.rpc('attribute_referral', { p_code: referralCode });
                if (referralError) {
                    localStorage.setItem('bb_pending_referral_code', referralCode.toUpperCase());
                    setNotice(t.referralInvalid);
                    referralPending = true;
                }
            }
            const destination = safeNext(next);
            router.replace(referralPending && destination === '/referrals'
                ? `/referrals?code=${encodeURIComponent(referralCode!.toUpperCase())}`
                : destination);
            router.refresh();
        } catch (cause) {
            setError(cause instanceof Error ? cause.message : t.retry);
        } finally { setBusy(false); }
    }

    return <form className="panel sign-in-form" onSubmit={sent ? verifyCode : sendCode}>
        <div className="eyebrow">Bites Box</div>
        <h1>{t.signIn}</h1>
        <p className="muted">{t.enterPhone}</p>
        {!sent ? <label className="field">{t.phone}<input autoComplete="tel" inputMode="tel" value={phone} onChange={(event) => setPhone(event.target.value)} placeholder="+91…" required /></label> : <label className="field">{t.code}<input autoComplete="one-time-code" inputMode="numeric" value={otp} onChange={(event) => setOtp(event.target.value)} required /></label>}
        {notice ? <p className="status-message" role="status">{notice}</p> : null}
        {error ? <p className="status-message" role="alert">{error}</p> : null}
        <button className="primary-button" disabled={busy}>{busy ? t.loading : sent ? t.verifyCode : t.sendCode}</button>
        {sent ? <button className="secondary-button" type="button" disabled={busy} onClick={() => { setSent(false); setOtp(''); }}>{locale === 'hi' ? 'नंबर बदलें' : 'Change phone number'}</button> : null}
    </form>;
}
