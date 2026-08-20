import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';
import type { OrderStatus, PaymentStatus, RefundStatus } from '@bitesbox/shared-types';
import { humanise } from '@/lib/utils';

const badgeVariants = cva(
    'inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-[11.5px] font-semibold tracking-wide whitespace-nowrap',
    {
        variants: {
            tone: {
                neutral: 'border-hairline bg-surface-muted text-ink-muted',
                info: 'border-info/20 bg-info-soft text-info',
                positive: 'border-positive/20 bg-positive-soft text-positive',
                caution: 'border-caution/25 bg-caution-soft text-caution',
                critical: 'border-critical/20 bg-critical-soft text-critical',
                brand: 'border-brand-200 bg-brand-50 text-brand-700',
                veg: 'border-positive/30 bg-positive-soft text-positive',
                nonveg: 'border-critical/30 bg-critical-soft text-critical',
            },
        },
        defaultVariants: { tone: 'neutral' },
    },
);

export type BadgeTone = NonNullable<VariantProps<typeof badgeVariants>['tone']>;

export interface BadgeProps
    extends React.ComponentProps<'span'>,
    VariantProps<typeof badgeVariants> {
    dot?: boolean;
}

export function Badge({ className, tone, dot, children, ...props }: BadgeProps) {
    return (
        <span className={cn(badgeVariants({ tone }), className)} {...props}>
            {dot ? <span className="size-1.5 rounded-full bg-current" aria-hidden /> : null}
            {children}
        </span>
    );
}

/** Order status → tone. Kept in one place so every screen agrees on colour. */
export function orderStatusTone(status: OrderStatus): BadgeTone {
    switch (status) {
        case 'DELIVERED':
        case 'COMPLETED':
            return 'positive';
        case 'PENDING_PAYMENT':
        case 'PAYMENT_CONFIRMED':
            return 'caution';
        case 'ORDER_PLACED':
            return 'brand';
        case 'STORE_ACCEPTED':
        case 'PREPARING':
        case 'READY_FOR_PICKUP':
            return 'info';
        case 'RIDER_ASSIGNED':
        case 'RIDER_ARRIVED_STORE':
        case 'PICKED_UP':
        case 'OUT_FOR_DELIVERY':
        case 'RIDER_ARRIVED_CUSTOMER':
            return 'info';
        case 'PAYMENT_FAILED':
        case 'STORE_REJECTED':
        case 'CUSTOMER_CANCELLED':
        case 'ADMIN_CANCELLED':
        case 'DELIVERY_FAILED':
            return 'critical';
        case 'REFUND_PENDING':
        case 'PARTIALLY_REFUNDED':
        case 'REFUNDED':
            return 'caution';
        default:
            return 'neutral';
    }
}

export function OrderStatusBadge({ status, className }: { status: OrderStatus; className?: string }) {
    return (
        <Badge tone={orderStatusTone(status)} dot className={className}>
            {humanise(status)}
        </Badge>
    );
}

export function paymentStatusTone(status: PaymentStatus): BadgeTone {
    switch (status) {
        case 'CAPTURED':
            return 'positive';
        case 'CREATED':
        case 'PENDING':
        case 'AUTHORIZED':
            return 'caution';
        case 'FAILED':
        case 'CANCELLED':
        case 'EXPIRED':
            return 'critical';
        case 'REFUNDED':
        case 'PARTIALLY_REFUNDED':
        case 'REFUND_PENDING':
            return 'info';
        default:
            return 'neutral';
    }
}

export function PaymentStatusBadge({ status }: { status: PaymentStatus }) {
    return <Badge tone={paymentStatusTone(status)}>{humanise(status)}</Badge>;
}

export function refundStatusTone(status: RefundStatus): BadgeTone {
    switch (status) {
        case 'COMPLETED':
            return 'positive';
        case 'REQUESTED':
        case 'APPROVAL_PENDING':
            return 'caution';
        case 'APPROVED':
        case 'PROCESSING':
            return 'info';
        case 'REJECTED':
        case 'FAILED':
            return 'critical';
        default:
            return 'neutral';
    }
}

/** Green/red veg marker used across the menu, kitchen and order screens. */
export function FoodTypeMark({
    type,
    className,
}: {
    type: 'VEG' | 'NON_VEG' | 'EGG' | 'VEGAN';
    className?: string;
}) {
    const colour =
        type === 'NON_VEG'
            ? 'border-critical text-critical'
            : type === 'EGG'
                ? 'border-caution text-caution'
                : 'border-positive text-positive';

    const label = type === 'NON_VEG' ? 'Non-vegetarian' : type === 'EGG' ? 'Contains egg' : 'Vegetarian';

    return (
        <span
            role="img"
            aria-label={label}
            title={label}
            className={cn(
                'inline-flex size-3.5 shrink-0 items-center justify-center rounded-[3px] border-[1.5px]',
                colour,
                className,
            )}
        >
            <span className="size-1.5 rounded-full bg-current" aria-hidden />
        </span>
    );
}
