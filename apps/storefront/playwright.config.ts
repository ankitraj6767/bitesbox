import { defineConfig, devices } from '@playwright/test';

const baseURL = 'http://127.0.0.1:3001';

export default defineConfig({
    testDir: './e2e',
    fullyParallel: false,
    retries: 0,
    reporter: 'list',
    timeout: 45_000,
    expect: { timeout: 12_000 },
    use: { baseURL, trace: 'retain-on-failure', ...devices['Desktop Chrome'] },
    webServer: [
        {
            command: 'node e2e/fake-supabase.mjs',
            url: 'http://127.0.0.1:55321/health',
            reuseExistingServer: !process.env.CI,
            timeout: 30_000,
        },
        {
            command: 'npm run dev -- --hostname 127.0.0.1',
            url: baseURL,
            reuseExistingServer: !process.env.CI,
            timeout: 120_000,
            env: {
                NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:55321',
                NEXT_PUBLIC_SUPABASE_ANON_KEY: 'sb_publishable_local_e2e_only',
                NEXT_PUBLIC_SITE_URL: baseURL,
                APP_ENV: 'test',
                NEXT_PUBLIC_APP_ENV: 'test',
                SENTRY_DSN: '',
                NEXT_PUBLIC_SENTRY_DSN: '',
            },
        },
    ],
});
