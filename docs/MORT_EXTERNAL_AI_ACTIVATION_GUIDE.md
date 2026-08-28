# MORT External AI Activation Guide

Updated: 2026-07-29

Status: disabled and fail-closed

MORT Support currently uses deterministic triage, approved knowledge retrieval,
citations, guided actions, and human handoff. External model access must remain
disabled until every gate below is complete. A provider key alone is not
approval.

## Required Gates

1. Owner approval: record the approved use cases, model, regions, budget, and
   rollback owner.
2. Privacy/legal review: approve the vendor, DPA, subprocessors, retention,
   training controls, cross-border transfer, deletion, and minor-data handling.
3. Data minimization: confirm prompts exclude job PINs, exact addresses,
   identity documents, evidence, secrets, unrelated account data, and raw
   conversation history beyond the authorized bounded context.
4. Safety review: prohibit emergency dispatch claims, diagnostic mental-health
   claims, moderation decisions, identity decisions, hiring decisions, payment
   decisions, and legal or medical advice.
5. Cost controls: set per-user and global budgets, hard provider timeouts,
   bounded retries, model allowlists, and an owner-approved spend alert.
6. Security: place credentials only in Supabase Edge Function secrets; never in
   Flutter, web assets, `.env.local`, source archives, logs, or client responses.
7. Evaluation: run the complete deterministic suite plus model-specific
   multilingual, prompt-injection, mutation, false-positive, false-negative,
   timeout, 429, 5xx, unsafe-output, and provider-unavailable cases.
8. Human operations: establish staffed escalation ownership before exposing a
   model response that may require human follow-up.

## Activation Procedure

1. Create a provider-specific staging secret and allowlisted model in the
   Supabase server environment.
2. Keep the production provider flag disabled while staging evaluation runs.
3. Confirm unsafe input is classified before provider eligibility and unsafe
   output is rejected before persistence or display.
4. Confirm citations come only from approved MORT knowledge and the provider
   cannot invoke arbitrary tools or database operations.
5. Verify deterministic fallback for missing key, timeout, rate limit, provider
   error, budget exhaustion, and unsafe output.
6. Record the evaluation run, approvers, budget, model version, and rollback.
7. Enable only the approved environment. Monitor privacy-safe aggregate usage
   and incidents; do not log raw prompts or responses.

## Immediate Rollback

Disable the server-side provider flag and revoke the provider credential if
there is suspected data exposure, unsafe output, budget failure, model drift,
vendor incident, or loss of human escalation coverage. The deterministic path
and ticket creation must remain available during rollback.

