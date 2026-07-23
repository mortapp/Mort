-- RLS and shared authorization helpers for the legal, payment, first-party
-- trust, and adult-team foundations. Writes are server-RPC only unless a
-- policy below states otherwise.

create or replace function private.user_is_contract_party(
  p_contract_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and exists (
    select 1
    from public.job_contracts contract
    where contract.id = p_contract_id
      and p_user_id in (contract.teen_id, contract.adult_id)
  );
$$;

create or replace function private.has_ready_team_role(
  p_user_id uuid,
  p_role_keys text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and exists (
    select 1
    from public.team_role_assignments assignment
    where assignment.user_id = p_user_id
      and assignment.role_key = any(p_role_keys)
      and assignment.access_status = 'active'
      and assignment.granted_at is not null
      and assignment.expires_at > now()
      and exists (
        select 1
        from public.team_confidentiality_acknowledgements confidentiality
        where confidentiality.user_id = p_user_id
          and confidentiality.affirmative_checkbox
          and confidentiality.revoked_at is null
          and confidentiality.expires_at > now()
      )
      and exists (
        select 1
        from public.team_conflict_disclosures conflict
        where conflict.user_id = p_user_id
          and conflict.review_status = 'cleared'
          and conflict.expires_at > now()
      )
      and exists (
        select 1
        from public.team_device_compliance device
        where device.user_id = p_user_id
          and device.review_status = 'approved'
          and device.expires_at > now()
      )
      and not exists (
        select 1
        from public.team_role_training_requirements requirement
        join public.team_training_modules module
          on module.module_key = requirement.module_key
         and module.active
        where requirement.role_key = assignment.role_key
          and requirement.required
          and not exists (
            select 1
            from public.team_training_completions completion
            where completion.user_id = p_user_id
              and completion.module_key = requirement.module_key
              and completion.module_version = module.module_version
              and completion.assessment_passed
              and completion.expires_at > now()
          )
      )
  );
$$;

create or replace function private.is_assigned_payment_dispute_reviewer(
  p_dispute_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_ready_team_role(
    p_user_id,
    array['safety_moderator', 'incident_manager', 'super_admin']::text[]
  ) and exists (
    select 1
    from public.payment_dispute_assignments assignment
    where assignment.dispute_id = p_dispute_id
      and assignment.reviewer_id = p_user_id
      and assignment.status = 'active'
      and assignment.expires_at > now()
  );
$$;

create or replace function private.is_assigned_appearance_reviewer(
  p_case_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_ready_team_role(
    p_user_id,
    array['document_reviewer', 'senior_document_reviewer']::text[]
  ) and exists (
    select 1
    from public.appearance_review_assignments assignment
    where assignment.appearance_case_id = p_case_id
      and assignment.reviewer_id = p_user_id
      and assignment.status = 'active'
      and assignment.expires_at > now()
  );
$$;

create or replace function private.prevent_restricted_poster_job_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('open', 'assigned')
     and exists (
       select 1
       from public.poster_payment_restrictions restriction
       where restriction.poster_id = new.poster_id
         and restriction.restriction_type = 'block_new_job_publication'
         and restriction.status = 'active'
         and (restriction.expires_at is null or restriction.expires_at > now())
     ) then
    raise exception using
      errcode = '42501',
      message = 'Poster is temporarily restricted from publishing jobs during private payment review.';
  end if;
  return new;
end;
$$;

drop trigger if exists jobs_enforce_payment_restriction on public.jobs;
create trigger jobs_enforce_payment_restriction
before insert or update of status, poster_id on public.jobs
for each row execute function private.prevent_restricted_poster_job_write();

drop trigger if exists payment_disputes_set_updated_at on public.payment_disputes;
create trigger payment_disputes_set_updated_at
before update on public.payment_disputes
for each row execute function public.set_updated_at();

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'legal_documents', 'legal_document_versions', 'legal_role_requirements',
    'legal_jurisdiction_requirements', 'legal_acceptances', 'legal_declines',
    'legal_reacceptance_requirements', 'legal_acceptance_audit_events',
    'job_contracts', 'job_contract_versions', 'job_contract_acceptances',
    'job_contract_change_requests', 'job_contract_change_acceptances',
    'job_completion_assertions', 'job_payment_obligations',
    'completion_evidence_records', 'payment_confirmation_records',
    'payment_disputes', 'payment_dispute_assignments',
    'payment_dispute_evidence', 'payment_dispute_timeline',
    'payment_dispute_decisions', 'poster_payment_restrictions',
    'jurisdiction_legal_resources', 'payment_evidence_export_events',
    'document_capture_sessions', 'document_capture_quality_results',
    'document_web_reuse_requests', 'document_web_reuse_results',
    'live_presence_challenges', 'live_presence_results',
    'appearance_review_cases', 'appearance_review_assignments',
    'appearance_review_decisions', 'team_role_assignments',
    'team_training_modules', 'team_role_training_requirements',
    'team_training_completions', 'team_confidentiality_acknowledgements',
    'team_conflict_disclosures', 'team_device_compliance',
    'team_access_audit_events'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
  end loop;
end;
$$;

alter table private.first_party_trust_control enable row level security;
alter table private.document_web_reuse_provider_configs enable row level security;

create policy legal_documents_published_or_admin_select
on public.legal_documents for select to authenticated
using (publication_status in ('published', 'retired') or (select public.is_admin()));

create policy legal_document_versions_published_or_admin_select
on public.legal_document_versions for select to authenticated
using (publication_status in ('published', 'retired') or (select public.is_admin()));

create policy legal_role_requirements_published_or_admin_select
on public.legal_role_requirements for select to authenticated
using (
  exists (
    select 1 from public.legal_documents document
    where document.id = legal_role_requirements.document_id
      and document.publication_status in ('published', 'retired')
  ) or (select public.is_admin())
);

create policy legal_jurisdiction_requirements_published_or_admin_select
on public.legal_jurisdiction_requirements for select to authenticated
using (
  exists (
    select 1 from public.legal_documents document
    where document.id = legal_jurisdiction_requirements.document_id
      and document.publication_status in ('published', 'retired')
  ) or (select public.is_admin())
);

create policy legal_acceptances_owner_select
on public.legal_acceptances for select to authenticated
using (user_id = (select auth.uid()));

create policy legal_declines_owner_select
on public.legal_declines for select to authenticated
using (user_id = (select auth.uid()));

create policy legal_reacceptance_owner_select
on public.legal_reacceptance_requirements for select to authenticated
using (user_id = (select auth.uid()));

create policy legal_acceptance_audit_owner_select
on public.legal_acceptance_audit_events for select to authenticated
using (user_id = (select auth.uid()));

create policy job_contracts_participant_select
on public.job_contracts for select to authenticated
using ((select auth.uid()) in (teen_id, adult_id));

create policy job_contract_versions_participant_select
on public.job_contract_versions for select to authenticated
using (private.user_is_contract_party(contract_id));

create policy job_contract_acceptances_participant_select
on public.job_contract_acceptances for select to authenticated
using (private.user_is_contract_party(contract_id));

create policy job_contract_change_requests_participant_select
on public.job_contract_change_requests for select to authenticated
using (private.user_is_contract_party(contract_id));

create policy job_contract_change_acceptances_participant_select
on public.job_contract_change_acceptances for select to authenticated
using (
  exists (
    select 1
    from public.job_contract_change_requests request
    where request.id = job_contract_change_acceptances.change_request_id
      and private.user_is_contract_party(request.contract_id)
  )
);

create policy job_completion_assertions_participant_select
on public.job_completion_assertions for select to authenticated
using (private.user_is_contract_party(contract_id));

create policy job_payment_obligations_participant_select
on public.job_payment_obligations for select to authenticated
using (private.user_is_contract_party(contract_id));

create policy completion_evidence_participant_select
on public.completion_evidence_records for select to authenticated
using (private.user_is_contract_party(contract_id));

create policy payment_confirmations_participant_select
on public.payment_confirmation_records for select to authenticated
using (
  exists (
    select 1
    from public.job_payment_obligations obligation
    where obligation.id = payment_confirmation_records.obligation_id
      and private.user_is_contract_party(obligation.contract_id)
  )
);

create policy payment_disputes_participant_or_assigned_select
on public.payment_disputes for select to authenticated
using (
  (select auth.uid()) in (worker_id, poster_id)
  or private.is_assigned_payment_dispute_reviewer(id)
);

create policy payment_dispute_assignments_self_or_admin_select
on public.payment_dispute_assignments for select to authenticated
using (reviewer_id = (select auth.uid()) or (select public.is_admin()));

create policy payment_dispute_evidence_participant_or_assigned_select
on public.payment_dispute_evidence for select to authenticated
using (
  exists (
    select 1
    from public.payment_disputes dispute
    where dispute.id = payment_dispute_evidence.dispute_id
      and (
        (select auth.uid()) in (dispute.worker_id, dispute.poster_id)
        or private.is_assigned_payment_dispute_reviewer(dispute.id)
      )
  )
);

create policy payment_dispute_timeline_participant_or_assigned_select
on public.payment_dispute_timeline for select to authenticated
using (
  exists (
    select 1
    from public.payment_disputes dispute
    where dispute.id = payment_dispute_timeline.dispute_id
      and (
        (select auth.uid()) in (dispute.worker_id, dispute.poster_id)
        or private.is_assigned_payment_dispute_reviewer(dispute.id)
      )
  )
);

create policy payment_dispute_decisions_participant_or_assigned_select
on public.payment_dispute_decisions for select to authenticated
using (
  exists (
    select 1
    from public.payment_disputes dispute
    where dispute.id = payment_dispute_decisions.dispute_id
      and (
        (select auth.uid()) in (dispute.worker_id, dispute.poster_id)
        or private.is_assigned_payment_dispute_reviewer(dispute.id)
      )
  )
);

create policy poster_payment_restrictions_owner_or_assigned_select
on public.poster_payment_restrictions for select to authenticated
using (
  poster_id = (select auth.uid())
  or private.is_assigned_payment_dispute_reviewer(dispute_id)
);

create policy jurisdiction_legal_resources_approved_select
on public.jurisdiction_legal_resources for select to authenticated
using ((active and status = 'approved') or (select public.is_admin()));

create policy payment_evidence_export_requester_select
on public.payment_evidence_export_events for select to authenticated
using (requested_by = (select auth.uid()));

create policy document_capture_subject_select
on public.document_capture_sessions for select to authenticated
using (subject_user_id = (select auth.uid()));

create policy document_capture_quality_subject_select
on public.document_capture_quality_results for select to authenticated
using (
  exists (
    select 1 from public.document_capture_sessions session
    where session.id = document_capture_quality_results.capture_session_id
      and session.subject_user_id = (select auth.uid())
  )
);

create policy document_web_reuse_requests_subject_select
on public.document_web_reuse_requests for select to authenticated
using (subject_user_id = (select auth.uid()));

-- Provider match URLs and internal reasons remain assigned-reviewer only.
create policy document_web_reuse_results_assigned_reviewer_select
on public.document_web_reuse_results for select to authenticated
using (
  exists (
    select 1
    from public.document_web_reuse_requests request
    join public.document_capture_sessions session on session.id = request.capture_session_id
    join public.appearance_review_cases appearance on appearance.document_review_case_id = session.review_case_id
    where request.id = document_web_reuse_results.request_id
      and private.is_assigned_appearance_reviewer(appearance.id)
  )
);

create policy live_presence_subject_select
on public.live_presence_challenges for select to authenticated
using (subject_user_id = (select auth.uid()));

create policy live_presence_results_subject_select
on public.live_presence_results for select to authenticated
using (
  exists (
    select 1 from public.live_presence_challenges challenge
    where challenge.id = live_presence_results.challenge_id
      and challenge.subject_user_id = (select auth.uid())
  )
);

create policy appearance_review_cases_subject_or_assigned_select
on public.appearance_review_cases for select to authenticated
using (subject_user_id = (select auth.uid()) or private.is_assigned_appearance_reviewer(id));

create policy appearance_assignments_self_select
on public.appearance_review_assignments for select to authenticated
using (reviewer_id = (select auth.uid()));

create policy appearance_decisions_subject_or_assigned_select
on public.appearance_review_decisions for select to authenticated
using (
  exists (
    select 1 from public.appearance_review_cases appearance
    where appearance.id = appearance_review_decisions.appearance_case_id
      and (
        appearance.subject_user_id = (select auth.uid())
        or private.is_assigned_appearance_reviewer(appearance.id)
      )
  )
);

create policy team_roles_self_or_admin_select
on public.team_role_assignments for select to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy team_training_modules_authenticated_select
on public.team_training_modules for select to authenticated
using (active);

create policy team_training_requirements_authenticated_select
on public.team_role_training_requirements for select to authenticated
using (required);

create policy team_training_completions_self_or_admin_select
on public.team_training_completions for select to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy team_confidentiality_self_or_admin_select
on public.team_confidentiality_acknowledgements for select to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy team_conflicts_self_or_admin_select
on public.team_conflict_disclosures for select to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy team_device_self_or_admin_select
on public.team_device_compliance for select to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy team_access_audit_self_select
on public.team_access_audit_events for select to authenticated
using (user_id = (select auth.uid()));

revoke all on table
  public.legal_documents, public.legal_document_versions,
  public.legal_role_requirements, public.legal_jurisdiction_requirements,
  public.legal_acceptances, public.legal_declines,
  public.legal_reacceptance_requirements, public.legal_acceptance_audit_events,
  public.job_contracts, public.job_contract_versions,
  public.job_contract_acceptances, public.job_contract_change_requests,
  public.job_contract_change_acceptances, public.job_completion_assertions,
  public.job_payment_obligations, public.completion_evidence_records,
  public.payment_confirmation_records, public.payment_disputes,
  public.payment_dispute_assignments, public.payment_dispute_evidence,
  public.payment_dispute_timeline, public.payment_dispute_decisions,
  public.poster_payment_restrictions, public.jurisdiction_legal_resources,
  public.payment_evidence_export_events, public.document_capture_sessions,
  public.document_capture_quality_results, public.document_web_reuse_requests,
  public.document_web_reuse_results, public.live_presence_challenges,
  public.live_presence_results, public.appearance_review_cases,
  public.appearance_review_assignments, public.appearance_review_decisions,
  public.team_role_assignments, public.team_training_modules,
  public.team_role_training_requirements, public.team_training_completions,
  public.team_confidentiality_acknowledgements, public.team_conflict_disclosures,
  public.team_device_compliance, public.team_access_audit_events
from public, anon, authenticated;

grant select on table
  public.legal_documents, public.legal_document_versions,
  public.legal_role_requirements, public.legal_jurisdiction_requirements,
  public.legal_acceptances, public.legal_declines,
  public.legal_reacceptance_requirements, public.legal_acceptance_audit_events,
  public.job_contracts, public.job_contract_versions,
  public.job_contract_acceptances, public.job_contract_change_requests,
  public.job_contract_change_acceptances, public.job_completion_assertions,
  public.job_payment_obligations, public.completion_evidence_records,
  public.payment_confirmation_records, public.payment_disputes,
  public.payment_dispute_assignments, public.payment_dispute_evidence,
  public.payment_dispute_timeline, public.payment_dispute_decisions,
  public.poster_payment_restrictions, public.jurisdiction_legal_resources,
  public.payment_evidence_export_events, public.document_capture_sessions,
  public.document_capture_quality_results, public.document_web_reuse_requests,
  public.document_web_reuse_results, public.live_presence_challenges,
  public.live_presence_results, public.appearance_review_cases,
  public.appearance_review_assignments, public.appearance_review_decisions,
  public.team_role_assignments, public.team_training_modules,
  public.team_role_training_requirements, public.team_training_completions,
  public.team_confidentiality_acknowledgements, public.team_conflict_disclosures,
  public.team_device_compliance, public.team_access_audit_events
to authenticated;

grant all on table
  public.legal_documents, public.legal_document_versions,
  public.legal_role_requirements, public.legal_jurisdiction_requirements,
  public.legal_acceptances, public.legal_declines,
  public.legal_reacceptance_requirements, public.legal_acceptance_audit_events,
  public.job_contracts, public.job_contract_versions,
  public.job_contract_acceptances, public.job_contract_change_requests,
  public.job_contract_change_acceptances, public.job_completion_assertions,
  public.job_payment_obligations, public.completion_evidence_records,
  public.payment_confirmation_records, public.payment_disputes,
  public.payment_dispute_assignments, public.payment_dispute_evidence,
  public.payment_dispute_timeline, public.payment_dispute_decisions,
  public.poster_payment_restrictions, public.jurisdiction_legal_resources,
  public.payment_evidence_export_events, public.document_capture_sessions,
  public.document_capture_quality_results, public.document_web_reuse_requests,
  public.document_web_reuse_results, public.live_presence_challenges,
  public.live_presence_results, public.appearance_review_cases,
  public.appearance_review_assignments, public.appearance_review_decisions,
  public.team_role_assignments, public.team_training_modules,
  public.team_role_training_requirements, public.team_training_completions,
  public.team_confidentiality_acknowledgements, public.team_conflict_disclosures,
  public.team_device_compliance, public.team_access_audit_events
to service_role;

grant usage, select on sequence public.legal_acceptance_audit_events_id_seq to service_role;
grant usage, select on sequence public.payment_dispute_timeline_id_seq to service_role;
grant usage, select on sequence public.team_access_audit_events_id_seq to service_role;

revoke all on function private.user_is_contract_party(uuid, uuid) from public, anon;
revoke all on function private.has_ready_team_role(uuid, text[]) from public, anon;
revoke all on function private.is_assigned_payment_dispute_reviewer(uuid, uuid) from public, anon;
revoke all on function private.is_assigned_appearance_reviewer(uuid, uuid) from public, anon;
revoke all on function private.prevent_restricted_poster_job_write() from public, anon, authenticated;
grant execute on function private.user_is_contract_party(uuid, uuid) to authenticated, service_role;
grant execute on function private.has_ready_team_role(uuid, text[]) to authenticated, service_role;
grant execute on function private.is_assigned_payment_dispute_reviewer(uuid, uuid) to authenticated, service_role;
grant execute on function private.is_assigned_appearance_reviewer(uuid, uuid) to authenticated, service_role;
