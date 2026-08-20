'use client';

import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
    'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-[var(--radius-control)] text-sm font-medium transition-all disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0 active:scale-[0.985]',
    {
        variants: {
            variant: {
                primary:
                    'bg-brand-600 text-white shadow-xs hover:bg-brand-700 focus-visible:outline-brand-600',
                secondary:
                    'bg-surface text-ink border border-hairline shadow-xs hover:bg-surface-muted',
                ghost: 'text-ink-muted hover:bg-surface-muted hover:text-ink',
                subtle: 'bg-surface-muted text-ink hover:bg-hairline',
                destructive:
                    'bg-critical text-white shadow-xs hover:bg-critical/90 focus-visible:outline-critical',
                outlineDestructive:
                    'border border-critical/30 text-critical bg-critical-soft hover:bg-critical/10',
                success: 'bg-positive text-white shadow-xs hover:bg-positive/90',
                link: 'text-brand-600 underline-offset-4 hover:underline',
            },
            size: {
                sm: 'h-8 px-3 text-[13px]',
                md: 'h-9.5 px-4',
                lg: 'h-11 px-5 text-[15px]',
                icon: 'size-9.5',
                iconSm: 'size-8',
            },
        },
        defaultVariants: { variant: 'primary', size: 'md' },
    },
);

export interface ButtonProps
    extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
    asChild?: boolean;
    loading?: boolean;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(function Button(
    { className, variant, size, asChild = false, loading = false, children, disabled, ...props },
    ref,
) {
    const Comp = asChild ? Slot : 'button';

    return (
        <Comp
            ref={ref}
            className={cn(buttonVariants({ variant, size, className }))}
            disabled={disabled || loading}
            aria-busy={loading || undefined}
            {...props}
        >
            {loading ? (
                <>
                    <Loader2 className="animate-spin" aria-hidden />
                    <span className="sr-only">Working…</span>
                    {children}
                </>
            ) : (
                children
            )}
        </Comp>
    );
});

export { buttonVariants };
