-- PROPOSAL ONLY. Apply only after all legitimate site writers have moved to the
-- authenticated `save_job_draft_or_publish(uuid,uuid,jsonb,boolean)` RPC and
-- their end-to-end create/review flow has passed QA. The production security-
-- definer RPC remains callable and performs validated job writes as its owner.
-- This revokes direct table writes because a table-level INSERT grant cannot
-- be safely constrained to omit only exact_address.

do $preflight$
begin
  if not exists (
    select 1 from pg_proc
    where oid = 'public.save_job_draft_or_publish(uuid,uuid,jsonb,boolean)'::regprocedure
      and prosecdef
  ) or not has_function_privilege(
    'authenticated',
    'public.save_job_draft_or_publish(uuid,uuid,jsonb,boolean)',
    'execute'
  ) then
    raise exception 'authorized_job_write_rpc_unavailable';
  end if;
end;
$preflight$;

revoke insert on table public.jobs from authenticated;
revoke insert (exact_address) on table public.jobs from authenticated;
revoke update (exact_address) on table public.jobs from authenticated;
