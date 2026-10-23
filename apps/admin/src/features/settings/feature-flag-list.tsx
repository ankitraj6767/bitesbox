'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Field, Input, Switch } from '@/components/ui/form-controls';
import {
    ConfirmDialog,
    Dialog,
    DialogBody,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/overlays';
import { Button } from '@/components/ui/button';
import { updateFeatureFlag } from './settings-actions';
import { Pencil } from 'lucide-react';

export interface FeatureFlagRow {
    key: string;
    label: string;
    description: string | null;
    is_enabled: boolean;
    rollout_percentage: number;
}

/** Flags that stop customers ordering get a confirmation step. */
const HIGH_IMPACT = new Set(['maintenance_mode', 'cod', 'delivery_tracking']);

export function FeatureFlagList({ flags, canEdit }: { flags: FeatureFlagRow[]; canEdit: boolean }) {
    const router = useRouter();
    const [pendingFlag, setPendingFlag] = React.useState<{
        key: string;
        next: boolean;
    } | null>(null);
    const [rolloutFlag, setRolloutFlag] = React.useState<FeatureFlagRow | null>(null);
    const [rollout, setRollout] = React.useState('100');

    const toggle = useMutation({
        mutationFn: async ({ key, next }: { key: string; next: boolean }) => {
            const flag = flags.find((item) => item.key === key);
            if (!flag) throw new Error('This feature flag is no longer available.');
            const result = await updateFeatureFlag({
                key,
                is_enabled: next,
                rollout_percentage: flag.rollout_percentage,
            });
            if (!result.ok) throw new Error(result.message);
            return { key, next };
        },
        onSuccess: ({ key, next }) => {
            toast.success(`${key} ${next ? 'enabled' : 'disabled'}`);
            setPendingFlag(null);
            router.refresh();
        },
        onError: (error) => toast.error(error.message),
    });

    const saveRollout = useMutation({
        mutationFn: async () => {
            if (!rolloutFlag) return;
            const value = Number(rollout);
            if (!Number.isInteger(value) || value < 0 || value > 100)
                throw new Error('Enter a whole percentage from 0 to 100.');
            const result = await updateFeatureFlag({
                key: rolloutFlag.key,
                rollout_percentage: value,
            });
            if (!result.ok) throw new Error(result.message);
            return value;
        },
        onSuccess: (value) => {
            if (value === undefined) return;
            toast.success(`${rolloutFlag?.label ?? 'Feature'} rollout set to ${value}%`);
            setRolloutFlag(null);
            router.refresh();
        },
        onError: (error) => toast.error(error.message),
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
                    description="Toggle a capability or adjust its stable rollout. Flags are code contracts and cannot be deleted from settings."
                />
                <CardContent className="divide-y divide-hairline">
                    {flags.map((flag) => (
                        <div
                            key={flag.key}
                            className="flex items-start justify-between gap-4 py-3 first:pt-0 last:pb-0"
                        >
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

                            <div className="flex items-center gap-2">
                                <Button
                                    variant="ghost"
                                    size="iconSm"
                                    aria-label={`Edit ${flag.label} rollout`}
                                    disabled={!canEdit}
                                    onClick={() => {
                                        setRollout(String(flag.rollout_percentage));
                                        setRolloutFlag(flag);
                                    }}
                                >
                                    <Pencil aria-hidden />
                                </Button>
                                <Switch
                                    checked={flag.is_enabled}
                                    disabled={!canEdit || toggle.isPending}
                                    onCheckedChange={(next) => request(flag.key, next)}
                                    aria-label={`${flag.is_enabled ? 'Disable' : 'Enable'} ${flag.label}`}
                                />
                            </div>
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

            <Dialog open={rolloutFlag !== null} onOpenChange={(open) => !open && setRolloutFlag(null)}>
                <DialogContent size="sm">
                    <DialogHeader>
                        <DialogTitle>Edit rollout</DialogTitle>
                        <DialogDescription>
                            {rolloutFlag?.label} is enabled for a stable percentage of eligible users. Setting it to 0
                            pauses rollout; setting it to 100 applies to everyone eligible.
                        </DialogDescription>
                    </DialogHeader>
                    <DialogBody>
                        <Field label="Rollout percentage" hint="Enter a whole number from 0 to 100.">
                            <Input
                                type="number"
                                min="0"
                                max="100"
                                step="1"
                                value={rollout}
                                onChange={(event) => setRollout(event.target.value)}
                            />
                        </Field>
                    </DialogBody>
                    <DialogFooter>
                        <Button
                            variant="secondary"
                            onClick={() => setRolloutFlag(null)}
                            disabled={saveRollout.isPending}
                        >
                            Cancel
                        </Button>
                        <Button onClick={() => saveRollout.mutate()} loading={saveRollout.isPending}>
                            Save rollout
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    );
}
