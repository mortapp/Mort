-- Force client applications through the eligibility-enforcing RPC.
-- submit_job_application performs marketplace, age, job-state, block, and
-- guardian-consent checks before invoking the owner-privileged insert routine.
REVOKE INSERT ON TABLE public.job_applications FROM authenticated;
