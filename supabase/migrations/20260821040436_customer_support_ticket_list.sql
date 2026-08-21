-- Customer support list surface. `message_count` is derived from the
-- conversation table; it is not a physical column on support_tickets.
create or replace function public.my_support_tickets(p_limit int default 50)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', t.id,
      'ticket_number', t.ticket_number,
      'category', t.category,
      'subject', t.subject,
      'status', t.status,
      'priority', t.priority,
      'order_id', t.order_id,
      'created_at', t.created_at,
      'resolved_at', t.resolved_at,
      'message_count', (
        select count(*) from public.support_messages m where m.ticket_id = t.id
      ),
      'last_message_at', t.last_message_at
    ) order by t.created_at desc
  ), '[]'::jsonb)
  from (
    select *
    from public.support_tickets
    where user_id = auth.uid()
    order by created_at desc
    limit least(coalesce(p_limit, 50), 50)
  ) t;
$$;

grant execute on function public.my_support_tickets(int) to authenticated;
