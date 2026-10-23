import { createServer } from 'node:http';

const host = '127.0.0.1';
const port = 55321;
const branchA = '00000000-0000-4000-8000-000000000101';
const branchB = '00000000-0000-4000-8000-000000000102';
const productId = '00000000-0000-4000-8000-000000000201';
const userId = '00000000-0000-4000-8000-000000000301';
const orderId = '00000000-0000-4000-8000-000000000501';
let importedGuestLines = [];

const product = (locale = 'en', branchId = branchA) => ({
    id: productId,
    name: locale === 'hi' ? 'लिट्टी चोखा' : 'Litti Chokha',
    slug: 'litti-chokha',
    category_id: '00000000-0000-4000-8000-000000000401',
    short_description: locale === 'hi' ? 'सत्तू से भरी लिट्टी' : 'Roasted litti with chokka',
    base_price: 120,
    min_price: 120,
    food_type: 'VEG',
    is_active: true,
    is_available: branchId === branchA,
    has_variants: false,
    variants: [],
    modifier_groups: [],
    images: [],
});

const outlets = [
    { id: branchA, name: 'Bakhtiyarpur', slug: 'bakhtiyarpur', city: 'Bakhtiyarpur', service_mode: 'BOTH', ordering: { accepting_orders: true, status: 'OPEN' } },
    { id: branchB, name: 'Patna pickup', slug: 'patna-pickup', city: 'Patna', service_mode: 'PICKUP', ordering: { accepting_orders: true, status: 'OPEN' } },
];

function send(response, status, body) {
    response.writeHead(status, {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store',
        'access-control-allow-origin': '*',
        'access-control-allow-headers': '*',
        'access-control-allow-methods': 'GET, POST, PATCH, DELETE, HEAD, OPTIONS',
    });
    response.end(body === undefined ? '' : JSON.stringify(body));
}

async function jsonBody(request) {
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    if (chunks.length === 0) return {};
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function claimsFor(request) {
    const token = request.headers.authorization?.replace(/^Bearer\s+/i, '');
    if (!token) return null;
    try {
        return JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
    } catch {
        return null;
    }
}

function accessToken() {
    const now = Math.floor(Date.now() / 1000);
    const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
    const payload = Buffer.from(JSON.stringify({ sub: userId, role: 'authenticated', aal: 'aal1', exp: now + 3600 })).toString('base64url');
    return `${header}.${payload}.e2e-signature`;
}

function userFor(claims) {
    if (!claims?.sub) return null;
    return { id: claims.sub, aud: 'authenticated', role: 'authenticated', phone: '+919999000001', created_at: '2026-10-23T00:00:00.000Z', app_metadata: { provider: 'phone', providers: ['phone'] }, user_metadata: {}, identities: [] };
}

function menu(locale = 'en', branchId = branchA) {
    return {
        branch: { id: branchId, accepting_orders: true, status: 'OPEN' },
        categories: [{ id: '00000000-0000-4000-8000-000000000401', name: locale === 'hi' ? 'लिट्टी' : 'Litti', slug: 'litti', is_active: true }],
        products: [product(locale, branchId)],
    };
}

function session(claims) {
    return {
        authenticated: true,
        user_id: claims.sub,
        profile: { id: claims.sub, full_name: 'E2E customer', preferred_language: 'en', preferred_branch_id: branchA },
        primary_role: 'CUSTOMER', permissions: [], branches: [], account_active: true,
    };
}

function checkoutQuote(branchId = branchA) {
    const lines = importedGuestLines.map((line, index) => ({
        cart_item_id: `00000000-0000-4000-8000-${String(701 + index).padStart(12, '0')}`,
        product_id: line.product_id,
        product_name: 'Litti Chokha',
        quantity: line.quantity,
        unit_price: 120,
        net_amount: 120 * line.quantity,
        is_available: branchId === branchA,
    }));
    return {
        cart_id: '00000000-0000-4000-8000-000000000601',
        branch_id: branchId,
        lines,
        item_count: lines.length,
        unit_count: lines.reduce((total, line) => total + line.quantity, 0),
        is_valid: lines.length > 0 && branchId === branchA,
        issues: [],
        totals: { items_subtotal: 120 * lines.length, total_discount: 0, tax_amount: 6, delivery_fee: 0, grand_total: 126 * lines.length, payable_amount: 126 * lines.length },
        branch: { accepting_orders: true },
    };
}

const server = createServer(async (request, response) => {
    const url = new URL(request.url ?? '/', `http://${request.headers.host ?? `${host}:${port}`}`);
    if (request.method === 'OPTIONS') return send(response, 204);
    if (url.pathname === '/health') return send(response, 200, { ok: true });

    if (url.pathname === '/auth/v1/otp' && request.method === 'POST') return send(response, 200, {});
    if (url.pathname === '/auth/v1/verify' && request.method === 'POST') {
        const body = await jsonBody(request);
        if (body.token !== '123456') return send(response, 400, { code: 'otp_expired', message: 'Invalid verification code.' });
        const token = accessToken();
        return send(response, 200, {
            access_token: token, token_type: 'bearer', expires_in: 3600, refresh_token: 'e2e-refresh-token',
            user: userFor(claimsFor({ headers: { authorization: `Bearer ${token}` } })),
        });
    }
    if (url.pathname === '/auth/v1/user') {
        const user = userFor(claimsFor(request));
        return user ? send(response, 200, user) : send(response, 401, { code: 'no_session', message: 'No session' });
    }
    if (url.pathname === '/auth/v1/aal') {
        const claims = claimsFor(request);
        return claims ? send(response, 200, { currentLevel: claims.aal, nextLevel: claims.aal }) : send(response, 401, { code: 'no_session' });
    }

    if (url.pathname.startsWith('/rest/v1/rpc/')) {
        const name = url.pathname.split('/').at(-1);
        const body = await jsonBody(request);
        const claims = claimsFor(request);
        if (name === 'public_outlets') return send(response, 200, outlets);
        if (name === 'calculate_checkout' || name === 'cart_set_options') return send(response, 200, checkoutQuote(body.p_branch_id ?? branchA));
        if (name === 'import_guest_cart') {
            importedGuestLines = body.p_lines ?? [];
            return send(response, 200, { imported: true, line_count: importedGuestLines.length, branch_id: body.p_branch_id, replayed: false });
        }
        if (name === 'order_detail') return claims && body.p_order_id === orderId ? send(response, 200, {
            id: orderId, order_number: 'BB-E2E-002', status: 'ORDER_PLACED', payment: { status: 'COD_PENDING', mode: 'COD' },
            totals: { grand_total: 126, currency_code: 'INR' }, items: [{ product_name: 'Litti Chokha', quantity: 1, net_amount: 120 }], timeline: [],
        }) : send(response, 404, { code: 'order_not_found' });
        if (name === 'localized_menu_catalog') return send(response, 200, menu(body.p_locale, body.p_branch_id ?? branchA));
        if (name === 'localized_search_menu') return send(response, 200, menu(body.p_locale, body.p_branch_id ?? branchA));
        if (name === 'localized_product_detail') return send(response, 200, { ...product(body.p_locale, body.p_branch_id ?? branchA), description: 'Roasted wheat litti served with smoky chokka.' });
        if (name === 'record_storefront_event') return send(response, 200, true);
        if (name === 'my_session') return claims ? send(response, 200, session(claims)) : send(response, 401, { code: 'no_session' });
        if (name === 'my_favorites') return claims ? send(response, 200, [{ ...product(body.p_locale, body.p_branch_id ?? branchA), is_favorite: true }]) : send(response, 401, { code: 'no_session' });
        if (name === 'set_my_favorite') return claims ? send(response, 200, { product_id: productId, is_favorite: body.p_favorite }) : send(response, 401, { code: 'no_session' });
        if (name === 'my_referral_summary') return claims ? send(response, 200, { code: 'BBE2E9K3', share_path: '/r/BBE2E9K3', program_active: false, attributed_count: 0, rewarded_count: 0, referrals: [] }) : send(response, 401, { code: 'no_session' });
        if (name === 'attribute_referral') return claims && body.p_code === 'BBINVITE42' ? send(response, 200, { attributed: true, referral_code: 'BBINVITE42' }) : send(response, 400, { code: 'invalid_referral_code', message: 'Referral code is invalid.' });
        if (name === 'update_my_profile') return send(response, 200, { preferred_language: body.p_preferred_language });
        if (name === 'set_preferred_branch') return claims && outlets.some((item) => item.id === body.p_branch_id) ? send(response, 200, { branch_id: body.p_branch_id }) : send(response, 400, { code: 'branch_unavailable' });
        if (name === 'my_orders') return claims ? send(response, 200, { orders: [] }) : send(response, 401, { code: 'no_session' });
        return send(response, 200, []);
    }

    if (url.pathname === '/rest/v1/addresses' && request.method === 'GET') return send(response, 200, []);
    if (url.pathname === '/functions/v1/create-order' && request.method === 'POST') {
        const body = await jsonBody(request);
        if (!claimsFor(request)) return send(response, 401, { message: 'Authentication required.' });
        if (body.payment_mode !== 'COD' || body.branch_id !== branchA) return send(response, 400, { message: 'Invalid E2E order intent.' });
        return send(response, 200, { order: { order_id: orderId, requires_payment: false } });
    }
    if (url.pathname.startsWith('/rest/v1/')) return send(response, 200, []);
    return send(response, 404, { message: 'Not found in deterministic storefront E2E fake' });
});

server.listen(port, host);
process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT', () => server.close(() => process.exit(0)));
