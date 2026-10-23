'use client';

import { useState } from 'react';
import { Heart } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';

export function FavoriteToggle({ productId, initial, label }: { productId: string; initial: boolean; label: string }) {
    const [favorite, setFavorite] = useState(initial);
    const [busy, setBusy] = useState(false);
    const router = useRouter();

    async function toggle(event: React.MouseEvent<HTMLButtonElement>) {
        event.preventDefault();
        event.stopPropagation();
        const supabase = createSupabaseBrowserClient();
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
            window.location.assign(`/sign-in?next=${encodeURIComponent(window.location.pathname)}`);
            return;
        }
        setBusy(true);
        const next = !favorite;
        const { error } = await supabase.rpc('set_my_favorite', { p_product_id: productId, p_favorite: next });
        if (!error) {
            setFavorite(next);
            router.refresh();
        }
        setBusy(false);
    }

    return <button type="button" className="favorite-toggle" aria-label={label} aria-pressed={favorite} disabled={busy} onClick={(event) => void toggle(event)}><Heart size={18} fill={favorite ? 'currentColor' : 'none'} /></button>;
}
