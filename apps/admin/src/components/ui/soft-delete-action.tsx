'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { Trash2 } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/ui/overlays';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';

type SoftDeletableTable = 'categories' | 'coupons' | 'promotions' | 'cms_sections' | 'cms_banners';

/** Soft-deletes editable content after confirmation; RLS remains authoritative. */
export function SoftDeleteAction({
    table,
    id,
    label,
}: {
    table: SoftDeletableTable;
    id: string;
    label: string;
}) {
    const router = useRouter();
    const [open, setOpen] = React.useState(false);

    const mutation = useMutation({
        mutationFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const relation = supabase.from(table as never) as unknown as {
                update(values: { deleted_at: string; is_active: boolean }): {
                    eq(column: string, value: string): Promise<{ error: unknown }>;
                };
            };
            const { error } = await relation
                .update({ deleted_at: new Date().toISOString(), is_active: false })
                .eq('id', id);
            if (error) throw error;
        },
        onSuccess: () => {
            toast.success(`${label} deleted`);
            setOpen(false);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    return (
        <>
            <Button
                variant="ghost"
                size="icon"
                className="text-critical hover:bg-critical-soft"
                aria-label={`Delete ${label}`}
                onClick={() => setOpen(true)}
            >
                <Trash2 />
            </Button>
            <ConfirmDialog
                open={open}
                onOpenChange={setOpen}
                title={`Delete ${label}?`}
                description="This hides the item from customer-facing surfaces and keeps its audit history."
                confirmLabel="Delete"
                destructive
                loading={mutation.isPending}
                onConfirm={() => mutation.mutate()}
            />
        </>
    );
}
