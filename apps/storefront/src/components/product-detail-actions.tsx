'use client';

import { useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Minus, Plus } from 'lucide-react';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { messages, type Locale } from '@/lib/site';
import { readGuestCart, writeGuestCart } from '@/lib/guest-cart';

interface ProductDetail {
    id: string;
    name: string;
    slug: string;
    base_price: number;
    thumbnail_path?: string | null;
    is_available: boolean;
    min_quantity_per_order?: number;
    max_quantity_per_order?: number;
    allows_special_instructions?: boolean;
    variants?: Array<{ id: string; name: string; price: number; is_default: boolean; is_available: boolean }>;
    modifier_groups?: Array<{
        id: string; name: string; selection: string; is_required: boolean; min_select: number; max_select: number;
        modifiers: Array<{ id: string; name: string; price: number; is_available: boolean }>;
    }>;
}

export function ProductDetailActions({ product, branchId, locale, signedIn }: { product: ProductDetail; branchId: string; locale: Locale; signedIn: boolean }) {
    const t = messages[locale];
    const router = useRouter();
    const variants = product.variants ?? [];
    const defaultVariant = variants.find((variant) => variant.is_default) ?? variants.find((variant) => variant.is_available);
    const [variantId, setVariantId] = useState<string | null>(defaultVariant?.id ?? null);
    const [quantity, setQuantity] = useState(product.min_quantity_per_order ?? 1);
    const [modifiers, setModifiers] = useState<Record<string, boolean>>({});
    const [instructions, setInstructions] = useState('');
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState('');
    const selectedModifiers = useMemo(() => Object.entries(modifiers).filter(([, selected]) => selected).map(([id]) => ({ modifier_id: id, quantity: 1 })), [modifiers]);
    const max = product.max_quantity_per_order ?? 20;
    const variant = variants.find((item) => item.id === variantId);
    const canAdd = product.is_available && (!variants.length || Boolean(variant?.is_available)) &&
        (product.modifier_groups ?? []).every((group) => {
            const selected = (group.modifiers ?? []).filter((item) => modifiers[item.id]).length;
            return !group.is_required || selected >= Math.max(1, group.min_select ?? 1);
        });

    async function add() {
        setBusy(true); setError('');
        try {
            if (signedIn) {
                const supabase = createSupabaseBrowserClient();
                const { data: result, error: addError } = await supabase.rpc('cart_add_item', {
                    p_product_id: product.id, p_variant_id: variantId, p_quantity: quantity,
                    p_modifiers: selectedModifiers, p_special_instructions: instructions.trim() || null,
                    p_branch_id: branchId,
                });
                if (addError) throw addError;
                if (result && typeof result === 'object' && 'is_valid' in result && (result as { is_valid?: boolean }).is_valid === false) {
                    const quote = result as { issues?: Array<{ message?: string }> };
                    throw new Error(quote.issues?.[0]?.message ?? t.unavailableItem);
                }
            } else {
                const cart = readGuestCart(branchId);
                cart.push({ productId: product.id, slug: product.slug, name: product.name, imagePath: product.thumbnail_path,
                    quantity, variantId, variantName: variant?.name ?? null, modifiers: selectedModifiers,
                    specialInstructions: instructions.trim(), displayedUnitPrice: Number(variant?.price ?? product.base_price) });
                writeGuestCart(branchId, cart);
            }
            router.push('/cart');
        } catch (cause) {
            setError(cause instanceof Error ? cause.message : t.retry);
        } finally { setBusy(false); }
    }

    return <div className="panel product-options">
        {variants.length ? <fieldset className="option-group"><legend>{t.chooseOptions}</legend>{variants.map((item) => <label key={item.id} className="choice-row">
            <input type="radio" name={`variant-${product.id}`} checked={variantId === item.id} disabled={!item.is_available} onChange={() => setVariantId(item.id)} />
            <span>{item.name}</span><span>{new Intl.NumberFormat(locale === 'hi' ? 'hi-IN' : 'en-IN', { style: 'currency', currency: 'INR' }).format(Number(item.price))}</span>
        </label>)}</fieldset> : null}
        {(product.modifier_groups ?? []).map((group) => <fieldset className="option-group" key={group.id}>
            <legend>{group.name}{group.is_required ? ' · *' : ''}</legend>
            {(group.modifiers ?? []).map((item) => <label key={item.id} className="choice-row">
                <input type="checkbox" checked={Boolean(modifiers[item.id])} disabled={!item.is_available} onChange={(event) => setModifiers((current) => ({ ...current, [item.id]: event.target.checked }))} />
                <span>{item.name}</span><span>{Number(item.price) > 0 ? `+${new Intl.NumberFormat(locale === 'hi' ? 'hi-IN' : 'en-IN', { style: 'currency', currency: 'INR' }).format(Number(item.price))}` : ''}</span>
            </label>)}
        </fieldset>)}
        {product.allows_special_instructions ? <label className="field">{t.specialInstructions}<textarea maxLength={240} value={instructions} onChange={(event) => setInstructions(event.target.value)} /></label> : null}
        <div className="quantity-control" aria-label={t.quantity}>
            <button type="button" aria-label={locale === 'hi' ? 'मात्रा घटाएँ' : 'Decrease quantity'} disabled={quantity <= (product.min_quantity_per_order ?? 1)} onClick={() => setQuantity((value) => Math.max(product.min_quantity_per_order ?? 1, value - 1))}><Minus size={16} /></button>
            <span>{quantity}</span>
            <button type="button" aria-label={locale === 'hi' ? 'मात्रा बढ़ाएँ' : 'Increase quantity'} disabled={quantity >= max} onClick={() => setQuantity((value) => Math.min(max, value + 1))}><Plus size={16} /></button>
        </div>
        {!product.is_available ? <p className="status-message">{t.unavailableProduct}</p> : null}
        {error ? <p className="status-message" role="alert">{error}</p> : null}
        <button className="primary-button" type="button" disabled={busy || !canAdd} onClick={() => void add()}>{busy ? t.loading : t.add}</button>
        {!signedIn ? <p className="muted">{t.guestCart}</p> : null}
    </div>;
}
