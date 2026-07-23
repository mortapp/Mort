-- Extend lifecycle enums in a standalone migration so later migrations can
-- safely use the new values after this transaction commits.
alter type public.job_status add value if not exists 'pending_review';
alter type public.job_status add value if not exists 'assigned';
alter type public.job_status add value if not exists 'in_progress';
alter type public.job_status add value if not exists 'proof_submitted';
alter type public.job_status add value if not exists 'completed';
alter type public.job_status add value if not exists 'canceled';
alter type public.job_status add value if not exists 'expired';
alter type public.job_status add value if not exists 'rejected';

alter type public.application_status add value if not exists 'viewed';
alter type public.application_status add value if not exists 'withdrawn';
alter type public.application_status add value if not exists 'in_progress';
alter type public.application_status add value if not exists 'proof_submitted';

alter type public.guardian_connection_status add value if not exists 'canceled';
alter type public.guardian_connection_status add value if not exists 'expired';
