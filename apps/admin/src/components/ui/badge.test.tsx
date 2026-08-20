import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { OrderStatus, PaymentStatus, RefundStatus } from '@bitesbox/shared-types';
import {
    Badge,
    FoodTypeMark,
    OrderStatusBadge,
    orderStatusTone,
    paymentStatusTone,
    refundStatusTone,
} from './badge';

/**
 * Status colour is operational signalling, not decoration. On the live operations
 * board a manager scans for red; a cancelled order rendered in the same tone as a
 * delivered one is a real failure, so the mapping is asserted directly.
 */
describe('orderStatusTone', () => {
    it('paints a finished order positively', () => {
        expect(orderStatusTone('DELIVERED')).toBe('positive');
        expect(orderStatusTone('COMPLETED')).toBe('positive');
    });

    it('paints every failure critically', () => {
        const failures: OrderStatus[] = [
            'PAYMENT_FAILED',
            'STORE_REJECTED',
            'CUSTOMER_CANCELLED',
            'ADMIN_CANCELLED',
            'DELIVERY_FAILED',
        ];

        for (const status of failures) {
            expect(orderStatusTone(status), status).toBe('critical');
        }
    });

    it('never paints a failure the same as a success', () => {
        expect(orderStatusTone('CUSTOMER_CANCELLED')).not.toBe(orderStatusTone('DELIVERED'));
    });

    it('treats anything awaiting money as needing attention', () => {
        expect(orderStatusTone('PENDING_PAYMENT')).toBe('caution');
        expect(orderStatusTone('REFUND_PENDING')).toBe('caution');
        expect(orderStatusTone('PARTIALLY_REFUNDED')).toBe('caution');
    });

    it('has a tone for every status in the enum', () => {
        const every: OrderStatus[] = [
            'PENDING_PAYMENT',
            'PAYMENT_CONFIRMED',
            'PAYMENT_FAILED',
            'ORDER_PLACED',
            'STORE_ACCEPTED',
            'STORE_REJECTED',
            'PREPARING',
            'READY_FOR_PICKUP',
            'RIDER_ASSIGNED',
            'RIDER_ARRIVED_STORE',
            'PICKED_UP',
            'OUT_FOR_DELIVERY',
            'RIDER_ARRIVED_CUSTOMER',
            'DELIVERED',
            'COMPLETED',
            'CUSTOMER_CANCELLED',
            'ADMIN_CANCELLED',
            'DELIVERY_FAILED',
            'REFUND_PENDING',
            'PARTIALLY_REFUNDED',
            'REFUNDED',
        ];

        for (const status of every) {
            expect(orderStatusTone(status), status).toBeTruthy();
        }
    });
});

describe('paymentStatusTone', () => {
    it('separates captured from failed', () => {
        expect(paymentStatusTone('CAPTURED')).toBe('positive');
        expect(paymentStatusTone('FAILED')).toBe('critical');
        expect(paymentStatusTone('EXPIRED')).toBe('critical');
    });

    it('treats an in-flight payment as unresolved', () => {
        const pending: PaymentStatus[] = ['CREATED', 'PENDING', 'AUTHORIZED'];
        for (const status of pending) {
            expect(paymentStatusTone(status), status).toBe('caution');
        }
    });
});

describe('refundStatusTone', () => {
    it('marks a refund awaiting a decision as caution', () => {
        const waiting: RefundStatus[] = ['REQUESTED', 'APPROVAL_PENDING'];
        for (const status of waiting) {
            expect(refundStatusTone(status), status).toBe('caution');
        }
    });

    it('marks a completed refund positively and a failed one critically', () => {
        expect(refundStatusTone('COMPLETED')).toBe('positive');
        expect(refundStatusTone('FAILED')).toBe('critical');
        expect(refundStatusTone('REJECTED')).toBe('critical');
    });
});

describe('OrderStatusBadge', () => {
    it('reads as a sentence, not an enum', () => {
        render(<OrderStatusBadge status="OUT_FOR_DELIVERY" />);
        expect(screen.getByText('Out for delivery')).toBeInTheDocument();
    });
});

describe('Badge', () => {
    it('renders its children', () => {
        render(<Badge>3 delayed</Badge>);
        expect(screen.getByText('3 delayed')).toBeInTheDocument();
    });

    it('hides the decorative dot from assistive technology', () => {
        const { container } = render(<Badge dot>Live</Badge>);
        expect(container.querySelector('[aria-hidden="true"]')).not.toBeNull();
    });
});

describe('FoodTypeMark', () => {
    // The veg/non-veg mark is regulated signalling in India and is conveyed by colour
    // alone visually, so the accessible label is the only thing carrying it to a
    // screen reader.
    it('labels each food type for a screen reader', () => {
        render(<FoodTypeMark type="NON_VEG" />);
        expect(screen.getByRole('img', { name: 'Non-vegetarian' })).toBeInTheDocument();

        render(<FoodTypeMark type="EGG" />);
        expect(screen.getByRole('img', { name: 'Contains egg' })).toBeInTheDocument();

        render(<FoodTypeMark type="VEG" />);
        expect(screen.getByRole('img', { name: 'Vegetarian' })).toBeInTheDocument();
    });

    it('does not label a vegan dish as non-vegetarian', () => {
        render(<FoodTypeMark type="VEGAN" />);
        expect(screen.getByRole('img', { name: 'Vegetarian' })).toBeInTheDocument();
    });
});
