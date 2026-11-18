-- Restore the app's participant-only read path for the legacy obligation table
-- and remove the default PUBLIC execution grant from the role activation RPC.
-- This migration is being applied only to the explicitly authorized test project.

ALTER TABLE public.job_payment_obligations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS job_payment_obligations_participant_select
  ON public.job_payment_obligations;

CREATE POLICY job_payment_obligations_participant_select
  ON public.job_payment_obligations
  FOR SELECT
  TO authenticated
  USING (
    (SELECT auth.uid()) = obligated_poster_id
    OR (SELECT auth.uid()) = worker_id
  );

REVOKE ALL PRIVILEGES ON TABLE public.job_payment_obligations
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.job_payment_obligations TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public.request_my_role_activation_v1()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_my_role_activation_v1()
  TO authenticated, service_role;
