import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { FlatCompat } from '@eslint/eslintrc';

// `eslint-config-next` still ships eslintrc-style config, so it is bridged into a
// flat config rather than replaced. This also lets `eslint .` be the entry point:
// `next lint` is deprecated and removed in Next 16, and it prompts interactively
// when no config exists — which hangs CI.
const compat = new FlatCompat({
    baseDirectory: dirname(fileURLToPath(import.meta.url)),
});

const config = [
    {
        ignores: [
            '.next/**',
            'node_modules/**',
            'next-env.d.ts',
            'tsconfig.tsbuildinfo',
            'coverage/**',
            'playwright-report/**',
            'test-results/**',
        ],
    },

    ...compat.extends('next/core-web-vitals', 'next/typescript'),

    {
        rules: {
            // An unused argument is often deliberate in a callback signature; a leading
            // underscore is the conventional way to say so.
            '@typescript-eslint/no-unused-vars': [
                'error',
                {
                    argsIgnorePattern: '^_',
                    varsIgnorePattern: '^_',
                    caughtErrorsIgnorePattern: '^_',
                },
            ],
            // Server components and RPC payloads cross a boundary the compiler cannot
            // see, so an explicit `any` there should be argued for, not silently allowed.
            '@typescript-eslint/no-explicit-any': 'error',
        },
    },

    {
        // Generated from the live schema; not ours to lint.
        files: ['src/**/database.types.ts'],
        rules: {
            '@typescript-eslint/no-explicit-any': 'off',
        },
    },
];

export default config;
