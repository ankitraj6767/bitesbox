import { defineConfig, devices } from '@playwright/test';

const baseURL = 'http://127.0.0.1:3100';

export default defineConfig({
    testDir: './e2e',
    fullyParallel: false,
    retries: 0,
    reporter: 'list',
    timeout: 60_000,
    expect: { timeout: 15_000 },
    use: {
        baseURL,
        trace: 'retain-on-failure',
        ...devices['Desktop Chrome'],
    },
    webServer: [
        {
            command: 'node e2e/fake-supabase.mjs',
            url: 'http://127.0.0.1:54321/health',
            reuseExistingServer: !process.env.CI,
            timeout: 30_000,
        },
        {
            command: 'npm run dev -- --hostname 127.0.0.1 --port 3100',
            url: baseURL,
            reuseExistingServer: !process.env.CI,
            timeout: 120_000,
            env: {
                NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321',
                NEXT_PUBLIC_SUPABASE_ANON_KEY: 'sb_publishable_local_e2e_only',
                NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_local_e2e_only',
                APP_ENV: 'test',
                NEXT_PUBLIC_APP_ENV: 'test',
                SENTRY_DSN: '',
                NEXT_PUBLIC_SENTRY_DSN: '',
            },
        },
    ],
});
