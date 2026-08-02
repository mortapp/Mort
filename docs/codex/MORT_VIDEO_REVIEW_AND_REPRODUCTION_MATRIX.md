# MORT 0.9.13 Video Review and Reproduction Matrix

Reviewed on 2026-08-02 from unmodified private copies under the ignored
`qa/recordings/2026-08-02` directory. The recordings and extracted frames are
not source or release artifacts.

| Recording | Observed evidence | Reproduced/root cause | Resolution | Verification |
| --- | --- | --- | --- | --- |
| A `Recording_20260801_235059.mp4` | Google identified the raw Supabase project host. A completed Teen profile later showed the generic `Your profile was not saved` message. | `ProfileSetupScreen` was reused by onboarding and settings. Both paths called `save_my_onboarding_profile`, which rejects completed onboarding as `onboarding_already_completed`; the client did not map that code. Multiple writes also allowed partial profile state. | Added caller-bound atomic `save_my_profile_setup_v2`, stable idempotency IDs, field-coded errors, encrypted draft recovery, and correct settings return navigation. | Hosted profile setup/edit/replay/immutable-role QA passed. Profile persistence and video hardening tests passed in the 276-test Flutter suite. Credentialed profile edit was not manually repeated on the emulator. |
| B `Recording_20260801_235508.mp4` | Adult setup exposed Teen availability, work-area, category, and goals content, creating dense and misleading role screens. Google again showed the raw Supabase host. | Shared fields and cards were rendered without a complete role partition. | Teen-only work preferences are now Teen-only. Adults receive account/business/scheduling/service fields. Guardians do not receive Teen job preferences. | Role-source and widget contracts passed. Exact credentialed role onboarding was not manually repeated on the emulator. |
| C `Recording_20260802_000547.mp4` | Job creation showed steps 1, 2, 4, 5, 6, and 8; category selection was long; duration validation and draft behavior were inconsistent; closed-pilot copy could overstate publication. | Step labels were not sourced from one authoritative flow and the server wrapper did not expose field-coded validation/publication state. | Added a single eight-step enum, searchable category sheet, field-level validation/focus, encrypted per-user drafts, stable request IDs, and truthful `draft`, `open`, `pending_review`, or `not_open` state. | Hosted job hardening and lifecycle QA passed, including real draft/open state and coded duration/ZIP/proof errors. Flutter tests passed. Credentialed end-to-end job creation was not manually repeated on the emulator. |

## Disposition

- Video profile failure: fixed and hosted-verified.
- Role-content mismatch: fixed and automatically verified.
- Job numbering/draft/publication issues: fixed and hosted-verified.
- Raw Supabase OAuth branding: reproduced on the final emulator flow and remains
  externally gated by custom-domain/DNS/provider configuration.
