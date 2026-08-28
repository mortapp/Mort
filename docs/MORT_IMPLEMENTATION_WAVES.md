# MORT Implementation Waves

The 1,891 accepted registry records are sequenced by dependency and risk. A wave assignment is not an implementation claim.

| Wave | Records | Current meaning |
| --- | ---: | --- |
| Wave 0 - existing completion | 16 | Evidence-backed unread and proof-review capabilities completed in this pass |
| Wave 1 - safety and core marketplace | 576 | Safety, accessibility, privacy, reliability, applications, messaging, and lifecycle foundations |
| Wave 2 - repeat value | 417 | Teen history, adult repeat hiring, profiles, healthy progress, and notifications |
| Wave 3 - MORT differentiation | 313 | Optional Guardian Mode, discovery, trust, and bounded AI assistance |
| Wave 4 - business and community scale | 234 | Community utility, accountable operations, and privacy-preserving analytics |
| Wave 5 - sustainable growth | 85 | Balanced neighborhood growth, referrals, and partnerships |
| Wave 6 - advanced platform capability | 250 | Optional monetization, payment education, onboarding depth, and native iOS capability |

## Wave 0 Evidence

- Remote migrations `20260717082454_feature_expansion_unread_proof_review.sql` and `20260717092233_feature_expansion_proof_review_fk_index.sql`
- SwiftUI models, repositories, routes, unread badges, thread read behavior, proof review screen, and contract tests
- Flutter models, repositories, routes, unread badges, thread read behavior, proof review screen, and contract tests
- Remote 15/15 feature-expansion QA, 30/30 multi-user isolation QA, private storage checks, abuse checks, concurrent read-cursor checks, and 25-request load sanity

## Wave Entry Rules

1. Finish existing incomplete authority or recovery before adjacent novelty.
2. Back up before schema change; use additive migrations and checked contracts.
3. Define free safety/accessibility/privacy paths and abuse cases.
4. Implement loading, empty, error, success, cancellation, restricted, offline, and accessible states where applicable.
5. Verify RLS/storage with isolated cross-user accounts.
6. Require Mac/iPhone/TestFlight, legal, dashboard, and operations gates where the registry marks them.

The highest-priority individual records are in `MORT_FEATURE_PRIORITY_SCORECARD.md`; the complete dependency-aware assignments are in `MORT_FEATURE_IMPLEMENTATION_WAVES.md` and the registry JSON/CSV.
