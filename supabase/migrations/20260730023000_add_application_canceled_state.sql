-- Keep poster cancellation distinct from applicant rejection or withdrawal.
-- This enum addition is isolated so PostgreSQL commits it before later
-- migrations use the value in transition functions.
alter type public.application_status
  add value if not exists 'canceled';
