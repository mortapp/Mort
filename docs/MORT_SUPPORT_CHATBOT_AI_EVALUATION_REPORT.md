# MORT Support Chatbot AI Evaluation Report

Date: 2026-07-29  
Final run: `c2b3645c-3e9a-4975-ae17-80b89272fa5c`

## Scope

The current external provider is disabled. This report therefore evaluates the
deterministic pre-provider classifier, provider eligibility gate, knowledge
citations, handoff behavior, and unsafe-authority protections. It does not claim
Anthropic answer quality was tested.

## Evaluation Set

The stored runner contains 150 concrete cases:

- 20 general-help cases, expected level 0
- 20 jobs/application/guardian cases, expected level 1
- 15 account and verification cases, expected level 1
- 15 payment/dispute cases, expected level 1
- 10 explicit human-handoff cases, expected level 1 and provider blocked
- 10 report/block cases, expected level 1
- 10 privacy/deletion cases, expected level 1
- 30 trust/safety and adversarial cases, expected level 2 and provider blocked
- 20 emergency/self-harm/violence/CSAM cases, expected level 3 and provider
  blocked

Adversarial cases include prompt injection, system/developer prompt requests,
service-role requests, database dumps, cross-user transcripts, grooming
secrecy, job PINs/codes, credentials, payment-card fields, and exact addresses.

## Iterations

1. Run `3d848d78-591a-4cad-8187-5147587a2546`: 146/150 passed. Failures found
   missing "kill me", "my guardian", verification, and account-deletion forms.
2. Run `cda9e4a2-1cac-4a50-b3d4-78d21bfc25d0`: 149/150 passed. One general case
   incorrectly expected a verification badge question to remain level 0.
3. Run `c77f7d6b-4697-43b5-a3da-a502d7e47e99`: 150/150 passed.
4. Final post-budget deployment run `c2b3645c-3e9a-4975-ae17-80b89272fa5c`:
   150/150 passed.

Remote endpoint QA separately caught PostgreSQL's different `\b` semantics for
PIN/CSAM/SSN/CVC/CVV. The database rules now use PostgreSQL word boundaries and
the full remote journey passed afterward.

## Grounding And Authority

- Hosted KB search returned real citation IDs, titles, and routes.
- Provider-disabled chat returned a stored deterministic answer with at least
  one approved citation.
- High-risk replies did not claim police or ambulance dispatch.
- Admin copilot output declared `human_staff_only` decision authority.
- Tool routes outside the allowlist returned an error.
- Human escalation created a real idempotent ticket ID and event record.

## Limits

- The 150 cases are a useful honest baseline, not comprehensive teen-safety
  certification.
- No external model, multilingual quality, long-conversation drift, jailbreak
  mutation corpus, or provider outage behavior was evaluated.
- Before provider activation, add model-specific normal/adversarial cases,
  multilingual teen phrasing, latency/error budgets, false-positive review,
  and human safety sign-off.

