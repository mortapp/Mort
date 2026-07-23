# Frontend Feature Audit

Date: 2026-07-08

## Implemented Or Wired

- Supabase Auth sign-in/sign-up/sign-out
- DOB/role onboarding
- teen/adult/guardian/admin navigation
- job feed, job detail, post job, applications
- guardian approval flow
- accepted-job messaging with safety scanner RPC
- reports/blocking
- proof upload metadata and private storage path flow
- business verification flow
- admin queues for jobs/users/reports/support/verification
- payment preference-only flow
- push token registration and notification screens
- monetization hub, paywall, ad-free, restore, manage, debug
- username settings backed by Supabase RPCs
- profile style pack, username token, and job boost screens
- ad preference settings and guarded ad slots

## Partial

- Saved job folders have backend helpers but no full saved-jobs screen yet.
- Profile theme settings have backend helpers and preview screen; full profile renderer is still partial.
- Rewarded ads are guarded/disabled until native EAS testing and policy review.
- RevenueCat products/offering prices need dashboard/App Store setup.

## Coming Later

- full portfolio CRUD
- reviews/reputation
- Hustle Academy content library
- admin flagged-message queue UI
- real RevenueCat webhook entitlement sync
- live AdMob interstitial/native formats
