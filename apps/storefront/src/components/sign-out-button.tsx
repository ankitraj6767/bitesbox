'use client';

import { useRouter } from 'next/navigation';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { messages, type Locale } from '@/lib/site';

export function SignOutButton({ locale }: { locale: Locale }) {
    const router = useRouter();
    const label = messages[locale].signOut;
    return <button className="secondary-button" type="button" onClick={async () => {
        await createSupabaseBrowserClient().auth.signOut();
        router.replace('/'); router.refresh();
    }}>{label}</button>;
}
