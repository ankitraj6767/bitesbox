'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Switch } from '@/components/ui/form-controls';
import { Tooltip } from '@/components/ui/overlays';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';

export function PromotionToggle({
    promotionId,
    isActive,
    name,
}: {
    promotionId: string;
    isActive: boolean;
    name: string;
}) {
    const router = useRouter();
    const [optimistic, setOptimistic] = React.useState(isActive);

    React.useEffect(() => setOptimistic(isActive), [isActive]);

    const mutation = useMutation({
        mutationFn: async (next: boolean) => {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase
                .from('promotions')
                .update({ is_active: next })
                .eq('id', promotionId);
            if (error) throw error;
            return next;
        },
        onSuccess: (next) => {
            toast.success(next ? `${name} is live` : `${name} paused`);
            router.refresh();
        },
        onError: (error) => {
            setOptimistic(isActive);
            toast.error(errorMessage(error));
        },
    });

    return (
        <Tooltip content={optimistic ? 'Pause this promotion' : 'Make this promotion live'}>
            <Switch
                checked={optimistic}
                disabled={mutation.isPending}
                onCheckedChange={(next) => {
                    setOptimistic(next);
                    mutation.mutate(next);
                }}
                aria-label={`${optimistic ? 'Pause' : 'Activate'} promotion ${name}`}
            />
        </Tooltip>
    );
}
