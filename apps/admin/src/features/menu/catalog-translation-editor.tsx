'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { Save } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Field, Input, Textarea } from '@/components/ui/form-controls';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';

type TranslationGroup = {
    id: string;
    name_hi: string;
    description_hi: string;
    modifiers: { id: string; name_hi: string; description_hi: string }[];
};

export function CatalogTranslationEditor({
    productId,
    variants,
    groups,
}: {
    productId: string;
    variants: { id: string; name_hi: string; option_group_hi: string }[];
    groups: TranslationGroup[];
}) {
    const router = useRouter();
    const [variantCopy, setVariantCopy] = React.useState(variants);
    const [groupCopy, setGroupCopy] = React.useState(groups);
    const [saving, setSaving] = React.useState(false);

    async function save() {
        setSaving(true);
        try {
            const { error } = await createSupabaseBrowserClient().rpc('save_menu_translations', {
                p_product_id: productId,
                p_translations: { variants: variantCopy, modifier_groups: groupCopy },
            });
            if (error) throw error;
            toast.success('Hindi option translations saved');
            router.refresh();
        } catch (error) {
            toast.error(errorMessage(error));
        } finally {
            setSaving(false);
        }
    }

    return (
        <Card>
            <div className="flex items-center justify-between border-b border-hairline px-5 py-4">
                <div>
                    <h2 className="text-[14px] font-semibold text-ink">Hindi options and add-ons</h2>
                    <p className="mt-1 text-[12px] text-ink-muted">Use reviewed menu copy. Blank values fall back to English.</p>
                </div>
                <Button onClick={() => void save()} loading={saving}><Save /> Save translations</Button>
            </div>
            <CardContent className="space-y-5 pt-5">
                {variantCopy.length ? <section className="space-y-3">
                    <h3 className="text-[12px] font-semibold text-ink-muted">Portions and sizes</h3>
                    {variantCopy.map((variant, index) => <div key={variant.id} className="grid gap-3 md:grid-cols-2">
                        <Field label={`Hindi name · ${index + 1}`}><Input lang="hi" value={variant.name_hi} onChange={(event) => setVariantCopy((items) => items.map((item) => item.id === variant.id ? { ...item, name_hi: event.target.value } : item))} /></Field>
                        <Field label={`Hindi option group · ${index + 1}`}><Input lang="hi" value={variant.option_group_hi} onChange={(event) => setVariantCopy((items) => items.map((item) => item.id === variant.id ? { ...item, option_group_hi: event.target.value } : item))} /></Field>
                    </div>)}
                </section> : null}
                {groupCopy.map((group, groupIndex) => <section key={group.id} className="space-y-3 border-t border-hairline pt-4">
                    <div className="grid gap-3 md:grid-cols-2">
                        <Field label={`Hindi add-on group · ${groupIndex + 1}`}><Input lang="hi" value={group.name_hi} onChange={(event) => setGroupCopy((items) => items.map((item) => item.id === group.id ? { ...item, name_hi: event.target.value } : item))} /></Field>
                        <Field label="Hindi group description"><Textarea lang="hi" value={group.description_hi} onChange={(event) => setGroupCopy((items) => items.map((item) => item.id === group.id ? { ...item, description_hi: event.target.value } : item))} rows={2} /></Field>
                    </div>
                    {group.modifiers.map((modifier, modifierIndex) => <div key={modifier.id} className="grid gap-3 md:grid-cols-2">
                        <Field label={`Hindi add-on · ${groupIndex + 1}.${modifierIndex + 1}`}><Input lang="hi" value={modifier.name_hi} onChange={(event) => setGroupCopy((items) => items.map((item) => item.id === group.id ? { ...item, modifiers: item.modifiers.map((entry) => entry.id === modifier.id ? { ...entry, name_hi: event.target.value } : entry) } : item))} /></Field>
                        <Field label="Hindi add-on description"><Input lang="hi" value={modifier.description_hi} onChange={(event) => setGroupCopy((items) => items.map((item) => item.id === group.id ? { ...item, modifiers: item.modifiers.map((entry) => entry.id === modifier.id ? { ...entry, description_hi: event.target.value } : entry) } : item))} /></Field>
                    </div>)}
                </section>)}
            </CardContent>
        </Card>
    );
}
