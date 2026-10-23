import { expect, test } from '@playwright/test';

function sessionCookie(email: string, aal: 'aal1' | 'aal2') {
    const now = Math.floor(Date.now() / 1000);
    const userId =
        email === 'operations@bitesbox.test'
            ? '00000000-0000-4000-8000-000000000002'
            : '00000000-0000-4000-8000-000000000001';
    const payload = Buffer.from(
        JSON.stringify({
            sub: userId,
            email,
            role: 'authenticated',
            aal,
            exp: now + 3600,
            amr: [{ method: 'password', timestamp: now }],
        }),
    ).toString('base64url');
    const header = Buffer.from(
        JSON.stringify({ alg: 'HS256', typ: 'JWT' }),
    ).toString('base64url');
    const signature = Buffer.from('deterministic-e2e-signature').toString(
        'base64url',
    );
    const accessToken = `${header}.${payload}.${signature}`;
    const value = Buffer.from(
        JSON.stringify({
            access_token: accessToken,
            token_type: 'bearer',
            expires_in: 3600,
            expires_at: now + 3600,
            refresh_token: `test-refresh-${userId}`,
            user: {
                id: userId,
                aud: 'authenticated',
                role: 'authenticated',
                email,
                phone: null,
                created_at: '2026-10-23T00:00:00.000Z',
                app_metadata: { provider: 'email', providers: ['email'] },
                user_metadata: { full_name: 'E2E staff' },
                identities: [],
            },
        }),
    ).toString('base64url');
    return { name: 'sb-127-auth-token', value: `base64-${value}` };
}

async function fakeZones(page: import('@playwright/test').Page) {
    const response = await page.request.get(
        'http://127.0.0.1:55320/__e2e/delivery-zones',
    );
    expect(response.ok()).toBe(true);
    return (await response.json()) as Array<Record<string, unknown>>;
}

test('staff signs in and is shown a safe error for invalid credentials', async ({
    page,
}) => {
    await page.goto('/refunds');
    await expect(page).toHaveURL(/\/login\?next=/);
    await page.getByLabel('Email address').fill('owner@bitesbox.test');
    await page.locator('#password').fill('not-a-valid-password');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(
        page.getByText('Those credentials do not match an account.'),
    ).toBeVisible();
});

test('staff can sign in and reach the protected refund queue', async ({
    page,
}) => {
    await page.goto('/login?next=%2Frefunds');
    await page.getByLabel('Email address').fill('owner@bitesbox.test');
    await page.locator('#password').fill('test-password');
    await page.getByRole('button', { name: 'Sign in' }).click();

    await expect(page).toHaveURL(/\/refunds$/);
    await expect(page.getByRole('heading', { name: 'Refunds' })).toBeVisible();
    await expect(page.getByText('BB-E2E-001')).toBeVisible();
});

test('AAL2 staff with refund permission can approve an eligible seeded refund', async ({
    page,
}) => {
    await page.context().addCookies([
        {
            ...sessionCookie('owner@bitesbox.test', 'aal2'),
            url: 'http://localhost:3100',
        },
    ]);
    await page.goto('/refunds');
    await expect(page).toHaveURL(/\/refunds$/);
    await expect(page.getByRole('heading', { name: 'Refunds' })).toBeVisible();
    await expect(page.getByText('BB-E2E-001')).toBeVisible();

    const approval = page.waitForResponse(
        (response) =>
            response.url().endsWith('/rest/v1/rpc/approve_refund') &&
            response.request().method() === 'POST',
    );
    await page.getByRole('button', { name: 'Approve' }).click();
    const response = await approval;
    expect(response.status()).toBe(200);
    expect(response.request().postDataJSON()).toEqual({
        p_refund_id: '00000000-0000-4000-8000-000000000201',
    });
    await expect(page.getByText(/Approved\./)).toBeVisible();
});

test('staff without refund permission is gated by the server-rendered route', async ({
    page,
}) => {
    await page.context().addCookies([
        {
            ...sessionCookie('operations@bitesbox.test', 'aal2'),
            url: 'http://localhost:3100',
        },
    ]);
    await page.goto('/refunds');
    await expect(page).toHaveURL(/\/no-access\?permission=refund\.view/);
    await expect(
        page.getByRole('heading', {
            name: 'You do not have access to this area',
        }),
    ).toBeVisible();
});

test('staff at AAL1 is routed to the authenticator challenge before console access', async ({
    page,
}) => {
    await page.context().addCookies([
        {
            ...sessionCookie('aal1@bitesbox.test', 'aal1'),
            url: 'http://localhost:3100',
        },
    ]);
    await page.goto('/refunds');
    await expect(page).toHaveURL(/\/mfa\?next=%2Frefunds/);
    await expect(
        page.getByRole('heading', { name: 'Secure staff sign-in' }),
    ).toBeVisible();
    await expect(page.getByLabel('Authenticator code')).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Refunds' })).toHaveCount(0);
});

test('branch selector accepts only a branch in the signed-in session scope', async ({
    page,
}) => {
    await page.context().addCookies([
        {
            ...sessionCookie('owner@bitesbox.test', 'aal2'),
            url: 'http://localhost:3100',
        },
    ]);
    await page.goto('/referrals');
    await expect(
        page.getByRole('heading', { name: 'Referrals' }),
    ).toBeVisible();
    const selector = page.getByLabel('Selected outlet');
    await expect(selector).toBeVisible();
    await expect(selector.locator('option')).toHaveCount(2);

    const selection = page.waitForResponse(
        (response) =>
            response.url().endsWith('/api/active-branch') &&
            response.request().method() === 'POST',
    );
    await selector.selectOption('00000000-0000-4000-8000-000000000102');
    expect((await selection).status()).toBe(200);
    await expect
        .poll(
            async () =>
                (await page.context().cookies()).find(
                    (cookie) => cookie.name === 'bb_active_branch',
                )?.value,
        )
        .toBe('00000000-0000-4000-8000-000000000102');

    const forbidden = await page.request.post('/api/active-branch', {
        data: { branchId: '00000000-0000-4000-8000-000000000999' },
    });
    expect(forbidden.status()).toBe(403);
});

test('branch-scoped admin only sees delivery-zone controls in the assigned outlet', async ({
    page,
}) => {
    const secondBranchId = '00000000-0000-4000-8000-000000000102';
    await page.context().addCookies([
        {
            ...sessionCookie('scoped-admin@bitesbox.test', 'aal2'),
            url: 'http://localhost:3100',
        },
        {
            name: 'bb_active_branch',
            value: secondBranchId,
            url: 'http://localhost:3100',
        },
    ]);
    await page.goto('/settings');
    await page.getByRole('tab', { name: 'Delivery' }).click();

    await expect(page.getByText('Patna outlet zone')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Add zone' })).toHaveCount(0);
    await expect(page.getByText(/does not include this outlet/i)).toBeVisible();
});

test('owner can configure referral terms while the independent rollout flag remains off', async ({
    page,
}) => {
    await page.context().addCookies([
        {
            ...sessionCookie('owner@bitesbox.test', 'aal2'),
            url: 'http://localhost:3100',
        },
    ]);
    await page.goto('/referrals');
    await expect(
        page.getByRole('heading', { name: 'Referrals' }),
    ).toBeVisible();
    await expect(page.getByText('Rollout flag off')).toBeVisible();
    await page.getByLabel('Referrer wallet reward (₹)').fill('25');
    await page.getByLabel('Referred customer wallet reward (₹)').fill('30');
    await page.getByLabel('Minimum qualifying order (₹)').fill('300');
    await page
        .getByLabel('Maximum rewarded referrals per customer (optional)')
        .fill('5');
    await page.getByLabel('Reward expiry in days (optional)').fill('90');

    const save = page.waitForResponse(
        (response) =>
            response.url().endsWith('/rest/v1/rpc/update_referral_program') &&
            response.request().method() === 'POST',
    );
    await page.getByRole('button', { name: 'Save terms' }).click();
    const response = await save;
    expect(response.status()).toBe(200);
    expect(response.request().postDataJSON()).toMatchObject({
        p_enabled: false,
        p_referrer_reward: 25,
        p_referred_reward: 30,
        p_minimum_order_amount: 300,
        p_max_rewards_per_referrer: 5,
        p_reward_expiry_days: 90,
    });
    await expect(
        page.getByText(
            'Referral terms saved. The rollout flag remains independent.',
        ),
    ).toBeVisible();
    await expect(page.getByText('Rollout flag off')).toBeVisible();
});

test('support ticket detail resolves its explicit refund relationship', async ({
    page,
}) => {
    const ticketId = '00000000-0000-4000-8000-000000000501';
    await page.context().addCookies([
        {
            ...sessionCookie('owner@bitesbox.test', 'aal2'),
            url: 'http://localhost:3100',
        },
    ]);
    await page.goto(`/support/${ticketId}`);
    await expect(page.getByText('BB-T-E2E-001', { exact: true })).toBeVisible();
    await expect(page.getByText('Missing item from delivery')).toBeVisible();
    await expect(page.getByText('Refund raised')).toBeVisible();
    await expect(page.getByText('Support Tester').first()).toBeVisible();
});

test('branch manager can create, edit, dynamically pause, and delete delivery zones', async ({
    page,
}) => {
    const secondBranchId = '00000000-0000-4000-8000-000000000102';
    const name = `QA Zone ${Date.now()}`;
    await page.context().addCookies([
        {
            ...sessionCookie('owner@bitesbox.test', 'aal2'),
            url: 'http://localhost:3100',
        },
    ]);
    await page.goto('/settings');
    await page.getByRole('tab', { name: 'Delivery' }).click();
    await expect(page.getByText('Bakhtiyarpur Town')).toBeVisible();
    await expect(page.getByText('Patna outlet zone')).toHaveCount(0);

    await page.getByRole('button', { name: 'Add zone' }).click();
    await page.getByLabel('Zone name').fill(name);
    await page.getByRole('button', { name: 'Create zone' }).click();
    await expect(page.getByText(name)).toBeVisible();
    const created = (await fakeZones(page)).find((zone) => zone.name === name);
    expect(created).toMatchObject({
        branch_id: '00000000-0000-4000-8000-000000000101',
        name,
        is_active: true,
    });

    await page.getByRole('button', { name: `Edit ${name}` }).click();
    await page.getByLabel('Delivery fee (₹)').fill('44');
    await page.getByRole('button', { name: 'Save changes' }).click();
    const editedRow = page.locator('tr').filter({ hasText: name });
    await expect(editedRow.getByText('₹44')).toBeVisible();
    expect(
        (await fakeZones(page)).find((zone) => zone.name === name)
            ?.delivery_fee,
    ).toBe(44);

    await page.getByRole('switch', { name: `Enable ${name}` }).click();
    await expect(editedRow.getByText('Paused')).toBeVisible();
    expect(
        (await fakeZones(page)).find((zone) => zone.name === name)?.is_active,
    ).toBe(false);

    await page.getByRole('switch', { name: `Enable ${name}` }).click();
    await expect(editedRow.getByText('Serviceable')).toBeVisible();
    expect(
        (await fakeZones(page)).find((zone) => zone.name === name)?.is_active,
    ).toBe(true);

    await page
        .getByRole('switch', { name: `Make ${name} serviceable` })
        .click();
    await expect(editedRow.getByText('Not serviceable')).toBeVisible();
    expect(
        (await fakeZones(page)).find((zone) => zone.name === name)
            ?.is_serviceable,
    ).toBe(false);

    await page.getByRole('button', { name: `Delete ${name}` }).click();
    await page.getByLabel(`Type ${name} to confirm`).fill(name);
    await page.getByRole('button', { name: 'Delete zone' }).click();
    await expect(page.getByText(name)).toHaveCount(0);
    const removed = (await fakeZones(page)).find((zone) => zone.name === name);
    expect(removed).toMatchObject({ is_active: false });
    expect(removed?.deleted_at).toEqual(expect.any(String));

    const branchChange = page.waitForResponse((response) =>
        response.url().endsWith('/api/active-branch'),
    );
    await page.getByLabel('Selected outlet').selectOption(secondBranchId);
    expect((await branchChange).status()).toBe(200);
    await expect(page.getByText('Patna outlet zone')).toBeVisible();
    await expect(page.getByText('Bakhtiyarpur Town')).toHaveCount(0);
});
