-- Require a reviewer to hold both an active case assignment and a
-- short-lived document-access grant before a review decision can change state.

create or replace function private.guard_teen_verification_review_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_service boolean := coalesce(auth.jwt()->>'role', '') = 'service_role';
begin
  if v_service then
    return new;
  end if;

  if new.reviewer_id is not null
     and (
       new.status is distinct from old.status
       or new.reviewed_at is distinct from old.reviewed_at
       or new.identity_status is distinct from old.identity_status
       or new.age_status is distinct from old.age_status
     ) then
    if v_actor is null or v_actor <> new.reviewer_id then
      raise exception 'teen_verification_reviewer_binding_required';
    end if;

    if not exists (
      select 1
      from private.teen_verification_review_assignments assignment
      where assignment.session_id = new.id
        and assignment.reviewer_id = v_actor
        and assignment.revoked_at is null
        and assignment.expires_at > now()
    ) then
      raise exception 'active_teen_verification_assignment_required';
    end if;

    if not exists (
      select 1
      from private.teen_school_id_documents document
      join private.teen_school_id_access_grants access_grant
        on access_grant.document_id = document.id
       and access_grant.reviewer_id = v_actor
       and access_grant.revoked_at is null
       and access_grant.expires_at > now()
      where document.session_id = new.id
        and document.deleted_at is null
    ) then
      raise exception 'active_school_id_access_grant_required';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists guard_teen_verification_review_transition
on private.teen_verification_sessions;
create trigger guard_teen_verification_review_transition
before update on private.teen_verification_sessions
for each row
execute function private.guard_teen_verification_review_transition();

revoke all on function private.guard_teen_verification_review_transition()
from public, anon, authenticated;
grant execute on function private.guard_teen_verification_review_transition()
to service_role;
