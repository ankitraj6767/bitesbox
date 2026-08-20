import type { Metadata } from 'next';
import { activeBranchId, hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { ErrorState, InlineNotice } from '@/components/ui/states';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/overlays';
import { Table, TableWrap, TBody, TD, TH, THead, TR } from '@/components/ui/table';
import { SettingsEditor, type SettingRow } from '@/features/settings/settings-editor';
import { FeatureFlagList, type FeatureFlagRow } from '@/features/settings/feature-flag-list';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { money, humanise } from '@/lib/utils';

export const metadata: Metadata = { title: 'Settings' };
export const dynamic = 'force-dynamic';

export default async function SettingsPage() {
    const session = await requirePermission(PERMISSIONS.SETTINGS_VIEW);
    const supabase = await createSupabaseServerClient();
    const branchId = activeBranchId(session);

    const canEditSettings = hasPermission(session, PERMISSIONS.SETTINGS_UPDATE);
    const canEditFlags = hasPermission(session, PERMISSIONS.FEATURE_FLAG_UPDATE);
    const canManageBranch = hasPermission(session, PERMISSIONS.BRANCH_MANAGE);

    const [settingsResult, flagsResult, zonesResult, hoursResult, branchResult, taxResult] =
        await Promise.all([
            supabase
                .from('settings')
                .select('key, value, value_type, group:group, label, description, is_public')
                .order('key'),
            supabase
                .from('feature_flags')
                .select('key, label, description, is_enabled, rollout_percentage')
                .order('key'),
            supabase
                .from('delivery_zones')
                .select(
                    `id, name, description, kind, min_distance_km, max_distance_km, delivery_fee,
           min_order_amount, free_delivery_threshold, per_km_surcharge, surcharge_after_km,
           peak_surcharge, peak_starts_at, peak_ends_at, base_eta_minutes, extra_eta_minutes,
           cod_enabled, max_cod_amount, is_serviceable, is_active, priority`,
                )
                .is('deleted_at', null)
                .order('priority'),
            supabase
                .from('branch_hours')
                .select('day_of_week, opens_at, closes_at, day_part, is_closed, closes_next_day')
                .order('day_of_week')
                .order('opens_at'),
            supabase
                .from('branches')
                .select(
                    `id, code, name, legal_name, phone, whatsapp_phone, email, address_line1, address_line2,
           city, state, postal_code, gstin, fssai_licence_no, fssai_valid_till, timezone,
           service_mode, default_prep_minutes, rush_buffer_minutes, max_concurrent_orders`,
                )
                .eq('id', branchId ?? '')
                .maybeSingle(),
            supabase
                .from('tax_categories')
                .select('code, name, rate, cgst_rate, sgst_rate, hsn_sac_code, is_inclusive, is_default')
                .is('deleted_at', null)
                .order('code'),
        ]);

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
    const branch = branchResult.data;
    const taxes = taxResult.data ?? [];

    const byGroup = (group: string) => settings.filter((setting) => setting.group === group);

    const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    return (
        <>
            <PageHeader
                title="Settings"
                description="Everything an operator can change without a deploy. Each change is versioned and audited."
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

                    <Card>
                        <CardToolbar
                            title="Delivery zones"
                            description="Fees and minimums per zone. Lowest priority wins when zones overlap."
                        />
                        <CardContent className="p-0">
                            <TableWrap className="rounded-none border-0">
                                <Table>
                                    <THead>
                                        <TR className="hover:bg-transparent">
                                            <TH>Zone</TH>
                                            <TH>Distance</TH>
                                            <TH numeric>Fee</TH>
                                            <TH numeric>Min order</TH>
                                            <TH numeric>Free above</TH>
                                            <TH numeric>ETA</TH>
                                            <TH>Cash on delivery</TH>
                                            <TH>State</TH>
                                        </TR>
                                    </THead>
                                    <TBody>
                                        {zones.map((zone) => (
                                            <TR key={zone.id}>
                                                <TD>
                                                    <span className="block text-[13px] font-medium text-ink">{zone.name}</span>
                                                    <span className="block max-w-56 truncate text-[11.5px] text-ink-muted">
                                                        {zone.description ?? humanise(zone.kind)}
                                                    </span>
                                                </TD>
                                                <TD className="text-[12.5px]">
                                                    {zone.kind === 'RADIUS'
                                                        ? `${zone.min_distance_km}–${zone.max_distance_km} km`
                                                        : 'Geofenced'}
                                                </TD>
                                                <TD numeric className="text-[13px] font-semibold">
                                                    {money(zone.delivery_fee)}
                                                    {Number(zone.peak_surcharge) > 0 ? (
                                                        <span className="block text-[11px] font-normal text-caution">
                                                            +{money(zone.peak_surcharge)} peak
                                                        </span>
                                                    ) : null}
                                                </TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {money(zone.min_order_amount)}
                                                </TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {zone.free_delivery_threshold ? money(zone.free_delivery_threshold) : '—'}
                                                </TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {zone.base_eta_minutes + zone.extra_eta_minutes}m
                                                </TD>
                                                <TD>
                                                    {zone.cod_enabled ? (
                                                        <Badge tone="positive">
                                                            Up to {zone.max_cod_amount ? money(zone.max_cod_amount) : 'limit'}
                                                        </Badge>
                                                    ) : (
                                                        <Badge tone="neutral">Not allowed</Badge>
                                                    )}
                                                </TD>
                                                <TD>
                                                    {zone.is_active && zone.is_serviceable ? (
                                                        <Badge tone="positive" dot>
                                                            Serviceable
                                                        </Badge>
                                                    ) : (
                                                        <Badge tone="critical">Off</Badge>
                                                    )}
                                                </TD>
                                            </TR>
                                        ))}
                                    </TBody>
                                </Table>
                            </TableWrap>
                        </CardContent>
                    </Card>
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
                        <CardToolbar
                            title="Tax categories"
                            description="GST rates applied to menu items. Restaurant supply is inclusive of tax."
                        />
                        <CardContent className="p-0">
                            <TableWrap className="rounded-none border-0">
                                <Table>
                                    <THead>
                                        <TR className="hover:bg-transparent">
                                            <TH>Code</TH>
                                            <TH>Name</TH>
                                            <TH numeric>Rate</TH>
                                            <TH numeric>CGST</TH>
                                            <TH numeric>SGST</TH>
                                            <TH>HSN/SAC</TH>
                                            <TH>Inclusive</TH>
                                        </TR>
                                    </THead>
                                    <TBody>
                                        {taxes.map((tax) => (
                                            <TR key={tax.code}>
                                                <TD className="font-mono text-[12.5px] font-semibold">
                                                    {tax.code}
                                                    {tax.is_default ? (
                                                        <Badge tone="brand" className="ml-1.5 px-1.5 py-0">
                                                            Default
                                                        </Badge>
                                                    ) : null}
                                                </TD>
                                                <TD className="text-[13px]">{tax.name}</TD>
                                                <TD numeric className="text-[13px] font-semibold">
                                                    {(Number(tax.rate) * 100).toFixed(2)}%
                                                </TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {(Number(tax.cgst_rate) * 100).toFixed(2)}%
                                                </TD>
                                                <TD numeric className="text-[12.5px]">
                                                    {(Number(tax.sgst_rate) * 100).toFixed(2)}%
                                                </TD>
                                                <TD className="font-mono text-[12px] text-ink-muted">
                                                    {tax.hsn_sac_code ?? '—'}
                                                </TD>
                                                <TD>
                                                    <Badge tone={tax.is_inclusive ? 'positive' : 'neutral'}>
                                                        {tax.is_inclusive ? 'Inclusive' : 'Added on top'}
                                                    </Badge>
                                                </TD>
                                            </TR>
                                        ))}
                                    </TBody>
                                </Table>
                            </TableWrap>
                        </CardContent>
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
                    {branch ? (
                        <Card>
                            <CardToolbar
                                title={branch.name}
                                description={`${branch.code} · ${branch.timezone}`}
                            />
                            <CardContent>
                                <dl className="grid gap-x-8 gap-y-3 sm:grid-cols-2">
                                    <Detail label="Legal name" value={branch.legal_name} />
                                    <Detail label="Phone" value={branch.phone} />
                                    <Detail label="WhatsApp" value={branch.whatsapp_phone} />
                                    <Detail label="Email" value={branch.email} />
                                    <Detail
                                        label="Address"
                                        value={[branch.address_line1, branch.address_line2, branch.city, branch.state, branch.postal_code]
                                            .filter(Boolean)
                                            .join(', ')}
                                    />
                                    <Detail label="GSTIN" value={branch.gstin} mono />
                                    <Detail label="FSSAI licence" value={branch.fssai_licence_no} mono />
                                    <Detail label="FSSAI valid till" value={branch.fssai_valid_till} />
                                    <Detail label="Service mode" value={humanise(branch.service_mode)} />
                                    <Detail label="Default prep time" value={`${branch.default_prep_minutes} minutes`} />
                                    <Detail label="Rush buffer" value={`${branch.rush_buffer_minutes} minutes`} />
                                    <Detail
                                        label="Max concurrent orders"
                                        value={branch.max_concurrent_orders ? String(branch.max_concurrent_orders) : 'Unlimited'}
                                    />
                                </dl>

                                {!canManageBranch ? (
                                    <InlineNotice tone="info" className="mt-4">
                                        Editing branch details needs the Manage branch permission.
                                    </InlineNotice>
                                ) : null}
                            </CardContent>
                        </Card>
                    ) : null}

                    <Card>
                        <CardToolbar
                            title="Trading hours"
                            description="When the kitchen accepts orders. Holidays in branch_holidays override these."
                        />
                        <CardContent className="p-0">
                            <TableWrap className="rounded-none border-0">
                                <Table>
                                    <THead>
                                        <TR className="hover:bg-transparent">
                                            <TH>Day</TH>
                                            <TH>Service</TH>
                                            <TH>Opens</TH>
                                            <TH>Closes</TH>
                                        </TR>
                                    </THead>
                                    <TBody>
                                        {hours.map((slot, index) => (
                                            <TR key={`${slot.day_of_week}-${slot.day_part}-${index}`}>
                                                <TD className="text-[13px] font-medium">{DAY_NAMES[slot.day_of_week]}</TD>
                                                <TD>
                                                    <Badge tone="neutral">{humanise(slot.day_part)}</Badge>
                                                </TD>
                                                <TD className="tnum text-[12.5px]">{slot.opens_at.slice(0, 5)}</TD>
                                                <TD className="tnum text-[12.5px]">
                                                    {slot.closes_at.slice(0, 5)}
                                                    {slot.closes_next_day ? ' (next day)' : ''}
                                                </TD>
                                            </TR>
                                        ))}
                                    </TBody>
                                </Table>
                            </TableWrap>
                        </CardContent>
                    </Card>
                </TabsContent>
            </Tabs>
        </>
    );
}

function Detail({
    label,
    value,
    mono = false,
}: {
    label: string;
    value: string | null | undefined;
    mono?: boolean;
}) {
    return (
        <div>
            <dt className="text-[11.5px] font-semibold tracking-wide text-ink-muted uppercase">{label}</dt>
            <dd className={`mt-0.5 text-[13px] text-ink ${mono ? 'font-mono' : ''}`}>{value ?? '—'}</dd>
        </div>
    );
}
