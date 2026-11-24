# MORT synthetic incident tabletop — 2026-11-22

**Classification:** Tabletop/documentation exercise only; no live drill was executed. No live incident, user, identity document, message, location, payment, provider, or safety evidence was used. No production or hosted QA control was changed.

**Exercise ID:** `SYNTH-2026-11-22-ACCOUNT-DELETION-FAILURE`

**Scenario:** A synthetic account-deletion worker deployment is missing its server configuration and returns the fail-closed `503 deletion_worker_not_configured` response. A second synthetic signal reports that a deletion request remains queued after a failed attempt. The exercise tests containment and escalation, not actual deletion.

**Environment:** Repository/replica reasoning only; production project `jxbnrkasktbhtiujkhay` and hosted QA project `ckcxakhxqlkhppsxxjhv` were not invoked by the exercise.

## Objectives and expected controls

| Objective | Expected control | Result |
|---|---|---|
| Detect unsafe configuration | Refuse module-load failure; return `503 deletion_worker_not_configured` before secret comparison or data access | PASS by source and package regression; hosted probe pending QA credentials |
| Prevent unauthorized invocation | Require `x-mort-deletion-secret` and constant-time comparison | PASS by source/package review; hosted `401` probe pending QA deployment |
| Protect users during uncertainty | Keep deletion request state idempotent; do not manually delete rows or retry with unknown credentials | PASS as procedural control |
| Preserve evidence safely | Record only redacted trace/error code and request metadata; never paste private content or secrets | PASS as runbook control |
| Recover safely | Deploy only reviewed package to isolated QA first; production command remains unexecuted | PASS as release procedure |
| Maintain child-safety boundaries | Escalate any safety signal to a verified adult operator; do not invent a contact, incident, or legal report | PASS as operational rule; designated adult operator remains external blocker |

## Synthetic timeline

| Time | Inject/event | Expected response | Actual tabletop response |
|---|---|---|---|
| T+00 | QA deployment is proposed with incomplete worker configuration | Stop before data access; return fail-closed configuration code | Accepted; no deployment performed |
| T+05 | Synthetic request lacks worker secret | Reject with `401`; do not claim hosted evidence | Accepted as required behavior; hosted probe remains pending |
| T+10 | Synthetic request appears stuck after an attempted worker failure | Inspect redacted status/error and attempt count; use idempotent retry only after configuration is corrected | Accepted; no database mutation performed |
| T+15 | Operator asks whether production can be smoke-tested | Refuse real deletion test; require approval, QA evidence, and non-destructive production check | Accepted; production untouched |
| T+20 | Safety escalation is mentioned in the scenario | Use child-safety runbook and verified adult escalation path; do not create a fake report or contact | Accepted; no incident created |

## Decisions and unresolved dependencies

The worker packaging correction is implemented and locally verified on PR #125. Hosted QA deployment and authorized synthetic end-to-end execution remain blocked by owner-controlled QA deployment authorization and server-only QA secrets. A verified adult child-safety contact, staffed on-call coverage, and an authorized restore target remain operational dependencies; this tabletop does not close those gaps.

## Evidence and follow-up

- Source/package evidence: `scripts/qa-account-deletion-package.test.mjs` — 6/6 passed.
- Deployment procedure: `docs/operations/ACCOUNT_DELETION_DEPLOYMENT_RUNBOOK.md`.
- Incident procedure: `docs/MORT_INCIDENT_RUNBOOK.md`.
- Child-safety escalation boundary: `docs/CHILD_SAFETY_OPERATIONAL_ESCALATION.md`.
- Follow-up owner dependency: provide protected QA deployment credentials and synthetic fixture authorization; then record real QA response codes and cleanup results separately.
