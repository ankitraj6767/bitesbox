import type { Metadata } from 'next';
import Link from 'next/link';
import { ShieldAlert } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { humanise } from '@/lib/utils';

export const metadata: Metadata = { title: 'No access' };

export default async function NoAccessPage({
    searchParams,
}: {
    searchParams: Promise<{ permission?: string; reason?: string }>;
}) {
    const { permission, reason } = await searchParams;

    const blocked = reason === 'blocked';

    return (
        <main id="main" className="flex min-h-dvh items-center justify-center px-6">
            <div className="w-full max-w-md text-center">
                <span className="mx-auto flex size-12 items-center justify-center rounded-full bg-caution-soft text-caution">
                    <ShieldAlert className="size-6" aria-hidden />
                </span>

                <h1 className="mt-5 font-display text-xl font-semibold tracking-tight text-ink">
                    {blocked ? 'This account is not active' : 'You do not have access to this area'}
                </h1>

                <p className="mt-2 text-[13.5px] leading-relaxed text-ink-muted text-balance">
                    {blocked ? (
                        <>Your account has been suspended or blocked. Please speak to your branch manager.</>
                    ) : permission ? (
                        <>
                            This screen needs the <span className="font-medium text-ink">{humanise(permission)}</span>{' '}
                            permission, which your role does not include. Ask an owner or administrator to grant it.
                        </>
                    ) : (
                        <>Your role does not include access to this screen.</>
                    )}
                </p>

                <div className="mt-6 flex items-center justify-center gap-2">
                    <Button asChild variant="secondary">
                        <Link href="/overview">Back to overview</Link>
                    </Button>
                    <form action="/auth/signout" method="post">
                        <Button type="submit" variant="ghost">
                            Sign out
                        </Button>
                    </form>
                </div>
            </div>
        </main>
    );
}
