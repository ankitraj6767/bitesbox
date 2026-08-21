'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { Save } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Field, Input, Select, SelectContent, SelectItem, SelectTrigger, SelectValue, Textarea } from '@/components/ui/form-controls';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';

type DayPart = 'BREAKFAST' | 'LUNCH' | 'SNACKS' | 'DINNER' | 'LATE_NIGHT' | 'ALL_DAY';

export type CategoryEditorInitial = {
    id?: string;
    name: string;
    slug: string;
    short_description: string;
    description: string;
    display_order: number;
    day_part: DayPart;
    accent_color: string;
    is_active: boolean;
    is_featured: boolean;
};

export function CategoryEditor({ initial }: { initial: CategoryEditorInitial }) {
    const router = useRouter();
    const [form, setForm] = React.useState(initial);
    const [saving, setSaving] = React.useState(false);

    const set = <K extends keyof CategoryEditorInitial>(key: K, value: CategoryEditorInitial[K]) =>
        setForm((current) => ({ ...current, [key]: value }));

    async function save(event: React.FormEvent) {
        event.preventDefault();
        setSaving(true);
        try {
            const supabase = createSupabaseBrowserClient();
            const payload = {
                name: form.name.trim(),
                slug: form.slug.trim().toLowerCase(),
                short_description: form.short_description.trim() || null,
                description: form.description.trim() || null,
                display_order: Number(form.display_order) || 0,
                day_part: form.day_part,
                accent_color: form.accent_color.trim() || null,
                is_active: form.is_active,
                is_featured: form.is_featured,
            };
            const result = form.id
                ? await supabase.from('categories').update(payload).eq('id', form.id)
                : await supabase.from('categories').insert(payload);
            if (result.error) throw result.error;

            toast.success(form.id ? 'Category updated' : 'Category created');
            router.push('/menu');
            router.refresh();
        } catch (error) {
            toast.error(errorMessage(error));
        } finally {
            setSaving(false);
        }
    }

    return (
        <form onSubmit={save} className="space-y-4">
            <Card>
                <CardContent className="grid gap-4 p-5 md:grid-cols-2">
                    <Field label="Name" required>
                        <Input value={form.name} onChange={(event) => set('name', event.target.value)} required />
                    </Field>
                    <Field label="Slug" required hint="Lowercase letters, numbers and hyphens only.">
                        <Input value={form.slug} onChange={(event) => set('slug', event.target.value)} pattern="[a-z0-9]+(?:-[a-z0-9]+)*" required />
                    </Field>
                    <Field label="Short description">
                        <Input value={form.short_description} onChange={(event) => set('short_description', event.target.value)} />
                    </Field>
                    <Field label="Accent colour" hint="Optional hex colour, e.g. #FDE7E7.">
                        <Input value={form.accent_color} onChange={(event) => set('accent_color', event.target.value)} placeholder="#FDE7E7" />
                    </Field>
                    <Field label="Description" className="md:col-span-2">
                        <Textarea value={form.description} onChange={(event) => set('description', event.target.value)} />
                    </Field>
                    <Field label="Day part">
                        <Select value={form.day_part} onValueChange={(value) => set('day_part', value as DayPart)}>
                            <SelectTrigger><SelectValue /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="ALL_DAY">All day</SelectItem>
                                <SelectItem value="BREAKFAST">Breakfast</SelectItem>
                                <SelectItem value="LUNCH">Lunch</SelectItem>
                                <SelectItem value="SNACKS">Snacks</SelectItem>
                                <SelectItem value="DINNER">Dinner</SelectItem>
                                <SelectItem value="LATE_NIGHT">Late night</SelectItem>
                            </SelectContent>
                        </Select>
                    </Field>
                    <Field label="Display order">
                        <Input type="number" min="0" step="1" value={String(form.display_order)} onChange={(event) => set('display_order', Number(event.target.value))} />
                    </Field>
                    <label className="flex items-center gap-2 text-[13px] text-ink">
                        <input type="checkbox" checked={form.is_active} onChange={(event) => set('is_active', event.target.checked)} />
                        Visible to customers
                    </label>
                    <label className="flex items-center gap-2 text-[13px] text-ink">
                        <input type="checkbox" checked={form.is_featured} onChange={(event) => set('is_featured', event.target.checked)} />
                        Featured category
                    </label>
                </CardContent>
            </Card>
            <div className="flex justify-end gap-2">
                <Button type="button" variant="secondary" onClick={() => router.push('/menu')}>Cancel</Button>
                <Button type="submit" loading={saving}><Save /> {form.id ? 'Save changes' : 'Create category'}</Button>
            </div>
        </form>
    );
}
