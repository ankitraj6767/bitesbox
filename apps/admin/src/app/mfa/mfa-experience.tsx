'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { ShieldCheck, Smartphone, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/form-controls';
import { InlineNotice } from '@/components/ui/states';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';

type TotpFactor = { id: string; status: string; friendly_name?: string | null };
type Enrollment = { id: string; qrCode: string; secret: string };

export function MfaExperience({ nextPath }: { nextPath: string }) {
    const router = useRouter();
    const supabase = React.useMemo(() => createSupabaseBrowserClient(), []);
    const [factors, setFactors] = React.useState<TotpFactor[]>([]);
    const [currentAal2, setCurrentAal2] = React.useState(false);
    const [loading, setLoading] = React.useState(true);
    const [busy, setBusy] = React.useState(false);
    const [error, setError] = React.useState<string | null>(null);
    const [code, setCode] = React.useState('');
    const [factorId, setFactorId] = React.useState<string | null>(null);
    const [enrollment, setEnrollment] = React.useState<Enrollment | null>(null);
    const [challengeFactorId, setChallengeFactorId] = React.useState<string | null>(null);
    const [verified, setVerified] = React.useState(false);

    const loadSecurityState = React.useCallback(async () => {
        setLoading(true);
        const [{ data: userData, error: userError }, { data: factorData, error: factorError }, { data: aalData }] =
            await Promise.all([
                supabase.auth.getUser(),
                supabase.auth.mfa.listFactors(),
                supabase.auth.mfa.getAuthenticatorAssuranceLevel(),
            ]);
        if (userError || !userData.user) {
            setError('Your staff session has expired. Sign in again to continue.');
            setLoading(false);
            return;
        }
        if (factorError) {
            setError(errorMessage(factorError));
            setLoading(false);
            return;
        }
        const totpFactors = factorData?.totp ?? [];
        setFactors(totpFactors);
        setCurrentAal2(aalData?.currentLevel === 'aal2');
        const verifiedFactor = totpFactors.find((factor) => factor.status === 'verified');
        if (verifiedFactor && aalData?.currentLevel !== 'aal2') {
            setChallengeFactorId(verifiedFactor.id);
        }
        setLoading(false);
    }, [supabase]);

    React.useEffect(() => { void loadSecurityState(); }, [loadSecurityState]);

    const beginEnrollment = async () => {
        setBusy(true);
        setError(null);
        const { data, error: enrollError } = await supabase.auth.mfa.enroll({
            factorType: 'totp',
            friendlyName: 'Bites Box staff authenticator',
        });
        if (enrollError || !data?.totp?.qr_code || !data.totp.secret) {
            setError(enrollError ? errorMessage(enrollError) : 'The authenticator setup could not be started.');
            setBusy(false);
            return;
        }
        setFactorId(data.id);
        setEnrollment({ id: data.id, qrCode: data.totp.qr_code, secret: data.totp.secret });
        setBusy(false);
    };

    const verifyCode = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        const activeFactorId = factorId ?? challengeFactorId;
        if (!activeFactorId) return;
        setBusy(true);
        setError(null);
        const { data: challenge, error: challengeError } = await supabase.auth.mfa.challenge({
            factorId: activeFactorId,
        });
        if (challengeError || !challenge?.id) {
            setError(challengeError ? errorMessage(challengeError) : 'The verification challenge expired. Try again.');
            setBusy(false);
            return;
        }
        const { error: verifyError } = await supabase.auth.mfa.verify({
            factorId: activeFactorId,
            challengeId: challenge.id,
            code: code.replace(/\s/g, ''),
        });
        if (verifyError) {
            setError('That code could not be verified. Check your authenticator clock and try the current code.');
            setBusy(false);
            return;
        }
        const { error: refreshError } = await supabase.auth.refreshSession();
        if (refreshError) {
            setError('The code was accepted, but the secure session could not refresh. Sign in again.');
            setBusy(false);
            return;
        }
        const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
        if (aal?.currentLevel !== 'aal2') {
            setError('Supabase did not issue an AAL2 session. Try again or contact the system owner.');
            setBusy(false);
            return;
        }
        setCurrentAal2(true);
        setVerified(true);
        setCode('');
        setFactorId(null);
        setChallengeFactorId(null);
        setEnrollment(null);
        await loadSecurityState();
        setBusy(false);
    };

    const removeFactor = async (id: string) => {
        const verifiedFactors = factors.filter((factor) => factor.status === 'verified');
        if (verifiedFactors.length < 2) {
            setError('Add and verify a backup authenticator before removing your last verified factor.');
            return;
        }
        setBusy(true);
        setError(null);
        const { error: unenrollError } = await supabase.auth.mfa.unenroll({ factorId: id });
        if (unenrollError) setError(errorMessage(unenrollError));
        else await loadSecurityState();
        setBusy(false);
    };

    const continueToAdmin = () => {
        router.replace(nextPath === '/mfa' ? '/overview' : nextPath);
        router.refresh();
    };

    const challengeRequired = !currentAal2 && challengeFactorId !== null;
    const setupRequired = !currentAal2 && factors.every((factor) => factor.status !== 'verified');

    return (
        <main id="main" className="flex min-h-dvh items-center justify-center bg-surface-muted px-4 py-10">
            <section className="w-full max-w-lg rounded-2xl border border-line bg-white p-6 shadow-sm sm:p-8" aria-labelledby="mfa-title">
                <span className="flex size-12 items-center justify-center rounded-xl bg-brand-50 text-brand-700">
                    <ShieldCheck className="size-6" aria-hidden />
                </span>
                <h1 id="mfa-title" className="mt-5 font-display text-2xl font-semibold tracking-tight text-ink">
                    Secure staff sign-in
                </h1>
                <p className="mt-2 text-sm leading-6 text-ink-muted">
                    Bites Box staff use an authenticator code for access to the operations console and sensitive actions.
                    Your role and branch permissions still apply after verification.
                </p>

                {error ? <div className="mt-5"><InlineNotice tone="critical">{error}</InlineNotice></div> : null}
                {loading ? <p className="mt-6 text-sm text-ink-muted" role="status">Checking your security setup…</p> : null}

                {!loading && challengeRequired ? (
                    <form onSubmit={verifyCode} className="mt-6 space-y-4">
                        <label className="block text-sm font-medium text-ink" htmlFor="totp-code">Authenticator code</label>
                        <Input id="totp-code" autoComplete="one-time-code" inputMode="numeric" pattern="[0-9 ]{6,8}"
                            maxLength={8} value={code} onChange={(event) => setCode(event.target.value)} required />
                        <Button className="w-full" loading={busy} disabled={code.replace(/\s/g, '').length < 6}>
                            Verify and continue
                        </Button>
                        <p className="text-xs leading-5 text-ink-muted">Use the current six-digit code from your authenticator app. Codes expire quickly.</p>
                    </form>
                ) : null}

                {!loading && setupRequired && !enrollment ? (
                    <div className="mt-6 space-y-4">
                        <div className="rounded-xl bg-surface-muted p-4 text-sm leading-6 text-ink-muted">
                            Install an authenticator app, then scan a private QR code. Set this up on a device you control.
                            A second authenticator can be added as a backup after verification.
                        </div>
                        <Button onClick={() => void beginEnrollment()} loading={busy} className="w-full">
                            <Smartphone className="mr-2 size-4" aria-hidden /> Set up authenticator
                        </Button>
                    </div>
                ) : null}

                {!loading && enrollment ? (
                    <div className="mt-6 space-y-4">
                        <div className="flex justify-center rounded-xl border border-line bg-white p-4">
                            {/* Supabase supplies a data URI generated for this factor. */}
                            {/* eslint-disable-next-line @next/next/no-img-element -- QR is a short-lived Auth-generated data URI. */}
                            <img src={enrollment.qrCode} alt="Authenticator setup QR code" className="size-48" />
                        </div>
                        <details className="rounded-xl bg-surface-muted p-4">
                            <summary className="cursor-pointer text-sm font-medium text-ink">Can’t scan the QR code?</summary>
                            <p className="mt-2 break-all font-mono text-xs text-ink-muted" aria-label="Authenticator setup key">{enrollment.secret}</p>
                            <p className="mt-2 text-xs text-ink-muted">Keep this key private. It can create valid sign-in codes.</p>
                        </details>
                        <form onSubmit={verifyCode} className="space-y-3">
                            <label className="block text-sm font-medium text-ink" htmlFor="setup-code">Enter the code shown by your authenticator</label>
                            <Input id="setup-code" autoComplete="one-time-code" inputMode="numeric" pattern="[0-9 ]{6,8}"
                                maxLength={8} value={code} onChange={(event) => setCode(event.target.value)} required />
                            <Button className="w-full" loading={busy} disabled={code.replace(/\s/g, '').length < 6}>Verify authenticator</Button>
                        </form>
                    </div>
                ) : null}

                {!loading && currentAal2 ? (
                    <div className="mt-6 space-y-4">
                        {verified ? <InlineNotice tone="positive">Authenticator verified. Your staff session now has AAL2 assurance.</InlineNotice> : null}
                        <h2 className="text-sm font-semibold text-ink">Verified authenticators</h2>
                        <ul className="space-y-2">
                            {factors.filter((factor) => factor.status === 'verified').map((factor, index) => (
                                <li key={factor.id} className="flex items-center justify-between rounded-xl border border-line px-4 py-3">
                                    <span className="text-sm text-ink">{factor.friendly_name || `Authenticator ${index + 1}`}</span>
                                    {factors.filter((item) => item.status === 'verified').length > 1 ? (
                                        <Button variant="ghost" size="sm" onClick={() => void removeFactor(factor.id)} disabled={busy}
                                            aria-label={`Remove ${factor.friendly_name || 'authenticator'}`}>
                                            <Trash2 className="size-4" aria-hidden />
                                        </Button>
                                    ) : null}
                                </li>
                            ))}
                        </ul>
                        <p className="text-xs leading-5 text-ink-muted">Keep at least one verified authenticator. For a lost or revoked device, ask the system owner to verify identity and reset factors in Supabase Auth; there is no email or support bypass.</p>
                        <div className="flex flex-col gap-2 sm:flex-row">
                            <Button variant="secondary" onClick={() => void beginEnrollment()} loading={busy} className="flex-1">
                                Add backup authenticator
                            </Button>
                            <Button onClick={continueToAdmin} className="flex-1">Continue to console</Button>
                        </div>
                    </div>
                ) : null}
            </section>
        </main>
    );
}
