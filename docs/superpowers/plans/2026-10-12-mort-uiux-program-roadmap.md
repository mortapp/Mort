# MORT UI/UX Program Implementation Roadmap

**Approved product spec:** `docs/superpowers/specs/2026-10-12-mort-mobile-ui-ux-design.md`

**Planning base:** `mortapp/Mort` `main` at `cfb1080b9fc9cbccd3a271536c72575f8c4cb72a`

**Active client stack:** Expo Router / React Native / TypeScript / Supabase. Do not revive or rebase work onto historical Flutter-only paths unless a later plan explicitly calls for migration work.

## Goal

Turn the approved MORT mobile UI/UX specification into a production implementation without doing a single giant rewrite, while keeping each subsystem independently reviewable, testable, and reversible.

## Delivery strategy

Implement in dependency order. Every plan ends with focused QA, `npm run check`, `npm run lint`, and the relevant existing Supabase/QA suites before the next plan begins. Do not combine plans into one mega-commit or one giant pull request.

## Program-wide locked constraints

- Teen tabs: `Home · Explore · Inbox · Profile`.
- Adult/business tabs: `Home · Explore · + · Inbox · Profile`.
- Home is the marketplace; no consumer-facing Dashboard.
- Palette: white, black, silver, gray/charcoal. No blue or purple brand accent.
- Light mode primary; dark mode first-class from day one.
- One visually dominant primary action per state.
- Flat MORT job fee: `$2.97` per completed job.
- Minimum job pay: `$10.00`.
- Finish-PIN problem auto-release window: `48 hours` absent a legitimate dispute.
- Adult payment-method verification authorization: `$1.25`, released/voided after verification.
- Share Status post-job grace period: `30 minutes`.
- Post-job chat default writable window: `24 hours`, extended while a linked unresolved case remains open.
- Exact job address is not permanently exposed; only privacy-safe area/distance remains after completion.
- Safety criticality outranks active-job, money/security, actionable work, discovery, Motion, and marketing.
- Marketing is opt-in and never suppresses operational/safety notifications.
- MORT Quiet Hours never suppress active-job high/critical safety inside the app.
- Do not claim silent 911 dialing, indefinite payment authorization, or OS-notification bypasses the platform cannot guarantee.

## Plan sequence

### Plan 01 — Foundation, design system, shared shell, canonical navigation

**Purpose:** Replace the current neon/dark-first shell and role-specific tab drift with the approved monochrome design tokens, reusable interaction primitives, light/dark theme infrastructure, and canonical teen/adult navigation.

**Primary existing files:**
- `lib/theme.ts`
- `components/DesignSystem.tsx`
- `components/Button.tsx`
- `components/Card.tsx`
- `components/Screen.tsx`
- `components/Text.tsx`
- `app/_layout.tsx`
- `app/teen/_layout.tsx`
- `app/adult/_layout.tsx`
- `app/teen/feed.tsx`
- `app/teen/messages.tsx`
- `app/adult/dashboard.tsx`
- `app/adult/messages.tsx`

**Exit gate:** New shell compiles with canonical tabs, theme is monochrome/light+dark capable, legacy routes redirect safely, and no primary consumer path uses the superseded `Jobs/Applies/Chat/Safety` or `Jobs/Post/Review/Chat/Verify/Profile` tab bars.

---

### Plan 02 — Domain model and lifecycle contracts

**Purpose:** Make the backend/domain model capable of representing the approved UX before feature screens depend on it.

**Primary files:**
- `types/domain.ts`
- `types/supabase.generated.ts`
- `lib/data.ts`
- new focused modules under `lib/jobs/`, `lib/payments/`, `lib/safety/`, `lib/reliability/`
- new additive migrations under `supabase/migrations/`
- focused QA scripts under `scripts/`

**Core contracts:**
- canonical job/application statuses and event timeline
- duration/schedule/scope/tool requirements
- privacy-safe location + protected exact destination fields
- start/finish PIN metadata without storing plaintext PINs
- job evidence stages/visibility
- safety check-ins/incidents/share-status state
- payment funding state, gross/fee/net values
- cancellation/dispute/case state
- reliability/review/history primitives

**Exit gate:** Fresh migration replay passes, RLS denies cross-user reads, service-role paths are explicit, generated Supabase types reconcile, and the client can represent every canonical lifecycle state without stringly-typed ad-hoc values.

---

### Plan 03 — Discovery, Explore, job cards, apply/accept/reschedule

**Purpose:** Implement the teen marketplace loop from opening MORT through an accepted scheduled job.

**Primary files:**
- `app/teen/home.tsx` (new canonical Home)
- `app/teen/explore.tsx`
- `app/job/[id].tsx`
- `app/teen/applications.tsx`
- `components/JobCard.tsx`
- new `components/jobs/*`
- `lib/data.ts` split into focused job/application modules

**Exit gate:** Quick Jobs rail + compact vertical feed, one-tap Apply, `Apply → Applying… → Applied ✓ → View application`, right-swipe Not Interested with 6-second Undo, mini poster profile, application status/read receipt, Accepted banner + pinned Inbox item, acceptance summary, structured reschedule cards, and address privacy all work from production-shaped data.

---

### Plan 04 — Adult/business posting, applicants, checkout, business-aware identity

**Purpose:** Replace `dashboard.tsx`/simple posting with the approved marketplace Home, smart posting flow, applicant preview/compare, and compact payment checkout.

**Primary files:**
- `app/adult/home.tsx`
- `app/adult/explore.tsx`
- `app/adult/post-job.tsx`
- `app/adult/applications.tsx`
- new `app/checkout/*`
- new `components/posting/*`
- new `components/applicants/*`
- new payment-method UI bridge modules

**Exit gate:** Natural-language job entry, suggested title/category/duration/pay, `$10–$100` pay rail plus typed higher amount, hybrid duration/date/time selection, private exact address, MORT-assigned 1h/2h/4h cancellation window shown before publish, real job-card preview, applicant smart ranking/compare, pre-accept job-only messaging, compact `Accept & secure payment` sheet, Apple Pay/Google Pay/card presentation, and declined-payment recovery.

---

### Plan 05 — Active Job, PINs, evidence, safety, offline recovery

**Purpose:** Build the highest-risk live-work subsystem as one coherent teen/adult state machine.

**Primary files:**
- new `app/job/[id]/active.tsx` route or route-group equivalent
- new `components/active-job/*`
- new `components/safety/*`
- new `lib/activeJob/*`
- `app/teen/safety.tsx` refactored into profile Safety Center
- new Supabase migrations/RPCs for PIN verification, check-ins, incident records, scope changes, evidence visibility, and event timeline

**Exit gate:** Teen Start PIN / adult Finish PIN, manual + QR/scan verification, `Ready to finish`, structured scope changes, Before/During/After evidence, floating draggable live-job circle + edge tab, adaptive check-ins on all jobs, dead-phone/offline escalation semantics, low-battery mode, Share Status, trusted contacts, press-and-hold Emergency Help, safe-exit flow, incident record creation, and role/privacy boundaries all pass adversarial QA.

---

### Plan 06 — Payments, Wallet, cancellations, disputes, history, reviews, reliability

**Purpose:** Implement the monetary and accountability layer built on Plan 05.

**Primary files:**
- new `app/wallet/*`
- new `components/wallet/*`
- new `lib/payments/*`
- new `lib/disputes/*`
- new `lib/reliability/*`
- new `app/history/*`
- new `app/reviews/*`
- relevant migrations/RPCs/Edge Functions/webhook handlers

**Exit gate:** pending/processing/available states, `$2.97` fee visibility from acceptance onward, standard + instant payout, adult active holds, 48-hour Finish-PIN dispute branch, adaptive cancellation tiers, `$1.34` minimum adult late-cancel compensation, Leave Job Early proposal/dispute, chronological timestamped History, optional two-way reviews with 25-minute edit window, and provisional-to-public reliability behavior.

---

### Plan 07 — Inbox, chat, Profile, Motion, settings, notifications, support

**Purpose:** Converge secondary surfaces onto the new architecture without turning them into dashboards.

**Primary files:**
- `app/teen/inbox.tsx`
- `app/adult/inbox.tsx`
- `app/messages/[threadId].tsx`
- `app/teen/profile.tsx`
- `app/adult/profile.tsx`
- new `app/motion/*`
- new `app/settings/*`
- `app/notifications.tsx`
- `app/support.tsx`
- new focused components/modules

**Exit gate:** mixed Inbox with priority pinning/Requests/filtering, job-context chat + structured work actions, 24-hour post-job write window, scan/warn/block behavior, compact identity-first Profile, Wallet/Motion/Safety entries, opt-in leaderboards, role-safe contact/discovery privacy, Security & Devices, quiet hours/bundling, and tracked support cases.

---

### Plan 08 — Verification, business staff, auth/security

**Purpose:** Implement the trust and account-control surfaces required before marketplace activation.

**Primary files:**
- `app/auth/*`
- `app/onboarding.tsx`
- `app/adult/verification.tsx`
- new `app/teen/verification/*`
- new `app/business/*`
- new `app/settings/security.tsx`
- new `lib/verification/*`
- new `lib/business/*`
- relevant migrations/RPCs/private storage policies

**Exit gate:** shared onboarding, email-code auth with Apple/Google and optional passkey/biometric setup, age-aware teen identity flow, mandatory school ID front/back, required school email when supported, adult ID+liveness+$1.25 payment verification, business legal/authority/payment verification, staff invites/preset roles/custom permissions, immediate revocation/reassignment, and audited sensitive permission changes.

---

### Plan 09 — Moderation/admin, system states, accessibility, release certification

**Purpose:** Finish the internal operating system and validate the product as a real iOS/Android app.

**Primary files:**
- `app/admin/*`
- new `components/admin/*`
- new moderation/case modules
- notification/security/system-state modules
- CI workflows under `.github/workflows/`
- release QA scripts under `scripts/`

**Exit gate:** priority case queue, case tabs, recommendations with human decision ownership, restriction presets + granular overrides, second approval for high-impact actions, immutable audit trail, appeal/reopen controls, offline/crash recovery, Reduce Motion/high-contrast/dynamic text/screen-reader validation, Android/iOS parity checks, exact-head CI, migration/RLS QA, and signed release-candidate builds.

## Program invariants to verify after every plan

1. **Fail closed.** Payments, verification, payouts, emergency sharing, and marketplace activation must not claim success when external configuration is missing.
2. **No privacy regression.** Exact addresses, private evidence, verification documents, emergency-contact data, and private incident details stay inaccessible to unauthorized roles.
3. **No teen-safety regression.** Safety withdrawals are not reliability-negative; blocking/reporting does not erase records; adult/business message requests never become unrestricted cold DMs.
4. **No visual regression to old brand.** Consumer UI must not reintroduce neon green, blue/purple accents, dark-first design, dashboard Home, or old tab nomenclature.
5. **No state lies.** UI labels such as `Payment secured`, `Paid`, `Verified`, `Check-in synced`, or `Emergency contact alerted` only appear after the corresponding backend/platform state is confirmed.
6. **Native parity.** iOS/Android use the same MORT information architecture while respecting platform-native payment, biometric, permission, back-navigation, notification, accessibility, and emergency-call behavior.

## Pull-request strategy

- One PR per plan unless a plan is split further after implementation complexity is discovered.
- Each PR begins from an exact known `main` SHA and records it in the PR description.
- No feature PR may include unrelated legal-site, release-signing, or historical Flutter cleanup.
- Keep production activation flags/fail-closed gates unchanged unless the plan explicitly includes an activation step and all external gates are verified.
- Require focused QA + full `npm run check` + `npm run lint` + relevant Supabase reconciliation/RLS suites before review.

## Recommended execution mode

**Subagent-driven development** is recommended for this program. The plans have security-sensitive boundaries (minors, payments, identity, live location, RLS, moderation) where an independent task reviewer is worth the extra context cost.
