-- Keep participant read access and route all response writes through the checked RPC.
revoke all on public.job_execution_review_responses from public, anon, authenticated;
grant select on public.job_execution_review_responses to authenticated;

