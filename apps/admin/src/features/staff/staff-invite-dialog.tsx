'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { Copy, KeyRound, UserPlus } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import {
    Dialog,
    DialogBody,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/overlays';
import { Field, Input, Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/form-controls';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';
import type { AppRole } from '@bitesbox/shared-types';

const STAFF_ROLE_OPTIONS: Array<{ value: AppRole; label: string }> = [
    { value: 'KITCHEN_STAFF', label: 'Kitchen staff' },
    { value: 'MANAGER', label: 'Manager' },
    { value: 'OPERATIONS', label: 'Operations' },
    { value: 'FINANCE', label: 'Finance' },
    { value: 'SUPPORT', label: 'Support' },
    { value: 'MARKETING', label: 'Marketing' },
    { value: 'ADMIN', label: 'Administrator' },
];

type Credentials = {
    email: string;
    fullName: string;
    role: string;
    temporaryPassword: string;
};

export function StaffInviteDialog() {
    const router = useRouter();
    const [open, setOpen] = React.useState(false);
    const [fullName, setFullName] = React.useState('');
    const [email, setEmail] = React.useState('');
    const [phone, setPhone] = React.useState('');
    const [role, setRole] = React.useState<AppRole>('KITCHEN_STAFF');
    const [password, setPassword] = React.useState('');
    const [employeeCode, setEmployeeCode] = React.useState('');
    const [designation, setDesignation] = React.useState('');
    const [department, setDepartment] = React.useState('');
    const [saving, setSaving] = React.useState(false);
    const [credentials, setCredentials] = React.useState<Credentials | null>(null);

    const resetForm = () => {
        setFullName('');
        setEmail('');
        setPhone('');
        setRole('KITCHEN_STAFF');
        setPassword('');
        setEmployeeCode('');
        setDesignation('');
        setDepartment('');
        setCredentials(null);
    };

    const close = (nextOpen: boolean) => {
        setOpen(nextOpen);
        if (!nextOpen) resetForm();
    };

    const create = async () => {
        if (fullName.trim().length < 2 || !email.includes('@') || password.length < 8) return;
        setSaving(true);
        try {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase.functions.invoke('admin-operation', {
                body: {
                    operation: 'CREATE_STAFF',
                    full_name: fullName,
                    email,
                    phone: phone || null,
                    role,
                    temporary_password: password,
                    employee_code: employeeCode || null,
                    designation: designation || null,
                    department: department || null,
                },
            });
            if (error) {
                const context = (error as { context?: { body?: unknown } }).context;
                throw context?.body ?? error;
            }

            const result = (data as { result?: { email?: string; full_name?: string; role?: string; temporary_password?: string } })?.result;
            const created: Credentials = {
                email: result?.email ?? email.trim().toLowerCase(),
                fullName: result?.full_name ?? fullName.trim(),
                role: result?.role ?? role,
                temporaryPassword: result?.temporary_password ?? password,
            };
            setCredentials(created);
            toast.success(`${created.fullName} can now sign in with the Bites Box app`);
            router.refresh();
        } catch (error) {
            toast.error(errorMessage(error));
        } finally {
            setSaving(false);
        }
    };

    const copy = async (value: string, label: string) => {
        await navigator.clipboard.writeText(value);
        toast.success(`${label} copied`);
    };

    return (
        <>
            <Button size="sm" onClick={() => setOpen(true)}>
                <UserPlus />
                Add staff
            </Button>

            <Dialog open={open} onOpenChange={close}>
                <DialogContent size="lg">
                    <DialogHeader>
                        <DialogTitle>{credentials ? 'Staff account created' : 'Add staff member'}</DialogTitle>
                        <DialogDescription>
                            {credentials
                                ? 'Share these credentials securely. The password is shown only in this dialog.'
                                : 'Creates the Auth account, staff record and app role together.'}
                        </DialogDescription>
                    </DialogHeader>

                    {credentials ? (
                        <DialogBody className="space-y-4">
                            <div className="rounded-[var(--radius-control)] border border-positive/25 bg-positive-soft p-4">
                                <p className="text-[13px] font-semibold text-ink">{credentials.fullName}</p>
                                <p className="mt-0.5 text-[12px] text-ink-muted">{credentials.role.replaceAll('_', ' ')}</p>
                            </div>
                            <Field label="Work email">
                                <div className="flex gap-2">
                                    <Input value={credentials.email} readOnly />
                                    <Button type="button" variant="secondary" size="icon" aria-label="Copy work email" onClick={() => copy(credentials.email, 'Work email')}>
                                        <Copy />
                                    </Button>
                                </div>
                            </Field>
                            <Field label="Temporary password" hint="Give this to the staff member through a secure channel.">
                                <div className="flex gap-2">
                                    <Input value={credentials.temporaryPassword} readOnly className="font-mono" />
                                    <Button type="button" variant="secondary" size="icon" aria-label="Copy temporary password" onClick={() => copy(credentials.temporaryPassword, 'Temporary password')}>
                                        <Copy />
                                    </Button>
                                </div>
                            </Field>
                            <p className="text-[12.5px] leading-relaxed text-ink-muted">
                                In the mobile app, open Account → Staff sign-in and use this work email and password.
                            </p>
                        </DialogBody>
                    ) : (
                        <DialogBody className="grid gap-4 md:grid-cols-2">
                            <Field label="Full name" required>
                                <Input value={fullName} onChange={(event) => setFullName(event.target.value)} autoFocus />
                            </Field>
                            <Field label="Work email" required hint="This is the login email.">
                                <Input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="email" />
                            </Field>
                            <Field label="Temporary password" required hint="At least 8 characters. You can reset it later from the row menu.">
                                <Input type="text" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="new-password" />
                            </Field>
                            <Field label="App role" required>
                                <Select value={role} onValueChange={(value) => setRole(value as AppRole)}>
                                    <SelectTrigger><SelectValue /></SelectTrigger>
                                    <SelectContent>
                                        {STAFF_ROLE_OPTIONS.map((item) => <SelectItem key={item.value} value={item.value}>{item.label}</SelectItem>)}
                                    </SelectContent>
                                </Select>
                            </Field>
                            <Field label="Phone" hint="Optional contact number.">
                                <Input value={phone} onChange={(event) => setPhone(event.target.value)} />
                            </Field>
                            <Field label="Employee code">
                                <Input value={employeeCode} onChange={(event) => setEmployeeCode(event.target.value)} placeholder="BB-EMP-009" />
                            </Field>
                            <Field label="Designation">
                                <Input value={designation} onChange={(event) => setDesignation(event.target.value)} placeholder="Kitchen staff" />
                            </Field>
                            <Field label="Department">
                                <Input value={department} onChange={(event) => setDepartment(event.target.value)} placeholder="Kitchen" />
                            </Field>
                        </DialogBody>
                    )}

                    <DialogFooter>
                        <Button variant="secondary" onClick={() => close(false)}>{credentials ? 'Done' : 'Cancel'}</Button>
                        {!credentials ? (
                            <Button loading={saving} disabled={fullName.trim().length < 2 || !email.includes('@') || password.length < 8} onClick={create}>
                                <KeyRound /> Create account
                            </Button>
                        ) : null}
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    );
}
