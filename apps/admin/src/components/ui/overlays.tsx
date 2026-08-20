'use client';

import * as React from 'react';
import * as DialogPrimitive from '@radix-ui/react-dialog';
import * as DropdownPrimitive from '@radix-ui/react-dropdown-menu';
import * as TooltipPrimitive from '@radix-ui/react-tooltip';
import * as TabsPrimitive from '@radix-ui/react-tabs';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from './button';
import { Input } from './form-controls';

// ── Dialog ─────────────────────────────────────────────────────────────────
export const Dialog = DialogPrimitive.Root;
export const DialogTrigger = DialogPrimitive.Trigger;
export const DialogClose = DialogPrimitive.Close;

export function DialogContent({
    className,
    children,
    size = 'md',
    ...props
}: React.ComponentProps<typeof DialogPrimitive.Content> & { size?: 'sm' | 'md' | 'lg' | 'xl' }) {
    const widths = {
        sm: 'max-w-sm',
        md: 'max-w-lg',
        lg: 'max-w-2xl',
        xl: 'max-w-4xl',
    } as const;

    return (
        <DialogPrimitive.Portal>
            <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-ink/35 backdrop-blur-[2px] data-[state=open]:animate-in data-[state=open]:fade-in" />
            <DialogPrimitive.Content
                className={cn(
                    'fixed top-1/2 left-1/2 z-50 w-[calc(100vw-2rem)] -translate-x-1/2 -translate-y-1/2',
                    'max-h-[calc(100vh-3rem)] overflow-y-auto scroll-slim rounded-[var(--radius-card)] border border-hairline bg-surface shadow-[var(--shadow-raised)]',
                    widths[size],
                    className,
                )}
                {...props}
            >
                {children}
                <DialogPrimitive.Close
                    aria-label="Close"
                    className="absolute top-4 right-4 rounded-md p-1 text-ink-muted transition-colors hover:bg-surface-muted hover:text-ink"
                >
                    <X className="size-4" aria-hidden />
                </DialogPrimitive.Close>
            </DialogPrimitive.Content>
        </DialogPrimitive.Portal>
    );
}

export function DialogHeader({ className, ...props }: React.ComponentProps<'div'>) {
    return <div className={cn('flex flex-col gap-1 px-5 pt-5 pr-12', className)} {...props} />;
}

export function DialogTitle({
    className,
    ...props
}: React.ComponentProps<typeof DialogPrimitive.Title>) {
    return (
        <DialogPrimitive.Title
            className={cn('font-display text-base font-semibold tracking-tight text-ink', className)}
            {...props}
        />
    );
}

export function DialogDescription({
    className,
    ...props
}: React.ComponentProps<typeof DialogPrimitive.Description>) {
    return (
        <DialogPrimitive.Description
            className={cn('text-[13px] leading-relaxed text-ink-muted', className)}
            {...props}
        />
    );
}

export function DialogBody({ className, ...props }: React.ComponentProps<'div'>) {
    return <div className={cn('px-5 py-4', className)} {...props} />;
}

export function DialogFooter({ className, ...props }: React.ComponentProps<'div'>) {
    return (
        <div
            className={cn(
                'flex flex-col-reverse gap-2 border-t border-hairline px-5 py-4 sm:flex-row sm:justify-end',
                className,
            )}
            {...props}
        />
    );
}

// ── Confirm dialog ─────────────────────────────────────────────────────────
/**
 * Destructive actions require confirmation. When `confirmText` is supplied the
 * operator must type it exactly — used for irreversible settings changes and
 * large refunds.
 */
export function ConfirmDialog({
    open,
    onOpenChange,
    title,
    description,
    confirmLabel = 'Confirm',
    cancelLabel = 'Cancel',
    destructive = false,
    confirmText,
    loading = false,
    onConfirm,
    children,
}: {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    title: string;
    description?: React.ReactNode;
    confirmLabel?: string;
    cancelLabel?: string;
    destructive?: boolean;
    confirmText?: string;
    loading?: boolean;
    onConfirm: () => void | Promise<void>;
    children?: React.ReactNode;
}) {
    const [typed, setTyped] = React.useState('');
    const matches = !confirmText || typed.trim() === confirmText;

    React.useEffect(() => {
        if (!open) setTyped('');
    }, [open]);

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent size="sm">
                <DialogHeader>
                    <DialogTitle>{title}</DialogTitle>
                    {description ? <DialogDescription>{description}</DialogDescription> : null}
                </DialogHeader>

                {children || confirmText ? (
                    <DialogBody className="space-y-3">
                        {children}
                        {confirmText ? (
                            <div className="space-y-1.5">
                                <p className="text-[13px] text-ink-muted">
                                    Type <span className="font-mono font-semibold text-ink">{confirmText}</span> to
                                    confirm.
                                </p>
                                <Input
                                    value={typed}
                                    onChange={(event) => setTyped(event.target.value)}
                                    placeholder={confirmText}
                                    autoComplete="off"
                                    aria-label={`Type ${confirmText} to confirm`}
                                />
                            </div>
                        ) : null}
                    </DialogBody>
                ) : null}

                <DialogFooter>
                    <Button variant="secondary" onClick={() => onOpenChange(false)} disabled={loading}>
                        {cancelLabel}
                    </Button>
                    <Button
                        variant={destructive ? 'destructive' : 'primary'}
                        onClick={() => void onConfirm()}
                        loading={loading}
                        disabled={!matches}
                    >
                        {confirmLabel}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}

// ── Dropdown ───────────────────────────────────────────────────────────────
export const DropdownMenu = DropdownPrimitive.Root;
export const DropdownMenuTrigger = DropdownPrimitive.Trigger;

export function DropdownMenuContent({
    className,
    align = 'end',
    ...props
}: React.ComponentProps<typeof DropdownPrimitive.Content>) {
    return (
        <DropdownPrimitive.Portal>
            <DropdownPrimitive.Content
                align={align}
                sideOffset={6}
                className={cn(
                    'z-50 min-w-48 overflow-hidden rounded-[var(--radius-control)] border border-hairline bg-surface p-1 shadow-[var(--shadow-raised)]',
                    className,
                )}
                {...props}
            />
        </DropdownPrimitive.Portal>
    );
}

export function DropdownMenuItem({
    className,
    destructive,
    ...props
}: React.ComponentProps<typeof DropdownPrimitive.Item> & { destructive?: boolean }) {
    return (
        <DropdownPrimitive.Item
            className={cn(
                'flex cursor-pointer items-center gap-2 rounded-md px-2.5 py-1.5 text-[13px] text-ink outline-none select-none',
                'data-highlighted:bg-surface-muted data-disabled:pointer-events-none data-disabled:opacity-50',
                '[&_svg]:size-4 [&_svg]:shrink-0 [&_svg]:text-ink-muted',
                destructive && 'text-critical data-highlighted:bg-critical-soft [&_svg]:text-critical',
                className,
            )}
            {...props}
        />
    );
}

export function DropdownMenuLabel({ className, ...props }: React.ComponentProps<typeof DropdownPrimitive.Label>) {
    return (
        <DropdownPrimitive.Label
            className={cn('px-2.5 py-1.5 text-[11.5px] font-semibold tracking-wider text-ink-muted uppercase', className)}
            {...props}
        />
    );
}

export function DropdownMenuSeparator({
    className,
    ...props
}: React.ComponentProps<typeof DropdownPrimitive.Separator>) {
    return <DropdownPrimitive.Separator className={cn('-mx-1 my-1 h-px bg-hairline', className)} {...props} />;
}

// ── Tooltip ────────────────────────────────────────────────────────────────
export const TooltipProvider = TooltipPrimitive.Provider;

export function Tooltip({
    content,
    children,
    side = 'top',
}: {
    content: React.ReactNode;
    children: React.ReactNode;
    side?: 'top' | 'right' | 'bottom' | 'left';
}) {
    return (
        <TooltipPrimitive.Root delayDuration={250}>
            <TooltipPrimitive.Trigger asChild>{children}</TooltipPrimitive.Trigger>
            <TooltipPrimitive.Portal>
                <TooltipPrimitive.Content
                    side={side}
                    sideOffset={6}
                    className="z-50 max-w-64 rounded-md bg-ink px-2.5 py-1.5 text-[12.5px] leading-snug text-white shadow-md"
                >
                    {content}
                    <TooltipPrimitive.Arrow className="fill-ink" />
                </TooltipPrimitive.Content>
            </TooltipPrimitive.Portal>
        </TooltipPrimitive.Root>
    );
}

// ── Tabs ───────────────────────────────────────────────────────────────────
export const Tabs = TabsPrimitive.Root;

export function TabsList({ className, ...props }: React.ComponentProps<typeof TabsPrimitive.List>) {
    return (
        <TabsPrimitive.List
            className={cn(
                'inline-flex items-center gap-1 rounded-[var(--radius-control)] bg-surface-muted p-1',
                className,
            )}
            {...props}
        />
    );
}

export function TabsTrigger({
    className,
    ...props
}: React.ComponentProps<typeof TabsPrimitive.Trigger>) {
    return (
        <TabsPrimitive.Trigger
            className={cn(
                'inline-flex items-center gap-1.5 rounded-md px-3 py-1.5 text-[13px] font-medium text-ink-muted transition-all',
                'data-[state=active]:bg-surface data-[state=active]:text-ink data-[state=active]:shadow-xs',
                className,
            )}
            {...props}
        />
    );
}

export function TabsContent({
    className,
    ...props
}: React.ComponentProps<typeof TabsPrimitive.Content>) {
    return <TabsPrimitive.Content className={cn('mt-4 outline-none', className)} {...props} />;
}
