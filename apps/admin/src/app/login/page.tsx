import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import { UtensilsCrossed } from 'lucide-react';
import { getSession } from '@/lib/session';
import { LoginForm } from './login-form';

export const metadata: Metadata = { title: 'Sign in' };

export default async function LoginPage({
    searchParams,
}: {
    searchParams: Promise<{ next?: string; error?: string }>;
}) {
    const [{ next, error }, session] = await Promise.all([searchParams, getSession()]);

    if (session.authenticated) {
        redirect(next && next.startsWith('/') ? next : '/overview');
    }

    return (
        <main id="main" className="grid min-h-dvh lg:grid-cols-[1.05fr_1fr]">
            {/* Brand panel — hidden on small screens so the form stays front and centre. */}
            <section className="relative hidden overflow-hidden bg-brand-700 p-12 text-white lg:flex lg:flex-col lg:justify-between">
                <div
                    aria-hidden
                    className="absolute inset-0 opacity-[0.13]"
                    style={{
                        backgroundImage:
                            'radial-gradient(circle at 18% 22%, #fff 0, transparent 42%), radial-gradient(circle at 82% 78%, #f0a202 0, transparent 46%)',
                    }}
                />

                <div className="relative flex items-center gap-2.5">
                    <span className="flex size-9 items-center justify-center rounded-xl bg-white/15 backdrop-blur-sm">
                        <UtensilsCrossed className="size-5" aria-hidden />
                    </span>
                    <span className="font-display text-lg font-semibold tracking-tight">Bites Box</span>
                </div>

                <div className="relative max-w-md">
                    <h1 className="font-display text-[2.6rem] leading-[1.08] font-semibold tracking-tight text-balance">
                        The operating system behind every order.
                    </h1>
                    <p className="mt-4 text-[15px] leading-relaxed text-white/75">
                        Live orders, kitchen queue, rider dispatch, payments and refunds — one console for the
                        Bakhtiyarpur kitchen.
                    </p>
                </div>

                <dl className="relative grid grid-cols-3 gap-6 border-t border-white/15 pt-6 text-white/80">
                    <div>
                        <dt className="text-[11.5px] font-semibold tracking-wider uppercase">Kitchen</dt>
                        <dd className="mt-1 text-[13px]">Live queue &amp; availability</dd>
                    </div>
                    <div>
                        <dt className="text-[11.5px] font-semibold tracking-wider uppercase">Delivery</dt>
                        <dd className="mt-1 text-[13px]">Dispatch &amp; OTP tracking</dd>
                    </div>
                    <div>
                        <dt className="text-[11.5px] font-semibold tracking-wider uppercase">Finance</dt>
                        <dd className="mt-1 text-[13px]">Payments &amp; refunds</dd>
                    </div>
                </dl>
            </section>

            <section className="flex items-center justify-center px-6 py-12">
                <div className="w-full max-w-sm">
                    <div className="mb-8 lg:hidden">
                        <span className="flex size-10 items-center justify-center rounded-xl bg-brand-600 text-white">
                            <UtensilsCrossed className="size-5" aria-hidden />
                        </span>
                    </div>

                    <h2 className="font-display text-2xl font-semibold tracking-tight text-ink">
                        Sign in to Bites Box
                    </h2>
                    <p className="mt-1.5 text-[13.5px] text-ink-muted">
                        Staff access only. Use the email address your manager set up.
                    </p>

                    <LoginForm nextPath={next} initialError={error} />

                    <p className="mt-8 text-[12.5px] leading-relaxed text-ink-muted">
                        Trouble signing in? Contact your branch manager or email{' '}
                        <a className="font-medium text-brand-600 hover:underline" href="mailto:hello@bitesbox.in">
                            hello@bitesbox.in
                        </a>
                        .
                    </p>
                </div>
            </section>
        </main>
    );
}
