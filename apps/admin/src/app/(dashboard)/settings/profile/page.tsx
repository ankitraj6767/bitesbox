import type { Metadata } from 'next';
import { ShieldCheck } from 'lucide-react';
import { requireSession } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { humanise, initials } from '@/lib/utils';

export const metadata: Metadata = { title: 'My profile' };
export const dynamic = 'force-dynamic';

export default async function ProfilePage() {
    const session = await requireSession();
    const supabase = await createSupabaseServerClient();

    const { data: staffRecord } = await supabase
        .from('staff_members')
        .select('employee_code, designation, department, joined_on, shift_start, shift_end')
        .eq('user_id', session.user_id ?? '')
        .maybeSingle();

    const profile = session.profile;
    const permissions = session.permissions ?? [];

    return (
        <>
            <PageHeader
                breadcrumbs={[{ label: 'Settings', href: '/settings' }, { label: 'My profile' }]}
                title="My profile"
                description="Your account, roles and exactly what you are allowed to do."
            />

            <div className="grid gap-4 lg:grid-cols-[320px_minmax(0,1fr)]">
                <Card className="h-fit">
                    <CardContent className="pt-5 text-center">
                        <span className="mx-auto flex size-16 items-center justify-center rounded-full bg-brand-600 font-display text-xl font-semibold text-white">
                            {initials(profile?.full_name ?? profile?.phone)}
                        </span>
                        <p className="mt-3 font-display text-[17px] font-semibold text-ink">
                            {profile?.full_name ?? 'Staff account'}
                        </p>
                        <p className="text-[12.5px] text-ink-muted">{profile?.email ?? profile?.phone}</p>

                        <div className="mt-3 flex flex-wrap justify-center gap-1.5">
                            {(session.roles ?? []).map((grant) => (
                                <Badge key={`${grant.role}-${grant.branch_id ?? 'all'}`} tone={grant.is_primary ? 'brand' : 'neutral'}>
                                    {grant.label}
                                </Badge>
                            ))}
                        </div>

                        <dl className="mt-4 space-y-1.5 border-t border-hairline pt-4 text-left text-[12.5px]">
                            {staffRecord?.employee_code ? (
                                <Row label="Employee code" value={staffRecord.employee_code} />
                            ) : null}
                            {staffRecord?.designation ? (
                                <Row label="Designation" value={staffRecord.designation} />
                            ) : null}
                            {staffRecord?.department ? (
                                <Row label="Department" value={staffRecord.department} />
                            ) : null}
                            {staffRecord?.shift_start && staffRecord.shift_end ? (
                                <Row
                                    label="Shift"
                                    value={`${staffRecord.shift_start.slice(0, 5)}–${staffRecord.shift_end.slice(0, 5)}`}
                                />
                            ) : null}
                            <Row label="Account" value={humanise(profile?.status ?? 'ACTIVE')} />
                            {profile?.id ? <Row label="Language" value={profile.preferred_language === 'hi' ? 'Hindi' : 'English'} /> : null}
                        </dl>
                    </CardContent>
                </Card>

                <Card>
                    <CardToolbar
                        title="What you can do"
                        description={`${permissions.length} permission${permissions.length === 1 ? '' : 's'} granted through your roles`}
                    />
                    <CardContent>
                        <div className="flex flex-wrap gap-1.5">
                            {permissions
                                .slice()
                                .sort()
                                .map((permission) => (
                                    <span
                                        key={permission}
                                        className="rounded bg-surface-muted px-1.5 py-0.5 font-mono text-[11px] text-ink-muted"
                                    >
                                        {permission}
                                    </span>
                                ))}
                        </div>

                        <div className="mt-5 flex items-start gap-2 rounded-[var(--radius-control)] border border-hairline bg-surface-muted/50 px-3 py-2.5">
                            <ShieldCheck className="mt-0.5 size-4 shrink-0 text-ink-muted" aria-hidden />
                            <p className="text-[12.5px] leading-relaxed text-ink-muted">
                                These permissions are checked by the database on every request. If a permission is
                                revoked, it takes effect on your next action — no sign-out needed.
                            </p>
                        </div>

                        <div className="mt-5 border-t border-hairline pt-4">
                            <p className="text-[11.5px] font-semibold tracking-wide text-ink-muted uppercase">
                                Branches you can act on
                            </p>
                            <div className="mt-2 flex flex-wrap gap-1.5">
                                {(session.branches ?? []).map((branch) => (
                                    <Badge key={branch.id} tone="neutral">
                                        {branch.name} ({branch.code})
                                    </Badge>
                                ))}
                            </div>
                        </div>

                        {profile ? (
                            <p className="mt-5 text-[12px] text-ink-muted">
                                Signed in as {profile.email ?? profile.phone}
                                {profile.onboarding_completed ? '' : ' · profile incomplete'}
                                {session.account_active ? '' : ' · account inactive'}
                            </p>
                        ) : null}
                    </CardContent>
                </Card>
            </div>
        </>
    );
}

function Row({ label, value }: { label: string; value: string }) {
    return (
        <div className="flex items-center justify-between gap-3">
            <dt className="text-ink-muted">{label}</dt>
            <dd className="font-medium text-ink">{value}</dd>
        </div>
    );
}
