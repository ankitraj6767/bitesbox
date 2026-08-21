'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import type { AssignmentMode, CancellationReason } from '@bitesbox/shared-types';

/**
 * Every kitchen and dispatch action in one hook.
 *
 * All of them are Postgres RPCs that re-check permissions and drive the order
 * state machine, so the UI never decides whether a transition is legal — it
 * just reports what the server said.
 */
export function useOrderActions({ onActionSuccess }: { onActionSuccess?: () => void } = {}) {
    const queryClient = useQueryClient();

    const afterSuccess = () => {
        void queryClient.invalidateQueries({ queryKey: ['live-operations'] });
        void queryClient.invalidateQueries({ queryKey: ['orders'] });
        void queryClient.invalidateQueries({ queryKey: ['order'] });
        void queryClient.invalidateQueries({ queryKey: ['kitchen-queue'] });
        void queryClient.invalidateQueries({ queryKey: ['sidebar-counts'] });
        onActionSuccess?.();
    };

    const accept = useMutation({
        mutationFn: async ({ orderId, prepMinutes }: { orderId: string; prepMinutes?: number }) => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('accept_order', {
                p_order_id: orderId,
                p_prep_minutes: prepMinutes ?? undefined,
            });
            if (error) throw error;
            return data;
        },
        onSuccess: () => {
            toast.success('Order accepted');
            afterSuccess();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const reject = useMutation({
        mutationFn: async ({
            orderId,
            reason,
            note,
        }: {
            orderId: string;
            reason: CancellationReason;
            note?: string;
        }) => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('reject_order', {
                p_order_id: orderId,
                p_reason: reason,
                p_note: note ?? undefined,
            });
            if (error) throw error;
            return data as { refund_required?: boolean; refund_amount?: number } | null;
        },
        onSuccess: (data) => {
            toast.success(
                data?.refund_required
                    ? 'Order rejected. A refund is required — raise it from the order screen.'
                    : 'Order rejected',
            );
            afterSuccess();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const startPreparing = useMutation({
        mutationFn: async (orderId: string) => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('start_preparing', { p_order_id: orderId });
            if (error) throw error;
            return data;
        },
        onSuccess: () => {
            toast.success('Marked as preparing');
            afterSuccess();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const markReady = useMutation({
        mutationFn: async (orderId: string) => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('mark_order_ready', { p_order_id: orderId });
            if (error) throw error;
            return data;
        },
        onSuccess: () => {
            toast.success('Order is ready. The pickup code has been issued.');
            afterSuccess();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const assignRider = useMutation({
        mutationFn: async ({
            orderId,
            deliveryPartnerId,
            mode = 'MANUAL',
        }: {
            orderId: string;
            deliveryPartnerId: string;
            mode?: AssignmentMode;
        }) => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('assign_rider', {
                p_order_id: orderId,
                p_delivery_partner_id: deliveryPartnerId,
                p_mode: mode,
            });
            if (error) throw error;
            return data as { rider_name?: string; changed?: boolean } | null;
        },
        onSuccess: (data) => {
            toast.success(
                data?.changed === false
                    ? 'That delivery partner is already assigned'
                    : `Assigned to ${data?.rider_name ?? 'delivery partner'}`,
            );
            afterSuccess();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const cancel = useMutation({
        mutationFn: async ({
            orderId,
            reason,
            note,
        }: {
            orderId: string;
            reason: CancellationReason;
            note?: string;
        }) => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.rpc('cancel_order', {
                p_order_id: orderId,
                p_reason: reason,
                p_note: note ?? undefined,
            });
            if (error) throw error;
            return data as { refund_amount?: number; refund_will_be_processed?: boolean } | null;
        },
        onSuccess: (data) => {
            toast.success(
                data?.refund_will_be_processed
                    ? 'Order cancelled. A refund is due to the customer.'
                    : 'Order cancelled',
            );
            afterSuccess();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const addNote = useMutation({
        mutationFn: async ({ orderId, note }: { orderId: string; note: string }) => {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase.from('order_notes').insert({
                order_id: orderId,
                note,
            });
            if (error) throw error;
        },
        onSuccess: () => {
            toast.success('Note added');
            afterSuccess();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    return { accept, reject, startPreparing, markReady, assignRider, cancel, addNote };
}
