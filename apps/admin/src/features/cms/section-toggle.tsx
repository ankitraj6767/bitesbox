'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Switch } from '@/components/ui/form-controls';
import { Tooltip } from '@/components/ui/overlays';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';

export function SectionToggle({
    sectionId,
    isActive,
    label,
}: {
    sectionId: string;
    isActive: boolean;
    label: string;
}) {
    const router = useRouter();
    const [optimistic, setOptimistic] = React.useState(isActive);

    React.useEffect(() => setOptimistic(isActive), [isActive]);

    const mutation = useMutation({
        mutationFn: async (next: boolean) => {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase
                .from('cms_sections')
                .update({ is_active: next })
                .eq('id', sectionId);
            if (error) throw error;
            return next;
        },
        onSuccess: (next) => {
            toast.success(next ? `${label} shown on the home screen` : `${label} hidden`);
            router.refresh();
        },
        onError: (error) => {
            setOptimistic(isActive);
            toast.error(errorMessage(error));
        },
    });

    return (
        <Tooltip content={optimistic ? 'Hide from the home screen' : 'Show on the home screen'}>
            <Switch
                checked={optimistic}
                disabled={mutation.isPending}
                onCheckedChange={(next) => {
                    setOptimistic(next);
                    mutation.mutate(next);
                }}
                aria-label={`${optimistic ? 'Hide' : 'Show'} ${label}`}
            />
        </Tooltip>
    );
}
