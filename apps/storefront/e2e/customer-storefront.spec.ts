import { expect, test } from '@playwright/test';

const productId = '00000000-0000-4000-8000-000000000201';
const userId = '00000000-0000-4000-8000-000000000301';

function sessionCookie() {
    const now = Math.floor(Date.now() / 1000);
    const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
    const payload = Buffer.from(JSON.stringify({ sub: userId, role: 'authenticated', aal: 'aal1', exp: now + 3600 })).toString('base64url');
    const token = `${header}.${payload}.e2e-signature`;
    const value = Buffer.from(JSON.stringify({
        access_token: token,
        token_type: 'bearer',
        expires_in: 3600,
        expires_at: now + 3600,
        refresh_token: 'e2e-refresh-token',
        user: { id: userId, aud: 'authenticated', role: 'authenticated', phone: '+919999000001', created_at: '2026-10-23T00:00:00.000Z', app_metadata: { provider: 'phone', providers: ['phone'] }, user_metadata: {}, identities: [] },
    })).toString('base64url');
    return { name: 'sb-127-auth-token', value: `base64-${value}` };
}

test('guest browses, switches outlet and language, and adds a dish to the branch cart', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Food made for your cravings.' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Litti Chokha', exact: true })).toBeVisible();

    const savedLocale = page.waitForResponse((response) => response.url().endsWith('/api/customer-preferences') && response.request().method() === 'POST');
    await page.getByLabel('Language').selectOption('hi');
    expect((await savedLocale).status()).toBe(200);
    await page.reload();
    await expect(page.getByRole('heading', { name: 'आपकी पसंद का स्वाद।' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'लिट्टी चोखा', exact: true })).toBeVisible();

    await page.getByLabel('चुना हुआ आउटलेट').selectOption('00000000-0000-4000-8000-000000000102');
    await expect(page.getByText('हर आउटलेट का अलग कार्ट है। बदलने पर उस आउटलेट का सहेजा कार्ट खुलेगा।')).toBeVisible();
    await page.goto('/menu/litti-chokha');
    await expect(page.getByText('यह व्यंजन अभी इस आउटलेट पर उपलब्ध नहीं है।')).toBeVisible();
    await expect(page.getByRole('button', { name: 'कार्ट में जोड़ें' })).toBeDisabled();
    await page.getByLabel('चुना हुआ आउटलेट').selectOption('00000000-0000-4000-8000-000000000101');
    await expect(page.getByText('हर आउटलेट का अलग कार्ट है। बदलने पर उस आउटलेट का सहेजा कार्ट खुलेगा।')).toBeVisible();
    await page.reload();
    await page.getByRole('button', { name: 'कार्ट में जोड़ें' }).click();
    await expect(page).toHaveURL(/\/cart$/);
    await expect(page.getByText(/आपका कार्ट इस डिवाइस पर सहेजा है/)).toBeVisible();
    await expect(page.getByRole('link', { name: 'सुरक्षित चेकआउट जारी रखें' })).toBeVisible();

    await page.goto('/');
    await page.getByLabel('चुना हुआ आउटलेट').selectOption('00000000-0000-4000-8000-000000000102');
    await expect(page.getByText('हर आउटलेट का अलग कार्ट है। बदलने पर उस आउटलेट का सहेजा कार्ट खुलेगा।')).toBeVisible();
    await page.goto('/cart');
    await expect(page.getByText('आपका कार्ट खाली है।')).toBeVisible();
    await page.getByLabel('चुना हुआ आउटलेट').selectOption('00000000-0000-4000-8000-000000000101');
    await expect(page.getByText('हर आउटलेट का अलग कार्ट है। बदलने पर उस आउटलेट का सहेजा कार्ट खुलेगा।')).toBeVisible();
    await page.reload();
    await expect(page.getByText(/आपका कार्ट इस डिवाइस पर सहेजा है/)).toBeVisible();
});

test('referral deep link survives phone OTP and is attributed through the RPC contract', async ({ page }) => {
    let attributedCode = '';
    page.on('request', (request) => {
        if (request.url().endsWith('/rest/v1/rpc/attribute_referral')) {
            attributedCode = request.postDataJSON()?.p_code ?? '';
        }
    });

    await page.goto('/r/BBINVITE42');
    await page.getByRole('link', { name: 'Continue with phone' }).click();
    await page.getByLabel('Phone number').fill('+919999000001');
    await page.getByRole('button', { name: 'Send code' }).click();
    await page.getByLabel('Verification code').fill('123456');
    await page.getByRole('button', { name: 'Verify code' }).click();
    await expect(page).toHaveURL(/\/referrals$/);
    await expect.poll(() => attributedCode).toBe('BBINVITE42');
    await expect(page.getByRole('heading', { name: 'How the rewards work' })).toBeVisible();
    await expect(page.getByText('Reward expires after')).toBeVisible();
    await expect(page.getByText(/Invite 1: Invited/)).toBeVisible();
});

test('guest cart moves through OTP into server-priced checkout and order tracking', async ({ page }) => {
    let importedLines: unknown[] = [];
    page.on('request', (request) => {
        if (request.url().endsWith('/rest/v1/rpc/import_guest_cart')) {
            importedLines = request.postDataJSON()?.p_lines ?? [];
        }
    });

    await page.goto('/menu/litti-chokha');
    await page.getByRole('button', { name: 'Add to cart' }).click();
    await expect(page).toHaveURL(/\/cart$/);
    await page.getByRole('link', { name: 'Continue to secure checkout' }).click();
    await page.getByLabel('Phone number').fill('+919999000001');
    await page.getByRole('button', { name: 'Send code' }).click();
    await page.getByLabel('Verification code').fill('123456');
    await page.getByRole('button', { name: 'Verify code' }).click();
    await expect(page).toHaveURL(/\/cart$/);
    await expect(page.getByRole('heading', { name: 'Items saved on this device' })).toBeVisible();
    await page.getByRole('button', { name: 'Add saved items to my cart' }).click();
    await expect.poll(() => importedLines).toEqual([{
        product_id: productId,
        variant_id: null,
        quantity: 1,
        modifiers: [],
        special_instructions: null,
    }]);
    await expect(page.getByText('Litti Chokha', { exact: true })).toBeVisible();
    await page.getByLabel('Payment method').selectOption('COD');
    await expect(page.getByRole('button', { name: 'Place order' })).toBeEnabled();
    await page.getByRole('button', { name: 'Place order' }).click();
    await expect(page).toHaveURL(/\/order\/00000000-0000-4000-8000-000000000501$/);
    await expect(page.getByRole('heading', { name: 'Order number · BB-E2E-002' })).toBeVisible();
    await expect(page.getByText('Current status:')).toBeVisible();
});

test('online checkout uses the existing Razorpay create and verify contracts without a real charge', async ({ page }) => {
    await page.route('https://checkout.razorpay.com/v1/checkout.js', (route) => route.fulfill({
        status: 200,
        contentType: 'application/javascript',
        body: `window.Razorpay = function(options) {
            this.on = function() {};
            this.open = function() { options.handler({
                razorpay_order_id: options.order_id,
                razorpay_payment_id: 'pay_test_local',
                razorpay_signature: 'signature_test_local'
            }); };
        };`,
    }));
    const functionCalls: string[] = [];
    page.on('request', (request) => {
        const match = request.url().match(/\/functions\/v1\/(create-order|create-payment|verify-payment)$/);
        if (match) functionCalls.push(match[1]);
    });

    await page.goto('/menu/litti-chokha');
    await page.getByRole('button', { name: 'Add to cart' }).click();
    await page.getByRole('link', { name: 'Continue to secure checkout' }).click();
    await page.getByLabel('Phone number').fill('+919999000001');
    await page.getByRole('button', { name: 'Send code' }).click();
    await page.getByLabel('Verification code').fill('123456');
    await page.getByRole('button', { name: 'Verify code' }).click();
    await expect(page).toHaveURL(/\/cart$/);
    await page.getByRole('button', { name: 'Add saved items to my cart' }).click();
    await page.getByLabel('Fulfilment').selectOption('PICKUP');
    await page.getByLabel('Payment method').selectOption('ONLINE');
    await page.getByRole('button', { name: 'Place order' }).click();
    await expect(page).toHaveURL(/\/order\/00000000-0000-4000-8000-000000000501$/);
    await expect(page.getByText('CAPTURED')).toBeVisible();
    expect(functionCalls).toEqual(['create-order', 'create-payment', 'verify-payment']);
});

test('signed-in favorites stay private behind the customer session and support removal', async ({ context, page }) => {
    await context.addCookies([{ ...sessionCookie(), url: 'http://127.0.0.1:3001' }]);
    await page.goto('/favorites');
    await expect(page.getByRole('heading', { name: 'Favorites' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Litti Chokha', exact: true })).toBeVisible();

    const mutation = page.waitForRequest((request) => request.url().endsWith('/rest/v1/rpc/set_my_favorite'));
    await page.getByRole('button', { name: 'Remove from favorites' }).first().click();
    expect((await mutation).postDataJSON()).toEqual({ p_product_id: productId, p_favorite: false });
});
