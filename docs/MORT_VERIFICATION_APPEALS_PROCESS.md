# MORT Verification Appeals Process

Status: implemented submission and restricted review path; staffing, service levels, and legal language remain to be approved.

## Eligibility

A user may appeal a rejected, suspended, or expired verification outcome. An appeal does not automatically restore marketplace access, change the verification level, or remove an account restriction.

## User Flow

1. The app displays the current status and a non-sensitive decision code.
2. The user submits a factual explanation of at least 20 characters.
3. `submit_identity_verification_appeal` creates a pending appeal and moves the verification to `appeal_pending`.
4. The user receives status updates without raw reviewer notes or evidence paths.
5. The user may provide additional permitted evidence only through the controlled verification upload route.

## Reviewer Flow

1. A verification reviewer or senior safety moderator opens the restricted appeal queue.
2. The reviewer checks the original decision, evidence metadata, risk signals, duplicate flags, and relevant policy version.
3. Raw evidence is accessed only when necessary through a reasoned, short-lived grant.
4. The reviewer records approve, request-information, reject, or suspend through `admin_review_identity_verification`.
5. The RPC updates the profile eligibility status, resolves the pending appeal, writes an audit event, and sends a private notification.

## Fairness Rules

- Do not reject solely because a teen lacks a school ID; assess approved alternatives.
- Do not treat automated duplicate, image, or risk signals as final decisions.
- Use a reviewer who was not the original decision maker when staffing permits, especially for suspension or fraud allegations.
- Provide a meaningful, non-accusatory reason and a correction path.
- Never publish allegations, school details, ID details, or appeal content.

## Escalation

Child-safety, impersonation, coercion, exploitation, or active threats move to the restricted incident process without replacing the verification appeal. Immediate danger guidance directs the user to local emergency services; MORT is not an emergency dispatcher.

## Operational Work Remaining

Define appeal service levels, conflict-of-interest assignment, second-review thresholds, accessibility and language support, regulator complaint paths, reviewer training, quality sampling, and jurisdiction-specific notices before real-user launch.
