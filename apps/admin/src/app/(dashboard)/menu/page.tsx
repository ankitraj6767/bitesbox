import type { Metadata } from 'next';
import Link from 'next/link';
import Image from 'next/image';
import { ChefHat, Plus, Star, TrendingUp } from 'lucide-react';
import { requirePermission, hasPermission, activeBranchId } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Badge, FoodTypeMark } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { EmptyState, ErrorState } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { money, storageUrl } from '@/lib/utils';

export const metadata: Metadata = { title: 'Menu' };
export const dynamic = 'force-dynamic';

export default async function MenuPage({
    searchParams,
}: {
    searchParams: Promise<{ category?: string }>;
}) {
    const [session, params] = await Promise.all([
        requirePermission(PERMISSIONS.MENU_VIEW),
        searchParams,
    ]);

    const supabase = await createSupabaseServerClient();
    const branchId = activeBranchId(session);
    const canEdit = hasPermission(session, [PERMISSIONS.MENU_CREATE, PERMISSIONS.MENU_UPDATE]);

    const [categoriesResult, productsResult] = await Promise.all([
        supabase
            .from('categories')
            .select('id, name, slug, thumbnail_path, display_order, is_active, day_part, is_featured')
            .is('deleted_at', null)
            .order('display_order'),
        supabase
            .from('products')
            .select(
                `id, name, slug, category_id, thumbnail_path, food_type, base_price, compare_price,
         preparation_minutes, is_active, is_featured, is_best_seller, is_new, is_combo,
         rating_average, rating_count, order_count, display_order,
         product_variants(id), product_availability(state, branch_id)`,
            )
            .is('deleted_at', null)
            .order('display_order'),
    ]);

    if (categoriesResult.error || productsResult.error) {
        return (
            <>
                <PageHeader title="Menu" />
                <Card>
                    <ErrorState
                        title="Could not load the menu"
                        message={categoriesResult.error?.message ?? productsResult.error?.message}
                    />
                </Card>
            </>
        );
    }

    const categories = categoriesResult.data ?? [];
    const products = productsResult.data ?? [];
    const activeCategory = params.category ?? categories[0]?.id;
    const visibleProducts = products.filter((product) => product.category_id === activeCategory);

    const stats = {
        categories: categories.length,
        products: products.length,
        unavailable: products.filter((product) =>
            product.product_availability?.some(
                (row) => (!branchId || row.branch_id === branchId) && row.state !== 'AVAILABLE',
            ),
        ).length,
        bestSellers: products.filter((product) => product.is_best_seller).length,
    };

    return (
        <>
            <PageHeader
                title="Menu"
                description={`${stats.products} dishes across ${stats.categories} categories. ${stats.unavailable} currently unavailable.`}
                actions={
                    <>
                        <Button asChild variant="secondary" size="sm">
                            <Link href="/availability">Availability</Link>
                        </Button>
                        {canEdit ? (
                            <Button asChild size="sm">
                                <Link href="/menu/new">
                                    <Plus />
                                    Add dish
                                </Link>
                            </Button>
                        ) : null}
                    </>
                }
            />

            <div className="grid gap-4 lg:grid-cols-[240px_minmax(0,1fr)]">
                {/* Category rail */}
                <Card className="h-fit">
                    <CardToolbar title="Categories" description={`${categories.length} total`} />
                    <CardContent className="p-2">
                        {categories.length === 0 ? (
                            <EmptyState title="No categories yet" description="Create a category to begin." />
                        ) : (
                            <ul className="space-y-0.5">
                                {categories.map((category) => {
                                    const count = products.filter((p) => p.category_id === category.id).length;
                                    const active = category.id === activeCategory;

                                    return (
                                        <li key={category.id}>
                                            <Link
                                                href={`/menu?category=${category.id}`}
                                                aria-current={active ? 'true' : undefined}
                                                className={
                                                    active
                                                        ? 'flex items-center gap-2 rounded-[var(--radius-control)] bg-brand-50 px-2.5 py-2 text-[13px] font-medium text-brand-700'
                                                        : 'flex items-center gap-2 rounded-[var(--radius-control)] px-2.5 py-2 text-[13px] font-medium text-ink-muted transition-colors hover:bg-surface-muted hover:text-ink'
                                                }
                                            >
                                                <span className="min-w-0 flex-1 truncate">{category.name}</span>
                                                {!category.is_active ? (
                                                    <Badge tone="neutral" className="px-1.5 py-0">
                                                        Off
                                                    </Badge>
                                                ) : null}
                                                <span className="tnum shrink-0 text-[11.5px] text-ink-muted">{count}</span>
                                            </Link>
                                        </li>
                                    );
                                })}
                            </ul>
                        )}
                    </CardContent>
                </Card>

                {/* Products */}
                <TableWrap>
                    <Table>
                        <THead>
                            <TR className="hover:bg-transparent">
                                <TH>Dish</TH>
                                <TH>Tags</TH>
                                <TH numeric>Price</TH>
                                <TH numeric>Prep</TH>
                                <TH numeric>Sold</TH>
                                <TH>Rating</TH>
                                <TH>State</TH>
                                {canEdit ? <TH className="w-16" /> : null}
                            </TR>
                        </THead>
                        <TBody>
                            {visibleProducts.length === 0 ? (
                                <TableMessageRow colSpan={canEdit ? 8 : 7}>
                                    <EmptyState
                                        icon={ChefHat}
                                        title="No dishes in this category"
                                        description={canEdit ? 'Add the first dish to get started.' : undefined}
                                        action={
                                            canEdit ? (
                                                <Button asChild size="sm">
                                                    <Link href="/menu/new">
                                                        <Plus />
                                                        Add dish
                                                    </Link>
                                                </Button>
                                            ) : undefined
                                        }
                                    />
                                </TableMessageRow>
                            ) : (
                                visibleProducts.map((product) => {
                                    const availability = product.product_availability?.find(
                                        (row) => !branchId || row.branch_id === branchId,
                                    );
                                    const variantCount = product.product_variants?.length ?? 0;
                                    const image = storageUrl(product.thumbnail_path);

                                    return (
                                        <TR key={product.id}>
                                            <TD>
                                                <div className="flex items-center gap-3">
                                                    {image ? (
                                                        <Image
                                                            src={image}
                                                            alt=""
                                                            width={40}
                                                            height={40}
                                                            className="size-10 shrink-0 rounded-lg object-cover"
                                                            unoptimized
                                                        />
                                                    ) : (
                                                        <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-ink-muted">
                                                            <ChefHat className="size-4" aria-hidden />
                                                        </span>
                                                    )}
                                                    <div className="min-w-0">
                                                        <p className="flex items-center gap-1.5 text-[13.5px] font-medium text-ink">
                                                            <FoodTypeMark type={product.food_type} />
                                                            <span className="max-w-56 truncate">{product.name}</span>
                                                        </p>
                                                        <p className="text-[11.5px] text-ink-muted">
                                                            {variantCount > 0
                                                                ? `${variantCount} option${variantCount === 1 ? '' : 's'}`
                                                                : 'Single size'}
                                                        </p>
                                                    </div>
                                                </div>
                                            </TD>

                                            <TD>
                                                <div className="flex flex-wrap gap-1">
                                                    {product.is_best_seller ? (
                                                        <Badge tone="brand" className="px-1.5 py-0">
                                                            <TrendingUp className="size-2.5" aria-hidden />
                                                            Best seller
                                                        </Badge>
                                                    ) : null}
                                                    {product.is_new ? (
                                                        <Badge tone="info" className="px-1.5 py-0">
                                                            New
                                                        </Badge>
                                                    ) : null}
                                                    {product.is_combo ? (
                                                        <Badge tone="caution" className="px-1.5 py-0">
                                                            Combo
                                                        </Badge>
                                                    ) : null}
                                                    {product.is_featured ? (
                                                        <Badge tone="neutral" className="px-1.5 py-0">
                                                            Featured
                                                        </Badge>
                                                    ) : null}
                                                </div>
                                            </TD>

                                            <TD numeric>
                                                <span className="text-[13px] font-semibold">{money(product.base_price)}</span>
                                                {product.compare_price ? (
                                                    <span className="block text-[11.5px] text-ink-muted line-through">
                                                        {money(product.compare_price)}
                                                    </span>
                                                ) : null}
                                            </TD>

                                            <TD numeric className="text-[12.5px] text-ink-muted">
                                                {product.preparation_minutes}m
                                            </TD>

                                            <TD numeric className="text-[12.5px] text-ink-muted">
                                                {product.order_count}
                                            </TD>

                                            <TD>
                                                {product.rating_count > 0 ? (
                                                    <span className="inline-flex items-center gap-1 text-[12.5px]">
                                                        <Star className="size-3 fill-turmeric-500 text-turmeric-500" aria-hidden />
                                                        {product.rating_average.toFixed(1)}
                                                        <span className="text-ink-muted">({product.rating_count})</span>
                                                    </span>
                                                ) : (
                                                    <span className="text-[12.5px] text-ink-muted">—</span>
                                                )}
                                            </TD>

                                            <TD>
                                                {!product.is_active ? (
                                                    <Badge tone="neutral">Hidden</Badge>
                                                ) : availability?.state === 'OUT_OF_STOCK' ? (
                                                    <Badge tone="critical">Out of stock</Badge>
                                                ) : availability?.state === 'TEMPORARILY_UNAVAILABLE' ? (
                                                    <Badge tone="caution">Paused</Badge>
                                                ) : (
                                                    <Badge tone="positive">Live</Badge>
                                                )}
                                            </TD>

                                            {canEdit ? (
                                                <TD>
                                                    <Button asChild variant="ghost" size="sm">
                                                        <Link href={`/menu/${product.id}`}>Edit</Link>
                                                    </Button>
                                                </TD>
                                            ) : null}
                                        </TR>
                                    );
                                })
                            )}
                        </TBody>
                    </Table>
                </TableWrap>
            </div>
        </>
    );
}
