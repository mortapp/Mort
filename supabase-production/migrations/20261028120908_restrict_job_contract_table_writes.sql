revoke all on table
  public.job_contracts,
  public.job_contract_versions,
  public.job_contract_acceptances,
  public.job_contract_change_requests,
  public.job_contract_change_acceptances
from authenticated;

grant select on table
  public.job_contracts,
  public.job_contract_versions,
  public.job_contract_acceptances,
  public.job_contract_change_requests,
  public.job_contract_change_acceptances
to authenticated;

comment on table public.job_contracts is 'Private-to-participants agreement envelope for a MORT job application. Authenticated clients are read-only; writes go through guarded RPCs.';
comment on table public.job_contract_versions is 'Immutable agreement terms snapshots. Authenticated clients are read-only; writes go through guarded RPCs.';