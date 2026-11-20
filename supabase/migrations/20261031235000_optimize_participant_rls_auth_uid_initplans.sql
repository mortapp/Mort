-- Optimize participant RLS predicates by evaluating auth.uid() once per statement.
-- Authorization predicates and participant ownership semantics are unchanged.

drop policy if exists job_contract_parties_read on public.job_contracts;
create policy job_contract_parties_read on public.job_contracts
for select to authenticated
using (((select auth.uid()) = teen_id) or ((select auth.uid()) = adult_id));

drop policy if exists job_contract_versions_parties_read on public.job_contract_versions;
create policy job_contract_versions_parties_read on public.job_contract_versions
for select to authenticated
using (
  exists (
    select 1 from public.job_contracts contract
    where contract.id = job_contract_versions.contract_id
      and (((select auth.uid()) = contract.teen_id) or ((select auth.uid()) = contract.adult_id))
  )
);

drop policy if exists job_contract_acceptances_parties_read on public.job_contract_acceptances;
create policy job_contract_acceptances_parties_read on public.job_contract_acceptances
for select to authenticated
using (
  exists (
    select 1 from public.job_contracts contract
    where contract.id = job_contract_acceptances.contract_id
      and (((select auth.uid()) = contract.teen_id) or ((select auth.uid()) = contract.adult_id))
  )
);

drop policy if exists job_contract_changes_parties_read on public.job_contract_change_requests;
create policy job_contract_changes_parties_read on public.job_contract_change_requests
for select to authenticated
using (
  exists (
    select 1 from public.job_contracts contract
    where contract.id = job_contract_change_requests.contract_id
      and (((select auth.uid()) = contract.teen_id) or ((select auth.uid()) = contract.adult_id))
  )
);

drop policy if exists job_contract_change_responses_parties_read on public.job_contract_change_acceptances;
create policy job_contract_change_responses_parties_read on public.job_contract_change_acceptances
for select to authenticated
using (
  exists (
    select 1
    from public.job_contract_change_requests request
    join public.job_contracts contract on contract.id = request.contract_id
    where request.id = job_contract_change_acceptances.change_request_id
      and (((select auth.uid()) = contract.teen_id) or ((select auth.uid()) = contract.adult_id))
  )
);

drop policy if exists proof_uploads_participants_read on public.proof_uploads;
create policy proof_uploads_participants_read on public.proof_uploads
for select to authenticated
using (
  exists (
    select 1 from public.job_assignments assignment
    where assignment.id = proof_uploads.assignment_id
      and (((select auth.uid()) = assignment.teen_user_id) or ((select auth.uid()) = assignment.adult_user_id))
  )
);
