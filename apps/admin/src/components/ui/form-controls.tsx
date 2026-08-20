'use client';

import * as React from 'react';
import * as LabelPrimitive from '@radix-ui/react-label';
import * as SelectPrimitive from '@radix-ui/react-select';
import * as SwitchPrimitive from '@radix-ui/react-switch';
import * as SeparatorPrimitive from '@radix-ui/react-separator';
import { Check, ChevronDown, Search } from 'lucide-react';
import { cn } from '@/lib/utils';

// ── Label ──────────────────────────────────────────────────────────────────
export function Label({
    className,
    required,
    children,
    ...props
}: React.ComponentProps<typeof LabelPrimitive.Root> & { required?: boolean }) {
    return (
        <LabelPrimitive.Root
            className={cn('text-[13px] font-medium text-ink select-none', className)}
            {...props}
        >
            {children}
            {required ? (
                <span className="ml-0.5 text-critical" aria-hidden>
                    *
                </span>
            ) : null}
        </LabelPrimitive.Root>
    );
}

// ── Input ──────────────────────────────────────────────────────────────────
export const Input = React.forwardRef<HTMLInputElement, React.ComponentProps<'input'>>(
    function Input({ className, ...props }, ref) {
        return (
            <input
                ref={ref}
                className={cn(
                    'h-9.5 w-full rounded-[var(--radius-control)] border border-hairline bg-surface px-3 text-sm text-ink shadow-xs',
                    'placeholder:text-ink-muted/70 focus-visible:border-brand-400 focus-visible:outline-brand-600',
                    'disabled:cursor-not-allowed disabled:bg-surface-muted disabled:opacity-70',
                    'aria-invalid:border-critical aria-invalid:outline-critical',
                    className,
                )}
                {...props}
            />
        );
    },
);

export const Textarea = React.forwardRef<HTMLTextAreaElement, React.ComponentProps<'textarea'>>(
    function Textarea({ className, ...props }, ref) {
        return (
            <textarea
                ref={ref}
                className={cn(
                    'min-h-20 w-full rounded-[var(--radius-control)] border border-hairline bg-surface px-3 py-2 text-sm text-ink shadow-xs',
                    'placeholder:text-ink-muted/70 focus-visible:border-brand-400 focus-visible:outline-brand-600',
                    'aria-invalid:border-critical',
                    className,
                )}
                {...props}
            />
        );
    },
);

/** Input with a leading search icon, used by every filter bar. */
export const SearchInput = React.forwardRef<HTMLInputElement, React.ComponentProps<'input'>>(
    function SearchInput({ className, ...props }, ref) {
        return (
            <div className="relative">
                <Search
                    className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-ink-muted"
                    aria-hidden
                />
                <Input ref={ref} type="search" className={cn('pl-9', className)} {...props} />
            </div>
        );
    },
);

// ── Field wrapper ──────────────────────────────────────────────────────────
export function Field({
    label,
    hint,
    error,
    required,
    htmlFor,
    children,
    className,
}: {
    label?: React.ReactNode;
    hint?: React.ReactNode;
    error?: string | null;
    required?: boolean;
    htmlFor?: string;
    children: React.ReactNode;
    className?: string;
}) {
    return (
        <div className={cn('flex flex-col gap-1.5', className)}>
            {label ? (
                <Label htmlFor={htmlFor} required={required}>
                    {label}
                </Label>
            ) : null}
            {children}
            {error ? (
                <p className="text-[12.5px] font-medium text-critical" role="alert">
                    {error}
                </p>
            ) : hint ? (
                <p className="text-[12.5px] text-ink-muted">{hint}</p>
            ) : null}
        </div>
    );
}

// ── Select ─────────────────────────────────────────────────────────────────
export const Select = SelectPrimitive.Root;
export const SelectValue = SelectPrimitive.Value;

export function SelectTrigger({
    className,
    children,
    ...props
}: React.ComponentProps<typeof SelectPrimitive.Trigger>) {
    return (
        <SelectPrimitive.Trigger
            className={cn(
                'flex h-9.5 w-full items-center justify-between gap-2 rounded-[var(--radius-control)] border border-hairline bg-surface px-3 text-sm text-ink shadow-xs',
                'data-[placeholder]:text-ink-muted/80 focus-visible:border-brand-400 disabled:opacity-60',
                className,
            )}
            {...props}
        >
            {children}
            <SelectPrimitive.Icon asChild>
                <ChevronDown className="size-4 shrink-0 text-ink-muted" aria-hidden />
            </SelectPrimitive.Icon>
        </SelectPrimitive.Trigger>
    );
}

export function SelectContent({
    className,
    children,
    ...props
}: React.ComponentProps<typeof SelectPrimitive.Content>) {
    return (
        <SelectPrimitive.Portal>
            <SelectPrimitive.Content
                position="popper"
                sideOffset={6}
                className={cn(
                    'z-50 max-h-72 min-w-[var(--radix-select-trigger-width)] overflow-hidden rounded-[var(--radius-control)] border border-hairline bg-surface shadow-[var(--shadow-raised)]',
                    className,
                )}
                {...props}
            >
                <SelectPrimitive.Viewport className="p-1">{children}</SelectPrimitive.Viewport>
            </SelectPrimitive.Content>
        </SelectPrimitive.Portal>
    );
}

export function SelectItem({
    className,
    children,
    ...props
}: React.ComponentProps<typeof SelectPrimitive.Item>) {
    return (
        <SelectPrimitive.Item
            className={cn(
                'relative flex cursor-pointer items-center gap-2 rounded-md py-1.5 pr-2 pl-8 text-sm text-ink outline-none select-none',
                'data-highlighted:bg-surface-muted data-[state=checked]:font-medium',
                className,
            )}
            {...props}
        >
            <span className="absolute left-2 flex size-4 items-center justify-center">
                <SelectPrimitive.ItemIndicator>
                    <Check className="size-3.5 text-brand-600" aria-hidden />
                </SelectPrimitive.ItemIndicator>
            </span>
            <SelectPrimitive.ItemText>{children}</SelectPrimitive.ItemText>
        </SelectPrimitive.Item>
    );
}

// ── Switch ─────────────────────────────────────────────────────────────────
export function Switch({
    className,
    ...props
}: React.ComponentProps<typeof SwitchPrimitive.Root>) {
    return (
        <SwitchPrimitive.Root
            className={cn(
                'peer inline-flex h-5.5 w-10 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors',
                'data-[state=checked]:bg-brand-600 data-[state=unchecked]:bg-hairline disabled:cursor-not-allowed disabled:opacity-50',
                className,
            )}
            {...props}
        >
            <SwitchPrimitive.Thumb
                className={cn(
                    'pointer-events-none block size-4.5 rounded-full bg-white shadow-sm ring-0 transition-transform',
                    'data-[state=checked]:translate-x-4.5 data-[state=unchecked]:translate-x-0',
                )}
            />
        </SwitchPrimitive.Root>
    );
}

export function Separator({
    className,
    ...props
}: React.ComponentProps<typeof SeparatorPrimitive.Root>) {
    return (
        <SeparatorPrimitive.Root
            className={cn('shrink-0 bg-hairline data-[orientation=horizontal]:h-px data-[orientation=vertical]:w-px', className)}
            {...props}
        />
    );
}
