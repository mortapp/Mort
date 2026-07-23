# MORT Mutual Trust and Real-World Safety Results

## Status boundary

The old Supabase project `rakjydmgwwgtdislanbt` now contains the additive mutual identity and real-world safety backend and passed the remote checks listed here. Flutter Web compiles and Swift source passes static verification.

MORT is not being called production-ready. Identity verification does not guarantee safety. Background checks do not guarantee safety. Safety tools do not guarantee safety.

Not completed in this environment:

- automated identity-provider adjudication
- live liveness or document-authenticity checks
- physical document capture testing
- native Swift compilation
- physical iPhone testing
- TestFlight testing
- trained moderation operations
- legal, privacy, youth-work, screening, emergency-disclosure, or App Store approval

## Implemented architecture

- Mandatory server-owned identity states and levels gate publishing, applying, job-participant messaging, exact-location release, proof, review, and other marketplace actions.
- Adults use government-ID, ownership-selfie, and private address-evidence routes. Raw evidence is private and vendor adjudication is still required for automated authenticity/liveness/address outcomes.
- Teens have school-photo-ID, government-ID, verified-school-account, approved-program, and manual-exception routes. School name, student number, and raw evidence stay outside public profile payloads.
- Guardian Mode remains optional and separate from identity verification. A verified teen without a guardian can use ordinary marketplace flows.
- Safety Circle is optional, permission-specific, and does not grant messages, earnings, identity documents, profile editing, impersonation, or unrestricted location history.
- Job participants independently confirm a versioned Mutual Safety Agreement before work starts. Material term or restricted-location changes invalidate prior confirmation.
- Exact job addresses are separate from verified home addresses and use accepted-participant release stages.
- Temporary location sharing is explicit, visible, job-bound, stoppable, and expiring. The Flutter web experience uses coarse-area sharing.
- Arrival handshake uses short-lived single-use codes and an independent person-match confirmation. It does not exchange identity documents.
- Either participant can report, block, preserve evidence, use safety cancellation, and receive participant-safe incident status.
- Sexual adult-minor content and critical threats are blocked from the ordinary thread, stored as restricted evidence, and escalated to human-review incident records.
- Incident evidence uses hashes, metadata-only manifests, reasoned short-lived access, audit events, retention metadata, and preservation locks.
- Restricted admin queues use specialized safety roles. Generic support/admin roles do not inherit identity or incident-evidence access.
- Reviews use blind reveal plus moderation; serious private safety feedback is separate from public reputation content.

## Remote migrations

Applied and aligned:

1. `20260717161125_mutual_identity_verification.sql`
2. `20260717161132_mutual_trust_real_world_safety.sql`
3. `20260717193747_trust_safety_evidence_manifests.sql`
4. `20260718024657_allow_rls_policy_predicates.sql`
5. `20260718024844_fix_identity_evidence_storage_policy.sql`
6. `20260718030325_protect_registered_incident_evidence_objects.sql`
7. `20260718040458_fix_mutual_safety_job_word_boundaries.sql`

`npx supabase migration list --linked` showed local and remote alignment through `20260718040458`. A final `npx supabase db push --linked --dry-run` returned `Remote database is up to date.`

## Bugs found and fixed

1. Deprecated `auth.role()` policy checks were replaced with current role/JWT-safe patterns.
2. Private address re-verification hashes no longer include or expose exact residential address in ordinary agreement state.
3. Identity and incident evidence manifests now allow authorized metadata discovery without leaking storage paths.
4. Private RLS predicate helpers received the minimum execute grants required for policy evaluation.
5. Identity Storage policy nested-RLS failure was replaced with private checked predicates.
6. Registered incident evidence can no longer be deleted by the submitting participant.
7. Business trust submission no longer changes the separate mandatory personal identity state.
8. Blocked message raw evidence no longer rolls back with the ordinary placeholder message transaction.
9. QA preservation correctly validates server-side object survival after a denied client deletion.
10. The new job-risk trigger no longer matches `roof` inside `proof`; real roof work remains prohibited.
11. Legacy lifecycle tests now perform the required two-party Safety Agreement confirmation.
12. Blind-review QA now matches the implemented reveal-plus-moderation boundary.
13. Review reports now use `submit_safety_report` rather than a closed direct table insert.
14. Shared QA teardown now removes only the current run's restricted dependencies before Auth deletion; one stale QA user from an earlier failed run was removed.
15. The guarded stale-QA utility no longer forces `process.exit()` while Supabase async handles are open, avoiding a Windows libuv shutdown assertion.

## QA results

- Dedicated mutual-trust suites: 19/19 passed in one consolidated run.
- Required scenarios: all 30 passed, including unverified action blocks, guardian-independent teen access, document isolation, alternative teen evidence, forgery denial, address privacy, Safety Circle limits, blocking, preservation, replay rejection, sexual/threat controls, no-penalty safety cancellation, admin access audit, incident isolation, expiration, appeals, duplicate evidence, public school-data exclusion, and no global guardian requirement.
- Old-project remote smoke: passed, including 74 required table checks, six private buckets, migration history, no mobile service-role reference, and send-push unauthorized/authorized checks.
- Job lifecycle: passed.
- Job applications/proof transitions: passed after the Safety Agreement and `proof`/`roof` checks were aligned.
- Feature expansion: 15/15 passed, including proof authorization, stale-proof denial, append-only audit, unread state, concurrency, and 25-call load sanity.
- Complete multi-user isolation: 30/30 passed; the Flutter wrapper repeated the same 30/30 hosted-data checks successfully.
- Review, avatar Storage, business verification, optional guardian, and saved-job suites: passed.
- `qa-old-project-rls.mjs`: not rerun because its retired seeded credential variable `MORT_REBUILD_TEST_PASSWORD` is not present. No password was invented. The fresh-user 30/30 isolation suite is the current authoritative RLS run.
- Stale feature-QA cleanup: one account removed; subsequent checked teardowns completed cleanly.

## Build and static results

- `flutter pub get`: passed; 29 newer package versions are incompatible with current constraints and were not force-upgraded.
- `dart format lib test`: passed; 91 files, zero changes.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 60/60.
- `flutter build web`: passed; output at `flutter_mort/build/web` and Wasm dry-run succeeded.
- `node .\Scripts\generate-xcode-project.mjs`: passed; 85 app sources, 9 unit-test sources, 1 UI-test source.
- `.\Scripts\static-audit.ps1`: passed; no local Swift secrets, env files, DerivedData, Pods, or build output.
- Swift was not compiled because this Windows environment does not provide Xcode.

## Registry result

- Accepted records remain exactly 1,891.
- All category quotas remain exact.
- Accepted exact/normalized and semantic near-duplicates: zero.
- 45 generic roadmap records were replaced across nine topics with mutual identity, harassment/sexual safety, threats/coercion, safe first meetings, verification review, incident evidence, location privacy, and optional support capabilities.
- Validation passed with 61 evidence-backed implementation claims.
- Implementation audit retained 61 claims and downgraded zero.

## Advisor result

- Performance WARN/ERROR findings: zero.
- Security errors: zero.
- Security warnings: 84.
- Warning breakdown: 82 authenticated callable `SECURITY DEFINER` RPCs, one anonymous callable minimized public trust-badge RPC, and one leaked-password setting.
- The callable RPC warnings require continuing contract review; they are not automatically dismissed. Current remote QA verified caller, role, ownership, participant, isolation, forgery, and replay boundaries for the workflows in this pass.
- Leaked-password protection is **DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT**, not an unresolved code bug. No paid plan change was made.

## External work still required

### Verification vendor

- document authenticity and expiration
- live selfie/liveness and ownership match
- address validation
- duplicate identity/document detection across vendor records
- provider retention/deletion and breach terms
- safe fallback and outage behavior

### Legal and policy review

- FCRA and state/local screening applicability, consent, dispute, and adverse action
- youth work, curfew, category, wage, and jurisdiction rules
- identity/biometric/privacy notices and retention
- child sexual safety reporting and NCMEC procedures
- emergency disclosure, preservation, and law-enforcement request handling
- moderation due process, appeals, false reports, and discrimination controls
- App Store privacy labels, safety disclosures, terms, and age-rating review

### People and operations

- trained verification reviewers
- child-safety specialists and incident managers
- 24/7 or clearly bounded emergency escalation coverage
- moderator conflict-of-interest and supervisory approval process
- legal-request reviewer and counsel channel
- victim-support resources and accused-user appeal handling

### Device and release validation

- Xcode build and unit/UI tests on a Mac
- physical iPhone document and selfie capture
- camera/photo permissions and metadata behavior
- APNs, Safety Ping, check-in, and background notification behavior
- arrival handshake under poor connectivity and real clock skew
- TestFlight privacy, crash, performance, accessibility, and abuse testing

## Warning before real users

Do not admit real users or accept real identity evidence until a verification vendor, final retention jobs, trained restricted staff, emergency procedures, legal review, production monitoring, Mac/Xcode compilation, physical iPhone testing, and TestFlight validation are complete. The current system reduces specific risks; it cannot establish that a person is harmless or guarantee a safe encounter.
