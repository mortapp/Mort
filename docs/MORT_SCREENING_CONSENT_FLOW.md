# MORT Screening Consent Flow

Status: product and legal design draft. No consumer report is requested by the current app.

## Preconditions

1. Counsel approves the exact screening purpose, eligible users, timing, jurisdiction rules, and provider.
2. The provider contract and server integration pass security and privacy review.
3. MORT can determine whether the requesting party has a permissible purpose.
4. Required disclosure and authorization documents have immutable versions.

## User Flow

1. Explain that enhanced screening is separate from identity verification and does not guarantee safety.
2. Show the stand-alone screening disclosure without Terms, liability releases, marketing, safety promises, or unrelated acknowledgements.
3. Offer the current legally reviewed Summary of Rights and provider/privacy information separately.
4. Show report scope, purpose, requesting entity, whether ongoing reports are contemplated, expected timing, and support/dispute access.
5. Require an unchecked affirmative authorization control and typed/signed confirmation where approved.
6. Record document version, locale, timestamp, user ID, purpose, jurisdiction context, and consent receipt on the server.
7. Let the user cancel before procurement without creating a false completed-screening state.
8. The server certifies approved prerequisites to the provider and requests only the authorized report.

## Result Handling

- Raw reports stay in restricted server storage or at the provider.
- The client receives only `not_started`, `consent_required`, `pending`, `review`, `clear_under_current_policy`, `dispute_pending`, `expired`, or a similarly counsel-approved status.
- A result that may affect eligibility enters human review and, when applicable, pre-adverse-action flow.
- Consent withdrawal stops future procurement where legally and contractually possible; it does not erase an active legal hold or completed decision record automatically.

## Accessibility And Youth Rules

The flow must support screen readers, keyboard navigation, text scaling, plain language, translation review, document download, and a no-time-pressure path. Do not ask teens for adult background-screening consent through this flow. Any future minor screening requires a separate legal and ethical decision.

## Failure States

Provider outage, identity mismatch, incomplete consent, unsupported jurisdiction, and stale policy version must block procurement and return a truthful next step. The app must never synthesize a pass, badge, or report when the provider is unavailable.
