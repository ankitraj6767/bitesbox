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

export type CouponEditorInitial = {
    id?: string;
    code: string;
    title: string;
    description: string;
    discount_kind: DiscountKind;
    discount_value: number;
    min_order_amount: number;
    max_discount_amount: number | null;
    starts_at: string;
    ends_at: string | null;
    is_visible: boolean;
    is_active: boolean;
};

export function CouponEditor({ initial }: { initial: CouponEditorInitial }) {
    const router = useRouter();
    const [form, setForm] = React.useState(initial);
    const [saving, setSaving] = React.useState(false);

    const set = <K extends keyof CouponEditorInitial>(key: K, value: CouponEditorInitial[K]) =>
        setForm((current) => ({ ...current, [key]: value }));

    async function save(event: React.FormEvent) {
        event.preventDefault();
        setSaving(true);
        try {
            const supabase = createSupabaseBrowserClient();
            const payload = {
                code: form.code.trim().toUpperCase(),
                title: form.title.trim(),
                description: form.description.trim() || null,
                discount_kind: form.discount_kind,
                discount_value: Number(form.discount_value) || 0,
                min_order_amount: Number(form.min_order_amount) || 0,
                max_discount_amount: form.max_discount_amount === null ? null : Number(form.max_discount_amount) || 0,
                starts_at: new Date(form.starts_at).toISOString(),
                ends_at: form.ends_at ? new Date(form.ends_at).toISOString() : null,
                is_visible: form.is_visible,
                is_active: form.is_active,
            };

            const result = form.id
                ? await supabase.from('coupons').update(payload).eq('id', form.id)
                : await supabase.from('coupons').insert(payload);
            if (result.error) throw result.error;

            toast.success(form.id ? 'Coupon updated' : 'Coupon created');
            router.push('/coupons');
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
                    <Field label="Code" required>
                        <Input value={form.code} onChange={(event) => set('code', event.target.value)} required />
                    </Field>
                    <Field label="Title" required>
                        <Input value={form.title} onChange={(event) => set('title', event.target.value)} required />
                    </Field>
                    <Field label="Description" className="md:col-span-2">
                        <Textarea value={form.description} onChange={(event) => set('description', event.target.value)} />
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
                    <Field label="Minimum order amount">
                        <Input type="number" min="0" step="1" value={String(form.min_order_amount)} onChange={(event) => set('min_order_amount', Number(event.target.value))} />
                    </Field>
                    <Field label="Maximum discount amount">
                        <Input type="number" min="0" step="1" value={form.max_discount_amount == null ? '' : String(form.max_discount_amount)} onChange={(event) => set('max_discount_amount', event.target.value ? Number(event.target.value) : null)} />
                    </Field>
                    <Field label="Starts at" required>
                        <Input type="datetime-local" value={toLocalInput(form.starts_at)} onChange={(event) => set('starts_at', event.target.value)} required />
                    </Field>
                    <Field label="Ends at">
                        <Input type="datetime-local" value={toLocalInput(form.ends_at)} onChange={(event) => set('ends_at', event.target.value || null)} />
                    </Field>
                    <label className="flex items-center gap-2 text-[13px] text-ink md:col-span-2">
                        <input type="checkbox" checked={form.is_visible} onChange={(event) => set('is_visible', event.target.checked)} />
                        Show this coupon to customers
                    </label>
                </CardContent>
            </Card>
            <div className="flex justify-end gap-2">
                <Button type="button" variant="secondary" onClick={() => router.push('/coupons')}>Cancel</Button>
                <Button type="submit" loading={saving}><Save /> {form.id ? 'Save changes' : 'Create coupon'}</Button>
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
