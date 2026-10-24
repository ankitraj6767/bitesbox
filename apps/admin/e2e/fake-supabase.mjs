import { createServer } from 'node:http';

const host = '127.0.0.1';
const port = 55320;
const branchId = '00000000-0000-4000-8000-000000000101';
const secondBranchId = '00000000-0000-4000-8000-000000000102';
const refundId = '00000000-0000-4000-8000-000000000201';
const ownerId = '00000000-0000-4000-8000-000000000001';
const operationsId = '00000000-0000-4000-8000-000000000002';
const scopedAdminId = '00000000-0000-4000-8000-000000000003';
const supportTicketId = '00000000-0000-4000-8000-000000000501';
const supportTicketNumber = 'BB-T-E2E-001';
let zoneSequence = 0;
const defaultReferralSettings = {
    enabled: false,
    referrer_reward: null,
    referred_reward: null,
    minimum_order_amount: null,
    max_rewards_per_referrer: null,
    reward_expiry_days: null,
};
let referralSettings = { ...defaultReferralSettings };
let referralFlagEnabled = false;

const branches = [
    {
        id: branchId,
        code: 'BKP-01',
        name: 'Bites Box Bakhtiyarpur',
        legal_name: 'Bites Box Foods Private Limited',
        phone: '+919431100100',
        alternate_phone: null,
        whatsapp_phone: '+919431100100',
        email: 'bakhtiyarpur@bitesbox.test',
        address_line1: 'Station Road',
        address_line2: 'Near Bakhtiyarpur Junction',
        landmark: 'Ward 12',
        city: 'Bakhtiyarpur',
        state: 'Bihar',
        postal_code: '803212',
        latitude: 25.46,
        longitude: 85.51,
        google_maps_url: 'https://maps.google.com/?q=25.46,85.51',
        gstin: '10ABCDE1234F1Z5',
        fssai_licence_no: '20424001000123',
        fssai_valid_till: '2027-03-31',
        timezone: 'Asia/Kolkata',
        service_mode: 'BOTH',
        default_prep_minutes: 22,
        rush_buffer_minutes: 0,
        max_concurrent_orders: 40,
        is_active: true,
        is_default: true,
        deleted_at: null,
    },
    {
        id: secondBranchId,
        code: 'PAT-01',
        name: 'Patna Test Outlet',
        legal_name: 'Bites Box Foods Private Limited',
        phone: '+919431100101',
        alternate_phone: null,
        whatsapp_phone: null,
        email: 'patna@bitesbox.test',
        address_line1: 'Test Road',
        address_line2: null,
        landmark: null,
        city: 'Patna',
        state: 'Bihar',
        postal_code: '800001',
        latitude: 25.61,
        longitude: 85.14,
        google_maps_url: null,
        gstin: null,
        fssai_licence_no: null,
        fssai_valid_till: null,
        timezone: 'Asia/Kolkata',
        service_mode: 'BOTH',
        default_prep_minutes: 30,
        rush_buffer_minutes: 0,
        max_concurrent_orders: null,
        is_active: true,
        is_default: false,
        deleted_at: null,
    },
];

const zones = [
    {
        id: '00000000-0000-4000-8000-000000000401',
        branch_id: branchId,
        name: 'Bakhtiyarpur Town',
        description: 'Town core',
        kind: 'RADIUS',
        min_distance_km: 0,
        max_distance_km: 3,
        polygon: null,
        delivery_fee: 20,
        min_order_amount: 99,
        free_delivery_threshold: 349,
        per_km_surcharge: 0,
        surcharge_after_km: null,
        peak_surcharge: 10,
        peak_starts_at: '19:30:00',
        peak_ends_at: '22:00:00',
        dynamic_surcharge: 0,
        base_eta_minutes: 25,
        extra_eta_minutes: 0,
        cod_enabled: true,
        max_cod_amount: 2000,
        is_serviceable: true,
        is_active: true,
        priority: 10,
        deleted_at: null,
    },
    {
        id: '00000000-0000-4000-8000-000000000402',
        branch_id: secondBranchId,
        name: 'Patna outlet zone',
        description: 'Second outlet test zone',
        kind: 'RADIUS',
        min_distance_km: 0,
        max_distance_km: 5,
        polygon: null,
        delivery_fee: 30,
        min_order_amount: 149,
        free_delivery_threshold: null,
        per_km_surcharge: 0,
        surcharge_after_km: null,
        peak_surcharge: 0,
        peak_starts_at: null,
        peak_ends_at: null,
        dynamic_surcharge: 0,
        base_eta_minutes: 35,
        extra_eta_minutes: 0,
        cod_enabled: true,
        max_cod_amount: null,
        is_serviceable: true,
        is_active: true,
        priority: 10,
        deleted_at: null,
    },
];

const ownerPermissions = [
    'refund.view',
    'refund.approve',
    'refund.reject',
    'order.view',
    'customer.view',
    'payment.view',
    'audit.view',
    'referral.manage',
    'support.view',
    'support.respond',
    'support.close',
    'settings.view',
    'settings.update',
    'branch.manage',
    'feature_flag.update',
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
        'access-control-allow-methods':
            'GET, POST, PATCH, DELETE, HEAD, OPTIONS',
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
    const isScopedAdmin = claims.email === 'scoped-admin@bitesbox.test';
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
            full_name: isNoRefund
                ? 'Operations Tester'
                : isScopedAdmin
                  ? 'Scoped Admin Tester'
                  : 'Owner Tester',
        },
        factors: hasAal1Factor
            ? [
                  {
                      id: 'factor-e2e-1',
                      factor_type: 'totp',
                      status: 'verified',
                      friendly_name: 'Test authenticator',
                  },
              ]
            : [],
        identities: [],
    };
}

function sessionFor(claims) {
    const isNoRefund = claims.email === 'operations@bitesbox.test';
    const isScopedAdmin = claims.email === 'scoped-admin@bitesbox.test';
    const isAal1 = claims.email === 'aal1@bitesbox.test';
    const role = isNoRefund ? 'OPERATIONS' : isScopedAdmin ? 'ADMIN' : 'OWNER';
    const permissions = isNoRefund ? ['order.view'] : ownerPermissions;
    return {
        authenticated: true,
        user_id: claims.sub,
        profile: {
            id: claims.sub,
            phone: null,
            email: claims.email,
            full_name: isNoRefund
                ? 'Operations Tester'
                : isScopedAdmin
                  ? 'Scoped Admin Tester'
                  : 'Owner Tester',
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
        roles: isScopedAdmin
            ? [
                  {
                      role: 'ADMIN',
                      label: 'Administrator',
                      branch_id: branchId,
                      is_primary: true,
                      surfaces: ['admin'],
                  },
                  {
                      role: 'OPERATIONS',
                      label: 'Operations',
                      branch_id: secondBranchId,
                      is_primary: false,
                      surfaces: ['admin'],
                  },
              ]
            : [
                  {
                      role,
                      label:
                          role === 'OWNER'
                              ? 'Owner'
                              : role === 'OPERATIONS'
                                ? 'Operations'
                                : 'Administrator',
                      branch_id: branchId,
                      is_primary: true,
                      surfaces: ['admin'],
                  },
              ],
        permissions,
        branches: [
            { id: branchId, code: 'BKP', name: 'Bakhtiyarpur', status: 'OPEN' },
            {
                id: secondBranchId,
                code: 'PAT',
                name: 'Patna Test Outlet',
                status: 'OPEN',
            },
        ],
        account_active: true,
        test_factor_pending: isAal1,
    };
}

function singularOrArray(request, rows) {
    return request.headers.accept?.includes('application/vnd.pgrst.object+json')
        ? (rows[0] ?? null)
        : rows;
}

function jwtFor(email) {
    const isAal1 = email === 'aal1@bitesbox.test';
    const sub = isAal1
        ? ownerId
        : email === 'scoped-admin@bitesbox.test'
          ? scopedAdminId
          : email === 'operations@bitesbox.test'
            ? operationsId
            : ownerId;
    const payload = {
        sub,
        email,
        role: 'authenticated',
        aal: isAal1 ? 'aal1' : 'aal2',
        exp: Math.floor(Date.now() / 1000) + 3600,
        amr: [{ method: 'password', timestamp: Math.floor(Date.now() / 1000) }],
    };
    const header = Buffer.from(
        JSON.stringify({ alg: 'HS256', typ: 'JWT' }),
    ).toString('base64url');
    const signature = Buffer.from('deterministic-e2e-signature').toString(
        'base64url',
    );
    return `${header}.${Buffer.from(JSON.stringify(payload)).toString('base64url')}.${signature}`;
}

const server = createServer(async (request, response) => {
    const url = new URL(
        request.url ?? '/',
        `http://${request.headers.host ?? `${host}:${port}`}`,
    );
    if (request.method === 'OPTIONS') return send(response, 204);
    if (url.pathname === '/health') return send(response, 200, { ok: true });
    if (url.pathname === '/__e2e/delivery-zones') {
        return send(response, 200, zones);
    }
    if (url.pathname === '/__e2e/branches') {
        return send(response, 200, branches);
    }
    if (url.pathname === '/__e2e/reset-referrals' && request.method === 'POST') {
        referralSettings = { ...defaultReferralSettings };
        referralFlagEnabled = false;
        return send(response, 200, { ok: true });
    }
    if (url.pathname === '/__e2e/referral-state') {
        return send(response, 200, {
            settings: referralSettings,
            feature_flag_enabled: referralFlagEnabled,
        });
    }

    if (
        url.pathname === '/auth/v1/token' &&
        url.searchParams.get('grant_type') === 'password'
    ) {
        const body = await jsonBody(request);
        if (body.password !== 'test-password') {
            return send(response, 400, {
                code: 'invalid_credentials',
                msg: 'Invalid login credentials',
            });
        }
        const email = String(body.email ?? '').toLowerCase();
        const accessToken = jwtFor(email);
        const claims = getClaims({
            headers: { authorization: `Bearer ${accessToken}` },
        });
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
            : send(response, 401, {
                  code: 'no_session',
                  message: 'No session',
              });
    }

    if (url.pathname === '/auth/v1/aal') {
        const claims = getClaims(request);
        return claims
            ? send(response, 200, {
                  currentLevel: claims.aal,
                  nextLevel:
                      claims.email === 'aal1@bitesbox.test'
                          ? 'aal2'
                          : claims.aal,
              })
            : send(response, 401, {
                  code: 'no_session',
                  message: 'No session',
              });
    }

    if (url.pathname === '/auth/v1/factors') {
        const claims = getClaims(request);
        const factors =
            claims?.email === 'aal1@bitesbox.test'
                ? [
                      {
                          id: 'factor-e2e-1',
                          factor_type: 'totp',
                          status: 'verified',
                          friendly_name: 'Test authenticator',
                      },
                  ]
                : [];
        return claims
            ? send(response, 200, { all: factors, totp: factors, phone: [] })
            : send(response, 401, {
                  code: 'no_session',
                  message: 'No session',
              });
    }

    if (
        url.pathname === '/auth/v1/token' &&
        url.searchParams.get('grant_type') === 'refresh_token'
    ) {
        const claims = getClaims(request);
        if (!claims)
            return send(response, 401, {
                code: 'no_session',
                message: 'No session',
            });
        const now = Math.floor(Date.now() / 1000);
        const accessToken = jwtFor(claims.email);
        return send(response, 200, {
            access_token: accessToken,
            token_type: 'bearer',
            expires_in: 3600,
            expires_at: now + 3600,
            refresh_token: `test-refresh-${claims.sub}`,
            user: getUser(
                getClaims({
                    headers: { authorization: `Bearer ${accessToken}` },
                }),
            ),
        });
    }

    if (url.pathname.startsWith('/rest/v1/rpc/')) {
        const name = url.pathname.split('/').at(-1);
        const claims = getClaims(request);
        if (name === 'has_permission') {
            const body = await jsonBody(request);
            if (!claims) {
                return send(response, 401, {
                    code: 'no_session',
                    message: 'No session',
                });
            }
            const canManage =
                claims.email === 'owner@bitesbox.test' ||
                (claims.email === 'scoped-admin@bitesbox.test' &&
                    body.p_branch_id === branchId);
            return send(
                response,
                200,
                canManage && body.p_permission === 'branch.manage',
            );
        }
        if (name === 'my_session') {
            return claims
                ? send(response, 200, sessionFor(claims))
                : send(response, 401, {
                      code: 'no_session',
                      message: 'No session',
                  });
        }
        if (name === 'branch_ordering_state') return send(response, 200, null);
        if (name === 'referral_admin_overview') {
            return send(response, 200, {
                settings: referralSettings,
                feature_flag_enabled: referralFlagEnabled,
                metrics: {
                    attributed: 0,
                    qualified: 0,
                    rewarded: 0,
                    reversed: 0,
                },
                activity: [],
            });
        }
        if (name === 'update_referral_program' && request.method === 'POST') {
            const body = await jsonBody(request);
            referralSettings = {
                enabled: body.p_enabled,
                referrer_reward: body.p_referrer_reward,
                referred_reward: body.p_referred_reward,
                minimum_order_amount: body.p_minimum_order_amount,
                max_rewards_per_referrer: body.p_max_rewards_per_referrer,
                reward_expiry_days: body.p_reward_expiry_days ?? null,
            };
            return send(response, 200, {
                id: true,
                ...referralSettings,
            });
        }
        if (name === 'approve_refund' && request.method === 'POST') {
            const body = await jsonBody(request);
            if (!claims || claims.email !== 'owner@bitesbox.test') {
                return send(response, 403, {
                    code: 'permission_denied',
                    message: 'Permission denied',
                });
            }
            if (body.p_refund_id !== refundId) {
                return send(response, 404, {
                    code: 'refund_not_found',
                    message: 'Refund not found',
                });
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
        return send(response, 200, [
            {
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
            },
        ]);
    }

    if (url.pathname === '/rest/v1/delivery_zones') {
        if (request.method === 'HEAD') {
            response.writeHead(200, {
                'content-range': `0-0/${zones.filter((zone) => zone.deleted_at === null).length}`,
            });
            return response.end();
        }

        if (request.method === 'GET') {
            const branchFilter = url.searchParams.get('branch_id');
            const branch = branchFilter?.startsWith('eq.')
                ? branchFilter.slice(3)
                : null;
            const rows = zones
                .filter(
                    (zone) =>
                        zone.deleted_at === null &&
                        (!branch || zone.branch_id === branch),
                )
                .sort((left, right) => left.priority - right.priority);
            return send(response, 200, singularOrArray(request, rows));
        }

        if (request.method === 'POST') {
            const body = await jsonBody(request);
            const insert = Array.isArray(body) ? body[0] : body;
            zoneSequence += 1;
            const created = {
                ...insert,
                id: `00000000-0000-4000-8000-${String(500 + zoneSequence).padStart(12, '0')}`,
                deleted_at: null,
            };
            zones.push(created);
            return send(response, 201, singularOrArray(request, [created]));
        }

        if (request.method === 'PATCH') {
            const body = await jsonBody(request);
            const idFilter = url.searchParams.get('id');
            const branchFilter = url.searchParams.get('branch_id');
            const id = idFilter?.startsWith('eq.') ? idFilter.slice(3) : null;
            const branch = branchFilter?.startsWith('eq.')
                ? branchFilter.slice(3)
                : null;
            const found = zones.filter(
                (zone) =>
                    zone.id === id &&
                    zone.branch_id === branch &&
                    zone.deleted_at === null,
            );
            for (const zone of found) Object.assign(zone, body);
            return send(response, 200, singularOrArray(request, found));
        }
    }

    if (url.pathname === '/rest/v1/branches') {
        if (request.method === 'HEAD') {
            const idFilter = url.searchParams.get('id');
            const excludedId = idFilter?.startsWith('neq.') ? idFilter.slice(4) : null;
            const count = branches.filter(
                (branch) => branch.is_active && branch.deleted_at === null && branch.id !== excludedId,
            ).length;
            response.writeHead(200, {
                'content-range': count === 0 ? '0-0/0' : `0-${count - 1}/${count}`,
            });
            return response.end();
        }

        if (request.method === 'GET') {
            const idFilter = url.searchParams.get('id');
            const id = idFilter?.startsWith('eq.') ? idFilter.slice(3) : null;
            const rows = branches.filter((branch) => branch.deleted_at === null && (!id || branch.id === id));
            return send(response, 200, singularOrArray(request, rows));
        }

        if (request.method === 'PATCH') {
            const body = await jsonBody(request);
            const idFilter = url.searchParams.get('id');
            const id = idFilter?.startsWith('eq.') ? idFilter.slice(3) : null;
            const changed = branches.filter((branch) => branch.id === id && branch.deleted_at === null);
            for (const branch of changed) Object.assign(branch, body);
            return send(response, 200, singularOrArray(request, changed));
        }
    }

    if (url.pathname === '/rest/v1/feature_flags' && request.method === 'PATCH') {
        const claims = getClaims(request);
        const keyFilter = url.searchParams.get('key');
        const body = await jsonBody(request);
        if (!claims || claims.email !== 'owner@bitesbox.test') {
            return send(response, 403, {
                code: 'permission_denied',
                message: 'Permission denied',
            });
        }
        if (keyFilter === 'eq.referrals' && typeof body.is_enabled === 'boolean') {
            referralFlagEnabled = body.is_enabled;
        }
        const row = { key: 'referrals', is_enabled: referralFlagEnabled };
        return send(response, 200, singularOrArray(request, [row]));
    }

    if (
        url.pathname === '/rest/v1/support_tickets' &&
        request.method === 'GET'
    ) {
        const select = url.searchParams.get('select') ?? '';
        if (
            select.includes('refunds(') &&
            !select.includes('refunds!support_tickets_refund_id_fkey(')
        ) {
            return send(response, 400, {
                code: 'PGRST201',
                message:
                    'Could not embed because more than one relationship was found for refunds and support_tickets.',
                details:
                    'Use the explicit support_tickets_refund_id_fkey relationship.',
            });
        }

        const ticket = {
            id: supportTicketId,
            ticket_number: supportTicketNumber,
            category: 'MISSING_ITEM',
            subject: 'Missing item from delivery',
            description: 'One item was missing from my order.',
            status: 'OPEN',
            priority: 'NORMAL',
            created_at: '2026-10-23T08:00:00.000Z',
            last_message_at: '2026-10-23T08:05:00.000Z',
            first_response_due_at: '2026-10-23T09:00:00.000Z',
            first_response_at: null,
            resolved_at: null,
            resolution_note: null,
            satisfaction_rating: null,
            wallet_credit_amount: 0,
            order_id: '00000000-0000-4000-8000-000000000301',
            refund_id: refundId,
            assigned_to: null,
            profiles: {
                id: '00000000-0000-4000-8000-000000000004',
                full_name: 'Support Tester',
                phone: '+919900000004',
                email: 'support-tester@bitesbox.test',
                completed_orders: 2,
                lifetime_value: 900,
            },
            orders: {
                id: '00000000-0000-4000-8000-000000000301',
                order_number: 'BB-E2E-001',
                status: 'DELIVERED',
                grand_total: 500,
                refunded_amount: 0,
            },
            refunds: {
                id: refundId,
                amount: 250,
                status: 'APPROVAL_PENDING',
                destination: 'ORIGINAL_PAYMENT_METHOD',
            },
        };

        const idFilter = url.searchParams.get('id');
        const statusFilter = url.searchParams.get('status');
        const isDetail =
            idFilter?.startsWith('eq.') &&
            idFilter.slice(3) === supportTicketId;
        const isOpen = statusFilter?.includes('OPEN');
        const rows = isDetail || isOpen ? [ticket] : [];
        return send(response, 200, singularOrArray(request, rows));
    }

    if (
        url.pathname === '/rest/v1/support_messages' &&
        request.method === 'GET'
    ) {
        return send(response, 200, [
            {
                id: '00000000-0000-4000-8000-000000000601',
                author_kind: 'CUSTOMER',
                body: 'One item was missing from my order.',
                is_internal: false,
                created_at: '2026-10-23T08:05:00.000Z',
                author: { full_name: 'Support Tester' },
            },
        ]);
    }

    if (url.pathname.startsWith('/rest/v1/')) {
        if (request.method === 'HEAD') {
            response.writeHead(200, { 'content-range': '0-0/0' });
            return response.end();
        }
        return send(response, 200, []);
    }

    send(response, 404, {
        message: 'Not found in deterministic E2E Supabase fake',
    });
});

server.listen(port, host);
process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT', () => server.close(() => process.exit(0)));
