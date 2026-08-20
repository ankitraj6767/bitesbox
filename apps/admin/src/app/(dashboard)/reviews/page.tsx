import type { Metadata } from 'next';
import Link from 'next/link';
import { MessageSquareQuote, Star } from 'lucide-react';
import { hasPermission, requirePermission } from '@/lib/session';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageHeader } from '@/components/layout/page-header';
import { Card, CardContent, CardToolbar } from '@/components/ui/card';
import { StatCard } from '@/components/ui/stat-card';
import { Badge } from '@/components/ui/badge';
import { EmptyState, ErrorState } from '@/components/ui/states';
import { ReviewModeration } from '@/features/reviews/review-moderation';
import { PERMISSIONS } from '@bitesbox/shared-types';
import { dateTime, humanise } from '@/lib/utils';

export const metadata: Metadata = { title: 'Reviews' };
export const dynamic = 'force-dynamic';

export default async function ReviewsPage() {
    const session = await requirePermission(PERMISSIONS.REVIEW_VIEW);
    const supabase = await createSupabaseServerClient();
    const canModerate = hasPermission(session, PERMISSIONS.REVIEW_MODERATE);

    const { data: reviews, error } = await supabase
        .from('reviews')
        .select(
            `id, order_id, food_rating, delivery_rating, overall_rating, comment, tags, status,
       response_body, responded_at, created_at, flagged_reason,
       profiles!reviews_user_profile_fkey(id, full_name),
       orders(order_number),
       delivery_partners(full_name)`,
        )
        .order('created_at', { ascending: false })
        .limit(120);

    if (error) {
        return (
            <>
                <PageHeader title="Reviews" />
                <Card>
                    <ErrorState title="Could not load reviews" message={error.message} />
                </Card>
            </>
        );
    }

    const list = reviews ?? [];
    const average =
        list.length > 0
            ? list.reduce((sum, review) => sum + review.overall_rating, 0) / list.length
            : 0;
    const lowRated = list.filter((review) => review.overall_rating <= 2);
    const withComments = list.filter((review) => review.comment);
    const flagged = list.filter((review) => review.status === 'FLAGGED' || review.status === 'HIDDEN');

    return (
        <>
            <PageHeader
                title="Reviews"
                description="What customers said about the food and the delivery."
            />

            <section aria-label="Review summary" className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatCard
                    label="Average rating"
                    value={average > 0 ? average.toFixed(2) : '—'}
                    icon={Star}
                    tone={average >= 4 ? 'positive' : average >= 3 ? 'caution' : 'critical'}
                    hint={`${list.length} reviews`}
                />
                <StatCard
                    label="Needs attention"
                    value={lowRated.length}
                    tone={lowRated.length > 0 ? 'critical' : 'positive'}
                    hint="1–2 star ratings"
                />
                <StatCard label="With comments" value={withComments.length} icon={MessageSquareQuote} />
                <StatCard label="Flagged or hidden" value={flagged.length} tone={flagged.length > 0 ? 'caution' : 'neutral'} />
            </section>

            <Card className="mt-5">
                <CardToolbar title="Latest reviews" description="Most recent 120" />
                <CardContent className="p-0">
                    {list.length === 0 ? (
                        <EmptyState
                            icon={Star}
                            title="No reviews yet"
                            description="Customers are asked to rate their order 45 minutes after delivery."
                        />
                    ) : (
                        <ul className="divide-y divide-hairline">
                            {list.map((review) => (
                                <li key={review.id} className="px-5 py-4">
                                    <div className="flex flex-wrap items-start justify-between gap-3">
                                        <div className="min-w-0">
                                            <div className="flex flex-wrap items-center gap-2">
                                                <span className="flex items-center gap-0.5" aria-label={`${review.overall_rating} out of 5`}>
                                                    {Array.from({ length: 5 }).map((_, index) => (
                                                        <Star
                                                            key={index}
                                                            className={
                                                                index < review.overall_rating
                                                                    ? 'size-3.5 fill-turmeric-500 text-turmeric-500'
                                                                    : 'size-3.5 text-hairline'
                                                            }
                                                            aria-hidden
                                                        />
                                                    ))}
                                                </span>

                                                <span className="text-[13px] font-medium text-ink">
                                                    {review.profiles?.full_name ?? 'Customer'}
                                                </span>

                                                {review.orders ? (
                                                    <Link
                                                        href={`/orders/${review.order_id}`}
                                                        className="font-mono text-[11.5px] text-ink-muted hover:text-brand-600"
                                                    >
                                                        {review.orders.order_number}
                                                    </Link>
                                                ) : null}

                                                {review.status !== 'PUBLISHED' ? (
                                                    <Badge tone={review.status === 'HIDDEN' ? 'neutral' : 'caution'}>
                                                        {humanise(review.status)}
                                                    </Badge>
                                                ) : null}
                                            </div>

                                            <p className="mt-1 text-[11.5px] text-ink-muted">
                                                Food {review.food_rating}/5
                                                {review.delivery_rating ? ` · Delivery ${review.delivery_rating}/5` : ''}
                                                {review.delivery_partners?.full_name
                                                    ? ` · ${review.delivery_partners.full_name}`
                                                    : ''}
                                                {' · '}
                                                {dateTime(review.created_at)}
                                            </p>

                                            {review.comment ? (
                                                <p className="mt-2 max-w-2xl text-[13.5px] leading-relaxed text-ink">
                                                    “{review.comment}”
                                                </p>
                                            ) : null}

                                            {review.tags && review.tags.length > 0 ? (
                                                <div className="mt-2 flex flex-wrap gap-1">
                                                    {review.tags.map((tag) => (
                                                        <Badge key={tag} tone="neutral" className="px-1.5 py-0">
                                                            {humanise(tag)}
                                                        </Badge>
                                                    ))}
                                                </div>
                                            ) : null}

                                            {review.response_body ? (
                                                <div className="mt-2 rounded-[var(--radius-control)] border-l-2 border-brand-400 bg-surface-muted px-3 py-2">
                                                    <p className="text-[11.5px] font-semibold text-ink-muted">
                                                        Bites Box replied
                                                    </p>
                                                    <p className="mt-0.5 text-[13px] text-ink">{review.response_body}</p>
                                                </div>
                                            ) : null}
                                        </div>

                                        {canModerate ? (
                                            <ReviewModeration
                                                reviewId={review.id}
                                                status={review.status}
                                                hasResponse={Boolean(review.response_body)}
                                            />
                                        ) : null}
                                    </div>
                                </li>
                            ))}
                        </ul>
                    )}
                </CardContent>
            </Card>
        </>
    );
}
