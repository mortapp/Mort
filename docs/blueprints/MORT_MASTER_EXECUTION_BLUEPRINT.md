# MORT Master Execution Blueprint

Status: executable engineering blueprint  
Branch seed: `feature/mort-master-blueprint-gamification`  
Authoritative client: `flutter_mort`  
Backend: hosted Supabase project `rakjydmgwwgtdislanbt`

This is not a brainstorm and not a prompt. It is the implementation contract for the next MORT completion pass.

---

# 0. Execution law

Codex must execute this blueprint with **one agent only**.

Do not spawn sub-agents. Do not delegate research, coding, testing, security review, or the final council to other models. The Believer / Skeptic / Investor / Judge review at the end is four sequential passes by the same Codex instance over the same exact committed diff and evidence.

Codex may use VS Code whenever useful, including the editor, global search, refactors, integrated terminal, Flutter tooling, Git, Android tools/emulators, available macOS/Xcode tooling, and connected GitHub/Supabase tooling. When the current environment cannot perform a real external step, Codex must prepare everything it can, record the exact blocker, and continue independent work. It must never invent success.

Before editing, read `AGENTS.md`.

---

# 1. Product north star

MORT is a teen-safe local work marketplace primarily for ages 13–17.

Core promise:

> Earn nearby. Move smart.

Brand motion:

> GET IN MOTION.

The app is not merely a job board. It combines:

- local work discovery;
- verified and safety-aware participation;
- job lifecycle and evidence;
- protected communication;
- optional guardian oversight;
- moderation and disputes;
- real-world payment infrastructure when approved;
- progression, identity, achievement, and community status;
- inexpensive optional monetization that does not paywall core utility or safety.

The original MORT concept included an important layer that the current production client only partially preserved: **gamified progression**. MORT should feel like the user is building a real work reputation and moving forward over time.

The next implementation must restore that layer without converting safety, income, or risky behavior into a game.

---

# 2. Non-negotiable safety and trust boundaries

These rules outrank feature velocity.

## 2.1 Teen safety

- Under-13 users remain blocked.
- Teen users remain 13–17.
- Exact teen location is never exposed through progression, leaderboards, public cards, referrals, or share cards.
- Age, DOB, school email, school ID, verification documents, private messages, reports, PINs, addresses, payment details, and guardian-private data may never appear in progression telemetry or public leaderboard payloads.
- No XP, token, badge, streak, or rank may reward risk-taking, faster dangerous work, ignoring safety steps, skipping reports, off-platform contact, or secrecy.
- A safety report must **never break a streak or reduce XP**. Users must never have an incentive not to report.
- Verification and school-ID submission must **not** award XP or Motion Tokens. MORT must not pressure a minor to upload sensitive identity documents for a game reward.
- Trust/verification badges must remain visually and semantically separate from game rank badges.

## 2.2 Client trust

The client is never authoritative for:

- XP;
- level;
- rank;
- Motion Token balance;
- badge grants;
- streak state;
- leaderboard score;
- completed-job credit;
- RevenueCat entitlements;
- Stripe payment/funding/payout state;
- identity verification;
- safety/moderation state;
- admin state.

The client may request, display, animate, and acknowledge authoritative state. It may not grant it.

## 2.3 Monetization

- Safety is free.
- Basic account, basic job feed, basic applying, basic Guardian Mode, report/block, Safety Ping/check-ins, safe messaging, basic proof upload, and basic notifications remain free.
- No pay-to-win XP multiplier.
- No paid rank boost.
- No paid leaderboard multiplier.
- No paid safety advantage.
- No paid verification advantage.
- No purchase may bypass moderation, job-safety screening, age rules, RLS, or identity gates.

## 2.4 Production truth

A feature is not “production ready” because UI exists.

Every production claim must match:

- exact committed code;
- hosted backend state;
- provider state where relevant;
- CI;
- real-device evidence where required;
- signing/provider/legal/operational gates.

Fail closed when external approval is absent.

---

# 3. Current system that must be preserved

Codex must inspect current code before changing any of this.

Key sources of truth include:

- `flutter_mort/`
- `supabase/migrations/`
- `supabase/functions/`
- `.github/workflows/mort-ci.yml`
- `.github/workflows/mort-signed-closed-test.yml`
- `.github/workflows/mort-ios-signed-closed-test.yml`
- `docs/FINAL_RLS_MATRIX.md`
- `docs/MORT_RELEASE_READINESS.md`
- `MORT_EXTERNAL_RELEASE_GATES.md`
- `docs/release/MORT_IOS_ANDROID_PARITY_AUDIT_2026-09-20.md`
- `docs/payments/`
- `docs/identity/MORT_VERIFY_RLS_MATRIX.md`
- `docs/REVENUECAT_PRODUCTS_AND_ENTITLEMENTS.md`
- `docs/ADMOB_SCREEN_ELIGIBILITY_MATRIX.md`

Existing components that must be reused rather than duplicated include:

- current job/application lifecycle;
- current completed-job authority;
- current reviews/moderation authority;
- current leaderboard v1 migration/RPC/repository;
- current Stripe sandbox/financial architecture;
- current RevenueCat service and webhook architecture;
- current AdMob eligibility system;
- current MORT Verify architecture;
- current Flutter release configuration;
- current Android/iOS shared Flutter architecture;
- current account deletion, evidence, moderation, guardian, messaging, and RLS controls.

---

# 3.1 Restore the original product personality

The earliest MORT product direction must remain visible in the final implementation:

- premium and serious, not childish;
- teen-coded without looking like a school app or allowance tracker;
- dark/high-contrast MORT atmosphere using the current canonical design tokens rather than resurrecting obsolete colors blindly;
- short, declarative copy;
- XP/level counters may animate subtly;
- no casino treatment;
- no loot boxes;
- no random paid rewards;
- no mascot-driven gamification;
- no noisy confetti dependency;
- motion should generally remain fast/subtle and respect Reduced Motion;
- abstract/original geometric achievement art is preferred to cartoon art.

The original concept also separated **XP/progression** from **trust**. Keep that separation.

- XP answers: how far has this user progressed through legitimate MORT activity?
- Trust/reputation answers: what does MORT's evidence say about reliability/safety-related marketplace history?
- Verification answers: what identity/age/affiliation evidence has actually been verified?

A high rank must never substitute for trust or verification, and trust must never be purchasable.

# 4. Restore MORT progression: levels, XP, ranks, badges, streaks, goals, tokens

This is the missing product layer.

## 4.1 Rank ladder

The previous early concept used provisional “Rookie → Legend” language. That is superseded by the current product direction.

The canonical MORT rank ladder is now:

| Rank | Levels | Meaning |
| --- | ---: | --- |
| Bronze | 1–10 | New worker building history |
| Silver | 11–20 | Consistent participation |
| Gold | 21–30 | Established local worker |
| Platinum | 31–40 | High sustained progression |
| Diamond | 41–50 | Highest MORT progression rank |

**Diamond is the highest rank.**

Rank is a progression status, not identity verification and not a safety guarantee.

## 4.2 XP curve

Use one deterministic server-side level curve.

For moving from level `L` to `L + 1`:

`xp_required_for_next_level = 100 + 25 * (L - 1)`

Rules:

- Level 1 begins at 0 cumulative XP.
- Level cap for v1 is 50.
- XP beyond level-50 threshold may continue accumulating internally for future compatibility, but rank remains Diamond and client level remains 50 until a future version intentionally changes the system.
- The formula must live in one backend helper and one mirrored pure-Dart display helper with contract tests proving identical thresholds.
- Never store a client-editable “level” or “rank” as the source of truth. Derive or server-maintain them from authoritative XP.

## 4.3 XP sources

Initial production-safe XP sources:

| Event | XP | Authority | Anti-abuse rule |
| --- | ---: | --- | --- |
| completed job | 100 | server-authoritative application/job completion | once per completed application |
| first completed job milestone | +100 | derived server-side | once per user ever |
| completed required safety check-in flow | 10 | server-authoritative check-in/job relation | at most once per qualifying job |
| submitted post-job review | 15 | authenticated completed-job participant RPC | once per eligible review |
| first completed job in a supported work category | 25 | derived from completed job category | once per category |
| selected milestone/badge completion | blueprint-defined | server-derived | idempotent unique milestone |

Do **not** award XP for:

- opening the app;
- time spent in app;
- messages sent;
- number of applications submitted;
- ad views;
- rewarded ad completion;
- purchases;
- subscription status;
- amount earned;
- tip amount;
- job price;
- speed of completion;
- unsafe/high-risk job categories;
- school-ID upload;
- age verification;
- reporting fewer safety issues.

Codex may tune exact XP constants only if a testable reason is recorded. Do not change the underlying safety rules.

## 4.4 Motion Tokens

Create a non-cash, non-transferable cosmetic reward currency called **Motion Tokens**.

Internal naming should clearly distinguish it from the existing RevenueCat `mort_username_change_token_1`.

Recommended internal names:

- `motion_tokens_balance`
- `motion_token_delta`
- `motion_token_ledger`

Motion Tokens:

- have no cash value;
- cannot be withdrawn;
- cannot be transferred user-to-user;
- cannot convert into earnings;
- cannot pay for real-world jobs;
- cannot unlock safety features;
- cannot improve job eligibility;
- cannot alter trust/verification;
- cannot buy leaderboard position;
- cannot buy XP/rank;
- must not be called money, balance of funds, wallet cash, earnings, or payout.

### Level rewards

Each newly crossed level awards:

- +1 Motion Token for every ordinary level-up.

Additional one-time rank-transition bonuses:

- entering Silver: +5 Motion Tokens;
- entering Gold: +10;
- entering Platinum: +15;
- entering Diamond: +25.

All rewards are server-issued and idempotent. If one job crosses several levels, award every crossed level exactly once.

## 4.5 Motion Token spending v1

Tokens should initially be spendable only on cosmetic/self-expression items, for example:

- profile frame variants;
- avatar ring variants;
- profile accent treatments;
- milestone/share-card backgrounds;
- rank-card presentation variants;
- non-safety badge display cosmetics.

Do not allow Motion Tokens to buy:

- job boosts;
- priority applications;
- safety access;
- messaging access;
- verification;
- moderation outcomes;
- payment benefits;
- payout speed;
- search ranking;
- identity/trust badges.

Paid RevenueCat cosmetics and earned Motion Token cosmetics must coexist without one silently granting the other.

## 4.6 Rank and token icons

Codex must create original MORT-owned assets, not copy game or platform artwork.

Required assets:

- Bronze rank emblem;
- Silver rank emblem;
- Gold rank emblem;
- Platinum rank emblem;
- Diamond rank emblem;
- Motion Token icon;
- generic level-up mark;
- badge base shapes needed by the initial badge set.

Preferred path:

`flutter_mort/assets/gamification/`

Suggested structure:

- `ranks/bronze.svg`
- `ranks/silver.svg`
- `ranks/gold.svg`
- `ranks/platinum.svg`
- `ranks/diamond.svg`
- `tokens/motion_token.svg`
- `badges/*.svg`

The visual language should reuse MORT’s actual design system, wordmark geometry, spacing, and accessible contrast. Avoid generic medieval shields if they conflict with MORT’s modern motion/marketplace identity.

If the environment does not support a design tool, Codex is explicitly allowed to create the SVGs directly in VS Code.

Every asset must have accessible semantics in Flutter or be marked decorative where appropriate.

## 4.7 Badges

Game badges are achievements, not verification.

Initial badge families should include:

### Work milestones
- First Move — first completed job.
- Getting In Motion — 5 completed jobs.
- Momentum — 10 completed jobs.
- Consistent — 25 completed jobs.
- Community Workhorse — 50 completed jobs.

Names can be refined for MORT brand quality, but must not imply guaranteed trust or legal certification.

### Category milestones
Use existing canonical job categories rather than inventing incompatible values.

Historical target categories include:

- Pet Care;
- Yard Work;
- Tutoring;
- Business Help.

For each supported category, initial tiers can be:

- first completion;
- 5 completions;
- 20 completions.

### Safety practice badges
Reward completed safety practices, not the absence of reports.

Examples:

- Check-In Ready — completed required safety check-ins on 3 eligible jobs.
- Safety Habit — completed required safety steps on 10 eligible jobs.

A report, block, moderation request, or emergency action must never remove these achievements.

## 4.8 Streaks

The canonical teen-safe streak is a **Safety Streak**, not a daily-login addiction loop.

A Safety Streak may advance when:

- an eligible job reaches legitimate completed state; and
- every safety check-in required for that job was completed.

It must not depend on:

- report count;
- rating;
- speed;
- earnings;
- consecutive calendar-day login;
- accepting every offered job.

Do not punish users for taking breaks.

A safety report must not reset the streak.

## 4.9 Goals / missions

The earliest MORT concept also used an earnings/independence goal progress bar. Preserve the concept, but keep it separate from XP and never expose it publicly by default. Existing earnings goals/Future Independence features remain the financial-goal authority; progression may celebrate a user reaching their own private milestone, but it must not turn earnings into leaderboard score.

Restore goals as a voluntary progression aid.

Examples:

- complete 1 job this week;
- complete 3 jobs this month;
- complete one job in a new category;
- complete all required safety check-ins on the next eligible job;
- leave feedback after a completed job.

Rules:

- no manipulative countdowns;
- no financial penalties;
- no loss of previously earned XP;
- no “apply to 20 jobs” spam goals;
- no dangerous job goals;
- no goal that discourages reporting/blocking.

---

# 5. Progression backend architecture

Progression must be server-authoritative, replay-safe, and reconstructable.

## 5.1 Additive schema

Codex should implement an additive migration after inspecting current schema.

Preferred architecture:

### `private.progression_accounts`

One row per user:

- `user_id uuid primary key`
- `xp_total bigint not null default 0`
- `level smallint not null default 1`
- `rank text not null default 'bronze'`
- `motion_tokens_balance integer not null default 0`
- `current_safety_streak integer not null default 0`
- `best_safety_streak integer not null default 0`
- timestamps

Constraints:

- XP >= 0
- level 1–50
- rank allowlist bronze/silver/gold/platinum/diamond
- token balance >= 0

This row is a materialized current state, not an independently client-editable authority.

### `private.progression_events`

Append-only ledger:

- `id uuid primary key`
- `user_id uuid`
- `event_type text`
- `source_type text`
- `source_id uuid/text`
- `xp_delta integer`
- `motion_token_delta integer`
- `idempotency_key text unique`
- `occurred_at timestamptz`
- safe metadata only
- server/audit actor fields when needed

No emails, DOB, exact addresses, school IDs, messages, report bodies, payment credentials, or raw private evidence in metadata.

### `private.progression_badges`

- `user_id`
- `badge_key`
- `awarded_at`
- `source_event_id`
- unique `(user_id, badge_key)`

### `public.progression_preferences` or equivalent self-scoped table

Minimum:

- `user_id primary key`
- `leaderboard_opt_in boolean default false`
- `show_badges boolean default true`
- `show_rank boolean default true`

If extending existing `profiles.leaderboard_opt_out` is safer than adding a second preference source, migrate deliberately and retain one canonical setting. Do not create contradictory opt-in/opt-out flags.

### optional derived weekly tables

Use only if required for efficient weekly/category boards. Prefer deterministic server queries or snapshots that can be regenerated.

## 5.2 Award pipeline

Do not expose “add XP” to normal clients.

Use authoritative events from already-hardened state.

Preferred sequence:

1. authoritative domain event becomes valid (for example application transitions to completed);
2. backend writes an idempotent progression event using deterministic source identity;
3. progression account recalculates/applies delta in the same transaction where practical;
4. backend computes crossed levels;
5. backend auto-awards level/rank Motion Tokens exactly once;
6. badge/streak rules run idempotently;
7. client later reads authoritative progression state.

If triggers are used, prove they cannot be invoked by a client forging the underlying state. If existing status RPCs are safer, integrate there.

Never award based on a client “job finished” boolean.

## 5.3 Public RPC boundary

Expected public authenticated RPCs may include:

- `get_my_progression_v1()`
- `get_my_progression_events_v1(p_cursor, p_limit)`
- `get_progression_leaderboard_v2(...)`
- `set_my_leaderboard_preference_v2(...)`
- `get_public_progression_card_v1(p_user_id)`
- `spend_motion_tokens_v1(p_cosmetic_key, p_client_request_id)`

Exact signatures must be designed after inspecting existing conventions.

Requirements:

- revoke from `public` and `anon`;
- authenticated only where appropriate;
- `SECURITY DEFINER` functions must have explicit hardened search path;
- self-bound actions use `auth.uid()`;
- spending must be transactional, balance-safe, idempotent, and inventory-allowlisted;
- no arbitrary XP/token amount parameter from clients.

## 5.4 RLS / direct access

Progression ledgers and authoritative state should live in `private` when possible and be read through narrow RPCs.

If any public table is used:

- RLS enabled;
- no anonymous CRUD;
- no cross-user mutation;
- no client mutation of XP/rank/token/badges;
- minimal safe public projection only.

Service role remains server-only.

---

# 6. Leaderboards v2

The existing leaderboard v1 proves the basic anti-forgery architecture. Build on it rather than throwing it away.

## 6.1 Boards

Historical MORT leaderboard targets:

- Weekly XP;
- Completed Jobs;
- Safety Streak;
- Beginner Helpers;
- Pet Care;
- Yard Work;
- Tutoring;
- Business Help.

Use only canonical categories that exist in the current backend. Map historical labels to real values rather than inventing mismatched strings.

## 6.2 Teen privacy

Teen public leaderboard participation is opt-in.

Public rows may show only safe fields such as:

- `@username`;
- avatar only if current public-profile rules allow it;
- rank;
- level;
- XP appropriate to the selected board/window;
- completed-job count appropriate to the board;
- safe badge/tier presentation.

Never expose:

- email;
- DOB/age;
- school;
- school email;
- school-ID status details beyond existing safe trust badge;
- exact city/state if current policy treats it as private;
- exact location;
- earnings;
- payout amount;
- job addresses;
- guardian identity;
- report/moderation detail.

## 6.3 Ranking integrity

No leaderboard for:

- fastest completion;
- most money;
- highest tips;
- most hours;
- most high-risk jobs;
- fewest reports.

Tie-breaking must be deterministic but not expose private identifiers.

Test accounts and restricted accounts must remain excluded according to current policy.

---

# 7. Flutter product experience

Implement the progression system in the authoritative Flutter client.

## 7.1 Core screens/components

Create or consolidate:

- Progression Hub;
- XP progress bar/ring;
- current level card;
- current rank card;
- Motion Token balance with non-cash explanation;
- badge gallery;
- weekly/monthly goals card;
- leaderboard screen with safe board tabs;
- leaderboard opt-in controls;
- level-up overlay;
- rank-up ceremony;
- cosmetic inventory/store using Motion Tokens;
- milestone share-card generator.

Use the existing MORT navigation/design system. Do not create a parallel visual system.

## 7.2 Entry points

Progression should be reachable from:

- Teen Home;
- Teen Profile;
- Settings / Experience;
- relevant post-completion success state;
- leaderboard card.

Do not bury safety actions under gamification.

## 7.3 Level-up UX

After the backend reports a new level that the local client has not acknowledged:

- show the new level;
- show XP progress;
- show Motion Tokens granted;
- if rank changed, show the new rank emblem;
- allow dismissal;
- persist an acknowledgement marker locally or server-side without altering authoritative progression.

No client-side speculative rank-up.

Reduced Motion:

- no confetti/parallax loops;
- use a simple fade/scale or static milestone card;
- same information must remain available.

## 7.4 Accessibility

- rank color is not the only signal;
- announce rank and level as text;
- token icon has a text label;
- progress has semantic current/max values;
- 200% text remains operable;
- animation does not block screen readers;
- every cosmetic asset has correct decorative/semantic treatment.

---

# 8. RevenueCat / digital monetization

RevenueCat is for optional digital goods/subscriptions. Do not merge it with Stripe’s real-world service-payment authority.

Current planned product families:

- `mort_plus_monthly`
- `mort_plus_yearly`
- `mort_plus_lifetime`
- `mort_ad_free_lifetime`
- `mort_username_change_token_1`
- `mort_profile_style_pack`
- `mort_adult_pro_monthly`
- `mort_guardian_plus_monthly`
- `mort_job_boost_1`

Current target positioning from MORT planning:

- MORT Plus: $0.99/month
- MORT Plus yearly: $7.99/year
- MORT Plus lifetime: $14.99 one time
- Ad-free lifetime: $1.99
- Username change token: $1.99
- Profile style pack: $0.99
- Adult Pro: $2.99/month
- Guardian Plus: $1.99/month
- Job Boost: $1.99

Runtime UI must display store/RevenueCat-returned pricing, not hard-coded planning prices.

## 8.1 Progression interaction

RevenueCat purchases must **not**:

- grant XP;
- multiply XP;
- grant rank;
- improve leaderboard position;
- alter trust score;
- improve safety access.

RevenueCat may unlock:

- premium cosmetics;
- profile style packs;
- ad-free status;
- the already-approved optional product entitlements;
- job-boost credits only through the existing safety/moderation-safe path.

Do not sell Motion Tokens in this phase.

If Motion Tokens are ever sold later, they become a digital good and must go through the approved store/RevenueCat path. Stripe must not sell them.

## 8.2 RevenueCat security

Preserve:

- server-validated webhook;
- idempotent event IDs;
- ordering protections;
- entitlement allowlists;
- atomic consumable credit grants;
- purchase audit logs;
- no client-trusted entitlement mutation.

Run RevenueCat tests after progression work to prove no cross-impact.

---

# 9. Ads / AdMob

Preserve the safe monetization posture.

Ads remain prohibited on:

- auth;
- onboarding;
- age gate;
- MORT Verify / school-ID screens;
- Safety Ping/check-ins;
- reports;
- messages;
- guardian approval;
- proof upload;
- payment;
- payout;
- disputes;
- admin;
- paywall;
- other sensitive screens already blocked by the eligibility matrix.

For teen/unknown-age users:

- conservative/non-personalized handling;
- no tracking-based widening;
- no rewarded-ad path that gates core work or safety;
- no XP or Motion Tokens for watching ads.

iOS currently declares no ATT tracking path; do not silently add one.

Rewarded ads, if ever enabled for eligible users, may not unlock:

- applying;
- safety;
- verification;
- reports;
- blocking;
- Guardian Mode;
- rank;
- XP;
- Motion Tokens.

Run the existing ad eligibility tests and add progression-specific negative tests.

---

# 10. Stripe / real-world job payments

Stripe is the MORT marketplace payment rail for approved real-world job payments, separate from digital monetization.

Preserve the existing architecture:

- server-generated funding quote;
- immutable contract authority;
- server-calculated amount/currency/fees;
- PaymentSheet client may only consume provider configuration;
- webhook/provider-confirmed state is authoritative;
- no optimistic “paid/funded” claim from client completion;
- Connect onboarding/requirements;
- settlements/transfers;
- refunds;
- disputes;
- tips;
- financial ledgers/documents;
- reconciliation;
- audit logs;
- negative-balance controls;
- tax/reporting gates;
- minor payout/guardian constraints;
- production activation controls.

## 10.1 Progression/payment separation

XP must be driven by legitimate job completion, not money.

Never calculate XP from:

- job amount;
- service fee;
- tip;
- payout;
- number of dollars earned;
- Stripe account status.

A refunded/disputed job needs a deliberate product rule.

Default safe rule:

- ordinary post-completion refund/dispute does not automatically erase earned XP unless the underlying job completion is adjudicated fraudulent/invalid;
- fraud/admin reversal may create an explicit negative progression correction event;
- correction must be audited, reason-coded, non-client-authoritative, and never make token balance negative without a defined debt rule.

Do not implement negative token debt in v1 unless required. Prefer preventing spend reversal from creating hidden negative balances.

## 10.2 Live mode

Do not turn on live Stripe merely because progression code is done.

Current production gates must remain authoritative. Provider/legal/privacy/minor-payout/tax/monitoring approvals require real evidence.

---

# 11. MORT Verify / identity

MORT Verify is a separate trust system.

Keep:

- school email affiliation flow;
- private school-ID evidence;
- independent age evidence;
- reviewer assignments;
- private Storage;
- signed reviewer access;
- retention/deletion;
- audit events;
- fail-closed production control.

Progression must not:

- reward ID upload;
- display raw verification evidence;
- use verification data as XP;
- let Diamond imply verified identity;
- unlock jobs that verification would otherwise deny.

Trust badge and game rank need clearly different names, icons, semantics, and accessibility labels.

---

# 12. RLS / database security completion

Every new progression capability must be included in the RLS/security audit.

Required adversarial cases:

- user tries direct UPDATE of XP;
- user tries direct UPDATE of level;
- user tries direct UPDATE of rank;
- user tries direct UPDATE of Motion Token balance;
- user tries direct INSERT into progression event ledger;
- user tries to replay completed-job progression event;
- user tries to forge another user’s source ID;
- user tries to spend another user’s tokens;
- user tries duplicate spend request;
- user tries concurrent double-spend;
- user tries to opt another user into leaderboards;
- adult tries teen-only private progression RPC;
- anonymous leaderboard access follows the intended policy;
- leaderboard does not leak PII;
- test/restricted accounts follow policy;
- admin correction requires valid admin role and reason;
- service-role-only surfaces are not executable by authenticated clients.

Create/update an adversarial script such as:

`scripts/qa-gamification-exploit.mjs`

Do not weaken existing policies just to satisfy the new system.

---

# 13. Android and iOS parity

Every progression feature ships through shared Flutter unless there is a documented native requirement.

Both platforms need parity for:

- progression data;
- rank icons;
- XP bar;
- level-up overlay;
- rank-up ceremony;
- haptics where supported;
- Motion Token inventory;
- badges;
- goals;
- leaderboard;
- share cards;
- RevenueCat entitlement display;
- ad exclusion rules;
- accessibility;
- deep navigation;
- offline/degraded states.

No Android-only gamification implementation.

No iOS-only gamification implementation.

## 13.1 Native/release checks

After implementation:

- Flutter format/analyze/tests;
- Android release build/closed-test artifact;
- iOS authoritative macOS build;
- CocoaPods lock/reproducibility;
- assets bundled on both platforms;
- iOS privacy manifest re-audit for new app-activity collection;
- Google Play Data Safety worksheet re-audit for new progression/app-activity data;
- no new permission unless absolutely required;
- no ATT permission introduced by progression;
- no advertising identifier required by progression.

---

# 13.1 Social identity / Motion layer

The original MORT vision included social identity and a lightweight “Motion” feeling around progress. Restore this carefully without creating an open minor directory or random chat system.

Allowed directions:

- an authenticated personal activity/progression feed;
- safe milestone cards from users the viewer already has an authorized MORT relationship with, if privacy rules permit;
- category/community milestones;
- progress/badge presentation on a user’s own profile and safe public profile projection;
- shareable external milestone cards controlled by the user.

Do **not** add global random teen discovery, dating/matchmaking, anonymous chat, or unrestricted direct messaging as part of gamification.

A future “Motion Feed” should be relationship/context aware and moderation aware. If Codex implements any feed now, it must be built from safe allowlisted event types and must not expose job addresses, earnings, school details, verification evidence, reports, or message content.

# 14. Growth: make MORT bigger without breaking trust

Growth must come from useful network effects, local density, identity, and shareable progress—not unsafe pressure.

## 14.1 Shareable milestones

Create privacy-safe share cards for:

- reaching a new rank;
- reaching a level;
- earning a badge;
- completing a work milestone.

Cards may include:

- MORT branding;
- rank/level;
- safe username/display identity according to user preference;
- generic milestone.

Cards must not include:

- earnings;
- job address;
- school;
- exact city if private;
- DOB/age;
- employer/client identity without explicit safe design;
- private job details.

This supports organic TikTok/Instagram/Snap sharing without leaking teen work locations.

## 14.2 Referrals

Design, but enable only after anti-abuse tests.

Referral rewards should initially be Motion Tokens/cosmetics, not cash.

A referral becomes reward-eligible only after meaningful anti-sybil criteria, for example:

- referred account is unique and age/role valid;
- referred teen completes legitimate onboarding;
- reward is not granted from simple sign-up alone;
- stronger reward may require first legitimate completed job;
- one source account cannot recursively self-refer;
- device/IP signals, when used, must respect privacy and not become sole authority.

Never create a pyramid-like escalating reward.

## 14.3 City/category launch loops

Preserve the original local-market growth approach:

- city-by-city density;
- local household jobs;
- business poster acquisition;
- category-specific discovery;
- teen-friendly social content;
- shareable progress;
- community trust.

Potential categories include the existing local-work categories such as yard work, pet care, tutoring, and business help.

Do not open a new jurisdiction publicly until legal/work eligibility rules for that jurisdiction are approved.

## 14.4 Retention

Use:

- visible progression;
- badges;
- achievable goals;
- saved jobs;
- useful notifications;
- reputation;
- profile self-expression;
- community milestones.

Do not use:

- manipulative daily-login loss;
- fake scarcity;
- unsafe FOMO;
- pay-to-maintain streaks;
- punishment for taking a break.

---

# 15. Analytics / experimentation

Progression needs measurement without sensitive telemetry.

Safe events can include:

- progression_hub_viewed;
- level_up_seen;
- rank_up_seen;
- badge_awarded;
- leaderboard_opened;
- leaderboard_opt_in_changed;
- cosmetic_unlocked;
- milestone_share_started/completed.

Do not send:

- raw job addresses;
- school email;
- school-ID path;
- DOB;
- message body;
- report body;
- PIN;
- Stripe client secret;
- card/bank data;
- private payout details.

Teen analytics consent/current product rules remain authoritative.

No A/B test may weaken safety or hide required disclosures.

---

# 16. Production-readiness convergence

Codex must treat this work as part of MORT’s broader production-readiness program, not as a standalone game feature.

After progression implementation, re-audit:

## 16.1 Flutter
- formatting;
- analyzer;
- full unit/widget suite;
- progression focused tests;
- navigation;
- startup/release config;
- provider-disabled builds;
- accessibility.

## 16.2 Supabase
- migrations aligned;
- schema lint;
- security advisors;
- RLS matrix updated;
- progression exploit tests;
- multi-user isolation;
- Storage unchanged unless progression intentionally adds assets outside app bundle;
- no service-role leakage.

## 16.3 Stripe
- contract tests;
- local regression;
- security freeze;
- hosted/provider tests when configured;
- production controls remain fail-closed unless real gates changed.

## 16.4 RevenueCat
- entitlement mapping;
- purchase/restore behavior;
- webhook replay;
- consumable idempotency;
- no progression pay-to-win path.

## 16.5 Ads
- screen eligibility;
- ad-free entitlement;
- teen/unknown privacy;
- iOS non-personalized rule;
- no XP/token reward for ads.

## 16.6 Android
- build;
- artifact;
- native contract;
- release signing only with real key;
- physical/device QA when available.

## 16.7 iOS
- macOS/Xcode authoritative build;
- CocoaPods;
- privacy manifest;
- signing/TestFlight workflow;
- APNs/config gates;
- physical iPhone/TestFlight QA when available.

## 16.8 MORT Verify
- collection state unchanged unless separately approved;
- no progression coupling to sensitive verification.

---

# 17. Implementation order

Codex should execute in this order to reduce rework.

## Phase A — baseline and inventory

1. Confirm exact branch/head.
2. Read `AGENTS.md` and this blueprint.
3. Inspect current progression/leaderboard code and migration.
4. Inspect current canonical job completion, review, and safety-check-in authority.
5. Inspect RevenueCat, ads, Stripe, Verify, release configuration, Android/iOS CI.
6. Record a short implementation inventory in `docs/blueprints/MORT_MASTER_EXECUTION_PROGRESS.md`.

Do not edit behavior before the authoritative event sources are identified.

## Phase B — progression database

1. Add additive progression migration.
2. Create private ledger/current-state tables.
3. Create deterministic XP/level/rank helpers.
4. Add idempotent award/correction functions.
5. Integrate completed-job awards at an authoritative backend boundary.
6. Integrate safe check-in/review/category milestones.
7. Add Motion Token level/rank rewards.
8. Add badges/streaks.
9. Add safe narrow RPCs.
10. Add grants/revokes/RLS boundary.
11. Add indexes/constraints.

Run database/RLS tests before UI.

## Phase C — progression adversarial QA

Build `scripts/qa-gamification-exploit.mjs`.

Prove:

- no direct forging;
- no replay;
- no cross-user spend;
- no token double-spend;
- no PII leaderboard leakage;
- no adult escalation;
- no XP from payments/ads/purchases/verification.

Fix before proceeding.

## Phase D — Flutter data layer

Implement:

- models;
- repository;
- providers/state;
- pure level/rank helpers;
- safe error mapping;
- loading/degraded states.

Contract test backend shapes.

## Phase E — assets and UI

Create original rank/token/badge assets.

Build:

- Progression Hub;
- XP/level widgets;
- rank widgets;
- Motion Token card;
- badge gallery;
- goals;
- leaderboard v2;
- cosmetic unlock view;
- level/rank celebration.

Wire entry points.

## Phase F — monetization boundaries

Prove:

- RevenueCat entitlements do not affect XP/rank;
- Motion Tokens not sold in v1;
- ads do not grant progression;
- job boost does not bypass safety;
- Stripe amount/tips do not affect XP.

## Phase G — growth layer

Implement privacy-safe milestone sharing.

Implement referral backend/UI only if the anti-sybil and privacy design can be completed without weakening existing gates. Otherwise leave referral activation disabled with code/docs ready.

## Phase H — Android/iOS parity

Run exact shared-client parity.

Fix any platform-specific crash/build/asset/config issue.

Do not call parity complete while one platform is untested for a changed native dependency.

## Phase I — release/security regression

Run all relevant CI, Supabase, Stripe, RevenueCat, ad, Verify, secret, and release checks.

Update stale docs rather than letting contradictory historical documents remain authoritative.

## Phase J — final single-agent council + bug-fix loop

Run the four passes below sequentially with **no sub-agents**.

---

# 18. Mandatory single-agent council

## 18.1 Believer pass

Make the strongest evidence-based case that the implementation fulfills MORT’s original product idea and current hardened architecture.

Verify:

- progression actually makes the product feel rewarding;
- rank/level/tokens work end to end;
- growth loops have value;
- monetization remains viable;
- cross-platform experience is coherent.

Do not excuse failing tests.

## 18.2 Skeptic pass

Attack the system as if trying to break it.

At minimum ask:

- Can I forge XP?
- Can I replay a job completion?
- Can I gain tokens twice?
- Can I double-spend tokens?
- Can I edit another user?
- Can I infer earnings/location/age from leaderboard output?
- Can payments or purchases boost rank?
- Can ads boost rank?
- Can a teen be pressured into ID upload for XP?
- Can a report damage a streak?
- Can a malicious client invoke service-only RPCs?
- Can an adult call teen-only progression paths?
- Can concurrent requests corrupt token balance?
- Can a refund/dispute create inconsistent progression?
- Can stale cached state show a fake rank-up?
- Can Android and iOS disagree?
- Can reduced-motion/accessibility users miss critical information?
- Can a missing RevenueCat/AdMob/Stripe provider create false success?
- Can an unconfigured production build silently open a gate?

Every reproducible defect must be fixed.

## 18.3 Investor / operations pass

Check whether the implementation can operate economically and supportably.

Verify:

- free core remains useful;
- RevenueCat products stay optional;
- progression improves retention without pay-to-win;
- token economy cannot create financial liability;
- support can explain XP/rank corrections;
- moderation can handle leaderboard abuse;
- instrumentation can measure adoption;
- referral abuse cannot create uncontrolled cost;
- production gates distinguish code-complete from external approval.

## 18.4 Judge pass

The Judge reads:

- final diff;
- all test evidence;
- Skeptic findings;
- unresolved external gates.

Possible outputs:

- `PASS_CODE_COMPLETE`
- `PASS_CODE_COMPLETE_EXTERNAL_GATES_REMAIN`
- `FAIL_FIX_REQUIRED`

The Judge may not return PASS while:

- a test is failing;
- CI is red for the exact head;
- a known security defect remains;
- RLS isolation is unproven for changed boundaries;
- Android/iOS changed code is broken on one platform;
- secrets are present;
- the app falsely claims live Stripe/Verify/RevenueCat/ads state.

If Judge returns FAIL, return to implementation, fix, rerun affected tests, and repeat the four passes.

---

# 19. Required automated tests

At minimum add tests for:

## Backend/progression

- level threshold boundaries;
- rank boundaries at levels 10/11, 20/21, 30/31, 40/41, 50;
- one job awards exactly once;
- first-job bonus exactly once;
- multiple levels crossed in one event award each level reward once;
- rank bonus exactly once;
- level 50 cap;
- token spend idempotency;
- concurrent token spend safety;
- badge idempotency;
- safety streak behavior;
- report does not reset streak;
- no XP from payment amount;
- no XP from ad event;
- no XP from RevenueCat event;
- no XP from Verify event.

## Flutter

- XP bar calculations;
- rank label/icon mapping;
- level-up state;
- rank-up state;
- Motion Token explanation;
- leaderboard privacy copy;
- opt-in/opt-out;
- reduced-motion;
- large text;
- empty/loading/error/degraded states;
- no purchase/ads/Stripe coupling.

## Security

- direct XP mutation denied;
- direct token mutation denied;
- direct rank mutation denied;
- cross-user preference mutation denied;
- cross-user spend denied;
- replay denied;
- anonymous access according to intended policy;
- public leaderboard field allowlist.

---

# 20. Documentation updates required

When implementation is done, update or create:

- `docs/blueprints/MORT_MASTER_EXECUTION_PROGRESS.md`
- progression architecture doc;
- progression RLS matrix;
- leaderboard privacy/safety rules;
- RevenueCat/Progression boundary;
- Ads/Progression boundary;
- Stripe/Progression boundary;
- Android/iOS parity matrix;
- Google Play Data Safety worksheet if progression analytics changes disclosure;
- App Store privacy prep if progression activity changes disclosure;
- release-readiness report.

Do not leave older docs saying a feature is absent after it has been implemented.

---

# 21. External gates Codex must not fake

Even after code completion, these may remain outside the repo:

- final legal/privacy/teen-safety approval;
- production MORT Verify document-collection approval;
- trained verification reviewers;
- live Stripe provider/use-case approval;
- minor payout/legal/tax approval;
- production monitoring/on-call;
- Apple distribution credentials/App Store Connect/TestFlight review;
- Google Play Console production access;
- real RevenueCat store product approval;
- real AdMob approval/configuration;
- physical-device test evidence where not available.

Record them separately. Do not weaken code to bypass them.

---

# 22. Definition of done

This blueprint is complete only when all of the following are true for the exact final head:

- progression database is additive and deployed only through approved migration workflow;
- XP is server-authoritative;
- Bronze → Silver → Gold → Platinum → Diamond works;
- level 1–50 works;
- level/rank Motion Token rewards work exactly once;
- original rank/token/badge icons exist and ship;
- badge/streak/goal system works without unsafe incentives;
- leaderboards are optional and privacy-safe;
- existing leaderboard compatibility is handled;
- RevenueCat remains optional and cannot buy rank;
- ads cannot grant rank/XP/tokens and stay off sensitive screens;
- Stripe remains authoritative and separated from digital monetization;
- MORT Verify remains separate from progression;
- RLS/adversarial QA passes;
- no cross-user progression attack succeeds;
- Android and iOS shared functionality is at parity;
- CI is green on the exact head;
- secret scan is clean;
- docs match actual code;
- the single-agent Believer/Skeptic/Investor/Judge cycle has been run;
- every reproducible bug found by that audit has been fixed and retested;
- remaining external gates are listed honestly.

Only then may Codex say the implementation is done.
