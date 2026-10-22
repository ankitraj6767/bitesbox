-- Notification rows are private to their owner when accessed through the
-- authenticated table API. Admin activity is exposed through a permission-
-- checked RPC below so a stale mobile client cannot read other users' rows.
drop policy if exists notifications_owner_read on public.notifications;

create policy notifications_owner_read on public.notifications
  for select to authenticated
  using (user_id = auth.uid());

create or replace function public.admin_recent_notifications(p_limit integer default 50)
returns table (
  id uuid,
  event public.notification_event,
  channel public.notification_channel,
  status public.notification_status,
  title text,
  created_at timestamptz,
  sent_at timestamptz,
  failure_reason text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (
    app.has_permission('notification.send')
    or app.has_permission('campaign.manage')
  ) then
    perform app.fail('PERMISSION_DENIED', 'You cannot view notification activity.');
  end if;

  return query
    select
      n.id,
      n.event,
      n.channel,
      n.status,
      n.title,
      n.created_at,
      n.sent_at,
      n.failure_reason
    from public.notifications as n
    order by n.created_at desc
    limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$$;

revoke all on function public.admin_recent_notifications(integer) from public, anon;
grant execute on function public.admin_recent_notifications(integer) to authenticated;
