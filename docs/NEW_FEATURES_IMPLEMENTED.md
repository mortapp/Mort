# New Features Implemented

Status date: 2026-07-13

This document records implemented behavior, not a production-readiness claim.

## Guardian Mode

- Optional teen onboarding step with skip, invite, email, and code paths.
- Product defaults are false through a jurisdiction-ready policy layer.
- Settings status, resend, cancel, accept, unlink, privacy copy, and teen-controlled alert categories.
- Guardian approvals apply only when a job or future reviewed jurisdiction policy requests them.
- Guardian Safety Ping visibility and notifications use active links and teen preferences.
- Guardian activity uses RLS-backed connection/review/report data.

## Jobs and applications

- Eight-section real job draft/publish wizard.
- Category, summary, details, duration, workers, skills, equipment, physical requirements, proof, schedule, recurrence, timezone, urgency, approximate location, travel radius, environment, payment preference, age, supervision, verification, guardian preference, and safety notes.
- Server safety scanner, field validation, rate limiting, and idempotent client request IDs.
- Draft resume/delete, pause/resume, close, cancel, duplicate to safe draft, owner management, and status history.
- Teen keyword and category search, minimum pay, payment type, schedule, verification, guardian, environment, and sort filters.
- Saved jobs with unavailable-state cleanup.
- Structured eligibility and application errors.
- Viewed, accepted/rejected, withdraw, start, real proof, complete, and status timeline.
- QA job isolation from normal users.

## Profiles and trust

- Private custom avatars for teen, adult, guardian, and business-capable adult profiles.
- Initials fallback, replace/remove, signed display URLs, source signature checks, resizing, and metadata-stripping re-encode.
- Bio, availability, preferred categories, approximate area, goals, verification state, and real profile completion meter.
- Guardian linking is excluded from the completion score.
- Real adult/business verification request UI, private sanitized document, pending status sync, request history, admin moderation queue, and RLS.

## Community and operations

- Two-sided reviews after completion, one per side, pending moderation, and reporting.
- Notification center with read/read-all and role-aware navigation.
- Support topics, private ticket history, transactional submission, and server rate limit.
- RLS-backed activity history.
- Admin queue actions for reports, verification, jobs, support, and reviews.
- Private, idempotent proof upload with evidence-retention policy.

## Web/PWA

- Hosted Supabase only; no Docker or developer-PC runtime dependency.
- Web build disables native IAP and ads through compile-time flags.
- Safari-compatible gallery selection for proof, avatar, and verification surfaces.
- Native-only camera controls are not shown on web where unsupported.
- PWA manifest, icons, theme, service worker, redirects, and security headers are present.
- A 390x844 local browser check found no horizontal overflow or console errors on splash, sign-in, and protected-route guard screens.

## Verification summary

- Flutter format: clean.
- Flutter analysis: no issues.
- Flutter tests: 56 passed.
- Flutter release web build: passed.
- Expo reference app: TypeScript, lint, export, and 20/20 Expo Doctor checks passed.
- Feature-specific remote Guardian, job, application, proof, avatar, saved-job, review, verification, rate-limit, and old-project smoke suites passed.
- Secret scan passed with Flutter source included.

## Not completed

- Physical iPhone and real Safari device testing.
- TestFlight or native App Store build.
- Native RevenueCat purchase QA and App Store product approval.
- Native AdMob impression/reward QA.
- Native push permission and delivery QA.
- Interactive avatar crop positioning.
- Adult Pro analytics, dedicated business profile editor, guardian emergency-contact bundle, and rich admin evidence detail views.
- Final legal, privacy, parental/jurisdiction, teen labor, payments, moderation, retention, and App Store safety review.
