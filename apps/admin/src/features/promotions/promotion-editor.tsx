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

type DiscountKind = 'PERCENTAGE' | 'FLAT' | 'FREE_DELIVERY' | 'PRODUCT_DISCOUNT' | 'CATEGORY_DISCOUNT' | 'BUY_X_GET_Y';
type PromotionTrigger = 'AUTOMATIC' | 'COUPON_CODE';

export type PromotionEditorInitial = {
    id?: string;
    name: string;
    headline: string;
    description: string;
    badge_text: string;
    trigger: PromotionTrigger;
    discount_kind: DiscountKind;
    discount_value: number;
    max_discount_amount: number | null;
    min_order_amount: number;
    priority: number;
    stacks_with_coupon: boolean;
    starts_at: string;
    ends_at: string | null;
};

export function PromotionEditor({ initial }: { initial: PromotionEditorInitial }) {
    const router = useRouter();
    const [form, setForm] = React.useState(initial);
    const [saving, setSaving] = React.useState(false);

    const set = <K extends keyof PromotionEditorInitial>(key: K, value: PromotionEditorInitial[K]) =>
        setForm((current) => ({ ...current, [key]: value }));

    async function save(event: React.FormEvent) {
        event.preventDefault();
        setSaving(true);
        try {
            const supabase = createSupabaseBrowserClient();
            const payload = {
                name: form.name.trim(),
                headline: form.headline.trim(),
                description: form.description.trim() || null,
                badge_text: form.badge_text.trim() || null,
                trigger: form.trigger,
                discount_kind: form.discount_kind,
                discount_value: Number(form.discount_value) || 0,
                max_discount_amount: form.max_discount_amount === null ? null : Number(form.max_discount_amount) || 0,
                min_order_amount: Number(form.min_order_amount) || 0,
                priority: Number(form.priority) || 100,
                stacks_with_coupon: form.stacks_with_coupon,
                starts_at: new Date(form.starts_at).toISOString(),
                ends_at: form.ends_at ? new Date(form.ends_at).toISOString() : null,
            };

            const result = form.id
                ? await supabase.from('promotions').update(payload).eq('id', form.id)
                : await supabase.from('promotions').insert(payload);
            if (result.error) throw result.error;

            toast.success(form.id ? 'Promotion updated' : 'Promotion created');
            router.push('/promotions');
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
                    <Field label="Internal name" required>
                        <Input value={form.name} onChange={(event) => set('name', event.target.value)} required />
                    </Field>
                    <Field label="Customer headline" required>
                        <Input value={form.headline} onChange={(event) => set('headline', event.target.value)} required />
                    </Field>
                    <Field label="Description">
                        <Textarea value={form.description} onChange={(event) => set('description', event.target.value)} />
                    </Field>
                    <Field label="Badge text">
                        <Input value={form.badge_text} onChange={(event) => set('badge_text', event.target.value)} placeholder="e.g. 20% OFF" />
                    </Field>
                    <Field label="Trigger" required>
                        <Select value={form.trigger} onValueChange={(value) => set('trigger', value as PromotionTrigger)}>
                            <SelectTrigger><SelectValue /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="AUTOMATIC">Automatic</SelectItem>
                                <SelectItem value="COUPON_CODE">Coupon code</SelectItem>
                            </SelectContent>
                        </Select>
                    </Field>
                    <Field label="Discount kind" required>
                        <Select value={form.discount_kind} onValueChange={(value) => set('discount_kind', value as DiscountKind)}>
                            <SelectTrigger><SelectValue /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="PERCENTAGE">Percentage</SelectItem>
                                <SelectItem value="FLAT">Flat amount</SelectItem>
                                <SelectItem value="FREE_DELIVERY">Free delivery</SelectItem>
                                <SelectItem value="PRODUCT_DISCOUNT">Product discount</SelectItem>
                                <SelectItem value="CATEGORY_DISCOUNT">Category discount</SelectItem>
                                <SelectItem value="BUY_X_GET_Y">Buy X get Y</SelectItem>
                            </SelectContent>
                        </Select>
                    </Field>
                    <Field label="Discount value">
                        <Input type="number" min="0" step="0.01" value={String(form.discount_value)} onChange={(event) => set('discount_value', Number(event.target.value))} />
                    </Field>
                    <Field label="Maximum discount amount">
                        <Input type="number" min="0" step="1" value={form.max_discount_amount == null ? '' : String(form.max_discount_amount)} onChange={(event) => set('max_discount_amount', event.target.value ? Number(event.target.value) : null)} />
                    </Field>
                    <Field label="Minimum order amount">
                        <Input type="number" min="0" step="1" value={String(form.min_order_amount)} onChange={(event) => set('min_order_amount', Number(event.target.value))} />
                    </Field>
                    <Field label="Priority">
                        <Input type="number" min="0" step="1" value={String(form.priority)} onChange={(event) => set('priority', Number(event.target.value))} />
                    </Field>
                    <Field label="Starts at" required>
                        <Input type="datetime-local" value={toLocalInput(form.starts_at)} onChange={(event) => set('starts_at', event.target.value)} required />
                    </Field>
                    <Field label="Ends at">
                        <Input type="datetime-local" value={toLocalInput(form.ends_at)} onChange={(event) => set('ends_at', event.target.value || null)} />
                    </Field>
                    <label className="flex items-center gap-2 text-[13px] text-ink md:col-span-2">
                        <input type="checkbox" checked={form.stacks_with_coupon} onChange={(event) => set('stacks_with_coupon', event.target.checked)} />
                        Allow this promotion to stack with coupon discounts
                    </label>
                </CardContent>
            </Card>
            <div className="flex justify-end gap-2">
                <Button type="button" variant="secondary" onClick={() => router.push('/promotions')}>Cancel</Button>
                <Button type="submit" loading={saving}><Save /> {form.id ? 'Save changes' : 'Create promotion'}</Button>
            </div>
        </form>
    );
}

function toLocalInput(value: string | null): string {
    if (!value) return '';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value.slice(0, 16);
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
