-- Cover the response table's independent foreign-key lookups.
create index job_execution_review_responses_dispute_idx
  on public.job_execution_review_responses(dispute_id);
create index job_execution_review_responses_responded_by_idx
  on public.job_execution_review_responses(responded_by);

