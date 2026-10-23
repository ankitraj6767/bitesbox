import * as React from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { optionalNumberFromInput, ProductForm } from './product-form';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';

const mocks = vi.hoisted(() => ({ routerPush: vi.fn(), routerRefresh: vi.fn() }));

vi.mock('next/navigation', () => ({
    useRouter: () => ({ push: mocks.routerPush, refresh: mocks.routerRefresh, back: vi.fn() }),
}));

vi.mock('@/lib/supabase/client', () => ({
    createSupabaseBrowserClient: vi.fn(),
}));

vi.mock('sonner', () => ({ toast: { success: vi.fn(), error: vi.fn() } }));

describe('ProductForm image upload', () => {
    const categoryId = '123e4567-e89b-42d3-a456-426614174000';
    const productInsert = vi.fn();
    const productUpdate = vi.fn();
    const storageUpload = vi.fn();
    const storageRemove = vi.fn();
    const supabase = {
        from: vi.fn(() => ({ insert: productInsert, update: productUpdate })),
        storage: {
            from: vi.fn(() => ({ upload: storageUpload, remove: storageRemove })),
        },
    };

    beforeEach(() => {
        vi.mocked(createSupabaseBrowserClient).mockReturnValue(supabase as never);
        productInsert.mockReturnValue({
            select: vi.fn(() => ({
                single: vi.fn().mockResolvedValue({ data: { id: 'product-1' }, error: null }),
            })),
        });
        productUpdate.mockReturnValue({ eq: vi.fn().mockResolvedValue({ error: null }) });
        storageUpload.mockResolvedValue({ data: { path: 'products/sattu-paratha/image.jpg' }, error: null });
        storageRemove.mockResolvedValue({ data: [], error: null });
        mocks.routerPush.mockClear();
        mocks.routerRefresh.mockClear();
        supabase.from.mockClear();
        supabase.storage.from.mockClear();
        storageUpload.mockClear();
        storageRemove.mockClear();
        productInsert.mockClear();
        productUpdate.mockClear();
    });

    it('mounts an existing dish with saved optional numeric values', () => {
        const client = new QueryClient({ defaultOptions: { mutations: { retry: false } } });

        const { container } = render(
            <QueryClientProvider client={client}>
                <ProductForm
                    productId="product-1"
                    defaults={{
                        name: 'Chicken Dum Biryani',
                        slug: 'chicken-dum-biryani',
                        category_id: categoryId,
                        base_price: 249,
                        compare_price: 299,
                        packaging_charge: 15,
                        preparation_minutes: 25,
                        serves_count: 2,
                        calories: 720,
                        max_quantity_per_order: 10,
                    }}
                    categories={[{ id: categoryId, label: 'Biryani' }]}
                    taxCategories={[]}
                    canDelete
                    canChangePrice
                />
            </QueryClientProvider>,
        );

        expect(container.querySelector<HTMLInputElement>('input[name="compare_price"]')?.value).toBe('299');
        expect(container.querySelector<HTMLInputElement>('input[name="serves_count"]')?.value).toBe('2');
        expect(container.querySelector<HTMLInputElement>('input[name="calories"]')?.value).toBe('720');
        expect(container.querySelector<HTMLInputElement>('input[name="max_quantity_per_order"]')?.value).toBe('10');
    });

    it('normalizes optional numeric inputs without assuming the value is a string', () => {
        expect(optionalNumberFromInput(299)).toBe(299);
        expect(optionalNumberFromInput(' 299 ')).toBe(299);
        expect(optionalNumberFromInput('   ')).toBeUndefined();
        expect(optionalNumberFromInput('not a number')).toBeNaN();
    });

    it('uploads an image to menu storage and saves it as both product image paths', async () => {
        Object.defineProperty(URL, 'createObjectURL', {
            configurable: true,
            value: vi.fn(() => 'blob:product-image-preview'),
        });
        Object.defineProperty(URL, 'revokeObjectURL', {
            configurable: true,
            value: vi.fn(),
        });
        Object.defineProperty(crypto, 'randomUUID', {
            configurable: true,
            value: vi.fn(() => 'image-uuid'),
        });
        const client = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
        const { container } = render(
            <QueryClientProvider client={client}>
                <ProductForm
                    defaults={{
                        name: 'Sattu Paratha',
                        slug: 'sattu-paratha',
                        category_id: categoryId,
                        base_price: 120,
                        packaging_charge: 0,
                        preparation_minutes: 15,
                    }}
                    categories={[{ id: categoryId, label: 'Parathas' }]}
                    taxCategories={[]}
                    canDelete={false}
                    canChangePrice
                />
            </QueryClientProvider>,
        );

        const image = new File([new Uint8Array([1, 2, 3])], 'paratha.jpg', { type: 'image/jpeg' });
        fireEvent.change(screen.getByLabelText('Upload dish image'), {
            target: { files: [image] },
        });
        expect(screen.getByText('paratha.jpg')).toBeInTheDocument();
        fireEvent.submit(container.querySelector('form')!);

        await waitFor(() => expect(productInsert).toHaveBeenCalled());
        const uploadedObjectPath = storageUpload.mock.calls[0]?.[0] as string;
        expect(storageUpload).toHaveBeenCalledWith(
            'products/sattu-paratha/image-uuid.jpg',
            image,
            expect.objectContaining({ contentType: 'image/jpeg', upsert: false }),
        );
        const payload = productInsert.mock.calls[0]?.[0] as Record<string, unknown>;
        expect(payload.thumbnail_path).toBe(`menu-images/${uploadedObjectPath}`);
        expect(payload.hero_image_path).toBe(payload.thumbnail_path);
        await waitFor(() => expect(mocks.routerPush).toHaveBeenCalledWith('/menu/product-1'));
    });
});
