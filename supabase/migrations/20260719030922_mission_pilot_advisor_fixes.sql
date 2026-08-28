-- Remove the overlapping permissive SELECT policies while preserving the
-- participant-read and teen-owner write behavior.
drop policy if exists support_circles_participant_select on public.support_circles;
drop policy if exists support_circles_teen_manage on public.support_circles;

create policy support_circles_participant_select
on public.support_circles for select to authenticated
using (
  teen_id = (select auth.uid())
  or exists (
    select 1
    from public.support_circle_members member
    where member.circle_id = support_circles.id
      and member.member_user_id = (select auth.uid())
      and member.status = 'active'
  )
);

create policy support_circles_teen_insert
on public.support_circles for insert to authenticated
with check (
  teen_id = (select auth.uid())
  and public.current_profile_role() = 'teen'
);

create policy support_circles_teen_update
on public.support_circles for update to authenticated
using (teen_id = (select auth.uid()))
with check (
  teen_id = (select auth.uid())
  and public.current_profile_role() = 'teen'
);

create policy support_circles_teen_delete
on public.support_circles for delete to authenticated
using (teen_id = (select auth.uid()));

-- Cover every foreign key introduced by the mission migration that remained
-- visible in the post-apply performance advisor.
create index if not exists document_review_appeals_case_idx
on public.document_review_appeals(case_id);

create index if not exists partner_audit_events_organization_idx
on public.partner_audit_events(organization_id)
where organization_id is not null;

create index if not exists partner_audit_events_subject_idx
on public.partner_audit_events(subject_user_id)
where subject_user_id is not null;

create index if not exists partner_invite_codes_revoked_by_idx
on public.partner_invite_codes(revoked_by)
where revoked_by is not null;

create index if not exists partner_organizations_pilot_approved_by_idx
on public.partner_organizations(pilot_approved_by)
where pilot_approved_by is not null;

create index if not exists support_circle_permissions_configured_by_idx
on public.support_circle_permissions(configured_by);
