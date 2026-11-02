-- Cover the cancellation table's foreign keys so profile, job, assignment, or
-- safety-report maintenance does not scan the full audit table.
create index job_safety_cancellations_assignment_idx
  on public.job_safety_cancellations(assignment_id);
create index job_safety_cancellations_job_idx
  on public.job_safety_cancellations(job_id);
create index job_safety_cancellations_actor_idx
  on public.job_safety_cancellations(actor_id);
create index job_safety_cancellations_reported_user_idx
  on public.job_safety_cancellations(reported_user_id);
create index job_safety_cancellations_safety_report_idx
  on public.job_safety_cancellations(safety_report_id);

