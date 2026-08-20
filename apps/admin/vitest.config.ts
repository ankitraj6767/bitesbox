import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'node:url';

export default defineConfig({
    plugins: [react()],
    resolve: {
        alias: {
            '@': fileURLToPath(new URL('./src', import.meta.url)),
        },
    },
    test: {
        environment: 'jsdom',
        globals: true,
        setupFiles: ['./src/test/setup.ts'],
        include: ['src/**/*.test.{ts,tsx}'],
        // The Playwright suite lives in e2e/ and is driven separately.
        exclude: ['e2e/**', 'node_modules/**', '.next/**'],
        coverage: {
            reporter: ['text', 'lcov'],
            include: ['src/lib/**', 'src/features/**', 'src/components/**'],
        },
    },
});
