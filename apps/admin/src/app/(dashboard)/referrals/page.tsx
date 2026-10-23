import type { Metadata } from 'next';
import { PageHeader } from '@/components/layout/page-header';
import { Card } from '@/components/ui/card';
import { ErrorState } from '@/components/ui/states';
import { ReferralManager } from '@/features/referrals/referral-manager';
import { requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PERMISSIONS } from '@bitesbox/shared-types';

export const metadata: Metadata = { title: 'Referrals' };
export const dynamic = 'force-dynamic';

interface ReferralOverview {
    settings: {
        enabled: boolean;
        referrer_reward: number | null;
        referred_reward: number | null;
        minimum_order_amount: number | null;
        max_rewards_per_referrer: number;
        reward_expiry_days: number | null;
    } | null;
    feature_flag_enabled: boolean;
    metrics: { attributed: number; qualified: number; rewarded: number; reversed: number };
    activity: Array<{
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
    }>;
}

export default async function ReferralsPage() {
    await requirePermission(PERMISSIONS.REFERRAL_MANAGE);
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase.rpc('referral_admin_overview');

    return (
        <>
            <PageHeader title="Referrals" description="Review attribution and wallet reward activity, then configure owner-approved terms." />
            {error || !data ? (
                <Card><ErrorState title="Could not load referral activity" message={error?.message ?? 'The referral service returned no data.'} /></Card>
            ) : (
                <ReferralManager initial={data as unknown as ReferralOverview} />
            )}
        </>
    );
}
