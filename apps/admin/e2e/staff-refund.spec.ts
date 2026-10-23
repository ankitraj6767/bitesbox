import { expect, test } from '@playwright/test';

function sessionCookie(email: string, aal: 'aal1' | 'aal2') {
    const now = Math.floor(Date.now() / 1000);
    const userId = email === 'operations@bitesbox.test'
        ? '00000000-0000-4000-8000-000000000002'
        : '00000000-0000-4000-8000-000000000001';
    const payload = Buffer.from(JSON.stringify({
        sub: userId,
        email,
        role: 'authenticated',
        aal,
        exp: now + 3600,
        amr: [{ method: 'password', timestamp: now }],
    })).toString('base64url');
    const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
    const signature = Buffer.from('deterministic-e2e-signature').toString('base64url');
    const accessToken = `${header}.${payload}.${signature}`;
    const value = Buffer.from(JSON.stringify({
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
    })).toString('base64url');
    return { name: 'sb-127-auth-token', value: `base64-${value}` };
}

test('staff signs in and is shown a safe error for invalid credentials', async ({ page }) => {
    await page.goto('/refunds');
    await expect(page).toHaveURL(/\/login\?next=/);
    await page.getByLabel('Email address').fill('owner@bitesbox.test');
    await page.locator('#password').fill('not-a-valid-password');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(page.getByText('Those credentials do not match an account.')).toBeVisible();
});

test('staff can sign in and reach the protected refund queue', async ({ page }) => {
    await page.goto('/login?next=%2Frefunds');
    await page.getByLabel('Email address').fill('owner@bitesbox.test');
    await page.locator('#password').fill('test-password');
    await page.getByRole('button', { name: 'Sign in' }).click();

    await expect(page).toHaveURL(/\/refunds$/);
    await expect(page.getByRole('heading', { name: 'Refunds' })).toBeVisible();
    await expect(page.getByText('BB-E2E-001')).toBeVisible();
});

test('AAL2 staff with refund permission can approve an eligible seeded refund', async ({ page }) => {
    await page.context().addCookies([{ ...sessionCookie('owner@bitesbox.test', 'aal2'), url: 'http://localhost:3100' }]);
    await page.goto('/refunds');
    await expect(page).toHaveURL(/\/refunds$/);
    await expect(page.getByRole('heading', { name: 'Refunds' })).toBeVisible();
    await expect(page.getByText('BB-E2E-001')).toBeVisible();

    const approval = page.waitForResponse((response) =>
        response.url().endsWith('/rest/v1/rpc/approve_refund') && response.request().method() === 'POST',
    );
    await page.getByRole('button', { name: 'Approve' }).click();
    const response = await approval;
    expect(response.status()).toBe(200);
    expect(response.request().postDataJSON()).toEqual({ p_refund_id: '00000000-0000-4000-8000-000000000201' });
    await expect(page.getByText(/Approved\./)).toBeVisible();
});

test('staff without refund permission is gated by the server-rendered route', async ({ page }) => {
    await page.context().addCookies([{ ...sessionCookie('operations@bitesbox.test', 'aal2'), url: 'http://localhost:3100' }]);
    await page.goto('/refunds');
    await expect(page).toHaveURL(/\/no-access\?permission=refund\.view/);
    await expect(page.getByRole('heading', { name: 'You do not have access to this area' })).toBeVisible();
});

test('staff at AAL1 is routed to the authenticator challenge before console access', async ({ page }) => {
    await page.context().addCookies([{ ...sessionCookie('aal1@bitesbox.test', 'aal1'), url: 'http://localhost:3100' }]);
    await page.goto('/refunds');
    await expect(page).toHaveURL(/\/mfa\?next=%2Frefunds/);
    await expect(page.getByRole('heading', { name: 'Secure staff sign-in' })).toBeVisible();
    await expect(page.getByLabel('Authenticator code')).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Refunds' })).toHaveCount(0);
});
