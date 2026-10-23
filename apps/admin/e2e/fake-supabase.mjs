import { createServer } from 'node:http';

const host = '127.0.0.1';
const port = 55320;
const branchId = '00000000-0000-4000-8000-000000000101';
const secondBranchId = '00000000-0000-4000-8000-000000000102';
const refundId = '00000000-0000-4000-8000-000000000201';
const ownerId = '00000000-0000-4000-8000-000000000001';
const operationsId = '00000000-0000-4000-8000-000000000002';

const ownerPermissions = [
    'refund.view',
    'refund.approve',
    'refund.reject',
    'order.view',
    'customer.view',
    'payment.view',
    'audit.view',
    'referral.manage',
];

const order = {
    order_number: 'BB-E2E-001',
    customer_name: 'E2E customer',
    grand_total: 500,
};

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

function getClaims(request) {
    const token = request.headers.authorization?.replace(/^Bearer\s+/i, '');
    if (!token) return null;
    try {
        const encoded = token.split('.')[1];
        return JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
    } catch {
        return null;
    }
}

function getUser(claims) {
    if (!claims?.sub) return null;
    const isNoRefund = claims.email === 'operations@bitesbox.test';
    const hasAal1Factor = claims.email === 'aal1@bitesbox.test';
    return {
        id: claims.sub,
        aud: 'authenticated',
        role: 'authenticated',
        email: claims.email,
        phone: null,
        created_at: '2026-10-23T00:00:00.000Z',
        app_metadata: { provider: 'email', providers: ['email'] },
        user_metadata: {
            full_name: isNoRefund ? 'Operations Tester' : 'Owner Tester',
        },
        factors: hasAal1Factor
            ? [{ id: 'factor-e2e-1', factor_type: 'totp', status: 'verified', friendly_name: 'Test authenticator' }]
            : [],
        identities: [],
    };
}

function sessionFor(claims) {
    const isNoRefund = claims.email === 'operations@bitesbox.test';
    const isAal1 = claims.email === 'aal1@bitesbox.test';
    const role = isNoRefund ? 'OPERATIONS' : 'OWNER';
    const permissions = isNoRefund ? ['order.view'] : ownerPermissions;
    return {
        authenticated: true,
        user_id: claims.sub,
        profile: {
            id: claims.sub,
            phone: null,
            email: claims.email,
            full_name: isNoRefund ? 'Operations Tester' : 'Owner Tester',
            avatar_url: null,
            status: 'ACTIVE',
            preferred_language: 'en',
            onboarding_completed: true,
            total_orders: 0,
            marketing_opt_in: false,
            push_enabled: true,
            sms_enabled: true,
            email_enabled: true,
            whatsapp_enabled: false,
        },
        primary_role: role,
        roles: [{
            role,
            label: role === 'OWNER' ? 'Owner' : 'Operations',
            branch_id: branchId,
            is_primary: true,
            surfaces: ['admin'],
        }],
        permissions,
        branches: [
            { id: branchId, code: 'BKP', name: 'Bakhtiyarpur', status: 'OPEN' },
            { id: secondBranchId, code: 'PAT', name: 'Patna Test Outlet', status: 'OPEN' },
        ],
        account_active: true,
        test_factor_pending: isAal1,
    };
}

function jwtFor(email) {
    const isAal1 = email === 'aal1@bitesbox.test';
    const sub = isAal1 ? ownerId : email === 'operations@bitesbox.test' ? operationsId : ownerId;
    const payload = {
        sub,
        email,
        role: 'authenticated',
        aal: isAal1 ? 'aal1' : 'aal2',
        exp: Math.floor(Date.now() / 1000) + 3600,
        amr: [{ method: 'password', timestamp: Math.floor(Date.now() / 1000) }],
    };
    const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
    const signature = Buffer.from('deterministic-e2e-signature').toString('base64url');
    return `${header}.${Buffer.from(JSON.stringify(payload)).toString('base64url')}.${signature}`;
}

const server = createServer(async (request, response) => {
    const url = new URL(request.url ?? '/', `http://${request.headers.host ?? `${host}:${port}`}`);
    if (request.method === 'OPTIONS') return send(response, 204);
    if (url.pathname === '/health') return send(response, 200, { ok: true });

    if (url.pathname === '/auth/v1/token' && url.searchParams.get('grant_type') === 'password') {
        const body = await jsonBody(request);
        if (body.password !== 'test-password') {
            return send(response, 400, { code: 'invalid_credentials', msg: 'Invalid login credentials' });
        }
        const email = String(body.email ?? '').toLowerCase();
        const accessToken = jwtFor(email);
        const claims = getClaims({ headers: { authorization: `Bearer ${accessToken}` } });
        const now = Math.floor(Date.now() / 1000);
        return send(response, 200, {
            access_token: accessToken,
            token_type: 'bearer',
            expires_in: 3600,
            expires_at: now + 3600,
            refresh_token: `test-refresh-${claims.sub}`,
            user: getUser(claims),
        });
    }

    if (url.pathname === '/auth/v1/user') {
        const user = getUser(getClaims(request));
        return user
            ? send(response, 200, user)
            : send(response, 401, { code: 'no_session', message: 'No session' });
    }

    if (url.pathname === '/auth/v1/aal') {
        const claims = getClaims(request);
        return claims
            ? send(response, 200, {
                currentLevel: claims.aal,
                nextLevel: claims.email === 'aal1@bitesbox.test' ? 'aal2' : claims.aal,
            })
            : send(response, 401, { code: 'no_session', message: 'No session' });
    }

    if (url.pathname === '/auth/v1/factors') {
        const claims = getClaims(request);
        const factors = claims?.email === 'aal1@bitesbox.test'
            ? [{ id: 'factor-e2e-1', factor_type: 'totp', status: 'verified', friendly_name: 'Test authenticator' }]
            : [];
        return claims
            ? send(response, 200, { all: factors, totp: factors, phone: [] })
            : send(response, 401, { code: 'no_session', message: 'No session' });
    }

    if (url.pathname === '/auth/v1/token' && url.searchParams.get('grant_type') === 'refresh_token') {
        const claims = getClaims(request);
        if (!claims) return send(response, 401, { code: 'no_session', message: 'No session' });
        const now = Math.floor(Date.now() / 1000);
        const accessToken = jwtFor(claims.email);
        return send(response, 200, {
            access_token: accessToken,
            token_type: 'bearer',
            expires_in: 3600,
            expires_at: now + 3600,
            refresh_token: `test-refresh-${claims.sub}`,
            user: getUser(getClaims({ headers: { authorization: `Bearer ${accessToken}` } })),
        });
    }

    if (url.pathname.startsWith('/rest/v1/rpc/')) {
        const name = url.pathname.split('/').at(-1);
        const claims = getClaims(request);
        if (name === 'my_session') {
            return claims
                ? send(response, 200, sessionFor(claims))
                : send(response, 401, { code: 'no_session', message: 'No session' });
        }
        if (name === 'branch_ordering_state') return send(response, 200, null);
        if (name === 'referral_admin_overview') {
            return send(response, 200, {
                settings: {
                    enabled: false,
                    referrer_reward: null,
                    referred_reward: null,
                    minimum_order_amount: null,
                    max_rewards_per_referrer: null,
                    reward_expiry_days: null,
                },
                feature_flag_enabled: false,
                metrics: { attributed: 0, qualified: 0, rewarded: 0, reversed: 0 },
                activity: [],
            });
        }
        if (name === 'update_referral_program' && request.method === 'POST') {
            const body = await jsonBody(request);
            return send(response, 200, {
                id: true,
                enabled: body.p_enabled,
                referrer_reward: body.p_referrer_reward,
                referred_reward: body.p_referred_reward,
                minimum_order_amount: body.p_minimum_order_amount,
                max_rewards_per_referrer: body.p_max_rewards_per_referrer,
                reward_expiry_days: body.p_reward_expiry_days ?? null,
            });
        }
        if (name === 'approve_refund' && request.method === 'POST') {
            const body = await jsonBody(request);
            if (!claims || claims.email !== 'owner@bitesbox.test') {
                return send(response, 403, { code: 'permission_denied', message: 'Permission denied' });
            }
            if (body.p_refund_id !== refundId) {
                return send(response, 404, { code: 'refund_not_found', message: 'Refund not found' });
            }
            return send(response, 200, {
                refund_id: refundId,
                status: 'APPROVED',
                requires_gateway_call: true,
                amount: 250,
            });
        }
        return send(response, 200, []);
    }

    if (url.pathname === '/rest/v1/refunds' && request.method === 'GET') {
        return send(response, 200, [{
            id: refundId,
            order_id: '00000000-0000-4000-8000-000000000301',
            status: 'APPROVAL_PENDING',
            kind: 'FULL_REFUND',
            reason: 'QUALITY_ISSUE',
            reason_note: null,
            destination: 'ORIGINAL_PAYMENT_METHOD',
            amount: 250,
            amount_processed: 0,
            created_at: '2026-10-23T08:00:00.000Z',
            completed_at: null,
            requested_by: '00000000-0000-4000-8000-000000000004',
            orders: order,
            requester: { full_name: 'Support Tester' },
        }]);
    }

    if (url.pathname.startsWith('/rest/v1/')) {
        if (request.method === 'HEAD') {
            response.writeHead(200, { 'content-range': '0-0/0' });
            return response.end();
        }
        return send(response, 200, []);
    }

    send(response, 404, { message: 'Not found in deterministic E2E Supabase fake' });
});

server.listen(port, host);
process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT', () => server.close(() => process.exit(0)));
