-- ═══════════════════════════════════════════════════════════════════════════
-- 0028a · NEW NOTIFICATION EVENTS
--
-- Kept in its own migration on purpose: PostgreSQL refuses to *use* a new enum
-- value in the same transaction that adds it, and the next migration inserts
-- templates for these events. Splitting the ALTER TYPE out keeps both safe.
--
-- Rider onboarding previously borrowed SYSTEM_ALERT, whose seeded copy is about
-- a late order ("{{order_number}} is about {{minutes_late}} min behind"). Sending
-- an approval through it would have rendered a sentence with holes in it.
-- ═══════════════════════════════════════════════════════════════════════════

alter type public.notification_event add value if not exists 'RIDER_DOCUMENT_REVIEWED';
alter type public.notification_event add value if not exists 'RIDER_APPROVED';
alter type public.notification_event add value if not exists 'RIDER_SUSPENDED';
