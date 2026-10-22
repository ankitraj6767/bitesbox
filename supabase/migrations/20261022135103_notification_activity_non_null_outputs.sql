-- Keep the admin activity RPC's display fields non-null so the generated API
-- contract matches the values returned to the dashboard.
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
      coalesce(n.title, '—'),
      n.created_at,
      coalesce(n.sent_at, n.created_at),
      coalesce(n.failure_reason, '')
    from public.notifications as n
    order by n.created_at desc
    limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$$;

revoke all on function public.admin_recent_notifications(integer) from public, anon;
grant execute on function public.admin_recent_notifications(integer) to authenticated;
