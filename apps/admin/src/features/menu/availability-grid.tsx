'use client';

import * as React from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { CheckCircle2, Clock, PackageX, Search } from 'lucide-react';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge, FoodTypeMark } from '@/components/ui/badge';
import { SearchInput } from '@/components/ui/form-controls';
import { EmptyState, ErrorState, InlineNotice, Skeleton } from '@/components/ui/states';
import { Tooltip } from '@/components/ui/overlays';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import { cn, money, relativeTime } from '@/lib/utils';
import type { AvailabilityState, FoodType } from '@bitesbox/shared-types';

interface AvailabilityProduct {
    id: string;
    name: string;
    thumbnail_path: string | null;
    food_type: FoodType;
    base_price: number;
    state: AvailabilityState;
    remaining_quantity: number | null;
    out_of_stock_until: string | null;
    out_of_stock_reason: string | null;
    changed_at: string | null;
    is_orderable: boolean;
    variants: Array<{ id: string; name: string; option_group: string; price: number; availability: AvailabilityState }>;
}

interface AvailabilityCategory {
    id: string;
    name: string;
    products: AvailabilityProduct[];
}

/**
 * The screen the kitchen actually uses mid-service. Toggling here writes through
 * `set_product_availability`, which the customer app receives over Realtime — so
 * a sold-out dish disappears from the menu within a second.
 */
export function AvailabilityGrid({ branchId, canToggle }: { branchId: string | null; canToggle: boolean }) {
    const queryClient = useQueryClient();
    const [term, setTerm] = React.useState('');
    const [filter, setFilter] = React.useState<'all' | 'unavailable'>('all');
    const [selected, setSelected] = React.useState<Set<string>>(new Set());

    const { data, isPending, isError, error, refetch } = useQuery({
        queryKey: ['kitchen-availability', branchId],
        refetchInterval: 60_000,
        queryFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('kitchen_availability', {
                p_branch_id: branchId ?? undefined,
            });
            if (error) throw error;
            return data as unknown as {
                categories: AvailabilityCategory[];
                out_of_stock_count: number;
            };
        },
    });

    const setAvailability = useMutation({
        mutationFn: async (input: {
            productIds: string[];
            state: AvailabilityState;
            minutes?: number;
            reason?: string;
        }) => {
            const supabase = createSupabaseBrowserClient();

            if (input.productIds.length === 1) {
                const { error } = await supabase.rpc('set_product_availability', {
                    p_product_id: input.productIds[0]!,
                    p_state: input.state,
                    p_branch_id: branchId ?? undefined,
                    p_minutes: input.minutes ?? undefined,
                    p_reason: input.reason ?? undefined,
                });
                if (error) throw error;
                return 1;
            }

            const { data, error } = await supabase.rpc('set_products_availability', {
                p_product_ids: input.productIds,
                p_state: input.state,
                p_branch_id: branchId ?? undefined,
                p_minutes: input.minutes ?? undefined,
                p_reason: input.reason ?? undefined,
            });
            if (error) throw error;
            return data ?? input.productIds.length;
        },
        onSuccess: (count, input) => {
            toast.success(
                input.state === 'AVAILABLE'
                    ? `${count} item${count === 1 ? '' : 's'} back on the menu`
                    : `${count} item${count === 1 ? '' : 's'} marked ${input.state === 'OUT_OF_STOCK' ? 'out of stock' : 'unavailable for now'
                    }`,
            );
            setSelected(new Set());
            void queryClient.invalidateQueries({ queryKey: ['kitchen-availability'] });
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const categories = React.useMemo(() => {
        const source = data?.categories ?? [];
        const search = term.trim().toLowerCase();

        return source
            .map((category) => ({
                ...category,
                products: category.products.filter((product) => {
                    if (filter === 'unavailable' && product.state === 'AVAILABLE') return false;
                    if (!search) return true;
                    return product.name.toLowerCase().includes(search);
                }),
            }))
            .filter((category) => category.products.length > 0);
    }, [data, term, filter]);

    const toggleSelected = (id: string) => {
        setSelected((current) => {
            const next = new Set(current);
            if (next.has(id)) next.delete(id);
            else next.add(id);
            return next;
        });
    };

    if (isPending) {
        return (
            <Card className="p-5">
                <Skeleton className="h-8 w-52" />
                <div className="mt-4 space-y-2">
                    {Array.from({ length: 6 }).map((_, index) => (
                        <Skeleton key={index} className="h-14 w-full" />
                    ))}
                </div>
            </Card>
        );
    }

    if (isError || !data) {
        return (
            <Card>
                <ErrorState
                    title="Could not load availability"
                    message={error instanceof Error ? error.message : undefined}
                    onRetry={() => void refetch()}
                />
            </Card>
        );
    }

    return (
        <>
            <div className="mb-4 flex flex-wrap items-center gap-2">
                <div className="min-w-56 flex-1">
                    <SearchInput
                        value={term}
                        onChange={(event) => setTerm(event.target.value)}
                        placeholder="Find a dish"
                        aria-label="Search dishes"
                    />
                </div>

                <div className="inline-flex rounded-[var(--radius-control)] bg-surface-muted p-0.5">
                    {(['all', 'unavailable'] as const).map((option) => (
                        <button
                            key={option}
                            type="button"
                            onClick={() => setFilter(option)}
                            className={
                                filter === option
                                    ? 'rounded-md bg-surface px-3 py-1.5 text-[12.5px] font-medium text-ink shadow-xs'
                                    : 'rounded-md px-3 py-1.5 text-[12.5px] font-medium text-ink-muted'
                            }
                        >
                            {option === 'all' ? 'All dishes' : `Out of stock (${data.out_of_stock_count})`}
                        </button>
                    ))}
                </div>
            </div>

            {/* Bulk bar appears only when something is selected. */}
            {canToggle && selected.size > 0 ? (
                <div className="sticky top-16 z-20 mb-3 flex flex-wrap items-center gap-2 rounded-[var(--radius-card)] border border-brand-200 bg-brand-50 px-4 py-2.5">
                    <p className="text-[13px] font-medium text-brand-700">
                        {selected.size} dish{selected.size === 1 ? '' : 'es'} selected
                    </p>
                    <div className="ml-auto flex flex-wrap gap-2">
                        <Button
                            size="sm"
                            variant="secondary"
                            loading={setAvailability.isPending}
                            onClick={() =>
                                setAvailability.mutate({ productIds: [...selected], state: 'AVAILABLE' })
                            }
                        >
                            <CheckCircle2 />
                            Mark available
                        </Button>
                        <Button
                            size="sm"
                            variant="secondary"
                            loading={setAvailability.isPending}
                            onClick={() =>
                                setAvailability.mutate({
                                    productIds: [...selected],
                                    state: 'TEMPORARILY_UNAVAILABLE',
                                    minutes: 60,
                                    reason: 'Paused by kitchen',
                                })
                            }
                        >
                            <Clock />
                            Pause 1 hour
                        </Button>
                        <Button
                            size="sm"
                            variant="outlineDestructive"
                            loading={setAvailability.isPending}
                            onClick={() =>
                                setAvailability.mutate({
                                    productIds: [...selected],
                                    state: 'OUT_OF_STOCK',
                                    reason: 'Finished for today',
                                })
                            }
                        >
                            <PackageX />
                            Out of stock
                        </Button>
                        <Button size="sm" variant="ghost" onClick={() => setSelected(new Set())}>
                            Clear
                        </Button>
                    </div>
                </div>
            ) : null}

            {data.out_of_stock_count > 0 && filter === 'all' ? (
                <InlineNotice tone="caution" className="mb-4">
                    {data.out_of_stock_count} dish{data.out_of_stock_count === 1 ? ' is' : 'es are'} currently
                    unavailable to customers.
                </InlineNotice>
            ) : null}

            {categories.length === 0 ? (
                <Card>
                    <EmptyState
                        icon={Search}
                        title="No dishes match"
                        description={
                            filter === 'unavailable'
                                ? 'Everything on the menu is currently available.'
                                : 'Try a different search term.'
                        }
                    />
                </Card>
            ) : (
                <div className="space-y-4">
                    {categories.map((category) => (
                        <Card key={category.id}>
                            <CardToolbar
                                title={category.name}
                                description={`${category.products.length} dish${category.products.length === 1 ? '' : 'es'}`}
                            />
                            <CardContent className="p-0">
                                <ul className="divide-y divide-hairline">
                                    {category.products.map((product) => (
                                        <li
                                            key={product.id}
                                            className={cn(
                                                'flex items-center gap-3 px-5 py-3',
                                                !product.is_orderable && 'bg-critical-soft/30',
                                            )}
                                        >
                                            {canToggle ? (
                                                <input
                                                    type="checkbox"
                                                    checked={selected.has(product.id)}
                                                    onChange={() => toggleSelected(product.id)}
                                                    className="size-4 shrink-0 accent-brand-600"
                                                    aria-label={`Select ${product.name}`}
                                                />
                                            ) : null}

                                            <div className="min-w-0 flex-1">
                                                <p className="flex items-center gap-1.5 text-[13.5px] font-medium text-ink">
                                                    <FoodTypeMark type={product.food_type} />
                                                    <span className="truncate">{product.name}</span>
                                                </p>
                                                <p className="mt-0.5 text-[11.5px] text-ink-muted">
                                                    {money(product.base_price)}
                                                    {product.variants.length > 0
                                                        ? ` · ${product.variants.length} option${product.variants.length === 1 ? '' : 's'}`
                                                        : ''}
                                                    {product.changed_at && product.state !== 'AVAILABLE'
                                                        ? ` · changed ${relativeTime(product.changed_at)}`
                                                        : ''}
                                                </p>
                                                {product.out_of_stock_reason ? (
                                                    <p className="mt-0.5 text-[11.5px] text-caution">
                                                        {product.out_of_stock_reason}
                                                    </p>
                                                ) : null}
                                            </div>

                                            <StateBadge product={product} />

                                            {canToggle ? (
                                                <div className="flex shrink-0 gap-1">
                                                    {product.state === 'AVAILABLE' ? (
                                                        <>
                                                            <Tooltip content="Pause for one hour">
                                                                <Button
                                                                    variant="ghost"
                                                                    size="iconSm"
                                                                    aria-label={`Pause ${product.name} for an hour`}
                                                                    onClick={() =>
                                                                        setAvailability.mutate({
                                                                            productIds: [product.id],
                                                                            state: 'TEMPORARILY_UNAVAILABLE',
                                                                            minutes: 60,
                                                                            reason: 'Paused by kitchen',
                                                                        })
                                                                    }
                                                                >
                                                                    <Clock />
                                                                </Button>
                                                            </Tooltip>
                                                            <Tooltip content="Out of stock for the rest of the day">
                                                                <Button
                                                                    variant="ghost"
                                                                    size="iconSm"
                                                                    aria-label={`Mark ${product.name} out of stock`}
                                                                    onClick={() =>
                                                                        setAvailability.mutate({
                                                                            productIds: [product.id],
                                                                            state: 'OUT_OF_STOCK',
                                                                            reason: 'Finished for today',
                                                                        })
                                                                    }
                                                                >
                                                                    <PackageX className="text-critical" />
                                                                </Button>
                                                            </Tooltip>
                                                        </>
                                                    ) : (
                                                        <Button
                                                            variant="secondary"
                                                            size="sm"
                                                            onClick={() =>
                                                                setAvailability.mutate({
                                                                    productIds: [product.id],
                                                                    state: 'AVAILABLE',
                                                                })
                                                            }
                                                        >
                                                            <CheckCircle2 />
                                                            Restore
                                                        </Button>
                                                    )}
                                                </div>
                                            ) : null}
                                        </li>
                                    ))}
                                </ul>
                            </CardContent>
                        </Card>
                    ))}
                </div>
            )}
        </>
    );
}

function StateBadge({ product }: { product: AvailabilityProduct }) {
    if (product.state === 'OUT_OF_STOCK') {
        return <Badge tone="critical">Out of stock</Badge>;
    }

    if (product.state === 'TEMPORARILY_UNAVAILABLE') {
        return (
            <Badge tone="caution">
                {product.out_of_stock_until
                    ? `Back ${new Date(product.out_of_stock_until).toLocaleTimeString('en-IN', {
                        hour: 'numeric',
                        minute: '2-digit',
                    })}`
                    : 'Paused'}
            </Badge>
        );
    }

    if (!product.is_orderable) {
        return <Badge tone="neutral">Off schedule</Badge>;
    }

    return <Badge tone="positive">Available</Badge>;
}
