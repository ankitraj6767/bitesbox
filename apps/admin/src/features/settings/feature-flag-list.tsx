'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Switch } from '@/components/ui/form-controls';
import { ConfirmDialog } from '@/components/ui/overlays';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';

export interface FeatureFlagRow {
    key: string;
    label: string;
    description: string | null;
    is_enabled: boolean;
    rollout_percentage: number;
}

/** Flags that stop customers ordering get a confirmation step. */
const HIGH_IMPACT = new Set(['maintenance_mode', 'cod', 'delivery_tracking']);

export function FeatureFlagList({
    flags,
    canEdit,
}: {
    flags: FeatureFlagRow[];
    canEdit: boolean;
}) {
    const router = useRouter();
    const [pendingFlag, setPendingFlag] = React.useState<{ key: string; next: boolean } | null>(null);

    const toggle = useMutation({
        mutationFn: async ({ key, next }: { key: string; next: boolean }) => {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase
                .from('feature_flags')
                .update({ is_enabled: next })
                .eq('key', key);
            if (error) throw error;
            return { key, next };
        },
        onSuccess: ({ key, next }) => {
            toast.success(`${key} ${next ? 'enabled' : 'disabled'}`);
            setPendingFlag(null);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const request = (key: string, next: boolean) => {
        if (HIGH_IMPACT.has(key)) {
            setPendingFlag({ key, next });
            return;
        }
        toggle.mutate({ key, next });
    };

    return (
        <>
            <Card>
                <CardToolbar
                    title="Feature flags"
                    description="Turn capabilities on and off without a deploy. Changes apply on the next request."
                />
                <CardContent className="divide-y divide-hairline">
                    {flags.map((flag) => (
                        <div key={flag.key} className="flex items-start justify-between gap-4 py-3 first:pt-0 last:pb-0">
                            <div className="min-w-0">
                                <p className="flex flex-wrap items-center gap-2 text-[13.5px] font-medium text-ink">
                                    {flag.label}
                                    {HIGH_IMPACT.has(flag.key) ? (
                                        <Badge tone="caution" className="px-1.5 py-0">
                                            High impact
                                        </Badge>
                                    ) : null}
                                    {flag.rollout_percentage < 100 ? (
                                        <Badge tone="info" className="px-1.5 py-0">
                                            {flag.rollout_percentage}% rollout
                                        </Badge>
                                    ) : null}
                                </p>
                                {flag.description ? (
                                    <p className="mt-0.5 text-[12.5px] leading-relaxed text-ink-muted">
                                        {flag.description}
                                    </p>
                                ) : null}
                                <p className="mt-1 font-mono text-[11px] text-ink-muted/70">{flag.key}</p>
                            </div>

                            <Switch
                                checked={flag.is_enabled}
                                disabled={!canEdit || toggle.isPending}
                                onCheckedChange={(next) => request(flag.key, next)}
                                aria-label={`${flag.is_enabled ? 'Disable' : 'Enable'} ${flag.label}`}
                            />
                        </div>
                    ))}
                </CardContent>
            </Card>

            <ConfirmDialog
                open={pendingFlag !== null}
                onOpenChange={(open) => !open && setPendingFlag(null)}
                title={
                    pendingFlag?.key === 'maintenance_mode' && pendingFlag.next
                        ? 'Put Bites Box into maintenance mode?'
                        : `${pendingFlag?.next ? 'Enable' : 'Disable'} ${pendingFlag?.key}?`
                }
                description={
                    pendingFlag?.key === 'maintenance_mode' && pendingFlag.next
                        ? 'Customers will not be able to place any orders until you turn this off. Orders already in the kitchen are unaffected.'
                        : 'This changes what customers can do in the app immediately.'
                }
                confirmLabel={pendingFlag?.next ? 'Enable' : 'Disable'}
                destructive={pendingFlag?.key === 'maintenance_mode' && pendingFlag.next}
                confirmText={pendingFlag?.key === 'maintenance_mode' && pendingFlag.next ? 'MAINTENANCE' : undefined}
                loading={toggle.isPending}
                onConfirm={() => {
          if (pendingFlag) toggle.mutate(pendingFlag);
        }}
            />
        </>
    );
}
