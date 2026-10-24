'use client';

import { useState } from 'react';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { messages, type Locale } from '@/lib/site';
import { siteUrl } from '@/lib/site';

export interface ReferralSummary {
    code?: string | null;
    program_active?: boolean;
    attributed_count?: number;
    qualified_count?: number;
    rewarded_count?: number;
    terms?: {
        referrer_reward: number;
        referred_reward: number;
        minimum_order_amount: number;
        reward_expiry_days?: number | null;
    } | null;
    referrals?: Array<{
        status: string;
        attributed_at: string;
        rewarded_at: string | null;
        reward_amount: number;
    }>;
}

export function ReferralPanel({ locale, userId, code, inviteCode, summary }: {
    locale: Locale;
    userId: string | null;
    code?: string;
    inviteCode?: string;
    summary?: ReferralSummary | null;
}) {
    const t = messages[locale];
    const [value, setValue] = useState(inviteCode ?? '');
    const [status, setStatus] = useState('');
    const [busy, setBusy] = useState(false);
    const shareUrl = code ? `${siteUrl}/r/${encodeURIComponent(code)}` : '';
    const programActive = summary?.program_active === true;
    const formatMoney = (amount: number) => new Intl.NumberFormat(locale === 'hi' ? 'hi-IN' : 'en-IN', {
        style: 'currency', currency: 'INR', maximumFractionDigits: 2,
    }).format(amount);
    const statusLabel = (value: string) => ({
        ATTRIBUTED: t.statusAttributed,
        QUALIFIED: t.statusQualified,
        REWARDED: t.statusRewarded,
        REVERSED: t.statusReversed,
    }[value] ?? value);

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
        if (!shareUrl || !programActive) return;
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
        <p>{programActive ? t.referralTerms : t.referralInactive}</p>
        {code ? <><label className="field">{locale === 'hi' ? 'आपका कोड' : 'Your code'}<input readOnly value={code} /></label>
            <button className="secondary-button" type="button" disabled={!programActive} onClick={() => { void navigator.clipboard.writeText(code); setStatus(t.copy); }}>{t.copy}</button>
            <button className="secondary-button" type="button" disabled={!programActive} onClick={() => void share()}>{locale === 'hi' ? 'आमंत्रण साझा करें' : 'Share invitation'}</button>
            <p className="muted">{locale === 'hi' ? 'आमंत्रण लिंक' : 'Invite link'}: {programActive ? <a href={shareUrl}>{shareUrl}</a> : shareUrl}</p></> : null}
        {programActive && summary?.terms ? <section className="panel" aria-label={t.referralRewardsTitle}>
            <h2>{t.referralRewardsTitle}</h2>
            <p>{t.youEarn}: <strong>{formatMoney(summary.terms.referrer_reward)}</strong></p>
            <p>{t.friendEarns}: <strong>{formatMoney(summary.terms.referred_reward)}</strong></p>
            <p>{t.minimumOrder}: <strong>{formatMoney(summary.terms.minimum_order_amount)}</strong></p>
            {summary.terms.reward_expiry_days ? <p>{t.rewardExpiry}: <strong>{summary.terms.reward_expiry_days} {t.days}</strong></p> : null}
        </section> : null}
        {summary?.referrals?.length ? <section className="panel" aria-label={t.yourInvites}>
            <h2>{t.yourInvites}</h2>
            <ul>{summary.referrals.map((referral, index) => <li key={`${referral.attributed_at}-${index}`}>
                {t.invite} {index + 1}: {statusLabel(referral.status)}
                {referral.rewarded_at && referral.reward_amount > 0 ? ` · ${formatMoney(referral.reward_amount)}` : ''}
            </li>)}</ul>
        </section> : <p className="muted">{t.noInvites}</p>}
        <form onSubmit={apply} className="coupon-row"><label className="field">{t.referral}<input value={value} onChange={(event) => setValue(event.target.value.toUpperCase())} maxLength={20} /></label><button className="primary-button" disabled={busy || !value.trim() || !programActive}>{busy ? t.loading : t.apply}</button></form>
        {status ? <p role="status" className="status-message">{status}</p> : null}
    </section>;
}
