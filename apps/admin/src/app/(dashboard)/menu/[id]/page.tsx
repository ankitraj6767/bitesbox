import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { ProductForm } from '@/features/menu/product-form';
import { ProductConfigurationEditor } from '@/features/menu/product-configuration-editor';
import { CatalogTranslationEditor } from '@/features/menu/catalog-translation-editor';
import { PERMISSIONS } from '@bitesbox/shared-types';

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

    const [productResult, categoriesResult, taxResult, modifierGroupsResult] = await Promise.all([
        isNew
            ? Promise.resolve({ data: null, error: null })
            : supabase
                .from('products')
                .select(
                    `id, name, name_hi, slug, category_id, thumbnail_path, hero_image_path, short_description, short_description_hi, description, description_hi, food_type, spice_level,
             base_price, compare_price, packaging_charge, preparation_minutes, serves_count,
             calories, tax_category_id, max_quantity_per_order, is_active, is_featured,
             is_best_seller, is_new, is_recommended, is_combo, allows_special_instructions,
             search_keywords, meta_title, meta_description,
             product_variants(id, name, name_hi, option_group, option_group_hi, sku, price, compare_price, calories, serves_count, preparation_minutes, availability, is_default, is_active, display_order, deleted_at),
             product_modifier_groups(id, modifier_group_id, is_required, min_select, max_select, display_order, modifier_groups(id, name, name_hi, description, description_hi, selection, is_required, min_select, max_select, modifiers(id, name, name_hi, description_hi, price, food_type, is_active, deleted_at)))`,
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
        isNew
            ? Promise.resolve({ data: [], error: null })
            : supabase
                .from('modifier_groups')
                .select('id, name, name_hi, description, selection, is_required, min_select, max_select, display_order, is_active, modifiers(id, name, name_hi, price, food_type, is_active, deleted_at)')
                .is('deleted_at', null)
                .order('display_order'),
    ]);

    if (!isNew && (productResult.error || !productResult.data)) notFound();
    if (!isNew && modifierGroupsResult.error) throw modifierGroupsResult.error;

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
                            name_hi: product.name_hi ?? '',
                            slug: product.slug,
                            category_id: product.category_id,
                            thumbnail_path: product.thumbnail_path ?? '',
                            hero_image_path: product.hero_image_path ?? '',
                            short_description: product.short_description ?? '',
                            short_description_hi: product.short_description_hi ?? '',
                            description: product.description ?? '',
                            description_hi: product.description_hi ?? '',
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
                <ProductConfigurationEditor
                    productId={product.id}
                    basePrice={Number(product.base_price)}
                    variants={(product.product_variants ?? []).filter((variant) => variant.deleted_at === null).map((variant) => ({
                        id: variant.id,
                        name: variant.name,
                        name_hi: variant.name_hi,
                        option_group: variant.option_group,
                        option_group_hi: variant.option_group_hi,
                        sku: variant.sku,
                        price: Number(variant.price),
                        compare_price: variant.compare_price === null ? null : Number(variant.compare_price),
                        calories: variant.calories,
                        serves_count: variant.serves_count,
                        preparation_minutes: variant.preparation_minutes,
                        is_default: variant.is_default,
                        is_active: variant.is_active,
                        display_order: variant.display_order,
                        availability: variant.availability,
                    }))}
                    modifierGroups={(modifierGroupsResult.data ?? []).map((group) => ({
                        id: group.id,
                        name: group.name,
                        name_hi: group.name_hi,
                        description: group.description,
                        is_active: group.is_active,
                        selection: group.selection,
                        is_required: group.is_required,
                        min_select: group.min_select,
                        max_select: group.max_select,
                        display_order: group.display_order,
                        modifiers: (group.modifiers ?? []).filter((modifier) => modifier.deleted_at === null).map((modifier) => ({
                            id: modifier.id,
                            name: modifier.name,
                            name_hi: modifier.name_hi,
                            price: Number(modifier.price),
                            food_type: modifier.food_type,
                            is_active: modifier.is_active,
                        })),
                    }))}
                    productGroupLinks={(product.product_modifier_groups ?? []).map((link) => ({
                        id: link.id,
                        modifier_group_id: link.modifier_group_id,
                        is_required: link.is_required,
                        min_select: link.min_select,
                        max_select: link.max_select,
                        display_order: link.display_order,
                    }))}
                    canManage={hasPermission(session, PERMISSIONS.MENU_UPDATE)}
                    canChangePrice={hasPermission(session, PERMISSIONS.MENU_PRICE_UPDATE)}
                />
            ) : null}

            {product && hasPermission(session, PERMISSIONS.MENU_UPDATE) ? (
                <div className="mt-4">
                    <CatalogTranslationEditor
                        productId={product.id}
                        variants={(product.product_variants ?? []).map((variant) => ({
                            id: variant.id,
                            name_hi: variant.name_hi ?? '',
                            option_group_hi: variant.option_group_hi ?? '',
                        }))}
                        groups={(product.product_modifier_groups ?? []).flatMap((link) => {
                            const group = link.modifier_groups;
                            return group ? [{
                                id: link.modifier_group_id,
                                name_hi: group.name_hi ?? '',
                                description_hi: group.description_hi ?? '',
                                modifiers: (group.modifiers ?? []).filter((modifier) => modifier.deleted_at === null).map((modifier) => ({
                                    id: modifier.id,
                                    name_hi: modifier.name_hi ?? '',
                                    description_hi: modifier.description_hi ?? '',
                                })),
                            }] : [];
                        })}
                    />
                </div>
            ) : null}
        </>
    );
}
