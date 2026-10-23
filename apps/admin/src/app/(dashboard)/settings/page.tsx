import type { Metadata } from 'next';
import { activeBranchId, hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent } from '@/components/ui/card';
import { ErrorState, InlineNotice } from '@/components/ui/states';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/overlays';
import { SettingsEditor, type SettingRow } from '@/features/settings/settings-editor';
import { FeatureFlagList, type FeatureFlagRow } from '@/features/settings/feature-flag-list';
import { DeliveryZoneManager } from '@/features/settings/delivery-zone-manager';
import { BranchSettingsManager } from '@/features/settings/branch-settings-manager';
import { BranchHoursManager } from '@/features/settings/branch-hours-manager';
import { BranchHolidayManager } from '@/features/settings/branch-holiday-manager';
import { TaxCategoryManager } from '@/features/settings/tax-category-manager';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { humanise } from '@/lib/utils';

export const metadata: Metadata = { title: 'Settings' };
export const dynamic = 'force-dynamic';

export default async function SettingsPage() {
    const session = await requirePermission(PERMISSIONS.SETTINGS_VIEW);
    const supabase = await createSupabaseServerClient();
    const branchId = await activeBranchId(session);

    const canEditSettings = hasPermission(session, PERMISSIONS.SETTINGS_UPDATE);
    const canEditFlags = hasPermission(session, PERMISSIONS.FEATURE_FLAG_UPDATE);

    const [
        settingsResult,
        flagsResult,
        zonesResult,
        hoursResult,
        holidaysResult,
        branchResult,
        taxResult,
        otherBranchesResult,
    ] = await Promise.all([
        supabase
            .from('settings')
            .select('key, value, value_type, group:group, label, description, is_public')
            .order('key'),
        supabase.from('feature_flags').select('key, label, description, is_enabled, rollout_percentage').order('key'),
        supabase
            .from('delivery_zones')
            .select(
                `id, branch_id, name, description, kind, min_distance_km, max_distance_km, polygon, delivery_fee,
           min_order_amount, free_delivery_threshold, per_km_surcharge, surcharge_after_km,
           peak_surcharge, peak_starts_at, peak_ends_at, dynamic_surcharge, base_eta_minutes, extra_eta_minutes,
           cod_enabled, max_cod_amount, is_serviceable, is_active, priority`,
            )
            .is('deleted_at', null)
            .eq('branch_id', branchId ?? '')
            .order('priority'),
        supabase
            .from('branch_hours')
            .select('id, branch_id, day_of_week, opens_at, closes_at, day_part, is_closed, closes_next_day')
            .eq('branch_id', branchId ?? '')
            .order('day_of_week')
            .order('opens_at'),
        supabase
            .from('branch_holidays')
            .select('id, branch_id, holiday_on, label, is_closed, opens_at, closes_at')
            .eq('branch_id', branchId ?? '')
            .order('holiday_on'),
        supabase
            .from('branches')
            .select(
                `id, code, name, legal_name, phone, alternate_phone, whatsapp_phone, email, address_line1, address_line2, landmark,
           city, state, postal_code, latitude, longitude, google_maps_url, gstin, fssai_licence_no, fssai_valid_till, timezone,
           service_mode, default_prep_minutes, rush_buffer_minutes, max_concurrent_orders, is_active, is_default`,
            )
            .eq('id', branchId ?? '')
            .maybeSingle(),
        supabase
            .from('tax_categories')
            .select(
                'id, code, name, description, rate, cgst_rate, sgst_rate, igst_rate, cess_rate, hsn_sac_code, is_inclusive, is_default, is_active',
            )
            .is('deleted_at', null)
            .order('code'),
        branchId
            ? supabase
                  .from('branches')
                  .select('id', { count: 'exact', head: true })
                  .neq('id', branchId)
                  .eq('is_active', true)
                  .is('deleted_at', null)
            : Promise.resolve({ count: 0, data: null, error: null }),
    ]);

    const branchPermissionResult = branchId
        ? await supabase.rpc('has_permission', {
              p_permission: PERMISSIONS.BRANCH_MANAGE,
              p_branch_id: branchId,
          })
        : null;
    const canManageBranch = branchPermissionResult?.data === true && !branchPermissionResult.error;
    const branchPermissionMessage = branchPermissionResult?.error
        ? 'Outlet access could not be verified. Refresh the page before managing delivery zones.'
        : !canManageBranch && hasPermission(session, PERMISSIONS.BRANCH_MANAGE)
          ? 'Your Manage branch permission does not include this outlet. Select an outlet in your assigned scope, or ask an owner to review your branch assignment.'
          : undefined;

    if (settingsResult.error) {
        return (
            <>
                <PageHeader title="Settings" />
                <Card>
                    <ErrorState title="Could not load settings" message={settingsResult.error.message} />
                </Card>
            </>
        );
    }

    const settings = (settingsResult.data ?? []) as unknown as SettingRow[];
    const flags = (flagsResult.data ?? []) as unknown as FeatureFlagRow[];
    const zones = zonesResult.data ?? [];
    const hours = hoursResult.data ?? [];
    const holidays = holidaysResult.data ?? [];
    const branch = branchResult.data;
    const taxes = taxResult.data ?? [];
    const canArchiveBranch = !otherBranchesResult.error && (otherBranchesResult.count ?? 0) > 0;

    const byGroup = (group: string) => settings.filter((setting) => setting.group === group);

    return (
        <>
            <PageHeader
                title="Settings"
                description="Everything an operator can change without a deploy. Record-based settings can be edited or archived; singleton keys and feature flags are edited in place. Each change is audited."
            />

            {!canEditSettings ? (
                <InlineNotice tone="info" className="mb-4">
                    You have read-only access to settings. Ask an owner or administrator to make changes.
                </InlineNotice>
            ) : null}

            <Tabs defaultValue="ordering">
                <TabsList className="flex-wrap">
                    <TabsTrigger value="ordering">Ordering</TabsTrigger>
                    <TabsTrigger value="delivery">Delivery</TabsTrigger>
                    <TabsTrigger value="payments">Payments</TabsTrigger>
                    <TabsTrigger value="branding">Branding</TabsTrigger>
                    <TabsTrigger value="growth">Growth</TabsTrigger>
                    <TabsTrigger value="flags">Feature flags</TabsTrigger>
                    <TabsTrigger value="branch">Branch</TabsTrigger>
                </TabsList>

                <TabsContent value="ordering" className="space-y-4">
                    <SettingsEditor
                        group="ordering"
                        title="Ordering"
                        description="Fees, rounding and scheduling behaviour."
                        settings={byGroup('ordering')}
                        canEdit={canEditSettings}
                    />
                    <SettingsEditor
                        group="kitchen"
                        title="Kitchen"
                        description="Service-level targets that drive the delay alerts."
                        settings={byGroup('kitchen')}
                        canEdit={canEditSettings}
                    />
                    <SettingsEditor
                        group="system"
                        title="System"
                        description="Maintenance mode, OTP provider and supported app versions."
                        settings={byGroup('system')}
                        canEdit={canEditSettings}
                        requireTypedConfirmation
                    />
                </TabsContent>

                <TabsContent value="delivery" className="space-y-4">
                    <SettingsEditor
                        group="delivery"
                        title="Delivery"
                        description="Distance limits, OTP length and location sampling."
                        settings={byGroup('delivery')}
                        canEdit={canEditSettings}
                    />

                    <DeliveryZoneManager
                        zones={zones}
                        branchId={branchId}
                        branchName={branch?.name ?? 'selected outlet'}
                        canManage={canManageBranch}
                        permissionMessage={branchPermissionMessage}
                        loadError={Boolean(zonesResult.error)}
                    />
                </TabsContent>

                <TabsContent value="payments" className="space-y-4">
                    <SettingsEditor
                        group="payments"
                        title="Payments & cash on delivery"
                        description="COD limits, unpaid order expiry and refund approval thresholds."
                        settings={byGroup('payments')}
                        canEdit={canEditSettings}
                        requireTypedConfirmation
                    />

                    <Card>
                        <TaxCategoryManager
                            categories={taxes}
                            canEdit={canEditSettings}
                            loadError={Boolean(taxResult.error)}
                        />
                    </Card>
                </TabsContent>

                <TabsContent value="branding" className="space-y-4">
                    <SettingsEditor
                        group="branding"
                        title="Brand"
                        description="Name, logo paths and colour tokens. The mobile app reads these at launch."
                        settings={byGroup('branding')}
                        canEdit={canEditSettings}
                    />
                    <SettingsEditor
                        group="contact"
                        title="Contact & social"
                        description="Shown in the app help screens and on invoices."
                        settings={byGroup('contact')}
                        canEdit={canEditSettings}
                    />
                    <SettingsEditor
                        group="tax"
                        title="Invoice"
                        description="Footer copy and tax notes printed on customer invoices."
                        settings={byGroup('tax')}
                        canEdit={canEditSettings}
                    />
                </TabsContent>

                <TabsContent value="growth" className="space-y-4">
                    <SettingsEditor
                        group="growth"
                        title="Growth & loyalty"
                        description="Segment thresholds, abandoned-cart timing and loyalty economics."
                        settings={byGroup('growth')}
                        canEdit={canEditSettings}
                    />
                </TabsContent>

                <TabsContent value="flags">
                    <FeatureFlagList flags={flags} canEdit={canEditFlags} />
                </TabsContent>

                <TabsContent value="branch" className="space-y-4">
                    {branchResult.error ? (
                        <Card>
                            <ErrorState
                                title="Could not load outlet settings"
                                message="Refresh the page or select another outlet before editing branch details."
                            />
                        </Card>
                    ) : branch ? (
                        <Card>
                            <BranchSettingsManager
                                branch={branch}
                                canManage={canManageBranch}
                                canArchive={canArchiveBranch}
                                archiveCheckFailed={Boolean(otherBranchesResult.error)}
                            />
                            <CardContent>
                                <dl className="grid gap-x-8 gap-y-3 sm:grid-cols-2">
                                    <Detail label="Legal name" value={branch.legal_name} />
                                    <Detail label="Phone" value={branch.phone} />
                                    <Detail label="WhatsApp" value={branch.whatsapp_phone} />
                                    <Detail label="Email" value={branch.email} />
                                    <Detail
                                        label="Address"
                                        value={[
                                            branch.address_line1,
                                            branch.address_line2,
                                            branch.city,
                                            branch.state,
                                            branch.postal_code,
                                        ]
                                            .filter(Boolean)
                                            .join(', ')}
                                    />
                                    <Detail label="GSTIN" value={branch.gstin} mono />
                                    <Detail label="FSSAI licence" value={branch.fssai_licence_no} mono />
                                    <Detail label="FSSAI valid till" value={branch.fssai_valid_till} />
                                    <Detail label="Service mode" value={humanise(branch.service_mode)} />
                                    <Detail
                                        label="Default prep time"
                                        value={`${branch.default_prep_minutes} minutes`}
                                    />
                                    <Detail label="Rush buffer" value={`${branch.rush_buffer_minutes} minutes`} />
                                    <Detail
                                        label="Max concurrent orders"
                                        value={
                                            branch.max_concurrent_orders
                                                ? String(branch.max_concurrent_orders)
                                                : 'Unlimited'
                                        }
                                    />
                                </dl>

                                {!canManageBranch ? (
                                    <InlineNotice tone="info" className="mt-4">
                                        Editing branch details needs the Manage branch permission.
                                    </InlineNotice>
                                ) : null}
                            </CardContent>
                        </Card>
                    ) : (
                        <Card>
                            <InlineNotice tone="info">
                                Select an outlet to view and manage its branch settings.
                            </InlineNotice>
                        </Card>
                    )}

                    <Card>
                        <BranchHoursManager
                            hours={hours}
                            canManage={canManageBranch}
                            loadError={Boolean(hoursResult.error)}
                        />
                    </Card>

                    <Card>
                        <BranchHolidayManager
                            holidays={holidays}
                            canManage={canManageBranch}
                            loadError={Boolean(holidaysResult.error)}
                        />
                    </Card>
                </TabsContent>
            </Tabs>
        </>
    );
}

function Detail({ label, value, mono = false }: { label: string; value: string | null | undefined; mono?: boolean }) {
    return (
        <div>
            <dt className="text-[11.5px] font-semibold tracking-wide text-ink-muted uppercase">{label}</dt>
            <dd className={`mt-0.5 text-[13px] text-ink ${mono ? 'font-mono' : ''}`}>{value ?? '—'}</dd>
        </div>
    );
}
