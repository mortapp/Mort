# Stripe Sandbox Setup

1. Use a Stripe test-mode account and confirm Connect is available for the intended platform model and country.
2. Set `MORT_STRIPE_MODE=sandbox`, `STRIPE_TEST_SECRET_KEY`, `STRIPE_TEST_PUBLISHABLE_KEY`, `STRIPE_TEST_WEBHOOK_SECRET`, `MORT_STRIPE_OPERATIONS_SECRET`, and `MORT_STRIPE_ALLOWED_REDIRECT_ORIGINS` only in Supabase Edge Function secrets.
3. Deploy all `stripe-*` functions to project `rakjydmgwwgtdislanbt`; keep `stripe-webhook` JWT verification disabled because it verifies Stripe signatures itself.
4. Register the deployed webhook endpoint and subscribe to the event list in `MORT_STRIPE_WEBHOOKS.md`.
5. Keep all database enablement flags false, run configuration and unauthorized probes, then enable sandbox onboarding/funding in a controlled QA window.
6. Use Stripe test identities, test payment methods, synthetic job records, and dedicated QA users only.
7. Run every `qa-stripe-*.mjs` test plus real provider flows and reconcile the resulting objects.

Never put test secrets in `.env.local`, Flutter dart-defines, screenshots, shell history, docs, or archives.
