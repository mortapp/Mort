# MORT Mobile Product UI/UX Design Specification

**Status:** Canonical design specification for review  
**Date:** 2026-10-12  
**Scope:** Consumer mobile app (iOS + Android), teen/adult/business experiences, active-job safety, payments, moderation, verification, support, accessibility, and internal moderation UX  
**Source of truth:** This document supersedes older MORT UI/UX prompts wherever they conflict with the decisions below.

---

## 1. Product Intent

MORT is a teen-safe local work marketplace. Teenagers discover nearby paid work, apply quickly, complete legitimate local jobs, get paid, build reputation, and grow through a progression system. Adults and businesses can post jobs, review applicants, secure payment, manage active work, communicate in work context, and build their own reliability history.

MORT must feel like a mature consumer product rather than a startup dashboard, school portal, gig-management console, or generic AI-generated app.

The primary product loop is:

> **Open MORT → See work → Apply → Get accepted → Do work → Get paid → Build reputation → See better work.**

The product should borrow interaction logic and information hierarchy from mature consumer apps such as TikTok, Netflix, Uber, Airbnb, Spotify, Gmail, and Slack without copying their branding or pixel-level visual designs.

---

## 2. Core Product Principles

1. **One product, not separate teen/adult apps.** Teen, adult, and business experiences share the same design system, information architecture, terminology, component language, and job lifecycle. Role determines permissions and emphasis, not product identity.
2. **Home is the marketplace.** It is not a dashboard. Jobs appear immediately.
3. **Search belongs in Explore.** Do not place a permanent search bar on Home.
4. **Every screen/state has one visually dominant primary action.** Secondary actions remain available but clearly lower in hierarchy.
5. **Progressive disclosure.** Use compact previews and bottom sheets before deeper screens when possible.
6. **Finger memory over invention.** Prefer familiar mobile interaction patterns.
7. **Safety is infrastructure.** It should be powerful and accessible without making the entire app feel alarmist or parental.
8. **Trust is visible.** Verification, reliability, job state, money state, and history must be clear.
9. **Privacy is role-aware and time-bounded.** Exact addresses, safety data, and verification documents are not exposed casually.
10. **Monochrome identity.** MORT uses white, black, silver, gray, and charcoal. No blue or purple brand accent.
11. **Motion is restrained.** Motion confirms state and hierarchy; it is never decorative noise.
12. **Native where it matters.** iOS and Android share the same MORT product architecture but use native platform behavior for Apple Pay/Google Pay, biometrics, back gestures, permission surfaces, emergency calling, accessibility, keyboards, and system notification behavior.

---

## 3. Global Attention Priority

Default product priority, from highest to lowest:

1. **Critical safety** — Emergency Help, serious active-job danger.
2. **Active job** — check-ins, PINs, scope, live completion problems.
3. **Money / account security** — payment failure, payouts, suspicious login, disputes.
4. **Actionable work** — accepted jobs, applicants, scope-change requests, relevant messages.
5. **Discovery** — jobs, Explore, saved-search matches.
6. **Progression** — Motion, XP, goals, badges.
7. **Marketing / optional content**.

Context may temporarily raise an item. Marketing never outranks safety, money, or real work.

---

## 4. Roles and Primary Navigation

### 4.1 Teen

Bottom navigation:

- **Home**
- **Explore**
- **Inbox**
- **Profile**

Exactly four primary tabs. No center `+` button and no Motion tab.

### 4.2 Adult / Business

Bottom navigation:

- **Home**
- **Explore**
- **+**
- **Inbox**
- **Profile**

The center `+` is primarily **Post a job**.

### 4.3 Business staff

Business staff use the adult/business shell, with role- and permission-aware actions. Sensitive actions remain attributable to the actual staff member.

### 4.4 Internal moderator

Internal moderation is a separate staff workspace. It does not share the consumer navigation shell.

---

## 5. Visual System

### 5.1 Color

Brand palette:

- White
- Black
- Silver
- Gray
- Charcoal

Do not use blue, purple, violet, neon, rainbow gradients, or default AI-style color washes.

Semantic colors may be used sparingly when required for accessibility and meaning (for example danger, warning, success), but they must not become brand colors.

### 5.2 Light and dark mode

Light mode is the primary presentation. Dark mode must be fully designed from day one.

Dark mode uses black/near-black, charcoal, gray, silver, and white. It is not a simple color inversion.

### 5.3 Shape language

Overall layouts are clean, premium, and editorial. Interactive controls can be rounded when touch usability benefits: buttons, chips, sheets, inputs, compact interactive cards.

Avoid both extremes:

- no bubbly “everything is a pill” design
- no harsh all-square utilitarian design

### 5.4 Motion

Use subtle motion for:

- state confirmation
- sheet transitions
- Apply → Applying → Applied
- heart/bookmark feedback
- card removal
- notification banners
- progress changes
- floating active-job control state changes

Avoid giant bounce, spin, glow, particle spam, constant movement, or gratuitous celebration.

### 5.5 Reduce Motion

When OS Reduce Motion is enabled:

- remove decorative motion
- retain subtle functional transitions when they improve comprehension
- preserve state clarity without animation dependence

---

## 6. Product Copy Style

MORT copy should be concise, human, modern, and role-aware.

- **Teen:** slightly warmer, never childish or slang-heavy.
- **Adult/business:** more direct and transactional.
- **Safety:** calm, precise, action-oriented.
- **Payments:** explicit amounts, fees, holds, and timing.
- **Moderation:** neutral, factual, consequence-oriented.
- **Motion:** slightly more energetic while remaining recognizably MORT.

Avoid corporate filler. Prefer “Payment secured” over “Your request has been successfully processed.”

---

## 7. Canonical Job Lifecycle

```text
DRAFT
  ↓
PUBLISHED / OPEN
  ↓
APPLICATION RECEIVED
  ↓
APPLIED
  ↓
VIEWED
  ↓
SHORTLISTED
  ↓
ACCEPTANCE INITIATED
  ↓
PAYMENT SETUP / AUTHORIZATION
  ├── FAIL → PENDING PAYMENT SETUP
  │            ↓
  │       CHANGE PAYMENT METHOD
  │            ↓
  │       AUTHORIZATION RETRY
  │
  └── SUCCESS
          ↓
       ACCEPTED
          ↓
       SCHEDULED
          ↓
       TRAVEL / PRE-JOB
          ↓
       START PIN
          ↓
       IN PROGRESS
          ↓
       READY TO FINISH
          ↓
       ADULT COMPLETION REVIEW
          ├── ACCEPT → FINISH PIN
          │               ↓
          │           PROCESSING
          │               ↓
          │           COMPLETED
          │               ↓
          │        FUNDS AVAILABLE
          │               ↓
          │      PAYOUT / HISTORY
          │
          └── REPORT PROBLEM
                    ↓
               DISPUTE
```

Every alternate state must map back to a known lifecycle branch. Do not create orphaned “special” states that bypass history, payment, or moderation.

---

# PART I — DISCOVERY AND APPLICATION

## 8. Home

Home is the marketplace. It starts with jobs immediately.

Do **not** place before jobs:

- greeting
- profile completion card
- analytics
- earnings summary
- giant MORT logo
- persistent search bar
- dashboard stats
- promo hero

### 8.1 Home structure

1. **Quick Jobs** horizontal rail
2. Compact vertical job feed
3. Contextual modules only when relevant (for example upcoming accepted job, payment issue)

### 8.2 Quick Jobs

Quick Jobs are jobs under **30 minutes**.

Photos are optional. A text-first card must look intentional and complete. Do not generate fake task imagery when no real image exists.

### 8.3 Feed density

Compact enough to show roughly 2–3 jobs at once depending on viewport and content. Do not use full-screen TikTok-style cards.

---

## 9. Compact Job Card

Canonical hierarchy:

1. **Distance**
   - Example: `1.2 miles away from your current location`
2. **Poster identity**
   - Example: `Janet ✓ · 96% reliable`
3. **Tiny category label**
   - Example: `Yard work`
4. **Job title**
   - Example: `Mow front yard`
5. **Metadata line**
   - Example: `$25 · 20 min · Today at 4 PM`
6. **Action row**
   - Heart
   - Bookmark
   - Apply (visually strongest)

Do not show poster jobs-posted count on the compact card.

### 9.1 Heart

Heart = interest/preference signal. It immediately influences recommendations. Use a restrained tap animation.

### 9.2 Bookmark

Bookmark = save for later. It is not a recommendation signal.

### 9.3 Not interested

Right swipe = Not interested.

- Full swipe removes the card.
- Left swipe does nothing.
- No haptic on dismissal.
- Show `Not interested · Undo` for **6 seconds**.
- Undo restores the job to the exact previous position.

---

## 10. Apply Flow

Default = **one-tap Apply**.

Button state:

`Apply → Applying… → Applied ✓ → View application`

Do not use a full-screen success page for routine applications.

### 10.1 Conditional confirmation

Use a compact bottom sheet only when the job requires extra confirmation:

- special requirements
- higher-risk work
- scheduled commitment
- equipment/tools
- availability constraint

Ask only what is necessary.

### 10.2 View application

Tap `View application` → compact bottom sheet first.

Show:

- status
- time applied
- poster
- job title
- category
- scheduled time if relevant
- next action
- path to full application

---

## 11. Application Statuses

Canonical labels:

- Applied
- Viewed
- Shortlisted
- Accepted
- Not selected
- Withdrawn
- Expired

### Viewed

Immediately visible when the poster opens the application. Also create a light Inbox activity event.

### Shortlisted

Create Inbox activity with primary text `Shortlisted`.

### Accepted

Accepted is high priority.

When teen is in-app:

- show top banner for up to **8 seconds**
- user may swipe it away early
- always create a persistent Inbox Accepted item
- pin Accepted item until teen opens it
- once opened, unpin immediately and return to normal chronology

### 11.1 Acceptance summary

Open Accepted → compact summary first.

Show:

- job title/category
- poster + verification + reliability
- pay
- date/time
- estimated duration
- distance
- next required step

Scheduled job actions:

- **Confirm schedule** (primary)
- Message poster
- View full job

Under Confirm schedule:

- `Request different time`

---

## 12. Rescheduling

Request different time opens the existing job chat with an editable prefilled draft such as:

> I need to request a different time.

Show current scheduled time above the draft.

Only in this reschedule context show `Suggest time`.

Suggested times render as structured time cards.

Poster can:

- Accept
- Suggest another time

Once both agree on the same time, update schedule automatically. No redundant final confirmation.

Chat system record:

`~~Sat 3:00 PM~~ → **Sat 4:30 PM**`

Same event appears in Job Activity/History.

---

# PART II — EXPLORE AND LOCATION PRIVACY

## 13. Explore

Explore owns search.

Default structure:

1. Search bar
2. Quick categories
3. Personalized suggested searches/jobs
4. Search results

### 13.1 Quick filters

Visible chips:

- Distance
- Pay
- Duration
- Date
- Category

`All filters` opens deeper controls such as:

- transportation fit
- Quick Jobs
- verified posters
- businesses only
- schedule flexibility
- minimum reliability
- tools/equipment requirements

### 13.2 Map

Explore defaults to list/feed. A compact `Map` action opens the nearby-job map.

Before acceptance, map uses approximate privacy-safe areas only.

### 13.3 Saved searches

Users can save searches such as:

`Yard work · within 3 miles · under 30 min · $15+`

Notifications are optional per saved search.

Routing:

- one strong new match → open that job
- multiple new matches → open saved-search results with new items highlighted

---

## 14. Address and Location Privacy

Exact job location is temporary operational data, not permanent profile/history data.

### Before acceptance

Show only:

- general area/neighborhood
- calculated distance

No exact pin, street number, or coordinates.

### After acceptance / before travel

Exact address remains protected unless needed operationally.

### Travel / active-job window

Default behavior is MORT navigation. Exact destination may appear temporarily when required to complete travel/job operations.

### After completion

Exact address disappears from normal user-facing history.

History shows privacy-safe information such as:

`Broad Ripple area · 1.2 mi away`

This protects both teens and posters/businesses.

---

# PART III — JOB POSTING, APPLICANTS, AND CHECKOUT

## 15. Post Job Entry

Adult/business center `+` opens the posting flow.

First prompt:

**What do you need help with?**

Poster enters a short natural-language description. MORT suggests:

- title
- category
- estimated duration
- likely tools/requirements
- suggested pay

Poster confirms/edits all suggestions before publishing.

---

## 16. Pay Selection

MORT suggests:

- one recommended amount
- a reasonable range

Primary control:

- horizontal amount selector from **$10 to $100**
- highlight recommended amount
- `Type amount instead` for precise or >$100 values

Minimum allowed job pay: **$10**.

Live economics must be visible as pay changes:

```text
Job pay:      $25.00
MORT fee:     $2.97
Teen receives $22.03
```

The $2.97 fee is deducted from the teen’s gross job pay.

---

## 17. Duration, Schedule, Location, Tools

### Duration

Hybrid:

- MORT suggests duration
- quick chips such as 15 min / 30 min / 1 hr / 2 hr
- Custom opens more precise picker/slider

### Date/time

Hybrid:

- Today / Tomorrow / This weekend
- focused date selector
- focused time selector
- combined editable summary

### Location

Poster enters exact job address privately. Teen sees only general area + distance until the operational travel window.

### Tools/requirements

MORT suggests likely requirements based on description. Poster confirms via structured controls + optional notes.

Examples:

- Poster provides tools
- Teen brings tools
- No tools required

---

## 18. Cancellation Window Before Publish

MORT automatically assigns a late-cancellation tier:

- 1 hour
- 2 hours
- 4 hours

Based on factors such as:

- job duration
- complexity
- travel burden
- scheduling rigidity
- difficulty replacing the slot

Poster sees the assigned rule before publishing but cannot choose a softer tier manually.

---

## 19. Review and Publish

Final review shows:

1. actual teen-facing compact job card preview
2. expandable full job details

Publishing/acceptance funding uses compact checkout, not a separate billing dashboard.

---

## 20. Adult/Business Checkout

Compact popout/bottom sheet.

Show:

- job pay
- authorization/hold amount
- payment method
- cancellation policy
- teen expected net after $2.97 fee

Example:

```text
Job pay:               $25.00
Authorized today:      $25.00
Teen receives:         $22.03
Payment method:        Apple Pay
Cancellation window:   2 hours
```

Primary CTA: `Secure payment & publish` or context-equivalent.

### 20.1 Payment methods

Platform-aware options:

- Apple Pay (when available)
- Google Pay (when available)
- saved card
- debit/credit card

Selected method appears prominently. Quick alternatives may appear inline. `Change` opens a compact picker. `Manage payment methods` opens full settings only when necessary.

### 20.2 Declined payment

Reference hierarchy:

- back arrow
- clean whitespace
- compact payment illustration/icon
- headline: `Try another payment method`
- helper copy explaining decline
- sticky CTA: `Change payment method`

Failed method marked `Declined`.

Change payment method opens bottom sheet first; full management only if needed.

Successful replacement returns user to checkout and retries authorization.

---

## 21. Applicant Management

Default = smart ranking with sort options:

- Best fit
- Newest
- Closest
- Reliability

Applicant rows/cards show only decision-critical information:

- avatar
- name
- verification
- reliability
- distance
- relevant completed-job count
- skills/bio snippet
- application state

### Applicant preview

Tap applicant → mid-sized bottom sheet first.

Show:

- avatar/name
- verification
- reliability
- distance
- completed-job count
- skills
- availability
- review highlights
- application state

Actions:

- Accept
- Shortlist
- Message
- View full profile

### Compare

Normal flow is one-at-a-time. When applicant count makes comparison useful, surface Compare. Up to 3 applicants in a compact comparison view.

### Accept

Tap Accept → compact confirmation:

- teen
- job
- pay
- schedule
- payment method
- authorization amount
- cancellation window

CTA: `Accept & secure payment`.

If funding succeeds → Accepted.

If funding fails → `Pending payment setup`; job cannot become active.

### Pre-accept messaging

Allowed only in the application thread and only about that job.

### Not selected

Teen receives `Not selected` with optional short reason:

- Schedule fit
- Experience/skills
- Distance
- Chose another applicant
- Other

---

# PART IV — ACTIVE JOB EXPERIENCE

## 22. Active Job Mode

After Start PIN verification, Active Job becomes the primary full-screen work experience.

### Header

Compact combined header:

- job title
- counterparty identity
- current status
- elapsed/remaining time
- scheduled end time

### Main body

1. task scope/checklist
2. quick actions:
   - Message
   - Safety
   - Evidence
   - Job details

### Task checklist

Interactive. Teen can check off tasks.

Major scope changes/new tasks require both sides to agree before they become official.

Every accepted change is written to Job Activity/History.

---

## 23. Scope Changes

Use structured `Scope change`, not silent task additions.

May include:

- changed/new task
- extra time
- extra pay

Both sides must agree.

Accepted changes become part of the official job scope and completion summary.

---

## 24. Evidence

Evidence is available throughout the job and organized into:

- **Before**
- **During**
- **After**

Supported:

- photos
- short video
- short written note/caption per item

Both teen and adult/business may upload evidence.

Visibility:

- **Shared job evidence** — visible to both sides
- **Private-to-MORT evidence** — for disputes/safety; not shown to the other party by default

Always label uploader and timestamp.

---

## 25. Start PIN

Teen receives Start PIN.

Adult/business verifies it by:

- manual PIN entry, or
- QR/scan/tap confirmation tied to the same verification event

Start PIN success changes job to `In progress`.

Do not allow active-job state before backend verification succeeds.

---

## 26. Ready to Finish

Teen taps **Ready to finish**.

Before Finish PIN flow, show compact completion summary:

- completed tasks
- Before/During/After evidence summary
- accepted scope changes
- actual time worked
- gross job pay
- MORT fee: **$2.97 flat**
- teen final net pay

Example:

```text
Job pay:    $25.00
MORT fee:   -$2.97
You receive $22.03
```

Teen confirms readiness.

---

## 27. Adult/Business Completion Review

After teen taps Ready to finish, adult/business sees:

- completed tasks
- time worked
- evidence summary
- accepted scope changes
- gross job pay

Then:

- `Show Finish PIN`, or
- `Report a problem`

Finish PIN remains hidden before this step.

---

## 28. Finish PIN

Adult/business receives/shows Finish PIN.

Teen verifies it by:

- manual entry, or
- QR/scan/tap confirmation

Success:

`Pending → Processing → Available`

Use a brief restrained `Job complete ✓` success moment, then final completion sheet.

---

## 29. Finish PIN Problem / Completion Dispute

Adult/business may not silently withhold Finish PIN.

If they disagree, they must:

1. tap `Report a problem`
2. choose structured reason
3. optionally add evidence
4. enter formal review state

Teen may also initiate `PIN problem` if the adult refuses to provide the code.

Canonical flow:

```text
Finish PIN problem reported
        ↓
48-hour review window
        ↓
Valid dispute/reason raised?
   ├── Yes → auto-release pauses → review
   └── No  → payment auto-releases to teen
```

The UI must clearly show `Completion disputed · Payment under review` rather than leaving the teen uncertain.

---

## 30. Floating Live-Job Control

When Active Job is minimized, show a persistent **floating circular live-job control**.

Properties:

- draggable
- snaps to safe screen edges
- adaptive around keyboard/bottom nav/sheets
- contains avatar/job icon + subtle progress ring
- remains until job completion

Tap → mid-sized live-job popup.

Popup shows:

- job title
- counterparty
- status
- time remaining
- checklist progress
- Safety
- Message
- Evidence
- payment state
- Open full job

The circle may be collapsed into a tiny edge tab, but active-job access never disappears completely.

Important events:

- subtle badge
- ring state change
- restrained micro-animation

Completion:

`Active circle → Job complete ✓ → tappable receipt → disappears after a short window`

---

## 31. Adult/Business Active Job Parity

The poster side mirrors the same live-work architecture wherever actions are shared:

- full-screen active job
- floating circle
- task progress
- Message
- Evidence
- Scope Change
- Activity/History
- alerts
- completion receipt
- dates/times
- payment state

Role-specific emphasis:

**Teen**
- Start PIN owner
- Safety
- Share Status
- Emergency Help
- net earnings

**Adult/business**
- Finish PIN owner
- payment hold status
- completion review
- poster-side scope management
- dispute initiation

Private teen safety data never mirrors to the poster.

### Adult/business check-ins

Adult/business also receives lighter periodic check-ins such as:

`Is the job still going as expected?`

Quick actions:

- Yes
- Need to message
- Report an issue

No access to teen private safety details.

---

# PART V — ACTIVE-JOB SAFETY

## 32. Active-Job Safety Surface

Tap **Safety** → compact popup/bottom sheet, not a dedicated dashboard.

Top live status strip always visible, e.g.:

`Job active · Check-in due in 12 min · Share Status on`

Primary action grid:

- Check in
- Share status
- Report issue
- Emergency help

PIN state/control may appear contextually when relevant.

---

## 33. Check-Ins

Automatic check-ins occur on every active job, including short jobs.

Cadence is adaptive:

- short job → one meaningful midpoint check
- medium job → small number of spaced checks
- long job → recurring checks
- higher-risk job → somewhat more frequent

Manual Check in is always available.

Manual check-in:

- one tap
- immediate success timestamp, e.g. `Checked in · 4:32 PM`
- optional short note such as `Everything’s good` or `Need more time`

---

## 34. Missed Check-In Escalation

Staged escalation:

1. reminder
2. stronger second alert
3. emergency-contact/share-status escalation if still unresponsive

Primary trusted contact is notified first. Poster/business notification is context-dependent.

MORT must distinguish `unreachable` from `confirmed emergency`.

Trusted-contact copy should say what MORT knows, e.g.:

`MORT hasn’t received a response from Jordan since 4:18 PM during an active job.`

Do not claim danger is confirmed unless it is.

---

## 35. Dead Phone / Offline Safety

If the device becomes unreachable:

- preserve last successful MORT contact time
- preserve last synced location when legally/technically available
- do not assume missed check-in = danger
- backend escalation still follows staged rules

If teen checks in offline:

`Check-in saved · Waiting to sync`

Local timestamp is preserved and reconciled when connectivity returns.

Backend escalation may still continue if servers remain unable to contact the device for too long.

---

## 36. Low Battery Safety

Before job start, if teen battery is below **20%**:

Show a practical warning recommending charging before starting so safety features stay available.

During active job, if Low Power Mode is on and battery is below 20%:

- automatically switch to reduced-power mode
- show compact banner
- offer `Extend battery`

`Extend battery` keeps only:

- job status
- checklist
- Safety
- Message
- PIN
- check-ins
- critical alerts

Nonessential animations, media loads, and background extras are reduced.

Essential safety features remain active.

---

## 37. Share Status

First use in a job:

- choose **who**
- choose **what**

Potential shared information:

- active job state
- scheduled end time
- check-in state
- poster/business identity
- live/last-known location where enabled

After first setup, allow fast `Share again / Resume sharing` plus `Edit`.

Emergency Help may automatically enable emergency sharing.

Live sharing remains active:

- during the active job
- for **30 minutes after completion**
- then stops automatically unless ended earlier

---

## 38. Emergency Contacts

Support multiple contacts with:

- Primary / secondary priority
- per-contact permissions
  - live location
  - missed check-in alerts
  - emergency-only alerts

Default contacts are preselected per job, but teen can adjust them before Start PIN.

---

## 39. Emergency Help

Activation uses deliberate **press-and-hold or slide-to-activate**.

Start in-place inside Safety popup. On activation:

- immediately enter emergency state
- alert configured emergency contact(s)
- start/continue live status/location sharing
- launch strongest platform-permitted 911 emergency calling flow
- create private incident record
- adult/business sees neutral safety-state notice
- safety restrictions may activate

Then expand into a larger dedicated emergency sheet only when more controls/details are needed.

### Adult/business view

Show neutral high-priority notice such as:

`This job has entered a safety state. Follow MORT instructions.`

Allowed actions may include:

- End job
- Contact MORT
- Follow safety instructions

Do **not** reveal:

- teen private report details
- emergency contact information
- teen live-location data

---

## 40. Safe Exit

After Emergency Help or serious safety incident, teen must complete a safe-exit flow before returning to normal MORT.

Options:

- I’m safe now
- I left the location
- I need more help

`I need more help` keeps emergency state active.

---

## 41. Incident Records

Emergency Help automatically creates a private incident record.

Auto-preserve relevant session data such as:

- safety timeline
- check-ins
- missed-check-in escalations
- PIN events
- job-state changes
- authorized location history
- related messages/evidence references

Afterward, ask teen whether they want to add:

- notes
- photos
- screenshots
- video
- additional context

The existence of the incident record does not depend on post-event opt-in.

---

## 42. Safety Restrictions After Incident

Serious safety incidents trigger immediate provisional safeguards while triage occurs.

Higher-severity incidents may trigger stronger automatic restrictions such as:

- no teen messaging
- no new job posting
- collaboration pause
- broader account lock

Lower-severity cases may get narrower protections + expedited review.

Do not expose teen private incident details to the restricted account.

---

## 43. Safety History and Export

Profile Safety Center preserves all safety activity:

- check-ins
- missed check-ins
- reminders/escalations
- Share Status sessions
- Emergency Help activations
- reports
- blocked users
- PIN-related safety issues
- serious incidents

Routine check-ins may be visually grouped/collapsed, but remain available.

Teen can selectively export a timestamped safety report including chosen sections such as:

- job timeline
- check-ins
- incident events
- relevant messages/evidence references
- payment/PIN events

Useful for trusted adult, school official, lawyer, investigator, or other appropriate authority.

---

# PART VI — PAYMENTS, WALLET, AND CANCELLATIONS

## 44. MORT Fee

Flat **$2.97** platform fee on every completed job.

Minimum job pay: **$10**.

The fee is transparent from acceptance onward.

Example:

```text
Gross pay:        $25.00
MORT fee:         -$2.97
Expected net:     $22.03
```

---

## 45. Funding Model

At acceptance, adult/business funding must be secured before the job can become official/active.

Product states:

- `Payment setup`
- `Payment secured`
- `Pending`
- `Processing`
- `Available`
- `Under review`
- `Paid`

If authorization fails:

- acceptance may remain initiated
- state becomes `Pending payment setup`
- teen does not see funds as secured
- job cannot become active
- Start PIN remains disabled

### Technical constraint

“Payment secured at acceptance” is a product promise, not necessarily one indefinitely held card authorization. For jobs scheduled far in advance, the backend may need reauthorization, compliant revalidation, or another processor-supported funding guarantee.

UI must only say `Payment secured` when funding is truly secured.

---

## 46. Teen Wallet

Top hierarchy:

**Available** — main number

Then smaller:

- Pending
- Lifetime earnings

Primary actions:

- Cash out
- Add payout method
- View activity

Accepted-job earnings appear immediately as **Pending**, showing gross and expected net.

Pending is never styled as spendable.

### Activity feed

One chronological feed with filters:

- All
- Earnings
- Payouts
- Fees
- Adjustments

Activity may include:

- job earnings
- $2.97 fee
- pending → available transition
- payouts
- reversals/refunds
- dispute adjustments
- corrections

### Transaction detail

Detailed receipt first:

- job
- poster/business
- date/time
- gross pay
- MORT fee
- net pay
- status
- payout destination
- payout timing

Then `View full job record`.

---

## 47. Payouts

Offer both:

- **Standard payout** — slower, lower/no additional fee where supported
- **Instant payout** — faster, processor fee shown before confirmation

Instant payout is available as soon as funds are `Available`, unless restricted for legitimate fraud, compliance, payout-risk, or account-safety reasons.

Support multiple payout methods, one default, with ability to choose another destination each cash-out.

---

## 48. Adult/Business Wallet

Clean financial overview:

- Active holds
- Recent charges
- Refunds/adjustments
- Payment methods

Active hold detail:

- job
- teen
- hold amount
- date/time
- status
- cancellation window
- what releases/captures the hold
- View full job
- Manage payment method

---

## 49. Pre-Start Cancellations

Rules depend on:

- who cancels
- timing relative to start
- job cancellation tier (1h/2h/4h)
- legitimate reason
- pattern/repetition

Safety-related cancellations must not be penalized.

### Adult/business late cancel

Teen receives adaptive cancellation compensation.

Minimum/base compensation: **$1.34**.

Amount may increase based on:

- how late cancellation occurred
- whether teen already started traveling
- disruption level

### Teen late cancel

Adaptive consequence based on:

- lateness
- communication
- repeat behavior
- legitimate reason

Possible consequences:

- reliability impact
- temporary application cooldown

Safety-related cancellation is protected.

---

## 50. Leave Job Early

Teen uses structured `Leave job early`, not automatic abandonment.

Teen provides:

- reason
- time worked
- completed tasks
- optional evidence

Adult/business chooses:

- No pay
- Partial pay
- Full pay

If Partial pay:

- enter/select exact dollar amount

Teen can:

- Accept
- Dispute

If disputed:

- MORT may suggest a fair amount using job/evidence/time/message/PIN/scope history
- automated suggestion is not final
- human reviewer makes final decision when contested or ambiguous

---

# PART VII — HISTORY AND REVIEWS

## 51. Job History

Default = chronological, newest first.

Filters:

- All
- Upcoming
- Completed
- Cancelled
- Disputed

Completed job entry should expose date/time clearly.

Example fields:

- job date
- scheduled start
- actual Start PIN time
- actual Finish PIN time
- time worked
- completion timestamp
- payment release time
- payout time

If schedule changed, preserve both original and updated time.

### Receipt-first detail

Tap History entry → receipt first, then `View full job record`.

Full record may include:

- activity timeline
- scope changes
- evidence summary
- payment history
- review

---

## 52. Reviews

Reviews are optional.

Post-completion prompt:

`How did it go?`

If skipped:

- Inbox reminder after **30 minutes**
- one final reminder later the same day
- then stop forever for that job

### Review sheet

Same compact sheet:

- star rating
- quick tags
- optional written review

Public review requires star rating.

Tags-only may be submitted privately to MORT.

### Direction-specific tags

Teen → adult/business examples:

- Paid on time
- Job matched description
- Respectful
- Communicated clearly
- Was ready
- Safe environment

Adult/business → teen examples:

- On time
- Communicated well
- Completed the job
- Respectful
- Reliable
- Followed instructions

### Edit window

Published reviews can be edited for exactly **25 minutes**.

Edited review shows `Edited`.

After 25 minutes, review is permanent subject to moderation/reporting.

### Low ratings

1–2 stars still publish immediately, but MORT asks for quick reason/tag and offers `Report a serious issue` when relevant.

### Profile display

Public summary remains simple:

- overall stars
- reliability

Deeper Reviews page may show broad patterns:

- Communication
- On time
- Job matched description
- Respectful
- Safe environment

### Reviewer identity

Privacy-aware identity such as first name + verification status. MORT may reduce visible identity further for sensitive/safety reasons while preserving verified provenance internally.

### Review sorting

Default `Most relevant`, with compact filters:

- Newest
- Highest
- Lowest

---

# PART VIII — RELIABILITY

## 53. Public Reliability

Early account:

`New · Building reliability`

Do not show a public percentage until MORT has enough meaningful evidence across factors such as:

- completion
- punctuality
- communication
- cancellations
- dispute outcomes

No arbitrary exact job-count threshold.

Once mature:

`95% reliable · Highly reliable`

If long inactivity occurs, keep score visible but add freshness context such as:

`Last active 8 months ago`

---

## 54. Teen Reliability Inputs

Potential inputs:

- on-time arrival
- completion of accepted jobs
- communication when plans change
- cancellations
- no-shows
- abandonment
- verified dispute outcomes

Patterns/repetition matter more than isolated incidents.

Safety-related withdrawals must not be penalized.

---

## 55. Adult/Business Reliability Inputs

Potential inputs:

- paying on time
- accurate job descriptions
- readiness when teen arrives
- scope/pay consistency
- communication
- cancellations
- verified dispute outcomes
- safety complaints

Again, patterns matter.

---

## 56. Reliability Detail

When owner taps their score:

Show broad factors/trends, not exact internal weights.

Example:

- On-time performance: Strong
- Job completion: Strong
- Communication: Good
- Cancellations: Improving

Exact scoring formula remains private.

After a job, show a small private summary:

- improved / same / decreased
- broad reasons

Public profiles show only percentage + label, not private trend.

### Challenge score impact

If change is tied to a specific event, user may tap `Review this change`.

Automatically attach relevant:

- job record
- timestamps
- messages
- evidence
- PIN events
- moderation outcome

---

# PART IX — INBOX AND CHAT

## 57. Inbox

Call it **Inbox**.

One mixed list combining:

- messages
- application updates
- accepted jobs
- payment updates
- verification
- safety
- requests
- review reminders
- system activity

Do not create Messages/Activity tabs.

### Priority

High-priority items may pin above chronology.

Normal chronology uses subtle date separators:

- Today
- Yesterday
- Earlier

### Unread

Normal unread:

- dot
- bold title/preview

High-priority unread:

- dot
- bold
- pinned until opened

### Requests

Compact `Requests` row near the top. Fresh/important requests may also appear as pinned previews until handled.

### Filters

Default = All.

Small filter control opens:

- Messages
- Jobs
- Applications
- Payments
- Safety
- Requests

### Swipe/archive behavior

Normal chats may support Mark read / Mute / Archive.

Safety/payment/dispute items cannot be casually destructively swiped away.

Resolved critical records may leave the main Inbox but remain in permanent History/Activity/Safety/Payment records.

---

## 58. Job Chat Row

Compact row includes:

- sender
- job title
- current job/application status
- message preview
- time

Example:

`Janet ✓ · Mow front yard`  
`Accepted · “Sounds good, see you at 4.” · 2m`

---

## 59. Message Requests

Out-of-job adult/business → teen contact goes to Requests.

Before acceptance show:

- sender avatar/name
- business affiliation/verification
- profile snapshot
- first-message preview

Actions:

- Accept
- Ignore/Decline
- Block
- Report

Safety guidance should be visible but not dramatic.

---

## 60. Teen-Initiated Messaging

Teen cold DMs are not unrestricted.

Allowed when legitimate work context exists:

- question about job
- job asks user to reach out first
- collaboration/service pitch

Keep work context attached.

---

## 61. Collaboration

Teen → business structured pitch:

- service offered
- proposed price
- availability
- optional proof (photos, portfolio link, relevant MORT reviews)

Business → teen work invite:

- pay
- expected duration/time commitment
- calculated distance
- work context

Negotiation supports:

- pay
- time
- schedule

Use structured counteroffers + discussion thread attached to the offer.

### Chat `+` menu

Context-aware, text-first actions such as:

- Send offer
- Counteroffer
- Make this a job
- Send availability
- Attach proof
- Request payment terms

Do not show irrelevant actions all the time.

### Make this a job

Open compact agreement summary:

- pay
- date/time
- estimated duration
- general location/distance
- scope
- who supplies tools/materials

Show separate agreement states:

- Teen Agreed ✓
- Business Agreed ✓

After both agree, open standard job setup prefilled with agreed terms. Ask only missing required details.

Either side may revoke pre-job agreement with a reason. Preserve reason in history.

---

## 62. Chat Read/Edit/Delete

Read state is lightweight:

- `Seen` on latest outgoing message/message cluster
- no obsessive per-message read timestamps

Edits:

- short edit window
- public `Edited` label
- original version preserved privately for moderation/disputes

Deletion:

- ordinary messages may be removed from user-facing view where appropriate
- safety, payment, scope-change, PIN, dispute, and job-critical records remain preserved

---

## 63. Attachments

Support:

- photos
- short video
- selected safe file types

If attachment is formal job proof, offer `Add to Evidence` so it becomes part of official Before/During/After evidence rather than remaining buried in chat.

---

## 64. Chat Safety Scanning

Real-time graduated intervention.

Clearly dangerous content:

- block or strongly warn

Examples:

- sexual content involving minors
- threats
- coercion
- unsafe off-platform meeting attempts
- suspicious payment requests

Risky but potentially legitimate content:

- warn/contextual guardrail

Borderline patterns:

- quietly flag for moderation where appropriate

Phone numbers, emails, social handles, external payment links:

- risky off-platform contact/payment attempts blocked by default
- legitimate job-context sharing only when MORT explicitly permits it
- emergency contact flows use MORT safety tools, not normal chat

---

## 65. Post-Job Chat Window

Normal post-job chat remains open for **24 hours** after completion.

Then it becomes read-only history.

Automatic extension if unresolved:

- payment issue
- dispute
- PIN problem
- support case
- safety review
- legitimate unresolved job matter

Once resolved, thread returns to read-only history.

---

# PART X — PROFILE, MOTION, WALLET, SAFETY CENTER

## 66. Profile Top

Identity dominates.

Show:

- avatar/photo
- name
- verification
- reliability
- primary work stat

Teen primary stat: jobs completed.  
Adult/business primary stat: jobs posted.

Motion appears immediately below but visually secondary.

---

## 67. Profile Body

Hybrid organization:

### Compact modules near top

- Wallet
- Motion
- Recent activity/job

### Utility rows

- Reviews
- Safety Center
- Saved jobs
- Verification
- Payment methods
- Settings
- Help & support

Avoid card soup.

### Wallet module

Show:

- Available
- Pending
- Open Wallet

### History module

Profile is not the main History destination. Show only a small recent-job/activity preview + `View all`.

### Reviews

Summary near top, detailed Reviews page on tap.

---

## 68. Safety Center (Profile)

Visible in upper half of Profile as a compact shield row/module.

Not alarmist.

Contains broader safety management:

- emergency contacts
- Share Status settings
- safety settings
- blocked users
- safety history
- safety education
- compact Emergency Help action always available

---

## 69. Motion Hub

Profile shows compact progression snapshot:

- rank
- level
- XP progress
- token balance preview

Tap opens dedicated Motion hub.

### Header

Primary:

- Rank
- Level
- XP bar

Secondary directly underneath:

- current goal
- safety streak

### Motion Tokens

Small balance near top. Full earning/spending history in Rewards section.

### Level-up

Short restrained moment:

- new level
- tokens earned
- unlocks

Then return to prior context.

### Rank visuals

Ranks:

- Bronze
- Silver
- Gold
- Platinum
- Diamond

Use unique badge shapes/material treatments within the monochrome system. No rainbow colors.

### Leaderboards

Private by default, opt-in only.

Possible privacy-safe scopes:

- Friends
- Local
- School/community
- Category

Do not expose exact location or private verification data.

### Goals

MORT suggests goals, teen can create custom goals.

Examples:

- Complete 3 jobs this week
- Maintain a safety streak
- Earn $50
- Reach next level

### Cosmetics

May include:

- profile frames
- badge treatments
- avatar effects
- subtle Motion themes
- restrained card/profile accents

Never interfere with readability or make the marketplace feel gamey.

### Safety Streak

Primarily based on completing required safety check-ins.

Also requires no unresolved safety violations or ignored critical safety alerts.

Using Emergency Help correctly must **not** break a streak.

---

# PART XI — VERIFICATION AND BUSINESS ACCOUNTS

## 70. Verification Goal

Teen verification is shown as one overall `MORT Verified` goal with separate required components.

Example:

`Identity ✓ · School pending`

Full teen check appears only when required components are complete.

---

## 71. School Selection

Search/select structured school record showing information such as:

- school name
- city
- district
- grade span

Behind the scenes use:

- NCES ID
- state school ID
- school type
- district
- grade span
- verified domain(s)

School domains are evidence, not school identity.

---

## 72. Teen School Verification

**School ID front + back are mandatory.**

If school has a recognized student-email system:

- school email required
- school ID front/back required

If school has no usable verified student-email system:

- school ID front/back required
- approved alternate/manual path replaces email requirement

If email domain is unrecognized:

- Try another school email
- Continue with School ID
- Request review

A valid School ID can allow progress even when domain recognition fails, subject to the school’s verification rules.

---

## 73. Teen Identity Verification by Age

### Ages 13–14

No government ID requirement by default.

Use:

- School ID
- school verification
- selfie/liveness
- automated checks
- manual review when confidence is insufficient

### Age 15

Government ID if available; alternate route if genuinely unavailable.

### Age 16

Government ID expected where available + selfie/liveness. Legitimate no-ID fallback remains.

### Age 17

Government ID + selfie/liveness is standard. Legitimate alternate/manual review remains if acceptable ID is genuinely unavailable.

### No-government-ID route

Use:

- School ID
- selfie/liveness
- school email or approved alternate school evidence

Automated first; manual review when uncertain or inconsistent.

---

## 74. Adult Verification

Required before posting jobs:

- government ID
- selfie/liveness
- payment-method verification

Payment-method verification uses a temporary **$1.25 authorization**, voided/released after verification.

UI must explain that the bank may temporarily continue displaying the pending authorization.

---

## 75. Business Verification

Require both business and controlling person verification:

- legal business name
- business registration / EIN or equivalent identifier where applicable
- business contact/address details (kept appropriately private)
- proof owner/admin is authorized to act for business
- owner/admin government ID
- owner/admin selfie/liveness
- verified business payment method
- temporary $1.25 payment-method authorization, released/voided after verification

Verified businesses use a distinct business/building badge.

Do not imply individual staff are MORT-verified solely because the business is verified.

---

## 76. Business Staff

Business supports multiple staff accounts.

Preset roles:

- Owner
- Admin
- Manager
- Poster
- Staff

Owner/admin can customize underlying permissions.

Possible permissions:

- post jobs
- message teens
- manage applicants
- approve scope changes
- handle payments
- view sensitive job data
- invite/remove staff
- manage permissions

Verification scales with permissions. Higher-risk capabilities require stronger identity verification.

Every important action remains attributable to the staff member who performed it.

### Staff view

Header summary example:

`8 staff · 3 can post jobs · 2 admins`

Each row:

- name
- role
- verification level
- access/status

### Staff detail

- identity/verification
- role
- editable permissions
- compact recent actions log

### Invites

Owner chooses preset role during invite and sees included permissions. Permissions activate only after the staff member joins and completes required verification.

### Permission reduction / staff removal

Forbidden actions stop immediately.

Affected active jobs/threads must be reassigned to another authorized staff member.

Historical attribution remains.

### Sensitive permission changes

Require:

- confirmation
- clear consequence preview
- permanent business audit log entry showing who changed what and when

---

# PART XII — BLOCKING, REPORTING, MODERATION, SUPPORT

## 77. Blocking

Blocking an adult/business:

- stops messaging immediately
- removes both sides from normal discovery/recommendations
- blocks new collaboration/contact attempts
- preserves historical jobs, receipts, reviews, evidence, and history
- unresolved job/payment/dispute records remain accessible as needed

Blocking does not erase accountability.

### Blocking during active job

Open safety resolution flow:

- End job safely
- Continue with restrictions
- Report issue

Apply stronger protections immediately. If job continues, only minimum work-critical communication remains.

---

## 78. Reporting

`Report issue` from Safety uses quick category first, then short context-specific form.

Categories:

- Safety concern
- Poster behavior
- Job conditions
- Payment/PIN problem
- Other

After report submission, always offer `Block this user too`; recommend it more strongly for harassment, threats, unsafe behavior, inappropriate contact, or coercion.

---

## 79. Risk-Based Restrictions

Severity matters more than raw report count.

MORT may weigh:

- threats
- harassment
- inappropriate contact
- unsafe job conditions
- payment abuse
- repeat behavior
- corroborating evidence
- prior verified incidents

Temporary restriction model:

- freeze new activity immediately when warranted
- review already scheduled jobs
- cancel, reassign, or allow with extra safeguards depending on severity

Affected teens must not receive reliability penalties for MORT-imposed safety actions.

---

## 80. User Case Tracker

Serious report/dispute status:

`Submitted → Evidence received → Under review → More info needed → Resolved`

Users may add evidence while case is open.

New evidence is appended and timestamped. Previously submitted evidence cannot be silently edited/deleted.

Resolved decision shows:

- decision
- short reason
- payment effect
- reliability effect
- account restriction effect
- job status effect

### Appeals

One normal appeal per case.

Appeal goes to a different reviewer/team by default.

Further review only if genuinely new evidence appears or an authorized exception applies.

---

## 81. Help + Support

Help opens with:

- prominent search
- category shortcuts
- clear support chat access

Categories:

- Jobs
- Payments
- Verification
- Safety
- Account
- Business
- Report a problem

### Support chat

Bot may resolve routine issues.

Human escalation is built into the same experience.

When escalating:

- MORT suggests relevant job/payment/verification/safety context
- user reviews what will be shared
- user may remove unnecessary context
- then send to human agent

### Support case tracker

Statuses:

- Open
- Waiting on you
- Waiting on MORT
- Resolved

Link support case to underlying job/payment/verification/safety/moderation record where applicable.

### Priority support

MORT automatically detects likely urgent cases and user may also mark `This is urgent` with a short reason.

Examples:

- active-job safety
- account takeover
- payment lock
- serious misconduct
- verification lockout blocking active work

If support case relates to active job:

- full support conversation stays in Help
- active-job UI shows compact `Support case active` + `View case`

---

# PART XIII — SETTINGS, PRIVACY, SECURITY, NOTIFICATIONS

## 82. Settings Structure

Grouped sections, most-used controls first:

- Account
- Privacy
- Safety
- Notifications
- Payments
- Appearance
- Help
- Legal/advanced lower down

---

## 83. Location Privacy Controls

Master location control + separate sub-controls:

- Job discovery
- Active-job navigation
- Live Safety Sharing

Before turning a sub-control off, explain which features will stop working.

---

## 84. Privacy & Permissions

Settings shows compact privacy summary.

Deeper page shows:

- Location
- Camera
- Photos
- Notifications
- Emergency contacts
- Biometrics
- Microphone
- other required platform permissions

Clearly distinguish:

- OS permission
- MORT feature-level sharing

### Data retention

Show what is retained and why, including sensitive categories such as:

- verification documents
- safety records
- evidence
- moderation records
- payment/job history

Allow deletion/export requests where legally/operationally permitted.

Explain when records must remain temporarily due to:

- active disputes
- safety investigations
- fraud prevention
- compliance/legal obligations

---

## 85. Discoverability and Contact Controls

User may turn off new discovery/collaboration visibility without deleting account.

Effects:

- stops new recommendations/search visibility
- stops new collaboration invites
- existing jobs/history/reviews remain
- active jobs continue
- user may re-enable later

Contact controls use safe role-based defaults with granular options:

- job-related messages
- application threads
- collaboration invites
- business outreach
- message requests
- repeat contact from past posters when permitted

Teen controls never become unrestricted “anyone can DM me.”

---

## 86. Security & Devices

Show:

- current device
- recent sessions/devices
- last active time
- approximate device/location context
- suspicious activity warnings

Controls:

- Sign out device
- Sign out all other devices

---

## 87. Notifications

Master notification control + category controls:

- Jobs
- Messages
- Payments
- Safety
- Motion
- Marketing

Marketing is explicit opt-in and separate from operational/safety notifications.

### Active-job mandatory/high priority set

- Emergency Help
- missed/overdue check-ins
- Start/Finish PIN problems
- active-job payment problems
- serious scope/safety disputes

### Normal job defaults

Push + Inbox by default:

- Accepted
- Payment available
- New message
- Saved-search match

Mostly Inbox:

- Viewed
- other light status updates

### Quiet Hours

Optional MORT Quiet Hours for normal notifications.

Active-job high-priority/critical safety can bypass MORT’s own quiet mode, subject to OS restrictions.

### Bundling

Bundle routine events such as:

- Viewed updates
- Motion activity
- low-priority system events

Do not bundle:

- Accepted
- Payment available
- important new messages
- saved-search match
- high/critical safety events

Routine notifications may bundle when several accumulate and may also produce one daily summary if unread low-priority activity remains.

Daily summary default time is sensible, but user may choose:

- Morning
- Afternoon
- Evening
- Custom

---

# PART XIV — AUTHENTICATION AND SECURITY

## 88. Auth Entry

Minimal auth screen.

Primary options:

- Continue with Apple
- Continue with Google
- Continue with email

Do not ask teen/adult/business role first.

### Email auth

Default = 6-digit email code.

Password/passkey may be set up later.

### Passkeys/biometrics

Offer after first successful login, never require.

Use Face ID/Touch ID/Android biometrics/passkeys when available.

---

## 89. New Device / Step-Up Verification

Normal sign-in first.

Trigger extra verification for:

- unusual devices
- suspicious activity
- payout/payment changes
- sensitive verification edits
- safety-sensitive/high-risk account actions

### Recovery

Use trusted recovery methods first.

If unavailable, escalate to identity re-verification/manual review for sensitive accounts.

### Suspicious activity state

Risk-based temporary security state.

Possible restrictions:

- payouts
- payment changes
- verification edits
- job posting
- teen messaging
- staff permission changes

Clear state by:

1. strongest convenient re-auth (passkey/biometric/email code)
2. identity re-verification if risk remains
3. manual review if still uncertain

---

# PART XV — OFFLINE, RECOVERY, ACCESSIBILITY

## 90. Offline Active Job

Essential active-job functions remain available offline:

- cached job details
- checklist
- cached scope
- poster identity
- Safety UI
- recent messages
- captured evidence/drafts
- floating live-job control

Actions that can safely queue may sync later.

Server-required actions clearly show `Waiting for connection`, including:

- PIN verification
- payment release
- live sharing
- sending report/dispute
- new outbound messages

Never display success when server confirmation has not happened.

---

## 91. Crash / Force Close / Restart Recovery

If active job still exists on reopen:

Show brief `Job still in progress` recovery state.

Restore as much cached state as possible:

- checklist
- scope
- evidence drafts
- timing
- active-job state

Unsynced actions show `Waiting to sync`.

Teen may minimize back into floating circle.

---

## 92. Accessibility Baseline

Required from day one:

- Dynamic Type / font scaling
- screen-reader semantics
- large tap targets
- Reduce Motion support
- strong contrast
- accessible error states
- keyboard navigation where relevant
- status never communicated by color alone
- Android back behavior
- iOS gesture compatibility

Monochrome hierarchy must rely on typography, spacing, iconography, labels, and surface treatment—not just color.

---

# PART XVI — INTERNAL MODERATION WORKSPACE

## 93. Moderator Home

Default workspace = priority case queue.

Order by:

- severity
- urgency
- active-job risk
- payment deadline
- safety risk

Stats/charts are secondary.

Priority case types may include:

- active-job safety incidents
- emergency cases
- payment/PIN disputes
- account takeover/security cases
- misconduct reports
- verification reviews
- appeals

---

## 94. Moderator Case Workspace

Top summary:

- case type
- severity
- parties
- current restriction state
- deadline/SLA
- recommended next action

Tabs:

- Timeline
- Evidence
- Messages
- Payments
- Account/Trust history

---

## 95. System Recommendations and Human Decision

MORT may suggest:

- No action
- Warning
- Temporary restriction
- Payment release
- Account suspension
- Escalate

Human moderator must confirm or override.

Final decision remains attributable to reviewer.

When moderator takes meaningful action:

- require internal reason
- generate separate user-facing explanation
- moderator reviews user-facing explanation before sending

---

## 96. Restriction Controls

Preset levels for speed, with granular controls underneath.

Possible granular controls:

- no teen messaging
- no job posting
- no payments
- no payouts
- no staff management
- no new collaborations
- full suspension

Every restriction shows:

- what it blocks
- start time
- reviewer
- expiry (if any)
- conditions to restore access

High-impact actions may require two-person approval when severity/financial/safety thresholds are crossed.

Examples:

- permanent bans
- serious teen-safety findings
- large payment reversals
- overriding identity verification
- restoring heavily restricted account

---

## 97. Moderator Audit Trail

Authorized staff can see full audit history showing who:

- viewed case
- changed status
- applied restriction
- released/held payment
- escalated
- requested more evidence
- approved appeal
- overrode recommendation

All timestamped.

Especially sensitive internal notes remain role-gated.

Resolved cases may be reopened only for:

- new evidence
- valid appeal
- linked safety incident
- authorized supervisor reopening with recorded reason

---

# PART XVII — COMPONENT AND INTERACTION LANGUAGE

## 98. Shared Component Defaults

Standardize where it improves learning:

- bottom sheets
- confirmation sheets
- status banners
- snackbars
- profile previews
- filters
- action menus
- loading states
- empty states
- error states
- verification badges
- reliability labels
- receipt patterns
- activity timeline rows

Allow intentional special cases when justified:

- Safety critical interruption
- native Apple Pay/Google Pay
- Motion progression moments
- onboarding whitespace
- dense Inbox
- floating Active Job control

---

## 99. Destructive / High-Impact Actions

Low-risk destructive action:

- simple confirmation may be enough

High-impact action:

- confirmation
- required reason when relevant
- consequence preview

Examples:

- Cancel active job
- Remove staff
- Block user
- Revoke agreement
- Delete account
- Suspend account

Consequence preview should explain effects on:

- payment
- reliability
- notifications
- reassignment
- history retention
- other party

---

## 100. Loading, Empty, Error, Restricted States

### Loading

Prefer:

- skeletons for feed
- inline loading for button actions
- compact progress indicators

Avoid full-screen spinner after every tap.

### Empty states

Design intentionally:

- No nearby jobs
- No saved jobs
- No messages
- No applications
- No reviews
- No wallet activity

Always provide useful next step.

### Error states

Avoid generic `Something went wrong`.

Explain:

- what failed
- whether action succeeded or not
- what user can do next

### Restricted states

Clearly explain:

- what action is unavailable
- why at a high level
- whether temporary
- what next step exists

Do not expose sensitive moderation details.

---

# PART XVIII — REQUIRED PROTOTYPE FLOWS

## 101. Teen Onboarding

Splash → Welcome → Auth → Intent → Birthday → Name → School selection → School verification → Identity verification → Location → Transportation → Optional photo → Safety education → Completion → Home

Onboarding rules:

- one meaningful decision per screen
- concise copy
- strong hierarchy
- generous whitespace
- sticky primary CTA when appropriate
- lightweight progress indicator
- no giant multi-field form

---

## 102. Teen Discovery/Application

Home → Quick Jobs → vertical feed → Heart → Bookmark → Not interested swipe → Undo → Apply → Applied → View application

---

## 103. Acceptance/Scheduling

Applied → Viewed → Shortlisted → Accepted banner → pinned Inbox item → acceptance summary → Confirm schedule / Request different time → structured rescheduling → schedule update

---

## 104. Adult Posting/Checkout

Home → + → natural-language job prompt → AI suggestions → pay control → duration → schedule → location → tools/requirements → cancellation window → job-card preview → checkout → payment secured → publish

Include declined-payment recovery.

---

## 105. Applicant Management

Applicants → smart-ranked list → applicant preview → shortlist/message/compare → Accept → compact confirmation → secure payment → Accepted

---

## 106. Active Job

Accepted → travel → Start PIN/QR → Active Job → checklist → check-ins → Safety popup → evidence → scope change → Ready to finish → adult review → Finish PIN/QR → Processing → Job complete → Wallet/History

---

## 107. Safety Incident

Active Job → Safety popup → Emergency Help hold/slide → emergency state → trusted-contact alert → live sharing → OS emergency-call flow → private incident record → temporary restriction → Safe Exit → Safety History/export

---

## 108. Finish PIN Dispute

Ready to finish → adult reports problem / teen PIN problem → evidence → 48-hour review window → auto-release absent valid dispute OR formal review → resolution → payment/reliability consequence summary

---

## 109. Early Exit

Active Job → Leave job early → reason/time/evidence → adult chooses No/Partial/Full → exact amount if partial → teen Accept/Dispute → MORT recommendation if needed → human review when contested

---

## 110. Collaboration

Teen business profile → structured pitch → business response → negotiation → counteroffer → work chat → Make this a job → both agree → standard job setup prefilled

Also prototype business → teen invite with pay/duration/distance and Accept/Counteroffer/Decline.

---

## 111. Reviews

Job complete → optional review → skip → 30-minute reminder → final same-day reminder → submit review → 25-minute edit state → permanent review → report/moderation path

---

## 112. Verification

Teen school record → email/domain handling → School ID front/back → identity/liveness → pending/approved/manual review

Adult ID/liveness/payment verification → $1.25 temp auth → verified

Business legal/owner/payment/authority verification → verified business badge

---

## 113. Business Staff

Business Profile → Staff → invite → role → verification → permissions → staff detail → permission change → audit log → staff removal/reassignment

---

## 114. Support/Moderation

Help → search/category → support bot → escalate → review context → human case → status tracking

User report → case tracker → add evidence → resolution → appeal

Moderator queue → case workspace → recommended action → human decision → restriction/payment action → audit log

---

# PART XIX — QA / ACCEPTANCE CRITERIA

## 115. Product Comprehension

A first-time teen should understand Home within ~2 seconds.

They should immediately understand:

- distance
- poster identity
- reliability
- job type
- pay
- duration
- time
- Apply

---

## 116. Safety QA

Verify:

- Safety popup is reachable in one tap from Active Job
- check-ins occur on short, medium, and long jobs
- missed check-in escalation works
- offline check-in timestamps reconcile correctly
- dead-phone/unreachable state does not falsely claim emergency
- low-battery warning appears under 20%
- Share Status permissions are scoped correctly
- 30-minute post-job sharing grace stops automatically
- Emergency Help deliberate activation prevents accidental trigger
- OS emergency-call constraints are respected
- Safe Exit is required after serious emergency state
- teen private safety data is never exposed to poster/business
- incident record is created and exportable

---

## 117. Payment QA

Verify:

- $10 minimum enforced
- $2.97 flat fee always displayed consistently
- gross/net math correct everywhere
- Pending earnings appears only after funding is truly secured
- failed authorization cannot create active job
- Start PIN disabled before funding security
- Finish PIN dispute opens formal state
- 48-hour no-valid-dispute path auto-releases
- payout states reflect processor truth
- $1.25 verification authorization is clearly temporary
- long-scheduled jobs handle reauthorization correctly

---

## 118. Privacy QA

Verify:

- no exact address before operational need
- exact address disappears from normal history after job
- public profiles never expose phone/email/verification documents/private school data
- private-to-MORT evidence stays private by default
- business staff do not inherit personal verification incorrectly
- blocked users disappear from discovery but history remains
- safety exports default to minimum necessary information

---

## 119. Accessibility QA

Test:

- Dynamic Type / large fonts
- screen readers
- high contrast
- Reduce Motion
- large touch targets
- keyboard behavior
- Android back navigation
- iOS gestures
- state labels without color dependence
- dark mode parity
- small/standard/large Android and iPhone sizes

---

## 120. Cross-Role Parity QA

For every lifecycle state, verify Teen vs Adult/Business views are consistent where shared and intentionally different where required.

No role should have a dead-end state where the other side has moved on.

Critical parity examples:

- acceptance/payment secured
- schedule changes
- Start PIN
- scope changes
- evidence
- Ready to finish
- Finish PIN
- dispute
- payment release
- cancellation
- support case

---

# PART XX — IMPLEMENTATION CONSTRAINTS AND EXTERNAL GATES

## 121. Payment Authorization Constraint

Do not assume card authorizations can stay valid indefinitely for far-future jobs. Backend must use processor-supported funding guarantees or reauthorization.

The UI may only promise `Payment secured` when backend state supports it.

---

## 122. Emergency Calling Constraint

Do not claim MORT can silently dial 911 if iOS/Android prohibit it.

Use strongest platform-permitted emergency-call flow.

---

## 123. Notification Constraint

MORT can bypass its own Quiet Hours, but cannot override every OS Do Not Disturb/notification restriction.

When app is open, critical in-app safety state is the reliable fallback.

---

## 124. Legal/Compliance Review Required

Before production enablement, external review is still required for areas such as:

- minors and marketplace work rules
- payments/escrow/authorization language
- payout eligibility
- identity verification and document retention
- school-data handling
- background-check representations
- emergency/safety claims
- dispute and cancellation language
- moderation and data retention
- privacy notices/consent

The UX should be designed now, but production claims must match actual legal/process capabilities.

---

# PART XXI — SUPERSEDED DESIGN DIRECTIONS

The following older ideas are no longer canonical:

- separate Teen Home / Adult Home products
- shared five-tab nav for all users
- Motion as a teen bottom-navigation tab
- permanent Home search bar
- Home analytics/dashboard cards
- blue/violet brand accents
- permanent exact address after acceptance
- full-screen job feed cards
- one-sided PIN ownership
- Safety as a separate active-job dashboard
- check-ins only for long jobs
- generic post-job history without exact timestamps
- public jobs-posted count on compact cards/mini profile
- public reliability trend details
- open-ended post-job chat forever
- hidden fee until completion
- percentage MORT fee

---

# PART XXII — DEFINITION OF DONE FOR UI/UX DESIGN

The MORT UI/UX design phase is considered complete when:

1. All flows in Parts XVIII are represented in an interactive prototype.
2. Light/dark themes are complete.
3. Teen/adult/business parity is verified.
4. Active Job + Safety are fully connected, including offline/dead-phone states.
5. Payment states are truthful to backend state.
6. Address privacy rules are applied consistently.
7. Verification badges match actual evidence semantics.
8. Inbox, History, Wallet, Safety Center, and Motion are connected to the same underlying job lifecycle.
9. Moderator/admin flows can resolve every dispute/safety/payment branch without orphaned states.
10. Accessibility and Reduce Motion are included from the start, not retrofitted.
11. No screen violates the global attention hierarchy.
12. The final prototype feels like one mature consumer product, not a collection of disconnected AI-generated screens.

---

## Final Design Statement

MORT should feel familiar enough that a teenager or adult immediately understands how to use it, but original enough that it is unmistakably MORT.

The product is **jobs-first, safety-aware, payment-transparent, privacy-conscious, role-consistent, and progression-enabled**.

Its visual identity is deliberately restrained:

> **White. Black. Silver. Gray. Fast. Calm. Trustworthy.**

The core experience must always favor real work and user safety over dashboards, decoration, or novelty.
