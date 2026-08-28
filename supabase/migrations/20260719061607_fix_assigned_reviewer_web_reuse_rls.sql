-- Resolve reviewer authorization without requiring access to subject-only join tables.

create or replace function private.can_review_document_web_reuse_result(
  p_result_id uuid,
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
    from public.document_web_reuse_results result
    join public.document_web_reuse_requests request
      on request.id = result.request_id
    join public.document_capture_sessions session
      on session.id = request.capture_session_id
    join public.appearance_review_cases appearance
      on appearance.document_review_case_id = session.review_case_id
    where result.id = p_result_id
      and private.is_assigned_appearance_reviewer(appearance.id, p_user_id)
  );
$$;

revoke all on function private.can_review_document_web_reuse_result(uuid, uuid)
from public, anon;
grant execute on function private.can_review_document_web_reuse_result(uuid, uuid)
to authenticated, service_role;

drop policy if exists document_web_reuse_results_assigned_reviewer_select
on public.document_web_reuse_results;
create policy document_web_reuse_results_assigned_reviewer_select
on public.document_web_reuse_results
for select
to authenticated
using (
  private.can_review_document_web_reuse_result(
    id,
    (select auth.uid())
  )
);
