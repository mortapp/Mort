# MORT Provider Budgets and Alerts

Status: server enforcement implemented; provider dashboard configuration blocked.

## Implemented

- Atomic AI reservation checks per-user and global daily/monthly request limits.
- Global daily/monthly cost ceilings, model allowlist, input/output limits, concurrency ceiling, timeout, and circuit-breaker controls are server-owned.
- External AI stays disabled while budget values are zero or provider configuration is absent.
- Stripe has separate sandbox/live and operation-specific shutdown switches. All money-moving and live switches are off.
- File size/MIME/path rules and signed-URL rate limits constrain media cost and abuse.

## Owner Actions

1. Set hard provider-side OpenAI project budgets and spend alerts below the business-approved maximum.
2. Configure matching nonzero server budgets in Supabase private controls only after legal/privacy approval.
3. Configure Stripe balance, dispute, webhook failure, refund, and Connect capability alerts.
4. Configure Supabase database, function, Storage, egress, and auth-usage alerts available to the plan.
5. Route alerts to named primary/secondary owners and execute a test alert.
6. Record screenshots or exports, owner, threshold, date, and test receipt in the external tracker.

No real budget number belongs in public client code or this repository. This gate remains incomplete until dashboard evidence exists.
