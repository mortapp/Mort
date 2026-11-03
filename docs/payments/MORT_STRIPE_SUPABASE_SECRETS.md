# Stripe Supabase Secrets

**Production Supabase project:** `jxbnrkasktbhtiujkhay`  
**Deleted project:** `rakjydmgwwgtdislanbt` — never use.

Server-only secret names (names only; never commit or print values):

- `MORT_STRIPE_MODE`
- `STRIPE_TEST_SECRET_KEY`
- `STRIPE_TEST_PUBLISHABLE_KEY`
- `STRIPE_TEST_WEBHOOK_SECRET`
- `STRIPE_TEST_CONNECT_WEBHOOK_SECRET`
- `STRIPE_LIVE_SECRET_KEY`
- `STRIPE_LIVE_PUBLISHABLE_KEY`
- `STRIPE_LIVE_WEBHOOK_SECRET`
- `STRIPE_LIVE_CONNECT_WEBHOOK_SECRET`
- `MORT_STRIPE_OPERATIONS_SECRET`
- `MORT_STRIPE_ALLOWED_REDIRECT_ORIGINS`

Do not set or rotate secrets until the correct handlers are deployed and an approved secure secrets workflow is available. Never put secret values in `.env.local`, Flutter source, dart-defines, committed files, CI logs, release archives, screenshots, or chat.

## Secret separation

- Platform PaymentIntent webhook and Connect webhook use separate endpoint-specific signing secrets.
- Sandbox credentials must be test-mode credentials only.
- Live credentials must not be present in a sandbox configuration.
- Publishable keys are not secret, but must still match the selected environment.
- Never expose secret keys or webhook signing secrets to clients.
- Never assume an old Stripe endpoint signing secret can be recovered from endpoint metadata.

## Read-only preflight

The preflight may inspect remote secret names only. It must not print raw CLI output or secret values. The expected project ref is `jxbnrkasktbhtiujkhay`. A missing secret name is a blocker, not a reason to enable a payment feature.

Local operator credentials such as `SUPABASE_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD` must remain in a protected shell or secret manager and must never be recorded in evidence.

## Operational rule

Do not redirect Stripe endpoints or enable payment controls until the corresponding handler, database contract, endpoint-specific secret, and integration tests have been verified. No production payment activation is authorized by this document.
