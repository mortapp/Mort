begin;

create or replace function public.current_user_is_production_identity_reviewer()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_production_identity_reviewer((select auth.uid()));
$$;

create or replace function public.production_identity_workflow_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.production_identity_ready();
$$;

revoke all on function public.current_user_is_production_identity_reviewer()
from public, anon;
revoke all on function public.production_identity_workflow_ready()
from public, anon;
grant execute on function public.current_user_is_production_identity_reviewer()
to authenticated;
grant execute on function public.production_identity_workflow_ready()
to authenticated;

drop policy if exists identity_verifications_production_reviewer_select
on public.identity_verifications;
create policy identity_verifications_production_reviewer_select
on public.identity_verifications for select to authenticated
using (
  environment = 'production'
  and public.current_user_is_production_identity_reviewer()
);

drop policy if exists identity_evidence_production_reviewer_select
on public.identity_verification_evidence;
create policy identity_evidence_production_reviewer_select
on public.identity_verification_evidence for select to authenticated
using (
  environment = 'production'
  and public.current_user_is_production_identity_reviewer()
  and exists (
    select 1
    from public.verification_evidence_access_grants access_grant
    where access_grant.evidence_id = identity_verification_evidence.id
      and access_grant.reviewer_id = (select auth.uid())
      and access_grant.revoked_at is null
      and access_grant.expires_at > now()
  )
);

drop policy if exists identity_appeals_owner_or_production_reviewer_select
on public.identity_verification_appeals;
create policy identity_appeals_owner_or_production_reviewer_select
on public.identity_verification_appeals for select to authenticated
using (
  user_id = (select auth.uid())
  or (
    public.current_user_is_production_identity_reviewer()
    and exists (
      select 1
      from public.identity_verifications verification
      where verification.id = identity_verification_appeals.verification_id
        and verification.environment = 'production'
    )
  )
);

drop policy if exists verification_access_grants_production_reviewer_select
on public.verification_evidence_access_grants;
create policy verification_access_grants_production_reviewer_select
on public.verification_evidence_access_grants for select to authenticated
using (
  reviewer_id = (select auth.uid())
  and public.current_user_is_production_identity_reviewer()
);

drop policy if exists identity_risk_signals_production_reviewer_select
on public.identity_risk_signals;
create policy identity_risk_signals_production_reviewer_select
on public.identity_risk_signals for select to authenticated
using (
  public.current_user_is_production_identity_reviewer()
  and exists (
    select 1
    from public.identity_verifications verification
    where verification.id = identity_risk_signals.verification_id
      and verification.environment = 'production'
  )
);

drop policy if exists identity_evidence_authorized_production_reviewer_read
on storage.objects;
create policy identity_evidence_authorized_production_reviewer_read
on storage.objects for select to authenticated
using (
  bucket_id = 'identity-evidence'
  and public.production_identity_workflow_ready()
  and public.current_user_is_production_identity_reviewer()
  and storage.allow_any_operation(array['object.get_authenticated_info', 'object.get_authenticated'])
  and exists (
    select 1
    from public.identity_verification_evidence evidence
    join public.verification_evidence_access_grants access_grant
      on access_grant.evidence_id = evidence.id
    where evidence.storage_path = name
      and evidence.environment = 'production'
      and evidence.storage_path like 'production/%'
      and access_grant.reviewer_id = (select auth.uid())
      and access_grant.revoked_at is null
      and access_grant.expires_at > now()
  )
);

comment on function public.current_user_is_production_identity_reviewer()
is 'RLS-safe current-user reviewer check; it does not accept another user id.';
comment on function public.production_identity_workflow_ready()
is 'RLS-safe readiness check. Production identity remains fail-closed until all server controls are approved.';

commit;
