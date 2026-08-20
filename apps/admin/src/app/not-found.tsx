import Link from 'next/link';
import { SearchX } from 'lucide-react';
import { Button } from '@/components/ui/button';

export default function NotFound() {
    return (
        <main id="main" className="flex min-h-dvh items-center justify-center px-6">
            <div className="max-w-md text-center">
                <span className="mx-auto flex size-12 items-center justify-center rounded-full bg-surface-muted text-ink-muted">
                    <SearchX className="size-6" aria-hidden />
                </span>
                <h1 className="mt-5 font-display text-xl font-semibold tracking-tight text-ink">
                    We could not find that
                </h1>
                <p className="mt-2 text-[13.5px] leading-relaxed text-ink-muted text-balance">
                    The page may have moved, or the record you are looking for no longer exists.
                </p>
                <Button asChild className="mt-6">
                    <Link href="/overview">Back to overview</Link>
                </Button>
            </div>
        </main>
    );
}
