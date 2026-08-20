'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Save, Trash2 } from 'lucide-react';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/ui/overlays';
import {
    Field,
    Input,
    Label,
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
    Switch,
    Textarea,
} from '@/components/ui/form-controls';
import { InlineNotice } from '@/components/ui/states';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import type { FoodType, SpiceLevel } from '@bitesbox/shared-types';

const schema = z.object({
    name: z.string().min(2, 'Give the dish a name').max(120),
    slug: z
        .string()
        .min(2, 'A URL slug is required')
        .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'Lowercase letters, numbers and hyphens only'),
    category_id: z.string().uuid('Choose a category'),
    short_description: z.string().max(180).optional().or(z.literal('')),
    description: z.string().max(2000).optional().or(z.literal('')),
    food_type: z.enum(['VEG', 'NON_VEG', 'EGG', 'VEGAN']),
    spice_level: z.enum(['NONE', 'MILD', 'MEDIUM', 'HOT', 'EXTRA_HOT']),
    base_price: z.coerce.number().min(0, 'Price cannot be negative'),
    compare_price: z.coerce.number().min(0).optional(),
    packaging_charge: z.coerce.number().min(0),
    preparation_minutes: z.coerce.number().int().min(1).max(240),
    serves_count: z.coerce.number().int().min(1).max(20).optional(),
    calories: z.coerce.number().int().min(0).max(10000).optional(),
    tax_category_id: z.string().uuid().optional().or(z.literal('')),
    max_quantity_per_order: z.coerce.number().int().min(1).max(100).optional(),
    is_active: z.boolean(),
    is_featured: z.boolean(),
    is_best_seller: z.boolean(),
    is_new: z.boolean(),
    is_recommended: z.boolean(),
    is_combo: z.boolean(),
    allows_special_instructions: z.boolean(),
    search_keywords: z.string().optional().or(z.literal('')),
    meta_title: z.string().max(160).optional().or(z.literal('')),
    meta_description: z.string().max(320).optional().or(z.literal('')),
});

/**
 * `z.coerce.*` accepts unknown input and yields a number, so the form is typed
 * with both shapes: the raw input the fields hold, and the parsed output that
 * reaches the submit handler.
 */
type ProductFormInput = z.input<typeof schema>;
export type ProductFormValues = z.output<typeof schema>;

export interface ProductFormOption {
    id: string;
    label: string;
}

/**
 * Product editor.
 *
 * Prices are validated here for a fast round trip, but the database is the real
 * authority: `menu.price_update` is required, and every price change is written
 * to the audit log by trigger.
 */
export function ProductForm({
    productId,
    defaults,
    categories,
    taxCategories,
    canDelete,
    canChangePrice,
}: {
    productId?: string;
    defaults: Partial<ProductFormInput>;
    categories: ProductFormOption[];
    taxCategories: ProductFormOption[];
    canDelete: boolean;
    canChangePrice: boolean;
}) {
    const router = useRouter();
    const [deleteOpen, setDeleteOpen] = React.useState(false);

    const {
        register,
        handleSubmit,
        watch,
        setValue,
        formState: { errors, isSubmitting, isDirty },
    } = useForm<ProductFormInput, unknown, ProductFormValues>({
        resolver: zodResolver(schema),
        defaultValues: {
            name: '',
            slug: '',
            category_id: categories[0]?.id ?? '',
            short_description: '',
            description: '',
            food_type: 'VEG',
            spice_level: 'NONE',
            base_price: 0,
            packaging_charge: 0,
            preparation_minutes: 15,
            is_active: true,
            is_featured: false,
            is_best_seller: false,
            is_new: false,
            is_recommended: false,
            is_combo: false,
            allows_special_instructions: true,
            search_keywords: '',
            ...defaults,
        },
    });

    const save = useMutation({
        mutationFn: async (values: ProductFormValues) => {
            const supabase = createSupabaseBrowserClient();

            const payload = {
                name: values.name.trim(),
                slug: values.slug.trim(),
                category_id: values.category_id,
                short_description: values.short_description?.trim() || null,
                description: values.description?.trim() || null,
                food_type: values.food_type as FoodType,
                spice_level: values.spice_level as SpiceLevel,
                base_price: values.base_price,
                compare_price: values.compare_price ?? null,
                packaging_charge: values.packaging_charge,
                preparation_minutes: values.preparation_minutes,
                serves_count: values.serves_count ?? null,
                calories: values.calories ?? null,
                tax_category_id: values.tax_category_id || null,
                max_quantity_per_order: values.max_quantity_per_order ?? null,
                is_active: values.is_active,
                is_featured: values.is_featured,
                is_best_seller: values.is_best_seller,
                is_new: values.is_new,
                is_recommended: values.is_recommended,
                is_combo: values.is_combo,
                allows_special_instructions: values.allows_special_instructions,
                search_keywords: (values.search_keywords ?? '')
                    .split(',')
                    .map((keyword) => keyword.trim())
                    .filter(Boolean),
                meta_title: values.meta_title?.trim() || null,
                meta_description: values.meta_description?.trim() || null,
            };

            if (productId) {
                const { error } = await supabase.from('products').update(payload).eq('id', productId);
                if (error) throw error;
                return productId;
            }

            const { data, error } = await supabase.from('products').insert(payload).select('id').single();
            if (error) throw error;
            return data.id;
        },
        onSuccess: (id) => {
            toast.success(productId ? 'Dish updated' : 'Dish created');
            router.push(`/menu/${id}`);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const remove = useMutation({
        mutationFn: async () => {
            const supabase = createSupabaseBrowserClient();
            // Soft delete: order history keeps its own snapshot, so nothing breaks.
            const { error } = await supabase
                .from('products')
                .update({ deleted_at: new Date().toISOString(), is_active: false })
                .eq('id', productId!);
            if (error) throw error;
        },
        onSuccess: () => {
            toast.success('Dish removed from the menu');
            router.push('/menu');
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const name = watch('name');

    // Suggest a slug while creating, never overwrite one on an existing dish.
    React.useEffect(() => {
        if (productId || !name) return;
        setValue(
            'slug',
            name
                .toLowerCase()
                .normalize('NFD')
                .replace(/[\u0300-\u036f]/g, '')
                .replace(/[^a-z0-9]+/g, '-')
                .replace(/^-+|-+$/g, ''),
            { shouldValidate: false },
        );
    }, [name, productId, setValue]);

    return (
        <form onSubmit={handleSubmit((values) => save.mutate(values))} className="space-y-4" noValidate>
            <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_340px]">
                <div className="space-y-4">
                    <Card>
                        <CardToolbar title="Basics" description="What the customer sees on the menu card" />
                        <CardContent className="space-y-4">
                            <Field label="Dish name" required error={errors.name?.message}>
                                <Input {...register('name')} placeholder="Chicken Dum Biryani" autoFocus />
                            </Field>

                            <Field
                                label="URL slug"
                                required
                                error={errors.slug?.message}
                                hint="Used in deep links and, later, on the ordering website."
                            >
                                <Input {...register('slug')} placeholder="chicken-dum-biryani" className="font-mono" />
                            </Field>

                            <Field
                                label="Short description"
                                error={errors.short_description?.message}
                                hint="One line on the menu card. Keep it appetising."
                            >
                                <Input
                                    {...register('short_description')}
                                    placeholder="Handi-sealed biryani with saffron rice and tender chicken"
                                />
                            </Field>

                            <Field label="Full description" error={errors.description?.message}>
                                <Textarea
                                    {...register('description')}
                                    rows={4}
                                    placeholder="Aged basmati layered with marinated chicken, browned onions, mint and saffron milk…"
                                />
                            </Field>

                            <div className="grid gap-4 sm:grid-cols-2">
                                <Field label="Category" required error={errors.category_id?.message}>
                                    <Select
                                        value={watch('category_id')}
                                        onValueChange={(value) => setValue('category_id', value, { shouldDirty: true })}
                                    >
                                        <SelectTrigger>
                                            <SelectValue placeholder="Choose a category" />
                                        </SelectTrigger>
                                        <SelectContent>
                                            {categories.map((category) => (
                                                <SelectItem key={category.id} value={category.id}>
                                                    {category.label}
                                                </SelectItem>
                                            ))}
                                        </SelectContent>
                                    </Select>
                                </Field>

                                <Field label="Food type" required>
                                    <Select
                                        value={watch('food_type')}
                                        onValueChange={(value) =>
                                            setValue('food_type', value as FoodType, { shouldDirty: true })
                                        }
                                    >
                                        <SelectTrigger>
                                            <SelectValue />
                                        </SelectTrigger>
                                        <SelectContent>
                                            <SelectItem value="VEG">Vegetarian</SelectItem>
                                            <SelectItem value="NON_VEG">Non-vegetarian</SelectItem>
                                            <SelectItem value="EGG">Contains egg</SelectItem>
                                            <SelectItem value="VEGAN">Vegan</SelectItem>
                                        </SelectContent>
                                    </Select>
                                </Field>
                            </div>

                            <Field label="Search keywords" hint="Comma separated. Include common misspellings.">
                                <Input
                                    {...register('search_keywords')}
                                    placeholder="biryani, biriyani, dum biryani, handi"
                                />
                            </Field>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardToolbar
                            title="Pricing"
                            description={
                                canChangePrice
                                    ? 'Prices include GST. Every change is written to the audit log.'
                                    : 'You do not have permission to change prices.'
                            }
                        />
                        <CardContent className="grid gap-4 sm:grid-cols-2">
                            <Field label="Price" required error={errors.base_price?.message}>
                                <Input
                                    type="number"
                                    step="1"
                                    min={0}
                                    disabled={!canChangePrice}
                                    className="tnum"
                                    {...register('base_price')}
                                />
                            </Field>

                            <Field
                                label="Compare-at price"
                                error={errors.compare_price?.message}
                                hint="Shown struck through. Leave empty for no discount badge."
                            >
                                <Input
                                    type="number"
                                    step="1"
                                    min={0}
                                    disabled={!canChangePrice}
                                    className="tnum"
                                    {...register('compare_price')}
                                />
                            </Field>

                            <Field label="Packaging charge" error={errors.packaging_charge?.message}>
                                <Input
                                    type="number"
                                    step="1"
                                    min={0}
                                    disabled={!canChangePrice}
                                    className="tnum"
                                    {...register('packaging_charge')}
                                />
                            </Field>

                            <Field label="Tax category">
                                <Select
                                    value={watch('tax_category_id') ?? ''}
                                    onValueChange={(value) =>
                                        setValue('tax_category_id', value, { shouldDirty: true })
                                    }
                                >
                                    <SelectTrigger>
                                        <SelectValue placeholder="Default GST" />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {taxCategories.map((tax) => (
                                            <SelectItem key={tax.id} value={tax.id}>
                                                {tax.label}
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </Field>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardToolbar title="Kitchen & nutrition" />
                        <CardContent className="grid gap-4 sm:grid-cols-2">
                            <Field
                                label="Preparation time (minutes)"
                                required
                                error={errors.preparation_minutes?.message}
                                hint="Feeds the delivery promise shown to customers."
                            >
                                <Input type="number" min={1} max={240} className="tnum" {...register('preparation_minutes')} />
                            </Field>

                            <Field label="Spice level">
                                <Select
                                    value={watch('spice_level')}
                                    onValueChange={(value) =>
                                        setValue('spice_level', value as SpiceLevel, { shouldDirty: true })
                                    }
                                >
                                    <SelectTrigger>
                                        <SelectValue />
                                    </SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="NONE">Not spicy</SelectItem>
                                        <SelectItem value="MILD">Mild</SelectItem>
                                        <SelectItem value="MEDIUM">Medium</SelectItem>
                                        <SelectItem value="HOT">Hot</SelectItem>
                                        <SelectItem value="EXTRA_HOT">Extra hot</SelectItem>
                                    </SelectContent>
                                </Select>
                            </Field>

                            <Field label="Serves" error={errors.serves_count?.message}>
                                <Input type="number" min={1} max={20} className="tnum" {...register('serves_count')} />
                            </Field>

                            <Field label="Calories" error={errors.calories?.message}>
                                <Input type="number" min={0} className="tnum" {...register('calories')} />
                            </Field>

                            <Field
                                label="Maximum per order"
                                error={errors.max_quantity_per_order?.message}
                                hint="Protects the kitchen from unrealistic orders."
                            >
                                <Input type="number" min={1} max={100} className="tnum" {...register('max_quantity_per_order')} />
                            </Field>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardToolbar
                            title="Search & web"
                            description="Used by in-app search today and the ordering website later."
                        />
                        <CardContent className="space-y-4">
                            <Field label="Meta title" error={errors.meta_title?.message}>
                                <Input {...register('meta_title')} placeholder="Chicken Dum Biryani | Bites Box" />
                            </Field>
                            <Field label="Meta description" error={errors.meta_description?.message}>
                                <Textarea
                                    {...register('meta_description')}
                                    rows={2}
                                    placeholder="Order authentic chicken dum biryani in Bakhtiyarpur, cooked in sealed handis."
                                />
                            </Field>
                        </CardContent>
                    </Card>
                </div>

                <div className="space-y-4">
                    <Card>
                        <CardToolbar title="Visibility" />
                        <CardContent className="space-y-3">
                            <ToggleRow
                                id="is_active"
                                label="On the menu"
                                hint="Turn off to hide the dish without deleting it."
                                checked={watch('is_active')}
                                onChange={(value) => setValue('is_active', value, { shouldDirty: true })}
                            />
                            <ToggleRow
                                id="allows_special_instructions"
                                label="Allow cooking instructions"
                                hint="Lets the customer add a note for this dish."
                                checked={watch('allows_special_instructions')}
                                onChange={(value) => setValue('allows_special_instructions', value, { shouldDirty: true })}
                            />
                        </CardContent>
                    </Card>

                    <Card>
                        <CardToolbar title="Merchandising" description="Where this dish can appear on the home screen" />
                        <CardContent className="space-y-3">
                            <ToggleRow
                                id="is_best_seller"
                                label="Best seller"
                                checked={watch('is_best_seller')}
                                onChange={(value) => setValue('is_best_seller', value, { shouldDirty: true })}
                            />
                            <ToggleRow
                                id="is_new"
                                label="New arrival"
                                checked={watch('is_new')}
                                onChange={(value) => setValue('is_new', value, { shouldDirty: true })}
                            />
                            <ToggleRow
                                id="is_recommended"
                                label="Recommended"
                                checked={watch('is_recommended')}
                                onChange={(value) => setValue('is_recommended', value, { shouldDirty: true })}
                            />
                            <ToggleRow
                                id="is_featured"
                                label="Featured"
                                checked={watch('is_featured')}
                                onChange={(value) => setValue('is_featured', value, { shouldDirty: true })}
                            />
                            <ToggleRow
                                id="is_combo"
                                label="Combo meal"
                                hint="Appears in the combos rail."
                                checked={watch('is_combo')}
                                onChange={(value) => setValue('is_combo', value, { shouldDirty: true })}
                            />
                        </CardContent>
                    </Card>

                    {productId ? (
                        <InlineNotice tone="info">
                            Variants, add-ons and images are managed from the dish page once saved. Availability is
                            controlled from the Availability screen so the kitchen can change it mid-service.
                        </InlineNotice>
                    ) : null}
                </div>
            </div>

            <div className="sticky bottom-0 -mx-4 flex items-center justify-between gap-3 border-t border-hairline bg-canvas/90 px-4 py-3 backdrop-blur-md lg:-mx-6 lg:px-6">
                <p className="text-[12.5px] text-ink-muted">
                    {isDirty ? 'You have unsaved changes.' : 'Everything is saved.'}
                </p>

                <div className="flex items-center gap-2">
                    {productId && canDelete ? (
                        <Button type="button" variant="outlineDestructive" onClick={() => setDeleteOpen(true)}>
                            <Trash2 />
                            Remove
                        </Button>
                    ) : null}
                    <Button type="button" variant="secondary" onClick={() => router.back()}>
                        Cancel
                    </Button>
                    <Button type="submit" loading={isSubmitting || save.isPending}>
                        <Save />
                        {productId ? 'Save changes' : 'Create dish'}
                    </Button>
                </div>
            </div>

            <ConfirmDialog
                open={deleteOpen}
                onOpenChange={setDeleteOpen}
                title="Remove this dish from the menu?"
                description="It disappears from the customer app immediately. Past orders keep their own snapshot, so order history and invoices are unaffected."
                confirmLabel="Remove dish"
                destructive
                confirmText="REMOVE"
                loading={remove.isPending}
                onConfirm={() => remove.mutate()}
            />
        </form>
    );
}

function ToggleRow({
    id,
    label,
    hint,
    checked,
    onChange,
}: {
    id: string;
    label: string;
    hint?: string;
    checked: boolean;
    onChange: (value: boolean) => void;
}) {
    return (
        <div className="flex items-start justify-between gap-4">
            <div className="min-w-0">
                <Label htmlFor={id} className="text-[13px]">
                    {label}
                </Label>
                {hint ? <p className="mt-0.5 text-[12px] text-ink-muted">{hint}</p> : null}
            </div>
            <Switch id={id} checked={checked} onCheckedChange={onChange} aria-label={label} />
        </div>
    );
}
