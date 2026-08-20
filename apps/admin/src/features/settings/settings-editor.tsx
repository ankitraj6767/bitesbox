'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Save } from 'lucide-react';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Field, Input, Switch } from '@/components/ui/form-controls';
import { ConfirmDialog } from '@/components/ui/overlays';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import { humanise } from '@/lib/utils';
import type { Json } from '@bitesbox/shared-types';

export interface SettingRow {
    key: string;
    value: Json;
    value_type: string;
    group: string;
    label: string;
    description: string | null;
    is_public: boolean;
}

/**
 * Settings editor.
 *
 * Values are stored as JSONB, so we round-trip through the declared value_type.
 * Every write is captured by the settings_history trigger and the audit log, so
 * "who changed the COD limit" is always answerable.
 */
export function SettingsEditor({
    group,
    title,
    description,
    settings,
    canEdit,
    requireTypedConfirmation = false,
}: {
    group: string;
    title: string;
    description?: string;
    settings: SettingRow[];
    canEdit: boolean;
    requireTypedConfirmation?: boolean;
}) {
    const router = useRouter();
    const [draft, setDraft] = React.useState<Record<string, string>>(() => initialDraft(settings));
    const [confirmOpen, setConfirmOpen] = React.useState(false);

    React.useEffect(() => setDraft(initialDraft(settings)), [settings]);

    const dirtyKeys = React.useMemo(
        () =>
            settings
                .filter((setting) => draft[setting.key] !== toInput(setting.value))
                .map((setting) => setting.key),
        [draft, settings],
    );

    const save = useMutation({
        mutationFn: async () => {
            const supabase = createSupabaseBrowserClient();

            for (const key of dirtyKeys) {
                const setting = settings.find((item) => item.key === key)!;
                const { error } = await supabase
                    .from('settings')
                    .update({ value: fromInput(draft[key] ?? '', setting.value_type) })
                    .eq('key', key);
                if (error) throw error;
            }

            return dirtyKeys.length;
        },
        onSuccess: (count) => {
            toast.success(`${count} setting${count === 1 ? '' : 's'} saved`);
            setConfirmOpen(false);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    if (settings.length === 0) return null;

    return (
        <>
            <Card>
                <CardToolbar
                    title={title}
                    description={description}
                    action={
                        canEdit && dirtyKeys.length > 0 ? (
                            <Button
                                size="sm"
                                loading={save.isPending}
                                onClick={() => (requireTypedConfirmation ? setConfirmOpen(true) : save.mutate())}
                            >
                                <Save />
                                Save {dirtyKeys.length} change{dirtyKeys.length === 1 ? '' : 's'}
                            </Button>
                        ) : null
                    }
                />
                <CardContent className="space-y-4">
                    {settings.map((setting) => {
                        const dirty = dirtyKeys.includes(setting.key);

                        if (setting.value_type === 'boolean') {
                            return (
                                <div
                                    key={setting.key}
                                    className="flex items-start justify-between gap-4 border-b border-hairline pb-3 last:border-0 last:pb-0"
                                >
                                    <div className="min-w-0">
                                        <p className="flex items-center gap-2 text-[13.5px] font-medium text-ink">
                                            {setting.label}
                                            {dirty ? (
                                                <Badge tone="caution" className="px-1.5 py-0">
                                                    Unsaved
                                                </Badge>
                                            ) : null}
                                        </p>
                                        {setting.description ? (
                                            <p className="mt-0.5 text-[12.5px] leading-relaxed text-ink-muted">
                                                {setting.description}
                                            </p>
                                        ) : null}
                                        <p className="mt-1 font-mono text-[11px] text-ink-muted/70">{setting.key}</p>
                                    </div>
                                    <Switch
                                        checked={draft[setting.key] === 'true'}
                                        disabled={!canEdit}
                                        onCheckedChange={(checked) =>
                                            setDraft((current) => ({ ...current, [setting.key]: String(checked) }))
                                        }
                                        aria-label={setting.label}
                                    />
                                </div>
                            );
                        }

                        return (
                            <Field
                                key={setting.key}
                                label={
                                    <span className="flex items-center gap-2">
                                        {setting.label}
                                        {dirty ? (
                                            <Badge tone="caution" className="px-1.5 py-0">
                                                Unsaved
                                            </Badge>
                                        ) : null}
                                    </span>
                                }
                                hint={setting.description ?? setting.key}
                            >
                                <Input
                                    value={draft[setting.key] ?? ''}
                                    disabled={!canEdit}
                                    inputMode={
                                        setting.value_type === 'number' || setting.value_type === 'money'
                                            ? 'decimal'
                                            : undefined
                                    }
                                    onChange={(event) =>
                                        setDraft((current) => ({ ...current, [setting.key]: event.target.value }))
                                    }
                                    className={
                                        setting.value_type === 'number' || setting.value_type === 'money' ? 'tnum' : ''
                                    }
                                />
                            </Field>
                        );
                    })}
                </CardContent>
            </Card>

            <ConfirmDialog
                open={confirmOpen}
                onOpenChange={setConfirmOpen}
                title={`Change ${humanise(group)} settings?`}
                description="These settings affect live ordering immediately. The change is recorded in the audit log."
                confirmLabel="Apply changes"
                confirmText="CONFIRM"
                destructive
                loading={save.isPending}
                onConfirm={() => save.mutate()}
            />
        </>
    );
}

function initialDraft(settings: SettingRow[]): Record<string, string> {
    return Object.fromEntries(settings.map((setting) => [setting.key, toInput(setting.value)]));
}

/** JSONB → form value. */
function toInput(value: Json): string {
    if (value === null || value === undefined) return '';
    if (typeof value === 'string') return value;
    if (typeof value === 'boolean' || typeof value === 'number') return String(value);
    return JSON.stringify(value);
}

/** Form value → JSONB, respecting the declared type. */
function fromInput(input: string, valueType: string): Json {
    switch (valueType) {
        case 'boolean':
            return input === 'true';
        case 'number':
        case 'money':
            return Number(input) || 0;
        case 'json':
        case 'array':
            try {
                return JSON.parse(input);
            } catch {
                return input;
            }
        default:
            return input;
    }
}
