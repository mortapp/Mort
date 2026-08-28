# MORT Complete Current-State Audit

Audit date: 2026-07-17

## Executive Result

MORT is a substantial multi-client product with a hosted Supabase backend. It is not production-ready. The native SwiftUI source is prepared for a first Mac/Xcode compile, Flutter Web is the currently executable free iPhone preview path, and the Expo app remains as a legacy reference. No Mac compile, XCTest run, physical iPhone test, TestFlight run, or App Store review occurred in this Windows pass.

No existing P0 defect was found. Two P1 completion gaps were confirmed and fixed: server-authoritative participant unread state and participant-authorized proof review with a completion gate. The exact 1,891-feature registry contains 16 evidence-backed records for this work and 1,875 accepted roadmap records.

## Inventory

| Surface | Audited state |
| --- | --- |
| SwiftUI | 83 app Swift files; 9 unit-test files with 36 test methods; 1 UI-test method |
| Flutter | 78 app Dart files; 10 test files with 60 test declarations |
| Expo reference | 114 TypeScript/TSX source files retained |
| Supabase | 40 additive migration files; 7 Edge Function directories; hosted project `rakjydmgwwgtdislanbt` |
| Feature registry | 1,891 accepted; 24 duplicate candidates removed; 24 unsafe/invalid candidates rejected |
| Current parity | 54 of 60 audited Flutter-to-Swift units have concrete Swift source, or 90.0% source parity |

## Completed Foundations

- Supabase Auth, DOB age gate, role onboarding, and role-aware navigation exist.
- Teen and adult job workflows, applications, conditional guardian approval, messages, reports, block, Safety Ping, reviews, verification, private uploads, notification records, support, admin queues, and preference-only payment records have backend contracts.
- Safety controls remain free. Guardian Mode remains optional by default.
- RevenueCat and AdMob code fail closed or degrade honestly when native SDK configuration is unavailable. Flutter Web disables native purchases and ads rather than simulating success.
- Private storage uses authenticated paths and short-lived signed URLs where applicable.
- The backend is hosted and does not require Docker, localhost, this Windows PC, or a manually running server for deployed use.

## P1 Work Fixed In This Pass

### Conversation unread state

The old source had no durable per-participant read cursor, so an accurate unread badge could not be claimed. Migration `20260717082454_feature_expansion_unread_proof_review.sql` adds a participant cursor, a checked mark-read RPC, a thread-list RPC that excludes the current user's own messages, participant isolation, and monotonic concurrent updates. SwiftUI and Flutter now consume the contract and mark a thread read on authorized use.

### Proof review and completion authority

The old clients could submit private proof but had no dedicated poster review contract. The migration adds proof decision state, an append-only review event trail, approve/resubmission/reject actions, stale-submission protection, private decision notifications, and a database completion gate. SwiftUI and Flutter now expose participant-authorized preview and review actions.

## Honest Incomplete Work

- Portfolio remains unavailable because no shared portfolio schema/RPC has been approved.
- Adult analytics remains unavailable because no privacy-reviewed adult-facing analytics contract exists.
- APNs device persistence, provider signing, and real-device delivery remain incomplete.
- Native RevenueCat purchases, Customer Center, AdMob placements, UMP, and ATT require Mac/device/dashboard verification.
- Several Flutter admin detail routes explicitly state that evidence timeline and action-note UX remain later work.
- Self-service deletion still requires final retention, legal, and operational policy review.
- Byte-level upload progress is not complete across every client.
- Jurisdiction rules need counsel-reviewed coverage before real teen work expands by state or locality.

## Source Scan Interpretation

The audit searched source for `TODO`, `FIXME`, `HACK`, placeholder/mock/fake/demo markers, `Coming Later`, unavailable states, fatal errors, localhost, and disabled actions. Most `unavailable` matches are legitimate network or configuration recovery UI. The remaining intentional coming-later surfaces are named above. Localhost references are confined to local QA and preview-serving scripts with explicit target guards.

## Release Gates

1. Compile in the current Xcode version and run all Swift unit/UI tests on macOS.
2. Test auth, permissions, media, notifications, links, purchases, ads, accessibility, interruption, and recovery on physical iPhones.
3. Complete TestFlight internal testing and crash/telemetry review.
4. Obtain legal review for youth labor, privacy, consent, retention, verification, advertising, and marketplace claims in each launch jurisdiction.
5. Staff moderation, appeals, incident response, support, and escalation coverage before inviting real users.

The Supabase leaked-password advisor item is not a code defect. It is classified as **DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT** because the current Free plan cannot enable the HaveIBeenPwned control. When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors.
