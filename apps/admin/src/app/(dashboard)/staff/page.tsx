import type { Metadata } from 'next';
import { ShieldCheck, UsersRound } from 'lucide-react';
import { hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { EmptyState, ErrorState, InlineNotice } from '@/components/ui/states';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/overlays';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { dateOnly, humanise, initials } from '@/lib/utils';
import { StaffActions } from '@/features/staff/staff-actions';
import { StaffInviteDialog } from '@/features/staff/staff-invite-dialog';

export const metadata: Metadata = { title: 'Staff & roles' };
export const dynamic = 'force-dynamic';

export default async function StaffPage() {
    const session = await requirePermission(PERMISSIONS.STAFF_VIEW);
    const supabase = await createSupabaseServerClient();
    const canManageRoles = hasPermission(session, PERMISSIONS.ROLE_MANAGE);
    const canManageStaff = hasPermission(session, PERMISSIONS.ROLE_ASSIGN);
    const canResetPassword = hasPermission(session, PERMISSIONS.STAFF_UPDATE);
    const canCreateStaff =
        hasPermission(session, PERMISSIONS.STAFF_CREATE) && hasPermission(session, PERMISSIONS.ROLE_ASSIGN);

    const [grantsResult, staffResult, rolesResult, permissionsResult] = await Promise.all([
        supabase
            .from('user_roles')
            .select(
                `id, user_id, branch_id, is_primary, is_active, assigned_at, expires_at,
         roles(code, label, rank, surfaces),
         profiles!user_roles_user_profile_fkey(id, full_name, phone, email, status, last_seen_at)`,
            )
            .eq('is_active', true)
            .order('assigned_at', { ascending: false }),
        supabase
            .from('staff_members')
            .select(
                `id, user_id, employee_code, designation, department, joined_on, shift_start, shift_end,
         is_active, profiles!staff_members_user_profile_fkey(full_name, phone)`,
            )
            .is('deleted_at', null)
            .order('employee_code'),
        supabase
            .from('roles')
            .select('id, code, label, description, rank, surfaces, is_default')
            .order('rank', { ascending: false }),
        supabase
            .from('role_permissions')
            .select('role_id, permissions(code, label, resource, is_sensitive)'),
    ]);

    if (grantsResult.error) {
        return (
            <>
                <PageHeader title="Staff & roles" />
                <Card>
                    <ErrorState title="Could not load staff" message={grantsResult.error.message} />
                </Card>
            </>
        );
    }

    const grants = grantsResult.data ?? [];
    const staff = staffResult.data ?? [];
    const roles = rolesResult.data ?? [];
    const rolePermissions = permissionsResult.data ?? [];

    // One row per person, with all their role grants collapsed together.
    const people = new Map<
        string,
        {
            id: string;
            name: string | null;
            phone: string | null;
            email: string | null;
            status: string;
            lastSeen: string | null;
            roles: Array<{ code: string; label: string; isPrimary: boolean }>;
        }
    >();

    for (const grant of grants) {
        const profile = grant.profiles;
        if (!profile || !grant.roles) continue;
        if (grant.roles.code === 'CUSTOMER') continue;

        const existing = people.get(grant.user_id);
        const entry = existing ?? {
            id: profile.id,
            name: profile.full_name,
            phone: profile.phone,
            email: profile.email,
            status: profile.status,
            lastSeen: profile.last_seen_at,
            roles: [],
        };

        entry.roles.push({
            code: grant.roles.code,
            label: grant.roles.label,
            isPrimary: grant.is_primary,
        });
        people.set(grant.user_id, entry);
    }

    const staffList = [...people.values()].sort((a, b) => (a.name ?? '').localeCompare(b.name ?? ''));

    const permissionsByRole = new Map<string, Array<{ code: string; label: string; isSensitive: boolean }>>();
    for (const row of rolePermissions) {
        if (!row.permissions) continue;
        const list = permissionsByRole.get(row.role_id) ?? [];
        list.push({
            code: row.permissions.code,
            label: row.permissions.label,
            isSensitive: row.permissions.is_sensitive,
        });
        permissionsByRole.set(row.role_id, list);
    }

    return (
        <>
            <PageHeader
                title="Staff & roles"
                description="Who can do what. Roles map to permissions; nothing in the platform checks a role name directly."
                actions={canCreateStaff ? <StaffInviteDialog /> : null}
            />

            <InlineNotice tone="info" className="mb-4">
                Permissions are enforced by the database on every request. Hiding a screen in this dashboard
                is a convenience, not the security boundary.
            </InlineNotice>

            <Tabs defaultValue="people">
                <TabsList>
                    <TabsTrigger value="people">People ({staffList.length})</TabsTrigger>
                    <TabsTrigger value="roles">Roles ({roles.length})</TabsTrigger>
                    <TabsTrigger value="records">Employment records</TabsTrigger>
                </TabsList>

                <TabsContent value="people">
                    <TableWrap>
                        <Table>
                            <THead>
                                <TR className="hover:bg-transparent">
                                    <TH>Person</TH>
                                    <TH>Contact</TH>
                                    <TH>Roles</TH>
                                    <TH>Account</TH>
                                    <TH>Last seen</TH>
                                    {canManageStaff ? <TH className="w-12" /> : null}
                                </TR>
                            </THead>
                            <TBody>
                                {staffList.length === 0 ? (
                                    <TableMessageRow colSpan={canManageStaff ? 6 : 5}>
                                        <EmptyState
                                            icon={UsersRound}
                                            title="No staff accounts yet"
                                            description={canCreateStaff ? 'Use Add staff to create a work account and give it a mobile sign-in password.' : 'Grant a back-office role to give someone access.'}
                                        />
                                    </TableMessageRow>
                                ) : (
                                    staffList.map((person) => (
                                        <TR key={person.id}>
                                            <TD>
                                                <div className="flex items-center gap-2.5">
                                                    <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-surface-muted text-[11.5px] font-semibold text-ink-muted">
                                                        {initials(person.name)}
                                                    </span>
                                                    <span className="max-w-40 truncate text-[13.5px] font-medium text-ink">
                                                        {person.name ?? 'Unnamed'}
                                                    </span>
                                                </div>
                                            </TD>

                                            <TD>
                                                <span className="block text-[12.5px]">{person.phone ?? '—'}</span>
                                                <span className="block max-w-40 truncate text-[11.5px] text-ink-muted">
                                                    {person.email ?? ''}
                                                </span>
                                            </TD>

                                            <TD>
                                                <div className="flex flex-wrap gap-1">
                                                    {person.roles.map((role) => (
                                                        <Badge key={role.code} tone={role.isPrimary ? 'brand' : 'neutral'}>
                                                            {role.label}
                                                        </Badge>
                                                    ))}
                                                </div>
                                            </TD>

                                            <TD>
                                                <Badge tone={person.status === 'ACTIVE' ? 'positive' : 'critical'}>
                                                    {humanise(person.status)}
                                                </Badge>
                                            </TD>

                                            <TD className="text-[12.5px] whitespace-nowrap text-ink-muted">
                                                {person.lastSeen ? dateOnly(person.lastSeen) : '—'}
                                            </TD>
                                            {canManageStaff ? (
                                                <TD>
                                                    <StaffActions
                                                        userId={person.id}
                                                        name={person.name ?? 'this person'}
                                                        roles={person.roles}
                                                        canResetPassword={canResetPassword}
                                                    />
                                                </TD>
                                            ) : null}
                                        </TR>
                                    ))
                                )}
                            </TBody>
                        </Table>
                    </TableWrap>
                </TabsContent>

                <TabsContent value="roles" className="space-y-4">
                    {roles
                        .filter((role) => role.code !== 'CUSTOMER')
                        .map((role) => {
                            const perms = permissionsByRole.get(role.id) ?? [];
                            const sensitive = perms.filter((permission) => permission.isSensitive);

                            return (
                                <Card key={role.id}>
                                    <CardToolbar
                                        title={
                                            <span className="flex items-center gap-2">
                                                {role.label}
                                                <Badge tone="neutral" className="px-1.5 py-0">
                                                    rank {role.rank}
                                                </Badge>
                                            </span>
                                        }
                                        description={role.description ?? undefined}
                                        action={
                                            <span className="text-[12.5px] text-ink-muted">
                                                {perms.length} permission{perms.length === 1 ? '' : 's'}
                                                {sensitive.length > 0 ? ` · ${sensitive.length} sensitive` : ''}
                                            </span>
                                        }
                                    />
                                    <CardContent>
                                        <div className="flex flex-wrap gap-1.5">
                                            {perms
                                                .sort((a, b) => a.code.localeCompare(b.code))
                                                .map((permission) => (
                                                    <span
                                                        key={permission.code}
                                                        className={
                                                            permission.isSensitive
                                                                ? 'inline-flex items-center gap-1 rounded bg-critical-soft px-1.5 py-0.5 font-mono text-[11px] text-critical'
                                                                : 'rounded bg-surface-muted px-1.5 py-0.5 font-mono text-[11px] text-ink-muted'
                                                        }
                                                        title={permission.label}
                                                    >
                                                        {permission.isSensitive ? (
                                                            <ShieldCheck className="size-2.5" aria-hidden />
                                                        ) : null}
                                                        {permission.code}
                                                    </span>
                                                ))}
                                        </div>

                                        {role.surfaces && role.surfaces.length > 0 ? (
                                            <p className="mt-3 text-[12px] text-ink-muted">
                                                Signs in to: {role.surfaces.map((surface) => humanise(surface)).join(', ')}
                                            </p>
                                        ) : null}
                                    </CardContent>
                                </Card>
                            );
                        })}

                    {!canManageRoles ? (
                        <InlineNotice tone="info">
                            Editing role permissions requires the Manage roles permission, which is reserved for the
                            owner.
                        </InlineNotice>
                    ) : null}
                </TabsContent>

                <TabsContent value="records">
                    <TableWrap>
                        <Table>
                            <THead>
                                <TR className="hover:bg-transparent">
                                    <TH>Employee</TH>
                                    <TH>Code</TH>
                                    <TH>Designation</TH>
                                    <TH>Department</TH>
                                    <TH>Shift</TH>
                                    <TH>Joined</TH>
                                    <TH>State</TH>
                                </TR>
                            </THead>
                            <TBody>
                                {staff.length === 0 ? (
                                    <TableMessageRow colSpan={7}>
                                        <EmptyState title="No employment records" />
                                    </TableMessageRow>
                                ) : (
                                    staff.map((member) => (
                                        <TR key={member.id}>
                                            <TD className="text-[13px] font-medium">
                                                {member.profiles?.full_name ?? '—'}
                                                <span className="block text-[11.5px] font-normal text-ink-muted">
                                                    {member.profiles?.phone ?? ''}
                                                </span>
                                            </TD>
                                            <TD className="font-mono text-[12.5px]">{member.employee_code ?? '—'}</TD>
                                            <TD className="text-[12.5px]">{member.designation ?? '—'}</TD>
                                            <TD className="text-[12.5px]">{member.department ?? '—'}</TD>
                                            <TD className="tnum text-[12.5px]">
                                                {member.shift_start && member.shift_end
                                                    ? `${member.shift_start.slice(0, 5)}–${member.shift_end.slice(0, 5)}`
                                                    : '—'}
                                            </TD>
                                            <TD className="text-[12.5px] whitespace-nowrap text-ink-muted">
                                                {dateOnly(member.joined_on)}
                                            </TD>
                                            <TD>
                                                <Badge tone={member.is_active ? 'positive' : 'neutral'}>
                                                    {member.is_active ? 'Active' : 'Inactive'}
                                                </Badge>
                                            </TD>
                                        </TR>
                                    ))
                                )}
                            </TBody>
                        </Table>
                    </TableWrap>
                </TabsContent>
            </Tabs>
        </>
    );
}
