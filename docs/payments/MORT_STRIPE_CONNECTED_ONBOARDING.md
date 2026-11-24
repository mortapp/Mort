# Stripe Connected Onboarding

The user starts payout setup from the earnings screen. The server validates the Supabase session, rate limit, role, environment, and runtime gates before creating a connected account or one-time Stripe-hosted Account Link. URLs must use approved HTTPS origins; expired links are regenerated server-side.

MORT displays only synchronized capability state: setup required, in progress, action required, restricted, or ready. A browser return is not proof of completion. `account.updated` must establish details/capability status, and the server rechecks transfer eligibility at money movement time. MORT does not collect bank account or identity fields itself.

The Accounts v2 candidate provisions recipient-only Express accounts for synthetic QA profiles and creates Stripe-hosted onboarding links with the same `recipient` configuration. It blocks live account and link creation rather than treating a MORT teen session, an app guardian link, or successful sandbox onboarding as provider approval. Use the [sandbox connector runbook](MORT_STRIPE_SANDBOX_CONNECT_WEBHOOK.md) for the snapshot destination and [Stripe's marketplace onboarding guide](https://docs.stripe.com/connect/marketplace/tasks/onboard) for the provider's v2 requirements.
