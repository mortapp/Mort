# Stripe CLI Testing

Install and authenticate the official Stripe CLI, then run `scripts/stripe-check-config.ps1`. For local Supabase, start the stack and run `scripts/stripe-listen-test.ps1`; for a deployed endpoint, pass its HTTPS URL with `-ForwardTo`.

`stripe listen` prints a temporary `whsec_` secret. Set it only for the active test session or directly in Supabase's secret store, restart/redeploy the webhook function, and clear the shell variable afterward. Never save it in source or command transcripts.

In another terminal run `scripts/stripe-trigger-test-events.ps1`. Confirm signature verification, environment match, atomic claim, idempotent duplicate handling, safe processing result, and database reconciliation. Generic CLI fixtures may not contain MORT metadata, so a provider event can be safely ignored or rejected; complete end-to-end QA must create provider objects through MORT's sandbox functions.
