'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { KeyRound, MoreHorizontal, Pencil, Plus, UserMinus, X } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
    ConfirmDialog,
    Dialog,
    DialogBody,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from '@/components/ui/overlays';
import { Field, Input, Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/form-controls';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import type { AppRole } from '@bitesbox/shared-types';
import { toast } from 'sonner';

const ROLE_OPTIONS: Array<{ value: AppRole; label: string }> = [
    { value: 'MANAGER', label: 'Manager' },
    { value: 'OPERATIONS', label: 'Operations' },
    { value: 'FINANCE', label: 'Finance' },
    { value: 'SUPPORT', label: 'Support' },
    { value: 'MARKETING', label: 'Marketing' },
    { value: 'KITCHEN_STAFF', label: 'Kitchen staff' },
    { value: 'DELIVERY_PARTNER', label: 'Delivery partner' },
    { value: 'ADMIN', label: 'Admin' },
];

export function StaffActions({
    userId,
    name,
    roles,
    canResetPassword,
}: {
    userId: string;
    name: string;
    roles: Array<{ code: string; label: string; isPrimary: boolean }>;
    canResetPassword: boolean;
}) {
    const router = useRouter();
    const [editOpen, setEditOpen] = React.useState(false);
    const [removeOpen, setRemoveOpen] = React.useState(false);
    const [resetOpen, setResetOpen] = React.useState(false);
    const [temporaryPassword, setTemporaryPassword] = React.useState('');
    const [selectedRole, setSelectedRole] = React.useState<AppRole>('MANAGER');

    const mutation = useMutation({
        mutationFn: async ({ role, grant }: { role: AppRole; grant: boolean }) => {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase.rpc('manage_user_role', {
                p_user_id: userId,
                p_role: role,
                p_grant: grant,
                p_make_primary: grant,
            });
            if (error) throw error;
        },
        onSuccess: (_data, input) => {
            toast.success(input.grant ? `${name} updated` : `${name} access removed`);
            setEditOpen(false);
            setRemoveOpen(false);
            router.refresh();
        },
        onError: (error) => toast.error(errorMessage(error)),
    });

    const revoke = async () => {
        for (const role of roles) {
            if (role.code === 'OWNER' || role.code === 'CUSTOMER') continue;
            await mutation.mutateAsync({ role: role.code as AppRole, grant: false });
        }
    };

    const resetPassword = async () => {
        if (temporaryPassword.trim().length < 8) return;
        try {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.functions.invoke('admin-operation', {
                body: {
                    operation: 'RESET_STAFF_PASSWORD',
                    user_id: userId,
                    temporary_password: temporaryPassword,
                },
            });
            if (error) {
                const context = (error as { context?: { body?: unknown } }).context;
                throw context?.body ?? error;
            }
            const result = (data as { result?: { temporary_password?: string } })?.result;
            toast.success(`${name}'s password was reset`);
            setResetOpen(false);
            setTemporaryPassword(result?.temporary_password ?? '');
        } catch (error) {
            toast.error(errorMessage(error));
        }
    };

    return (
        <>
            <DropdownMenu>
                <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon" aria-label={`Actions for ${name}`}>
                        <MoreHorizontal />
                    </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent>
                    <DropdownMenuItem onSelect={() => setEditOpen(true)}>
                        <Pencil />
                        Edit access
                    </DropdownMenuItem>
                    {canResetPassword ? (
                        <DropdownMenuItem onSelect={() => setResetOpen(true)}>
                            <KeyRound />
                            Reset password
                        </DropdownMenuItem>
                    ) : null}
                    <DropdownMenuSeparator />
                    <DropdownMenuItem destructive onSelect={() => setRemoveOpen(true)}>
                        <UserMinus />
                        Remove access
                    </DropdownMenuItem>
                </DropdownMenuContent>
            </DropdownMenu>

            <Dialog open={editOpen} onOpenChange={setEditOpen}>
                <DialogContent size="sm">
                    <DialogHeader>
                        <DialogTitle>Edit {name}</DialogTitle>
                        <DialogDescription>Grant a role or remove an existing role assignment.</DialogDescription>
                    </DialogHeader>
                    <DialogBody className="space-y-4">
                        <Field label="Current roles">
                            <div className="flex flex-wrap gap-1.5">
                                {roles.map((role) => (
                                    <span key={role.code} className="inline-flex items-center gap-1">
                                        <Badge tone={role.isPrimary ? 'brand' : 'neutral'}>{role.label}</Badge>
                                        {role.code !== 'OWNER' ? (
                                            <button
                                                type="button"
                                                className="rounded-full p-0.5 text-ink-muted hover:bg-critical-soft hover:text-critical"
                                                aria-label={`Remove ${role.label}`}
                                                onClick={() => mutation.mutate({ role: role.code as AppRole, grant: false })}
                                            >
                                                <X className="size-3" />
                                            </button>
                                        ) : null}
                                    </span>
                                ))}
                            </div>
                        </Field>
                        <Field label="Add or change primary role">
                            <div className="flex gap-2">
                                <Select value={selectedRole} onValueChange={(value) => setSelectedRole(value as AppRole)}>
                                    <SelectTrigger className="flex-1">
                                        <SelectValue />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {ROLE_OPTIONS.map((role) => (
                                            <SelectItem key={role.value} value={role.value}>
                                                {role.label}
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                                <Button
                                    size="icon"
                                    aria-label="Grant role"
                                    loading={mutation.isPending}
                                    onClick={() => mutation.mutate({ role: selectedRole, grant: true })}
                                >
                                    <Plus />
                                </Button>
                            </div>
                        </Field>
                    </DialogBody>
                    <DialogFooter>
                        <Button variant="secondary" onClick={() => setEditOpen(false)}>
                            Done
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            <ConfirmDialog
                open={removeOpen}
                onOpenChange={setRemoveOpen}
                title={`Remove ${name}'s access?`}
                description="This revokes every back-office role. The account remains in Supabase and can be granted access again later."
                confirmLabel="Remove access"
                destructive
                loading={mutation.isPending}
                onConfirm={revoke}
            />

            <Dialog open={resetOpen} onOpenChange={setResetOpen}>
                <DialogContent size="sm">
                    <DialogHeader>
                        <DialogTitle>Reset {name}&apos;s password</DialogTitle>
                        <DialogDescription>The staff member will use this new password in Staff sign-in.</DialogDescription>
                    </DialogHeader>
                    <DialogBody>
                        <Field label="Temporary password" required hint="At least 8 characters. Share it securely.">
                            <Input
                                type="text"
                                value={temporaryPassword}
                                onChange={(event) => setTemporaryPassword(event.target.value)}
                                autoFocus
                                autoComplete="new-password"
                            />
                        </Field>
                    </DialogBody>
                    <DialogFooter>
                        <Button variant="secondary" onClick={() => setResetOpen(false)}>Cancel</Button>
                        <Button disabled={temporaryPassword.trim().length < 8} onClick={() => void resetPassword()}>
                            <KeyRound /> Reset password
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    );
}
