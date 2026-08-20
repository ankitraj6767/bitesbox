'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Switch } from '@/components/ui/form-controls';
import { Tooltip } from '@/components/ui/overlays';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';

/**
 * Pause or resume a coupon. The write is a plain table update — RLS requires
 * `coupon.update`, and the audit trigger records the before/after values.
 */
export function CouponToggle({
    couponId,
    isActive,
    code,
}: {
    couponId: string;
    isActive: boolean;
    code: string;
}) {
    const router = useRouter();
    const [optimistic, setOptimistic] = React.useState(isActive);

    React.useEffect(() => setOptimistic(isActive), [isActive]);

    const mutation = useMutation({
        mutationFn: async (next: boolean) => {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase.from('coupons').update({ is_active: next }).eq('id', couponId);
            if (error) throw error;
            return next;
        },
        onSuccess: (next) => {
            toast.success(next ? `${code} is live again` : `${code} paused`);
            router.refresh();
        },
        onError: (error) => {
            setOptimistic(isActive);
            toast.error(errorMessage(error));
        },
    });

    return (
        <Tooltip content={optimistic ? 'Pause this coupon' : 'Make this coupon live'}>
            <Switch
                checked={optimistic}
                disabled={mutation.isPending}
                onCheckedChange={(next) => {
                    setOptimistic(next);
                    mutation.mutate(next);
                }}
                aria-label={`${optimistic ? 'Pause' : 'Activate'} coupon ${code}`}
            />
        </Tooltip>
    );
}
