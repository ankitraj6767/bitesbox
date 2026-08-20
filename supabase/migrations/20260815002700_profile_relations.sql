-- ═══════════════════════════════════════════════════════════════════════════
-- 0027 · PROFILE RELATIONSHIPS
--
-- Every user-referencing column already points at `auth.users`, which is correct
-- for identity but invisible to the Data API: PostgREST cannot embed a table it
-- does not expose. That forces the admin dashboard to issue a second query for
-- something as ordinary as "who raised this refund".
--
-- `public.profiles.id` is a 1:1 mirror of `auth.users.id`, so we add a parallel
-- foreign key to profiles on each of these columns. Effects:
--   · PostgREST can embed profiles directly (`requester:profiles!<fk>(...)`)
--   · referential integrity is unchanged — profiles.id is itself FK'd to
--     auth.users with ON DELETE CASCADE, so deleting a user still cascades
--   · constraint names are explicit so embeds stay unambiguous where a table
--     references profiles more than once (refunds has four such columns)
-- ═══════════════════════════════════════════════════════════════════════════

-- Helper: add a FK to public.profiles only when it is missing, so the migration
-- is safe to re-run and tolerant of partially migrated environments.
create or replace function app.add_profile_fk(
  p_table regclass,
  p_column text,
  p_constraint text,
  p_on_delete text default 'set null'
)
returns void
language plpgsql
as $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = p_constraint and conrelid = p_table
  ) then
    return;
  end if;

  execute format(
    'alter table %s add constraint %I foreign key (%I) references public.profiles (id) on delete %s',
    p_table, p_constraint, p_column, p_on_delete
  );
end;
$$;

-- ─── Customer-owned records ────────────────────────────────────────────────
select app.add_profile_fk('public.orders', 'user_id', 'orders_user_profile_fkey', 'restrict');
select app.add_profile_fk('public.addresses', 'user_id', 'addresses_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.carts', 'user_id', 'carts_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.payments', 'user_id', 'payments_user_profile_fkey', 'restrict');
select app.add_profile_fk('public.reviews', 'user_id', 'reviews_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.coupon_redemptions', 'user_id', 'coupon_redemptions_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.wallet_accounts', 'user_id', 'wallet_accounts_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.wallet_transactions', 'user_id', 'wallet_transactions_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.loyalty_accounts', 'user_id', 'loyalty_accounts_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.loyalty_transactions', 'user_id', 'loyalty_transactions_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.device_tokens', 'user_id', 'device_tokens_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.search_queries', 'user_id', 'search_queries_user_profile_fkey', 'cascade');

-- ─── Support ───────────────────────────────────────────────────────────────
select app.add_profile_fk('public.support_tickets', 'user_id', 'support_tickets_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.support_tickets', 'assigned_to', 'support_tickets_assignee_profile_fkey');
select app.add_profile_fk('public.support_tickets', 'resolved_by', 'support_tickets_resolver_profile_fkey');
select app.add_profile_fk('public.support_messages', 'author_id', 'support_messages_author_profile_fkey');

-- ─── Refunds (four references — hence explicit constraint names) ────────────
select app.add_profile_fk('public.refunds', 'user_id', 'refunds_user_profile_fkey', 'restrict');
select app.add_profile_fk('public.refunds', 'requested_by', 'refunds_requester_profile_fkey');
select app.add_profile_fk('public.refunds', 'approved_by', 'refunds_approver_profile_fkey');
select app.add_profile_fk('public.refunds', 'rejected_by', 'refunds_rejecter_profile_fkey');

-- ─── Operations ────────────────────────────────────────────────────────────
select app.add_profile_fk('public.order_notes', 'author_id', 'order_notes_author_profile_fkey');
select app.add_profile_fk('public.order_status_history', 'actor_id', 'order_status_history_actor_profile_fkey');
select app.add_profile_fk('public.delivery_partners', 'user_id', 'delivery_partners_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.delivery_assignments', 'assigned_by', 'delivery_assignments_assigner_profile_fkey');
select app.add_profile_fk('public.staff_members', 'user_id', 'staff_members_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.user_roles', 'user_id', 'user_roles_user_profile_fkey', 'cascade');
select app.add_profile_fk('public.audit_logs', 'actor_id', 'audit_logs_actor_profile_fkey');
select app.add_profile_fk('public.cod_collections', 'settled_by', 'cod_collections_settler_profile_fkey');
select app.add_profile_fk('public.notifications', 'user_id', 'notifications_user_profile_fkey', 'cascade');

-- Indexes for the new join paths that the admin actually filters on.
create index if not exists refunds_requested_by_idx on public.refunds (requested_by);
create index if not exists support_tickets_user_idx2 on public.support_tickets (user_id);
create index if not exists support_messages_author_idx on public.support_messages (author_id);
create index if not exists order_notes_author_idx on public.order_notes (author_id);

drop function app.add_profile_fk(regclass, text, text, text);
