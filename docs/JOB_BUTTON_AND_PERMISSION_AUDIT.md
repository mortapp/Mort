# Job Button and Permission Audit

Audit date: 2026-07-13

## Method

The audit followed active `GoRouter` routes from role dashboards into their screen callbacks, repository methods, RPCs/table operations, loading guards, success feedback, error translation, and RLS. Flutter analysis, widget/unit tests, isolated remote users, and a 390x844 web viewport were used to verify the highest-risk paths.

## Fixed active actions

| Surface | Action | Real implementation and permission boundary |
| --- | --- | --- |
| Teen job detail | Apply | Eligibility RPC plus `submit_job_application`; repeat taps blocked; structured reason copy; sticky SafeArea CTA. |
| Teen job detail | Save/unsave | `saved_jobs` persistence with owner RLS and unavailable-job cleanup. |
| Teen applications | Withdraw/start | `update_application_status_v2` validates teen ownership and state. |
| Teen applications | Upload proof | Gallery works on web, camera only offered natively, image is sanitized, private object plus transactional `submit_application_proof`. |
| Adult job wizard | Save/publish | Idempotent `save_job_draft_or_publish`, server scanner and validation, real navigation/result state. |
| Adult manage jobs | Pause/resume/close/cancel/duplicate | `manage_job` validates owner and current state; busy state prevents repeats. |
| Adult applicants | View/accept/reject/complete | Poster-only transition RPC; unrelated adult denial is remotely tested. |
| Adult verification | Submit/resubmit | Private sanitized upload plus idempotent `submit_business_verification`; pending request prevents duplicates. |
| Guardian dashboard | Links/permissions | Real Guardian Mode connection and teen-controlled preference UI. |
| Guardian dashboard | Safety pings | Guardian-scoped RLS screen; no admin repository reuse. |
| Guardian approvals | Approve/reject | Linked-guardian and requested-job checks in transition RPC. |
| Profile | Add/replace/remove avatar | Private Storage, randomized path, signed URL, rollback, and owner RLS. |
| Reviews | Submit/report | Completed participant check, one per side, pending moderation, report RLS. |
| Notifications | Read/read all/open | Recipient RLS and role-aware routes. |
| Support | Submit/history | Transactional RPC, private ticket RLS, five-per-day server limit. |
| Admin queues | Reports/verifications/jobs/support/reviews | Admin RLS, table-specific valid status action, busy guard, refresh, and success/error state. |

## Original permission repair

The application failure came from an insert-with-RETURNING RLS snapshot mismatch, not a missing guardian. Direct inserts are now closed and the structured application RPC owns validation and insertion. The UI no longer reduces all application failures to `You do not have permission to do that.`

## UI state checks

- Primary mutations use `_busy` or equivalent state to prevent repeat taps.
- Validation failures remain on the current screen and preserve entered content.
- Success paths show a toast and refresh or navigate to real persisted data.
- Empty, loading, error, and retry states exist on active list screens.
- Flexible schedules render `Flexible schedule`; exact schedules render actual values.
- Guardian badges are hidden when the job preference is false.
- Mobile job application and proof actions use SafeArea-aware placement and scrolling.
- Ad and purchase widgets are disabled by web build defines and do not execute native SDK paths in the PWA.

## Known inactive surfaces

The router still contains honest Coming Later screens for Adult Pro analytics, a dedicated business-profile editor, guardian emergency contacts, and rich admin evidence detail pages. They are not used to claim feature completion. Admin moderation actions remain available on the real queue screens.

`mort_screens.dart` also retains older public legacy job/application widget classes that are no longer referenced by active routes. Their disabled controls are unreachable; active teen and adult routes use `teen_job_screens.dart`, `application_screens.dart`, and `job_screens.dart`. Removing those legacy classes is a later cleanup, not a functional dependency.

## Test result

`flutter analyze` passed with no issues. `flutter test` passed 56 tests. Remote job/application/guardian/proof/verification/RLS suites passed. Physical iPhone keyboard, camera permissions, photo picker permissions, and Safari toolbar behavior still require manual device testing.
