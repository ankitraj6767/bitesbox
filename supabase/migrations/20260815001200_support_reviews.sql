-- ═══════════════════════════════════════════════════════════════════════════
-- 0012 · SUPPORT & REVIEWS
-- ═══════════════════════════════════════════════════════════════════════════

create sequence public.ticket_number_seq;

create table public.support_tickets (
  id                  uuid primary key default gen_random_uuid(),
  ticket_number       text not null,
  user_id             uuid not null references auth.users (id) on delete cascade,
  order_id            uuid references public.orders (id) on delete set null,
  branch_id           uuid references public.branches (id) on delete set null,

  category            public.ticket_category not null,
  subject             text not null,
  description         text not null,
  status              public.ticket_status not null default 'OPEN',
  priority            public.ticket_priority not null default 'NORMAL',

  assigned_to         uuid references auth.users (id) on delete set null,
  assigned_at         timestamptz,
  -- SLA target, computed from priority at creation.
  first_response_due_at timestamptz,
  first_response_at   timestamptz,
  resolution_due_at   timestamptz,
  resolved_at         timestamptz,
  resolved_by         uuid references auth.users (id) on delete set null,
  resolution_note     text,
  closed_at           timestamptz,

  -- Outcome
  refund_id           uuid references public.refunds (id) on delete set null,
  wallet_credit_amount app.money not null default 0,
  -- Customer satisfaction after closure
  satisfaction_rating smallint,
  satisfaction_note   text,

  -- Escalation
  escalated_at        timestamptz,
  escalated_to        uuid references auth.users (id) on delete set null,
  escalation_reason   text,

  reopen_count        smallint not null default 0,
  last_message_at     timestamptz not null default now(),
  metadata            jsonb not null default '{}'::jsonb,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint support_tickets_satisfaction check (
    satisfaction_rating is null or satisfaction_rating between 1 and 5
  ),
  constraint support_tickets_resolved_shape check (
    status not in ('RESOLVED', 'CLOSED') or resolved_at is not null
  )
);

create unique index support_tickets_number_key on public.support_tickets (ticket_number);
create index support_tickets_user_idx on public.support_tickets (user_id, created_at desc);
create index support_tickets_order_idx on public.support_tickets (order_id);
create index support_tickets_open_idx on public.support_tickets (priority, created_at)
  where status in ('OPEN', 'IN_PROGRESS', 'ESCALATED');
create index support_tickets_assignee_idx on public.support_tickets (assigned_to)
  where status not in ('RESOLVED', 'CLOSED');

select app.attach_updated_at('public.support_tickets');

alter table public.notifications
  add constraint notifications_ticket_fk
  foreign key (support_ticket_id) references public.support_tickets (id) on delete set null;

alter table public.refunds
  add constraint refunds_ticket_fk
  foreign key (support_ticket_id) references public.support_tickets (id) on delete set null;

-- ─── Messages ──────────────────────────────────────────────────────────────
create table public.support_messages (
  id            uuid primary key default gen_random_uuid(),
  ticket_id     uuid not null references public.support_tickets (id) on delete cascade,
  author_kind   public.message_author not null,
  author_id     uuid references auth.users (id) on delete set null,
  body          text not null,
  -- Internal notes are invisible to the customer.
  is_internal   boolean not null default false,
  attachments   jsonb not null default '[]'::jsonb,
  read_by_customer_at timestamptz,
  read_by_agent_at    timestamptz,
  created_at    timestamptz not null default now()
);

create index support_messages_ticket_idx on public.support_messages (ticket_id, created_at);

-- Keeps the ticket summary in step with its conversation.
create or replace function app.tg_support_message_rollup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.support_tickets t
  set last_message_at = new.created_at,
      first_response_at = case
        when new.author_kind = 'AGENT' and not new.is_internal and t.first_response_at is null
        then new.created_at
        else t.first_response_at
      end,
      status = case
        when new.author_kind = 'CUSTOMER' and t.status = 'WAITING_ON_CUSTOMER' then 'IN_PROGRESS'::public.ticket_status
        when new.author_kind = 'AGENT' and not new.is_internal and t.status = 'OPEN' then 'IN_PROGRESS'::public.ticket_status
        else t.status
      end,
      updated_at = now()
  where t.id = new.ticket_id;

  return new;
end;
$$;

create trigger support_message_rollup
  after insert on public.support_messages
  for each row execute function app.tg_support_message_rollup();

-- ─── Ticket creation (customer entry point) ────────────────────────────────
create or replace function public.create_support_ticket(
  p_category public.ticket_category,
  p_subject text,
  p_description text,
  p_order_id uuid default null,
  p_attachments jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_ticket public.support_tickets;
  v_priority public.ticket_priority := 'NORMAL';
  v_branch uuid;
  v_sla_minutes int;
begin
  if v_uid is null then
    perform app.fail('UNAUTHENTICATED', 'Sign in to contact support.');
  end if;

  if not app.consume_rate_limit('support_ticket', v_uid::text, 5, 3600) then
    perform app.fail('RATE_LIMITED', 'You have opened several tickets recently. Please wait a little while.');
  end if;

  -- An order-linked complaint must reference the customer's own order.
  if p_order_id is not null then
    select branch_id into v_branch
    from public.orders
    where id = p_order_id and user_id = v_uid;

    if v_branch is null then
      perform app.fail('ORDER_NOT_FOUND', 'We could not find that order on your account.');
    end if;
  end if;

  -- Money and food-safety issues jump the queue.
  v_priority := case p_category
    when 'PAYMENT_PROBLEM' then 'HIGH'
    when 'REFUND' then 'HIGH'
    when 'FOOD_QUALITY' then 'HIGH'
    when 'MISSING_ITEM' then 'HIGH'
    when 'ORDER_DELAYED' then 'URGENT'
    when 'DELIVERY_ISSUE' then 'URGENT'
    else 'NORMAL'
  end;

  v_sla_minutes := case v_priority
    when 'URGENT' then 15
    when 'HIGH' then 60
    else 240
  end;

  insert into public.support_tickets (
    ticket_number, user_id, order_id, branch_id, category, subject, description,
    priority, first_response_due_at, resolution_due_at
  )
  values (
    'BB-T' || lpad(nextval('public.ticket_number_seq')::text, 6, '0'),
    v_uid,
    p_order_id,
    coalesce(v_branch, app.default_branch_id()),
    p_category,
    p_subject,
    p_description,
    v_priority,
    now() + make_interval(mins => v_sla_minutes),
    now() + make_interval(mins => v_sla_minutes * 4)
  )
  returning * into v_ticket;

  insert into public.support_messages (ticket_id, author_kind, author_id, body, attachments)
  values (v_ticket.id, 'CUSTOMER', v_uid, p_description, coalesce(p_attachments, '[]'::jsonb));

  return jsonb_build_object(
    'ticket_id', v_ticket.id,
    'ticket_number', v_ticket.ticket_number,
    'status', v_ticket.status,
    'priority', v_ticket.priority,
    'first_response_due_at', v_ticket.first_response_due_at
  );
end;
$$;

create or replace function public.post_support_message(
  p_ticket_id uuid,
  p_body text,
  p_is_internal boolean default false,
  p_attachments jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_ticket public.support_tickets;
  v_kind public.message_author;
  v_id uuid;
begin
  select * into v_ticket from public.support_tickets where id = p_ticket_id;

  if not found then
    perform app.fail('TICKET_NOT_FOUND', 'That conversation no longer exists.');
  end if;

  if v_ticket.user_id = v_uid then
    v_kind := 'CUSTOMER';
    -- Customers can never write internal notes.
    p_is_internal := false;
  elsif app.has_permission('support.respond') then
    v_kind := 'AGENT';
  else
    perform app.fail('PERMISSION_DENIED', 'You cannot reply to this ticket.');
  end if;

  if v_ticket.status = 'CLOSED' and v_kind = 'CUSTOMER' then
    update public.support_tickets
    set status = 'OPEN', reopen_count = reopen_count + 1, closed_at = null, updated_at = now()
    where id = p_ticket_id;
  end if;

  insert into public.support_messages (ticket_id, author_kind, author_id, body, is_internal, attachments)
  values (p_ticket_id, v_kind, v_uid, p_body, coalesce(p_is_internal, false), coalesce(p_attachments, '[]'::jsonb))
  returning id into v_id;

  -- Notify the counterparty.
  if v_kind = 'AGENT' and not coalesce(p_is_internal, false) then
    perform app.enqueue_notification(
      v_ticket.user_id,
      'SUPPORT_REPLY'::public.notification_event,
      jsonb_build_object('ticket_number', v_ticket.ticket_number, 'ticket_id', v_ticket.id::text),
      array['PUSH', 'IN_APP']::public.notification_channel[],
      v_ticket.order_id
    );
  end if;

  return v_id;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- REVIEWS
-- ═══════════════════════════════════════════════════════════════════════════
create table public.reviews (
  id                  uuid primary key default gen_random_uuid(),
  order_id            uuid not null references public.orders (id) on delete cascade,
  user_id             uuid not null references auth.users (id) on delete cascade,
  branch_id           uuid not null references public.branches (id) on delete restrict,
  delivery_partner_id uuid references public.delivery_partners (id) on delete set null,

  food_rating         smallint not null,
  delivery_rating     smallint,
  overall_rating      smallint not null,
  comment             text,
  -- Structured feedback chips: {"packaging","temperature","portion",...}
  tags                text[] not null default '{}',
  images              jsonb not null default '[]'::jsonb,

  status              public.review_status not null default 'PUBLISHED',
  -- Internal moderation
  flagged_reason      text,
  moderated_by        uuid references auth.users (id) on delete set null,
  moderated_at        timestamptz,
  internal_note       text,
  -- Public reply from the restaurant
  response_body       text,
  responded_by        uuid references auth.users (id) on delete set null,
  responded_at        timestamptz,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint reviews_food_rating check (food_rating between 1 and 5),
  constraint reviews_delivery_rating check (delivery_rating is null or delivery_rating between 1 and 5),
  constraint reviews_overall_rating check (overall_rating between 1 and 5)
);

create unique index reviews_order_key on public.reviews (order_id);
create index reviews_branch_idx on public.reviews (branch_id, created_at desc);
create index reviews_rating_idx on public.reviews (overall_rating);
create index reviews_partner_idx on public.reviews (delivery_partner_id)
  where delivery_partner_id is not null;

select app.attach_updated_at('public.reviews');

-- Per-item ratings so merchandising can surface genuinely popular dishes.
create table public.review_items (
  id            uuid primary key default gen_random_uuid(),
  review_id     uuid not null references public.reviews (id) on delete cascade,
  order_item_id uuid references public.order_items (id) on delete set null,
  product_id    uuid references public.products (id) on delete set null,
  rating        smallint not null,
  comment       text,
  created_at    timestamptz not null default now(),

  constraint review_items_rating check (rating between 1 and 5)
);

create index review_items_product_idx on public.review_items (product_id);
create unique index review_items_key on public.review_items (review_id, order_item_id);

-- Rating aggregates on products and riders.
create or replace function app.tg_review_aggregates()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.delivery_partner_id is not null and new.delivery_rating is not null then
    update public.delivery_partners dp
    set rating_count = agg.cnt,
        rating_average = agg.avg_rating,
        updated_at = now()
    from (
      select count(*)::int as cnt, round(avg(delivery_rating)::numeric, 2) as avg_rating
      from public.reviews
      where delivery_partner_id = new.delivery_partner_id
        and delivery_rating is not null
        and status = 'PUBLISHED'
    ) agg
    where dp.id = new.delivery_partner_id;
  end if;

  return new;
end;
$$;

create trigger review_aggregates
  after insert or update of status, delivery_rating on public.reviews
  for each row execute function app.tg_review_aggregates();

create or replace function app.tg_review_item_aggregates()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.product_id is not null then
    update public.products p
    set rating_count = agg.cnt,
        rating_average = coalesce(agg.avg_rating, 0),
        updated_at = now()
    from (
      select count(*)::int as cnt, round(avg(ri.rating)::numeric, 2) as avg_rating
      from public.review_items ri
      join public.reviews r on r.id = ri.review_id
      where ri.product_id = new.product_id and r.status = 'PUBLISHED'
    ) agg
    where p.id = new.product_id;
  end if;

  return new;
end;
$$;

create trigger review_item_aggregates
  after insert or update of rating on public.review_items
  for each row execute function app.tg_review_item_aggregates();

-- ─── Review submission (only for delivered orders you own) ──────────────────
create or replace function public.submit_review(
  p_order_id uuid,
  p_food_rating smallint,
  p_overall_rating smallint,
  p_delivery_rating smallint default null,
  p_comment text default null,
  p_tags text[] default '{}',
  p_item_ratings jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders;
  v_review public.reviews;
  v_partner uuid;
  v_item jsonb;
begin
  select * into v_order from public.orders where id = p_order_id;

  if not found or v_order.user_id <> v_uid then
    perform app.fail('ORDER_NOT_FOUND', 'We could not find that order on your account.');
  end if;

  if v_order.status not in ('DELIVERED', 'COMPLETED', 'PARTIALLY_REFUNDED') then
    perform app.fail('REVIEW_NOT_ALLOWED', 'You can rate an order once it has been delivered.');
  end if;

  if exists (select 1 from public.reviews where order_id = p_order_id) then
    perform app.fail('REVIEW_ALREADY_SUBMITTED', 'You have already rated this order.');
  end if;

  select delivery_partner_id into v_partner
  from public.delivery_assignments
  where order_id = p_order_id and status = 'COMPLETED'
  order by attempt_number desc
  limit 1;

  insert into public.reviews (
    order_id, user_id, branch_id, delivery_partner_id,
    food_rating, delivery_rating, overall_rating, comment, tags
  )
  values (
    p_order_id, v_uid, v_order.branch_id, v_partner,
    p_food_rating, p_delivery_rating, p_overall_rating, nullif(btrim(coalesce(p_comment, '')), ''),
    coalesce(p_tags, '{}')
  )
  returning * into v_review;

  -- Optional per-dish ratings
  for v_item in select * from jsonb_array_elements(coalesce(p_item_ratings, '[]'::jsonb)) loop
    insert into public.review_items (review_id, order_item_id, product_id, rating, comment)
    select
      v_review.id,
      oi.id,
      oi.product_id,
      (v_item ->> 'rating')::smallint,
      nullif(v_item ->> 'comment', '')
    from public.order_items oi
    where oi.id = (v_item ->> 'order_item_id')::uuid
      and oi.order_id = p_order_id
    on conflict (review_id, order_item_id) do nothing;
  end loop;

  return jsonb_build_object('review_id', v_review.id, 'status', v_review.status);
end;
$$;
