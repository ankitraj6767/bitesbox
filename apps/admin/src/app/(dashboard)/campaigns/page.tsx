import type { Metadata } from 'next';
import { Bell, MailCheck, Send, Users } from 'lucide-react';
import { hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { StatCard } from '@/components/ui/stat-card';
import { Badge } from '@/components/ui/badge';
import { EmptyState, ErrorState } from '@/components/ui/states';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/overlays';
import { Table, TableWrap, TBody, TD, TH, THead, TR, TableMessageRow } from '@/components/ui/table';
import { CampaignLauncher } from '@/features/campaigns/campaign-launcher';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { dateTime, humanise } from '@/lib/utils';

export const metadata: Metadata = { title: 'Campaigns' };
export const dynamic = 'force-dynamic';

export default async function CampaignsPage() {
    const session = await requirePermission([
        PERMISSIONS.CAMPAIGN_MANAGE,
        PERMISSIONS.NOTIFICATION_SEND,
    ]);

    const supabase = await createSupabaseServerClient();
    const canSend = hasPermission(session, [
        PERMISSIONS.CAMPAIGN_MANAGE,
        PERMISSIONS.NOTIFICATION_SEND,
    ]);

    const [campaignsResult, templatesResult, recentResult] = await Promise.all([
        supabase
            .from('notification_campaigns')
            .select(
                `id, name, description, channels, segment, title, body, action_route, status,
         scheduled_for, started_at, completed_at, target_count, queued_count, sent_count,
         failed_count, read_count, created_at`,
            )
            .order('created_at', { ascending: false }),
        supabase
            .from('notification_templates')
            .select('id, event, channel, locale, title, body, is_active')
            .order('event')
            .order('channel'),
        supabase
            .from('notifications')
            .select('id, event, channel, status, title, created_at, sent_at, failure_reason')
            .order('created_at', { ascending: false })
            .limit(50),
    ]);

    if (campaignsResult.error) {
        return (
            <>
                <PageHeader title="Campaigns" />
                <Card>
                    <ErrorState title="Could not load campaigns" message={campaignsResult.error.message} />
                </Card>
            </>
        );
    }

    const campaigns = campaignsResult.data ?? [];
    const templates = templatesResult.data ?? [];
    const recent = recentResult.data ?? [];

    const sentTotal = campaigns.reduce((sum, campaign) => sum + campaign.sent_count, 0);
    const failedRecently = recent.filter((row) => row.status === 'FAILED').length;

    return (
        <>
            <PageHeader
                title="Campaigns"
                description="Push and SMS to customer segments. Marketing opt-outs are always respected."
            />

            <section aria-label="Campaign summary" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard label="Campaigns" value={campaigns.length} icon={Bell} />
                <StatCard
                    label="Scheduled"
                    value={campaigns.filter((c) => c.status === 'SCHEDULED').length}
                    icon={Send}
                    tone="brand"
                />
                <StatCard label="Notifications sent" value={sentTotal.toLocaleString('en-IN')} icon={MailCheck} tone="positive" />
                <StatCard
                    label="Recent failures"
                    value={failedRecently}
                    tone={failedRecently > 0 ? 'critical' : 'neutral'}
                    hint="Last 50 notifications"
                />
            </section>

            <Tabs defaultValue="campaigns" className="mt-5">
                <TabsList>
                    <TabsTrigger value="campaigns">Campaigns</TabsTrigger>
                    <TabsTrigger value="templates">Templates ({templates.length})</TabsTrigger>
                    <TabsTrigger value="activity">Recent activity</TabsTrigger>
                </TabsList>

                <TabsContent value="campaigns" className="space-y-3">
                    {campaigns.length === 0 ? (
                        <Card>
                            <EmptyState
                                icon={Bell}
                                title="No campaigns yet"
                                description="Create a campaign to reach a customer segment with an offer."
                            />
                        </Card>
                    ) : (
                        campaigns.map((campaign) => (
                            <Card key={campaign.id}>
                                <CardToolbar
                                    title={
                                        <span className="flex flex-wrap items-center gap-2">
                                            {campaign.name}
                                            <Badge
                                                tone={
                                                    campaign.status === 'COMPLETED'
                                                        ? 'positive'
                                                        : campaign.status === 'SCHEDULED'
                                                            ? 'info'
                                                            : campaign.status === 'RUNNING'
                                                                ? 'caution'
                                                                : 'neutral'
                                                }
                                            >
                                                {humanise(campaign.status)}
                                            </Badge>
                                        </span>
                                    }
                                    description={campaign.description ?? undefined}
                                    action={
                                        <CampaignLauncher
                                            campaignId={campaign.id}
                                            campaignName={campaign.name}
                                            status={campaign.status}
                                            segment={campaign.segment}
                                            canSend={canSend}
                                        />
                                    }
                                />
                                <CardContent className="space-y-3">
                                    <div className="rounded-[var(--radius-control)] border border-hairline bg-surface-muted/50 p-3">
                                        <p className="text-[13.5px] font-semibold text-ink">{campaign.title}</p>
                                        <p className="mt-0.5 text-[13px] leading-relaxed text-ink-muted">{campaign.body}</p>
                                        {campaign.action_route ? (
                                            <p className="mt-1.5 font-mono text-[11px] text-ink-muted/80">
                                                {campaign.action_route}
                                            </p>
                                        ) : null}
                                    </div>

                                    <dl className="grid grid-cols-2 gap-x-6 gap-y-1.5 text-[12.5px] sm:grid-cols-4">
                                        <div className="flex items-center gap-1.5">
                                            <Users className="size-3.5 text-ink-muted" aria-hidden />
                                            <dt className="text-ink-muted">Segment</dt>
                                            <dd className="font-medium text-ink">{humanise(campaign.segment)}</dd>
                                        </div>
                                        <div className="flex items-center gap-1.5">
                                            <dt className="text-ink-muted">Channels</dt>
                                            <dd className="font-medium text-ink">
                                                {campaign.channels.map((channel) => humanise(channel)).join(', ')}
                                            </dd>
                                        </div>
                                        <div className="flex items-center gap-1.5">
                                            <dt className="text-ink-muted">Queued</dt>
                                            <dd className="tnum font-medium text-ink">{campaign.queued_count}</dd>
                                        </div>
                                        <div className="flex items-center gap-1.5">
                                            <dt className="text-ink-muted">Sent</dt>
                                            <dd className="tnum font-medium text-ink">{campaign.sent_count}</dd>
                                        </div>
                                    </dl>

                                    {campaign.scheduled_for ? (
                                        <p className="text-[12px] text-ink-muted">
                                            Scheduled for {dateTime(campaign.scheduled_for)}
                                        </p>
                                    ) : null}
                                </CardContent>
                            </Card>
                        ))
                    )}
                </TabsContent>

                <TabsContent value="templates">
                    <Card>
                        <CardToolbar
                            title="Notification templates"
                            description="Editable copy for every transactional event. {{variables}} are filled server-side."
                        />
                        <CardContent className="p-0">
                            <TableWrap className="rounded-none border-0">
                                <Table>
                                    <THead>
                                        <TR className="hover:bg-transparent">
                                            <TH>Event</TH>
                                            <TH>Channel</TH>
                                            <TH>Locale</TH>
                                            <TH>Copy</TH>
                                            <TH>State</TH>
                                        </TR>
                                    </THead>
                                    <TBody>
                                        {templates.map((template) => (
                                            <TR key={template.id}>
                                                <TD className="text-[12.5px] font-medium whitespace-nowrap">
                                                    {humanise(template.event)}
                                                </TD>
                                                <TD>
                                                    <Badge tone="neutral">{humanise(template.channel)}</Badge>
                                                </TD>
                                                <TD className="text-[12px] uppercase">{template.locale}</TD>
                                                <TD className="max-w-lg">
                                                    {template.title ? (
                                                        <span className="block text-[12.5px] font-medium text-ink">
                                                            {template.title}
                                                        </span>
                                                    ) : null}
                                                    <span className="block text-[12px] text-ink-muted">{template.body}</span>
                                                </TD>
                                                <TD>
                                                    <Badge tone={template.is_active ? 'positive' : 'neutral'}>
                                                        {template.is_active ? 'Active' : 'Off'}
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

                <TabsContent value="activity">
                    <Card>
                        <CardToolbar title="Recent notifications" description="Last 50 across all channels" />
                        <CardContent className="p-0">
                            <TableWrap className="rounded-none border-0">
                                <Table>
                                    <THead>
                                        <TR className="hover:bg-transparent">
                                            <TH>Event</TH>
                                            <TH>Channel</TH>
                                            <TH>Message</TH>
                                            <TH>Status</TH>
                                            <TH>When</TH>
                                        </TR>
                                    </THead>
                                    <TBody>
                                        {recent.length === 0 ? (
                                            <TableMessageRow colSpan={5}>
                                                <EmptyState title="No notifications yet" />
                                            </TableMessageRow>
                                        ) : (
                                            recent.map((row) => (
                                                <TR key={row.id}>
                                                    <TD className="text-[12.5px] whitespace-nowrap">{humanise(row.event)}</TD>
                                                    <TD>
                                                        <Badge tone="neutral">{humanise(row.channel)}</Badge>
                                                    </TD>
                                                    <TD className="max-w-sm truncate text-[12.5px] text-ink-muted">
                                                        {row.title ?? '—'}
                                                    </TD>
                                                    <TD>
                                                        <Badge
                                                            tone={
                                                                row.status === 'FAILED'
                                                                    ? 'critical'
                                                                    : ['SENT', 'DELIVERED', 'READ'].includes(row.status)
                                                                        ? 'positive'
                                                                        : 'caution'
                                                            }
                                                        >
                                                            {humanise(row.status)}
                                                        </Badge>
                                                        {row.failure_reason ? (
                                                            <span className="mt-0.5 block max-w-40 truncate text-[11px] text-critical">
                                                                {row.failure_reason}
                                                            </span>
                                                        ) : null}
                                                    </TD>
                                                    <TD className="text-[12px] whitespace-nowrap text-ink-muted">
                                                        {dateTime(row.sent_at ?? row.created_at)}
                                                    </TD>
                                                </TR>
                                            ))
                                        )}
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
