'use client';

import * as React from 'react';
import { toast } from 'sonner';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { Input } from '@/components/ui/form-controls';
import { money } from '@/lib/utils';

interface ReferralSettings {
    enabled: boolean;
    referrer_reward: number | null;
    referred_reward: number | null;
    minimum_order_amount: number | null;
    max_rewards_per_referrer: number | null;
    reward_expiry_days: number | null;
}

interface ReferralActivity {
    id: string;
    status: string;
    referral_code: string;
    qualifying_order_id: string | null;
    branch_id: string | null;
    referrer_reward: number;
    referred_reward: number;
    reversal_shortfall: number;
    attributed_at: string;
    qualified_at: string | null;
    rewarded_at: string | null;
    reversed_at: string | null;
}

interface ReferralOverview {
    settings: ReferralSettings | null;
    feature_flag_enabled: boolean;
    metrics: { attributed: number; qualified: number; rewarded: number; reversed: number };
    activity: ReferralActivity[];
}

export function ReferralManager({ initial }: { initial: ReferralOverview }) {
    const [data, setData] = React.useState(initial);
    const [enabled, setEnabled] = React.useState(initial.settings?.enabled ?? false);
    const [referrerReward, setReferrerReward] = React.useState(initial.settings?.referrer_reward?.toString() ?? '');
    const [referredReward, setReferredReward] = React.useState(initial.settings?.referred_reward?.toString() ?? '');
    const [minimumOrder, setMinimumOrder] = React.useState(initial.settings?.minimum_order_amount?.toString() ?? '');
    const [cap, setCap] = React.useState(initial.settings?.max_rewards_per_referrer?.toString() ?? '');
    const [expiry, setExpiry] = React.useState(initial.settings?.reward_expiry_days?.toString() ?? '');
    const [busy, setBusy] = React.useState(false);

    async function save(event: React.FormEvent<HTMLFormElement>) {
        event.preventDefault();
        setBusy(true);
        try {
            const supabase = createSupabaseBrowserClient();
            const { error } = await supabase.rpc('update_referral_program', {
                p_enabled: enabled,
                p_referrer_reward: Number(referrerReward),
                p_referred_reward: Number(referredReward),
                p_minimum_order_amount: Number(minimumOrder),
                p_max_rewards_per_referrer: cap.trim() ? Number(cap) : (null as unknown as number),
                ...(expiry.trim() ? { p_reward_expiry_days: Number(expiry) } : {}),
            });
            if (error) throw error;
            const { data: refreshed, error: refreshError } = await supabase.rpc('referral_admin_overview');
            if (refreshError) throw refreshError;
            setData(refreshed as unknown as ReferralOverview);
            toast.success('Referral terms saved. The rollout flag remains independent.');
        } catch (error) {
            toast.error(error instanceof Error ? error.message : 'Could not save referral terms.');
        } finally {
            setBusy(false);
        }
    }

    return (
        <div className="space-y-5">
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                {([
                    ['Attributed', data.metrics.attributed],
                    ['Qualified', data.metrics.qualified],
                    ['Rewarded', data.metrics.rewarded],
                    ['Reversed', data.metrics.reversed],
                ] as const).map(([label, value]) => (
                    <Card key={label}><CardContent className="p-4">
                        <p className="text-xs text-ink-muted">{label}</p>
                        <p className="mt-1 text-2xl font-semibold tnum">{value}</p>
                    </CardContent></Card>
                ))}
            </div>

            <Card>
                <CardToolbar title="Program terms" description="No commercial values are prefilled. The database validates and applies saved terms." />
                <CardContent>
                    <form onSubmit={save} className="grid gap-4 md:grid-cols-2">
                        <label className="flex items-center gap-3 text-sm font-medium md:col-span-2">
                            <input type="checkbox" checked={enabled} onChange={(event) => setEnabled(event.target.checked)} />
                            Program configured and approved by the owner
                        </label>
                        <label className="space-y-1 text-sm">Referrer wallet reward (₹)
                            <Input required min="0.01" step="0.01" type="number" value={referrerReward} onChange={(event) => setReferrerReward(event.target.value)} />
                        </label>
                        <label className="space-y-1 text-sm">Referred customer wallet reward (₹)
                            <Input required min="0.01" step="0.01" type="number" value={referredReward} onChange={(event) => setReferredReward(event.target.value)} />
                        </label>
                        <label className="space-y-1 text-sm">Minimum qualifying order (₹)
                            <Input required min="0.01" step="0.01" type="number" value={minimumOrder} onChange={(event) => setMinimumOrder(event.target.value)} />
                        </label>
                        <label className="space-y-1 text-sm">Maximum rewarded referrals per customer (optional)
                            <Input min="1" max="1000" step="1" type="number" value={cap} onChange={(event) => setCap(event.target.value)} />
                        </label>
                        <label className="space-y-1 text-sm">Reward expiry in days (optional)
                            <Input min="1" max="3650" step="1" type="number" value={expiry} onChange={(event) => setExpiry(event.target.value)} />
                        </label>
                        <div className="flex items-end gap-3 md:col-span-2">
                            <Button type="submit" disabled={busy}>{busy ? 'Saving…' : 'Save terms'}</Button>
                            <Badge tone={data.feature_flag_enabled ? 'positive' : 'caution'}>
                                Rollout flag {data.feature_flag_enabled ? 'on' : 'off'}
                            </Badge>
                            {!data.feature_flag_enabled ? <span className="text-xs text-ink-muted">Customer attribution stays disabled until an authorized owner separately enables the referrals feature flag.</span> : null}
                        </div>
                    </form>
                </CardContent>
            </Card>

            <Card>
                <CardToolbar title="Recent referral activity" description="Codes and order references only; customer contact data is not exposed here." />
                <CardContent className="overflow-x-auto p-0">
                    <table className="w-full text-left text-sm">
                        <thead className="border-b border-hairline text-xs text-ink-muted"><tr>
                            <th className="px-4 py-3">Code</th><th className="px-4 py-3">Status</th>
                            <th className="px-4 py-3">Branch</th><th className="px-4 py-3">Rewards</th>
                            <th className="px-4 py-3">Order</th><th className="px-4 py-3">Date</th>
                        </tr></thead>
                        <tbody>
                            {data.activity.map((row) => <tr key={row.id} className="border-b border-hairline last:border-0">
                                <td className="px-4 py-3 font-mono text-xs">{row.referral_code}</td>
                                <td className="px-4 py-3"><Badge tone={row.status === 'REWARDED' ? 'positive' : row.status === 'REVERSED' ? 'critical' : 'neutral'}>{row.status}</Badge></td>
                                <td className="px-4 py-3 font-mono text-xs">{row.branch_id?.slice(0, 8) ?? '—'}</td>
                                <td className="px-4 py-3">{money(row.referrer_reward)} + {money(row.referred_reward)}{row.reversal_shortfall > 0 ? ` · ${money(row.reversal_shortfall)} unrecovered` : ''}</td>
                                <td className="px-4 py-3 font-mono text-xs">{row.qualifying_order_id?.slice(0, 8) ?? '—'}</td>
                                <td className="px-4 py-3 text-xs">{new Date(row.attributed_at).toLocaleDateString()}</td>
                            </tr>)}
                            {data.activity.length === 0 ? <tr><td colSpan={6} className="px-4 py-8 text-center text-ink-muted">No referral activity yet.</td></tr> : null}
                        </tbody>
                    </table>
                </CardContent>
            </Card>
        </div>
    );
}
