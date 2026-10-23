import { NextResponse } from 'next/server';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { hasSameSiteOrigin } from '@/lib/site';

const allowed = new Set(['MENU_VIEW', 'SEARCH', 'PRODUCT_VIEW', 'SERVICEABILITY_SUCCESS', 'SERVICEABILITY_FAILURE', 'CHECKOUT_START', 'CHECKOUT_COMPLETED']);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function POST(request: Request) {
    if (!hasSameSiteOrigin(request)) return NextResponse.json({ ok: false }, { status: 403 });
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    if (!body || typeof body.eventId !== 'string' || !uuid.test(body.eventId) || typeof body.eventName !== 'string' || !allowed.has(body.eventName)) {
        return NextResponse.json({ ok: false }, { status: 400 });
    }
    const branchId = body.branchId === null || body.branchId === undefined ? null : (typeof body.branchId === 'string' && uuid.test(body.branchId) ? body.branchId : undefined);
    const productId = body.productId === null || body.productId === undefined ? null : (typeof body.productId === 'string' && uuid.test(body.productId) ? body.productId : undefined);
    if (branchId === undefined || productId === undefined) return NextResponse.json({ ok: false }, { status: 400 });
    const supabase = await createSupabaseServerClient();
    await supabase.rpc('record_storefront_event', {
        p_event_id: body.eventId,
        p_event_name: body.eventName,
        p_branch_id: branchId,
        p_product_id: productId,
    });
    return NextResponse.json({ ok: true }, { headers: { 'cache-control': 'no-store' } });
}
