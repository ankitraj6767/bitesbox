import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { ProductForm } from '@/features/menu/product-form';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { money, humanise } from '@/lib/utils';

export const dynamic = 'force-dynamic';

export async function generateMetadata({
    params,
}: {
    params: Promise<{ id: string }>;
}): Promise<Metadata> {
    const { id } = await params;
    if (id === 'new') return { title: 'New dish' };

    const supabase = await createSupabaseServerClient();
    const { data } = await supabase.from('products').select('name').eq('id', id).maybeSingle();
    return { title: data?.name ?? 'Dish' };
}

export default async function ProductEditorPage({ params }: { params: Promise<{ id: string }> }) {
    const [session, { id }] = await Promise.all([
        requirePermission([PERMISSIONS.MENU_CREATE, PERMISSIONS.MENU_UPDATE]),
        params,
    ]);

    const isNew = id === 'new';
    const supabase = await createSupabaseServerClient();

    const [productResult, categoriesResult, taxResult] = await Promise.all([
        isNew
            ? Promise.resolve({ data: null, error: null })
            : supabase
                .from('products')
                .select(
                    `id, name, slug, category_id, short_description, description, food_type, spice_level,
             base_price, compare_price, packaging_charge, preparation_minutes, serves_count,
             calories, tax_category_id, max_quantity_per_order, is_active, is_featured,
             is_best_seller, is_new, is_recommended, is_combo, allows_special_instructions,
             search_keywords, meta_title, meta_description,
             product_variants(id, name, option_group, price, availability, is_default, is_active),
             product_modifier_groups(id, modifier_group_id, display_order, modifier_groups(name, selection, is_required))`,
                )
                .eq('id', id)
                .is('deleted_at', null)
                .maybeSingle(),
        supabase
            .from('categories')
            .select('id, name')
            .is('deleted_at', null)
            .order('display_order'),
        supabase
            .from('tax_categories')
            .select('id, code, name, rate')
            .is('deleted_at', null)
            .order('code'),
    ]);

    if (!isNew && (productResult.error || !productResult.data)) notFound();

    const product = productResult.data;
    const categories = (categoriesResult.data ?? []).map((category) => ({
        id: category.id,
        label: category.name,
    }));
    const taxCategories = (taxResult.data ?? []).map((tax) => ({
        id: tax.id,
        label: `${tax.name} (${(Number(tax.rate) * 100).toFixed(0)}%)`,
    }));

    return (
        <>
            <PageHeader
                breadcrumbs={[
                    { label: 'Menu', href: '/menu' },
                    { label: isNew ? 'New dish' : (product?.name ?? 'Dish') },
                ]}
                title={isNew ? 'Add a dish' : (product?.name ?? 'Dish')}
                description={
                    isNew
                        ? 'Create a dish, then add its options and add-ons.'
                        : 'Changes appear in the customer app immediately.'
                }
            />

            <ProductForm
                productId={isNew ? undefined : id}
                canDelete={hasPermission(session, PERMISSIONS.MENU_DELETE)}
                canChangePrice={hasPermission(session, PERMISSIONS.MENU_PRICE_UPDATE)}
                categories={categories}
                taxCategories={taxCategories}
                defaults={
                    product
                        ? {
                            name: product.name,
                            slug: product.slug,
                            category_id: product.category_id,
                            short_description: product.short_description ?? '',
                            description: product.description ?? '',
                            food_type: product.food_type,
                            spice_level: product.spice_level,
                            base_price: Number(product.base_price),
                            compare_price: product.compare_price ? Number(product.compare_price) : undefined,
                            packaging_charge: Number(product.packaging_charge),
                            preparation_minutes: product.preparation_minutes,
                            serves_count: product.serves_count ?? undefined,
                            calories: product.calories ?? undefined,
                            tax_category_id: product.tax_category_id ?? '',
                            max_quantity_per_order: product.max_quantity_per_order ?? undefined,
                            is_active: product.is_active,
                            is_featured: product.is_featured,
                            is_best_seller: product.is_best_seller,
                            is_new: product.is_new,
                            is_recommended: product.is_recommended,
                            is_combo: product.is_combo,
                            allows_special_instructions: product.allows_special_instructions,
                            search_keywords: (product.search_keywords ?? []).join(', '),
                            meta_title: product.meta_title ?? '',
                            meta_description: product.meta_description ?? '',
                        }
                        : {}
                }
            />

            {product ? (
                <div className="mt-4 grid gap-4 lg:grid-cols-2">
                    <Card>
                        <CardToolbar
                            title="Options"
                            description="Sizes and portions the customer chooses between"
                        />
                        <CardContent className="p-0">
                            {(product.product_variants ?? []).length === 0 ? (
                                <p className="px-5 py-6 text-[13px] text-ink-muted">
                                    No options — this dish is sold at a single size.
                                </p>
                            ) : (
                                <ul className="divide-y divide-hairline">
                                    {(product.product_variants ?? []).map((variant) => (
                                        <li key={variant.id} className="flex items-center gap-3 px-5 py-2.5">
                                            <div className="min-w-0 flex-1">
                                                <p className="text-[13px] font-medium text-ink">
                                                    {variant.name}
                                                    <span className="ml-1.5 text-[11.5px] font-normal text-ink-muted">
                                                        {variant.option_group}
                                                    </span>
                                                </p>
                                            </div>
                                            {variant.is_default ? (
                                                <Badge tone="brand" className="px-1.5 py-0">
                                                    Default
                                                </Badge>
                                            ) : null}
                                            <Badge tone={variant.availability === 'AVAILABLE' ? 'positive' : 'critical'}>
                                                {humanise(variant.availability)}
                                            </Badge>
                                            <span className="tnum shrink-0 text-[13px] font-semibold text-ink">
                                                {money(variant.price)}
                                            </span>
                                        </li>
                                    ))}
                                </ul>
                            )}
                        </CardContent>
                    </Card>

                    <Card>
                        <CardToolbar
                            title="Add-on groups"
                            description="Modifier groups attached to this dish"
                        />
                        <CardContent className="p-0">
                            {(product.product_modifier_groups ?? []).length === 0 ? (
                                <p className="px-5 py-6 text-[13px] text-ink-muted">No add-on groups attached.</p>
                            ) : (
                                <ul className="divide-y divide-hairline">
                                    {(product.product_modifier_groups ?? [])
                                        .slice()
                                        .sort((a, b) => a.display_order - b.display_order)
                                        .map((link) => (
                                            <li key={link.id} className="flex items-center gap-3 px-5 py-2.5">
                                                <span className="min-w-0 flex-1 text-[13px] font-medium text-ink">
                                                    {link.modifier_groups?.name ?? 'Group'}
                                                </span>
                                                <Badge tone="neutral" className="px-1.5 py-0">
                                                    {link.modifier_groups?.selection === 'SINGLE' ? 'Pick one' : 'Pick many'}
                                                </Badge>
                                                {link.modifier_groups?.is_required ? (
                                                    <Badge tone="caution" className="px-1.5 py-0">
                                                        Required
                                                    </Badge>
                                                ) : null}
                                            </li>
                                        ))}
                                </ul>
                            )}
                        </CardContent>
                    </Card>
                </div>
            ) : null}
        </>
    );
}
