'use client';

import * as React from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import type { LiveOperations } from '@bitesbox/shared-types';

export const LIVE_OPS_KEY = ['live-operations'] as const;

/**
 * Live operations feed.
 *
 * Realtime tells us *when* something changed; we then refetch the composed
 * payload rather than patching client state. Order rows, assignments and
 * timeline entries all affect the same board, and re-deriving it server-side is
 * both simpler and impossible to get subtly wrong. A 20 s poll is kept as a
 * safety net for dropped websockets on flaky connections.
 */
export function useLiveOperations(branchId: string | null) {
    const queryClient = useQueryClient();
    const [connected, setConnected] = React.useState(false);
    const [lastEventAt, setLastEventAt] = React.useState<Date | null>(null);

    const query = useQuery<LiveOperations>({
        queryKey: [...LIVE_OPS_KEY, branchId],
        refetchInterval: 20_000,
        staleTime: 5_000,
        queryFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('live_operations', {
                p_branch_id: branchId ?? undefined,
            });
            if (error) throw error;
            return data as unknown as LiveOperations;
        },
    });

    React.useEffect(() => {
        const supabase = createSupabaseBrowserClient();

        // Debounce: a single order transition can fire several table events.
        let timer: ReturnType<typeof setTimeout> | null = null;
        const invalidate = () => {
            setLastEventAt(new Date());
            if (timer) clearTimeout(timer);
            timer = setTimeout(() => {
                void queryClient.invalidateQueries({ queryKey: LIVE_OPS_KEY });
                void queryClient.invalidateQueries({ queryKey: ['sidebar-counts'] });
            }, 400);
        };

        const channel = supabase
            .channel('ops-board')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, invalidate)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'delivery_assignments' }, invalidate)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'delivery_partners' }, invalidate)
            .subscribe((status) => setConnected(status === 'SUBSCRIBED'));

        return () => {
            if (timer) clearTimeout(timer);
            void supabase.removeChannel(channel);
        };
    }, [queryClient]);

    return { ...query, connected, lastEventAt };
}
