-- ═══════════════════════════════════════════════════════════════════════════
-- 0032 · RIDER ONBOARDING REVIEW (staff read surface)
--
-- `review_rider_document` existed and was tested, but nothing could call it
-- usefully: the admin dashboard had no way to see what a rider had submitted.
-- The only rider action in the UI was "Approve rider", which the server correctly
-- refuses until every required document is approved — so the button was a dead
-- end that always returned an error.
--
-- The missing piece is a staff-side equivalent of `my_rider_onboarding`. It
-- cannot be assembled client-side because:
--
--   · the required-document list lives in `settings` under a non-public key, and
--     reading it needs `settings.view`, which the roles that review riders
--     (MANAGER upward, via rider.approve) do not necessarily hold;
--   · deriving "required" in TypeScript would duplicate
--     `app.required_rider_documents()` and drift from it the first time an outlet
--     changes what it demands.
--
-- So the same function that answers the rider answers the reviewer, and both read
-- one source of truth.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.rider_onboarding(p_delivery_partner_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_partner public.delivery_partners;
  v_required public.rider_document_type[] := app.required_rider_documents();
begin
  select * into v_partner
  from public.delivery_partners
  where id = p_delivery_partner_id and deleted_at is null;

  if not found then
    perform app.fail('RIDER_NOT_FOUND', 'Delivery partner not found.');
  end if;

  -- Reading a rider's identity documents is a privileged act in its own right,
  -- separate from being able to dispatch them.
  perform app.require_permission('rider.view', v_partner.branch_id);

  return jsonb_build_object(
    'delivery_partner_id', v_partner.id,
    'full_name', v_partner.full_name,
    'partner_code', v_partner.partner_code,
    'phone', v_partner.phone,
    'onboarding_status', v_partner.onboarding_status,
    'rejection_reason', v_partner.rejection_reason,
    'suspended_reason', v_partner.suspended_reason,
    'suspended_until', v_partner.suspended_until,
    'required_documents', to_jsonb(v_required),
    'documents', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', d.id,
          'document_type', d.document_type,
          'status', d.status,
          'document_number', d.document_number,
          'issued_on', d.issued_on,
          'expires_on', d.expires_on,
          -- The reviewer needs this to sign a URL for the private bucket. It is a
          -- path, not the file; reading the object still goes through the
          -- rider-documents storage policy.
          'storage_path', d.storage_path,
          'rejection_reason', d.rejection_reason,
          'reviewed_at', d.reviewed_at,
          'reviewed_by_name', (
            select coalesce(pr.full_name, pr.phone::text)
            from public.profiles pr where pr.id = d.reviewed_by
          ),
          'is_required', d.document_type = any (v_required),
          'is_expired', d.expires_on is not null and d.expires_on < current_date,
          'created_at', d.created_at
        ) order by (d.document_type = any (v_required)) desc, d.created_at
      )
      from public.delivery_partner_documents d
      where d.delivery_partner_id = v_partner.id
    ), '[]'::jsonb),
    -- Required types with nothing usable on file. Mirrors my_rider_onboarding:
    -- a REJECTED document counts as outstanding, a PENDING one does not.
    'outstanding', coalesce((
      select jsonb_agg(t)
      from unnest(v_required) as t
      where not exists (
        select 1 from public.delivery_partner_documents d
        where d.delivery_partner_id = v_partner.id
          and d.document_type = t
          and d.status in ('PENDING', 'APPROVED')
      )
    ), '[]'::jsonb),
    -- What the reviewer actually wants to know before pressing Approve.
    'awaiting_review_count', (
      select count(*) from public.delivery_partner_documents d
      where d.delivery_partner_id = v_partner.id and d.status = 'PENDING'
    ),
    'ready_to_activate', v_partner.onboarding_status = 'VERIFIED'
      or not exists (
        select 1 from unnest(v_required) as t
        where not exists (
          select 1 from public.delivery_partner_documents d
          where d.delivery_partner_id = v_partner.id
            and d.document_type = t
            and d.status = 'APPROVED'
        )
      )
  );
end;
$$;

comment on function public.rider_onboarding is
  'Staff view of one rider''s onboarding: documents, what is outstanding, and whether they can be activated. Requires rider.view.';

grant execute on function public.rider_onboarding(uuid) to authenticated;
