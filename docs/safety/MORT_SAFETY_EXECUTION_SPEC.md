MORT SAFETY CENTER — CODEX FULL EXECUTION PROMPT

You are working on the REAL existing MORT application.

This is an EXECUTION task.

Do not just plan.
Do not just audit.
Do not just explain.
Inspect the real repository, implement the approved Safety system, test it, self-audit it, fix defects, and report exact status.

==================================================
PROJECT IDENTITY
==================================================

Repository:
mortapp/Mort

Expected local repo:
C:\Users\micha\Mort

Client:
Flutter / Dart

Targets:
Android + iOS

Backend:
Existing Supabase PostgreSQL / Auth / Storage / RLS / Edge Functions

Marketplace payments:
Stripe

Digital MORT Pro:
RevenueCat

Ads:
AdMob where already supported

DO NOT BUILD:
- Next.js replacement
- React replacement
- standalone Safety website
- duplicate MORT app
- duplicate backend
- second parallel Supabase schema

The MORT Safety Center belongs INSIDE the existing Flutter app.

==================================================
AUTHORITATIVE SAFETY SPEC
==================================================

I am also providing the dedicated:

MORT SAFETY SKILL.md

READ THE ENTIRE SAFETY SKILL FIRST.

Treat it as the authoritative product and safety specification.

Do NOT substitute:
- an older general MORT constitution
- payment handoff documents
- RevenueCat plans
- previous unrelated prompts

If existing code conflicts with the Safety skill, inspect why before changing anything.

==================================================
NO SUBAGENTS
==================================================

Work single-agent and sequentially.

Do not spawn multiple agents.
Do not use parallel AI workers.

Use the available Codex effort on the actual repo.

==================================================
PHASE 0 — VERIFY REPOSITORY
==================================================

Run:

git -C C:\Users\micha\Mort rev-parse --show-toplevel
git -C C:\Users\micha\Mort remote -v
git -C C:\Users\micha\Mort status --short
git -C C:\Users\micha\Mort branch --show-current
git -C C:\Users\micha\Mort rev-parse HEAD
git -C C:\Users\micha\Mort worktree list

Confirm this is mortapp/Mort.

There are existing worktrees.

DO NOT use or modify old payment-specific worktrees for Safety.

In particular, do not implement Safety in any worktree named like:

read-mort-payment...
payment...
revenuecat...
monetization...

If a dedicated clean Safety worktree already exists, use it.

Otherwise, if the main repo contains unrelated dirty work, create:

Branch:
feature/mort-safety-center

Worktree:
C:\Users\micha\Mort.worktrees\feature-mort-safety-center

Do not delete existing worktrees.
Do not overwrite unrelated dirty changes.
Do not merge.
Do not activate production.

==================================================
LOCATE REAL FLUTTER ROOT
==================================================

Find pubspec.yaml.

Do not assume the repo root is the Flutter root.

The Flutter app may live under:

flutter_mort\

Verify first.

==================================================
PHASE 1 — FORENSICS
==================================================

Before changing code, inspect the real implementation for:

- authentication
- role model
- teen flows
- adult/business flows
- guardian flows
- admin/staff flows
- jobs
- applications
- accepted jobs
- job status machine
- travel status
- I'm On My Way
- I'm Here
- Start PIN
- Finish PIN
- active job state
- messaging
- notifications
- location
- background location
- battery
- connectivity
- offline persistence
- reports
- blocking
- evidence
- support
- moderation
- audit logging
- ratings
- disputes
- Stripe
- RevenueCat
- progression
- ads
- feature flags
- accessibility
- reduced motion

Search broadly for:

safety
guardian
trusted
emergency
panic
check
check_in
start_pin
finish_pin
travel
location
battery
offline
connection
report
block
evidence
moderation
audit
notification
arrival

Do not infer implementation from filenames only.

Read the code.

==================================================
PHASE 2 — SUPABASE FORENSICS
==================================================

Read the existing Supabase migrations before writing any SQL.

Identify canonical tables and backend logic for:

profiles
roles
jobs
applications
assignments
guardians
trusted contacts
messages
blocks
reports
evidence
notifications
ratings
payments
disputes
verification
moderation
staff roles
audit logs
progression
job status history
location/safety state

Inspect:

RLS policies
RPCs
Edge Functions
Storage buckets
Storage policies
triggers
scheduled jobs
service-role-only behavior

DO NOT duplicate an existing MORT concept.

Extend canonical architecture.

==================================================
PHASE 3 — SAFETY GAP AUDIT
==================================================

Classify every subsystem as:

EXISTS_AND_VERIFIED
EXISTS_BUT_INCOMPLETE
MISSING
EXTERNAL_GATE
OS_LIMITATION
CONFLICT_REQUIRES_DECISION

Audit:

Safety Center
Emergency Panel
Opening Emergency Sends Nothing
Guardian + Trusted Alert
60-Minute Live Sharing
Guardian Cannot Start Tracking
Manual I'm On My Way
Poster ETA Privacy
Nearby State
I'm Here
Start PIN
6-Minute Check-Ins
First Miss Reminder
Second Miss Escalation
2/5/15 Offline Escalation
Battery Prediction
Automatic Safety Battery Saver
15% Warning
5% Final Snapshot
Dead-Phone Travel
Dead-Phone Arrival
Reschedule
Reconnect
Safety Exit
Safety Exit Bypasses Finish PIN
Finish PIN
Final Safe Departure
Guardian UX
Trusted Contact UX
Urgent Contact Poster
Adult Safety UX
Safety Contact
Reports
Evidence
Blocking
Retaliation Protection
Safety Review Hold
Moderation
Audit Trail
Offline-First Safety
Reduced Motion
Android
iOS

DO NOT STOP AFTER THE AUDIT.

Continue into implementation unless there is a real owner or external blocker.

==================================================
IMPLEMENTATION METHOD
==================================================

Implement sequentially.

For each subsystem:

1. inspect existing code
2. reuse existing architecture
3. make smallest correct change
4. add backend/RLS changes if required
5. add tests
6. run focused tests
7. fix failures
8. run security/negative tests
9. continue

Do not create a huge untested code dump.

==================================================
CURRENT MORT VISUAL SYSTEM
==================================================

Preserve existing UI.

Use:

BLACK
WHITE
SILVER
GRAPHITE
CHARCOAL
restrained COOL BLUE

Attention:
AMBER

Urgent/emergency:
RESTRAINED RED

Do NOT revive old purple styling.

Do NOT redesign unrelated app screens.

==================================================
SAFETY MUST BE FREE
==================================================

MORT Pro must never gate or improve:

Safety Center
Emergency
Check-ins
Guardian safety
Trusted contact safety
Safety Exit
Live Safety Sharing
Reports
Block
Evidence
Offline safety
Location safety
Support escalation

RevenueCat has ZERO authority over safety.

Suppress on critical Safety screens:

ads
Pro prompts
companion overlays
floating pets
promotional UI

==================================================
TEEN SAFETY CENTER
==================================================

Build/complete the real Flutter Safety Center.

Normal:

You're Safe
No active safety alerts

Active job:

Job Safety Active

Show:

job title
remaining time
next 6-minute check-in
last successful check-in
battery
connection
Safety Battery Saver

Primary actions:

Emergency
I'm Safe
Leave This Job

Sections:

Active Job Safety
People Looking Out for You
Live Safety Sharing
Device Safety
Reports & Help
Safety Settings
Who Can See What

Teen must always be able to understand:

what is being shared
with whom
for how long

==================================================
EMERGENCY PANEL
==================================================

Opening Emergency sends NOTHING.

It opens immediately.

No:
- PIN
- password
- biometric gate
- paywall
- ad
- companion
- heavy animation

Actions:

ALERT MY SAFETY CONTACTS
CALL 911
LEAVE THIS JOB
SHARE LIVE LOCATION

==================================================
ALERT MY SAFETY CONTACTS
==================================================

When teen explicitly presses it:

Notify BOTH:

guardian
trusted/emergency contact

Include:

teen identity
active job
timestamp
current confirmed location
battery
connection
last check-in
safety event

Start:

60-minute Live Safety Sharing

Never show Sent until backend acknowledgment.

==================================================
LIVE SAFETY SHARING
==================================================

Duration:

60 minutes

Teen can:

Stop Sharing
Extend 60 Minutes

Guardian cannot extend.
Trusted contact cannot extend.
Guardian cannot start tracking.

When timer ends:

live updates actually stop.

Do not continue hidden tracking.

==================================================
CALL 911
==================================================

Use native OS emergency calling handoff.

Never claim:

911 contacted
police notified
emergency services dispatched

unless actual confirmation exists.

Safe language:

Emergency call opened

==================================================
SAFETY EXIT
==================================================

Teen taps:

Leave This Job

Show one confirmation:

Leave this job for safety?

You do not need the poster's permission or Finish PIN to leave.

LEAVE NOW
STAY AT JOB

On Leave Now:

stop normal active job flow
create Safety Exit state
bypass Finish PIN
preserve job evidence
preserve messages
preserve check-in history
notify guardian
notify trusted contact
send poster a neutral notice
apply retaliation protection
open post-incident options

Teen must never need adult permission to physically leave.

==================================================
START PIN
==================================================

Reuse/extend existing Start PIN.

Requirements:

temporary
job-scoped
server-authoritative
rate-limited
not reusable

Flow:

I'm Here
→ Start PIN
→ valid
→ In Progress
→ Safety monitoring active

Poster cannot complete teen's side.

Invalid PIN:

stay in Awaiting Start PIN
rate-limit repeated attempts
keep Safety accessible

==================================================
6-MINUTE CHECK-INS
==================================================

While job is In Progress:

Safety check-in every:

6 MINUTES

UI:

Quick safety check
Everything okay?

I'M SAFE
I NEED HELP
LEAVE JOB

Do NOT turn this into high-accuracy GPS polling every six minutes.

==================================================
MISSED CHECK-IN
==================================================

DEVICE ONLINE:

First consecutive miss:

remind teen only

No family alert
No penalty

Second consecutive miss:

Safety Attention
notify guardian
escalate trusted-contact path

Teen actions:

I'm Safe
I Need Help
Leave Job

Do not automatically classify this as Emergency.

==================================================
OFFLINE DEVICE
==================================================

Offline is separate from missed check-ins.

0–2 minutes:
quiet retry

2 minutes:
Connection Lost

5 minutes:
notify guardian + trusted contact

15 minutes:
Safety Attention

Preserve:

last check-in
last valid location
last battery
job/travel state
timestamp

Recipient actions:

Call Teen
Message Teen
View Last Known Location
View Active Job
Urgent Contact Poster
Emergency Options
I Reached Them

==================================================
NO DEAD-PHONE PUNISHMENT
==================================================

Offline/dead phone alone can NEVER cause:

No Show
Abandonment
Strike
Trust reduction
XP loss
Rank loss
Motion Token loss
Bad rating
Suspension
Payment guilt

==================================================
BATTERY SAFETY
==================================================

Evaluate:

battery %
recent drain
remaining travel time
remaining job duration
safety margin

Do not predict exact death time.

Use:

Battery looks sufficient
Battery may not last
Battery critically low

Around 30%:

evaluate more aggressively.

If likely insufficient:
warn teen.

25%:

if still likely insufficient:
AUTOMATICALLY enable MORT Safety Battery Saver.

Reduce:

companion animation
decorative effects
ads/ad refresh
noncritical analytics
nonessential sync
nonessential background work
unnecessary location precision

Keep:

Safety Center
Emergency
check-ins
critical messages
active job state
required safety sync

15%:

low battery warning

5%:

critical battery warning

Attempt minimal final Safety snapshot:

active job
timestamp
last location
last check-in
battery
travel state
live-share state

==================================================
POWER REQUIREMENT
==================================================

Safety must not drain the battery enough to cause the failure it is trying to prevent.

Audit:

timers
background services
GPS polling
wakeups
network polling
analytics
ads
animations

==================================================
LOCATION STRATEGY
==================================================

Normal travel/job:

adaptive low-power location.

No continuous high-accuracy GPS.

Stationary:
reduce updates.

Moving:
modestly increase.

Emergency Live Sharing:
higher frequency allowed.

Critical battery:
back off intelligently.

==================================================
JOB READY CHECK
==================================================

After job acceptance:

show lightweight readiness guidance.

Recommend:

Charge phone
Use Low Power Mode/Battery Saver if needed
Bring portable charger if available
Bring normal charger when possible
Keep MORT notifications enabled

Do not block attendance.

==================================================
TRAVEL SAFETY
==================================================

Travel starts ONLY when teen taps:

I'M ON MY WAY

Never silently start based on motion or schedule.

Teen sees:

On My Way
ETA
battery
connection
Safety Center
Cancel Trip

==================================================
POSTER TRAVEL VIEW
==================================================

Poster sees:

On the way
ETA range
Nearby
Arrived

Nearby ≈ <=10 minutes estimated travel time.

Poster never sees:

exact teen GPS
moving dot
full route
route history

==================================================
GUARDIAN NORMAL TRAVEL
==================================================

Guardian gets quiet travel notification.

May see:

travel active
ETA
job safety status

Normal travel does NOT expose exact live location.

==================================================
TRUSTED CONTACT NORMAL TRAVEL
==================================================

No routine travel notifications.

Trusted contact becomes active only during actual Safety escalation.

==================================================
PHONE DIES WHILE APPROACHING
==================================================

If teen manually started travel and last valid route showed approach to job:

DO NOT mark No Show.

Poster gets:

WAIT FOR WORKER
RESCHEDULE JOB
CANCEL FOR CONNECTION / SAFETY ISSUE

Reschedule must always be easy to find.

Use neutral connection text.

Never expose exact last coordinate.

==================================================
DEAD-PHONE ARRIVAL
==================================================

Poster may use:

WORKER ARRIVED BUT DEVICE UNAVAILABLE

Actions:

WAIT FOR DEVICE
RESCHEDULE
REPORT ARRIVAL ISSUE

Never:

START JOB FOR TEEN

==================================================
RECONNECT
==================================================

Restore valid Safety state.

Notify involved recipients.

If travel had been active:

Are you still on your way?

YES — CONTINUE TRIP
NO — STOP TRIP

Do not silently restart tracking.

==================================================
GUARDIAN SAFETY UX
==================================================

Guardian states may include:

No Active Job
Upcoming Job
Travel Active
Job Safety Active
Check-In Overdue
Connection Lost
Safety Attention
Live Safety Sharing
Safety Exit
Resolved

Guardian normally MAY see:

active/upcoming job
job title/category
schedule
travel
ETA
arrival
job started
latest check-in
connection
Safety Battery Saver
Safety event state

Guardian normally MUST NOT see:

full private messages
exact routine live GPS
historical route
private reports
evidence
poster private phone
unrelated sensitive data

Guardian cannot remotely start live tracking.

==================================================
TRUSTED CONTACT UX
==================================================

Trusted contact is event-based Safety support.

During active event they may see:

teen
event
job
authorized live/last location
battery
connection

Actions:

Call Teen
Message Teen
Urgent Contact Poster
Emergency Options
I Reached Them

No routine monitoring.

==================================================
I REACHED THEM
==================================================

Options:

YES, THEY'RE SAFE
I REACHED THEM, BUT THEY NEED HELP
CANCEL

Record:

who confirmed
relationship
timestamp
event id

Guardian/trusted confirmation is NOT the same as teen device check-in.

==================================================
URGENT CONTACT POSTER
==================================================

During valid Safety event:

guardian/trusted contact may see:

poster MORT name
business name
verification state
active job

Do not expose:

private phone
private email
unrelated personal info

Create temporary in-app:

SAFETY CONTACT

It must be:

event-scoped
logged
closed when event resolves
not a permanent relationship

==================================================
POSTER SAFETY UX
==================================================

Poster sees only necessary Safety state.

They do NOT see:

individual six-minute check-ins
private teen Safety reasoning
guardian actions
trusted contact actions
exact routine location
private report
private evidence

Use neutral language:

MORT Safety is checking on this job.

or:

A MORT Safety status is active for this job.

==================================================
POSTER SAFETY QUICK RESPONSES
==================================================

Allow:

Teen is here with me
Teen left the job
I have not seen Teen yet
The job ended
I need help too

These are status claims, not automatic truth.

==================================================
FINISH PIN
==================================================

Normal completion:

Teen taps Finish Job

Adult gets temporary Finish PIN

Teen enters PIN

Then:

FINAL SAFETY CHECK

Did you leave the job safely?

YES, I'M SAFE
I NEED HELP

Only after safe confirmation:
close normal job safety

Safety Exit never requires Finish PIN.

Poster cannot unrestrictedly force completion.

If PIN cannot complete:

Completion Problem
→ controlled support/dispute flow

==================================================
POST-INCIDENT UX
==================================================

After teen is safe:

You're safe now.

Options:

REPORT WHAT HAPPENED
UPLOAD EVIDENCE
CONTACT MORT SUPPORT
RESCHEDULE / CLOSE JOB
DO THIS LATER

No giant mandatory report.

==================================================
REPORTING
==================================================

Support categories:

I felt unsafe
Threat/harassment
Job differed from listing
Asked to do unsafe work
Someone touched me
Someone blocked me from leaving
Sexual/inappropriate behavior
Payment problem
Off-platform contact pressure
Unsafe location
Other

Allow multi-select.

Free text optional.

==================================================
EVIDENCE
==================================================

Where appropriate support:

photos
screenshots
video
audio subject to product/legal policy
MORT messages
work photos
receipts
existing timing/location metadata
other files

Security:

private Supabase storage
no public URLs
RLS/scoped access
ownership checks
audited staff reads
retention policy
safe file validation

Failed evidence upload must not delete the report.

==================================================
BLOCKING
==================================================

After block:

no new direct messages
no new invitations
no normal profile contact
no normal future matching

Preserve controlled staff/system/payment communication required for resolution.

Do not tell poster:

Teen blocked you.

==================================================
RETALIATION PROTECTION
==================================================

After:

Panic
Safety Exit
Report Person
Report Job
Block

restrict:

retaliatory negative rating
false no-show
abusive messaging
payment manipulation
retaliatory reports
repeated contact pressure

==================================================
SAFETY REVIEW HOLD
==================================================

Implement/extend canonical:

Safety Review Hold

Allow:

support
evidence
staff review
legitimate payment/dispute processing
guardian safety access
required notifications

Restrict:

retaliatory ratings
abusive messages
arbitrary no-show
destructive evidence deletion
unilateral completion rewriting

==================================================
PAYMENT SEPARATION
==================================================

Safety Review does not automatically decide payment.

Preserve relevant evidence for fair dispute review.

Stripe remains marketplace money authority.

RevenueCat remains digital Pro authority.

Safety remains independent and free.

==================================================
ADULT SAFETY
==================================================

Adults/businesses may:

Report Safety Concern
End Job for Safety

Their report does not automatically establish teen guilt.

Adult Safety End:

stop normal work
preserve evidence
neutral teen notice
open review/support
no Finish PIN required
restrict immediate retaliatory rating behavior

==================================================
MODERATION / ADMIN
==================================================

Use existing MORT staff architecture.

Extend with:

Safety Queue
Case Detail
Evidence
Relevant Messages
Safety Timeline
Temporary Restrictions
Job Suspension
Poster Suspension
Information Request
Escalation
Resolution
Payment/Dispute Referral
Appeal

==================================================
STAFF PRIVILEGE SEPARATION
==================================================

General Support:
ordinary support only

Safety Reviewer:
safety report/evidence/timeline scope

Verification Reviewer:
verification-only scope

Payments/Disputes:
payment-relevant scope

High-Privilege Admin:
exceptional audited access

Every sensitive read must be auditable.

==================================================
AUDIT LOGGING
==================================================

Record:

Safety Alert created
delivery attempt
delivery acknowledged
guardian/trusted access
Urgent Contact Poster
live share start
live share extend
live share stop
disconnect
reconnect
check-in transitions
Safety Exit
report submitted
evidence uploaded
staff evidence access
restriction applied
resolution
appeal

No silent privileged changes.

==================================================
RLS / SECURITY
==================================================

Explicitly test:

Teen A cannot read Teen B

Poster cannot read unrelated teen

Poster cannot read private teen Safety event

Guardian cannot read unlinked teen

Trusted contact cannot access unrelated event

Trusted contact cannot access expired event

Client cannot invoke service-only mutations

Evidence remains private

Staff privilege is role-checked

Banned/suspended behavior works

==================================================
SERVER AUTHORITY
==================================================

Do not trust client claims for:

role
verification
admin
PIN correctness
Safety state
live-share authority
guardian relationship
trusted-contact relationship
Safety Review Hold
payment state
moderation state
audit state

==================================================
OFFLINE FIRST
==================================================

Keep locally available:

Call 911
Call Guardian
Call Trusted Contact
Leave Job
Safety Center
last known job
draft report

Network-required actions show:

WAITING TO SEND

until acknowledged.

Never lie with:

Sent

before backend confirmation.

==================================================
ACCESSIBILITY
==================================================

Implement:

large touch targets
semantic labels
screen-reader support
text scaling
no color-only meaning
one-hand Emergency reach
reduced motion
no gesture-only critical actions
no critical action disappearing too quickly

Reduced motion:

no dramatic slide
no pulse
no bounce

Use simple transitions.

==================================================
ANDROID
==================================================

Audit:

background location
notification channels
battery APIs
battery optimization
app lifecycle
terminated state
native emergency call handoff
notification actions
deep links

==================================================
IOS
==================================================

Audit:

location permission
background modes
notifications/actions
Low Power Mode limitations
app lifecycle
background execution
native emergency call handoff
deep links

If physical iOS certification is impossible from Windows:

DO NOT call iOS verified.

Use:

IMPLEMENTED BUT EXTERNAL GATE REMAINS

==================================================
TESTING
==================================================

Run as applicable:

dart format
flutter analyze
flutter test

focused Safety tests

full regression suite where practical

Supabase SQL/migration validation

RLS adversarial tests

storage isolation tests

RPC authorization tests

Edge Function tests/typechecks

secret scanning

Android build

==================================================
ADD/EXTEND TESTS FOR
==================================================

Teen:

Safety Center
Emergency opens
Emergency open sends nothing
explicit alert sends
60-minute sharing
Safety Exit
Start PIN
Finish PIN
6-minute check-ins
first miss
second miss
offline 2/5/15
battery thresholds
Battery Saver
critical snapshot
travel
dead-phone travel
reconnect
reports
evidence

Guardian:

normal travel
no hidden tracking
second miss
offline escalation
live share
I Reached Them

Trusted Contact:

no routine travel notifications
event-scoped access

Poster:

ETA privacy
Nearby
Arrived
Start PIN
no check-in surveillance
connection issue
Reschedule
Safety Contact
Safety Exit
Finish PIN
no forced completion
retaliation restrictions

Admin:

case access
privilege separation
audit trail
evidence access

Security:

cross-user RLS
service-role protection
expired event access
guardian spoofing
trusted-contact spoofing
PIN replay
alert replay
live-share replay
evidence isolation
staff isolation

==================================================
RACE CONDITIONS
==================================================

Test:

check-in due while connection drops

reconnect during Safety Attention

Safety Exit during pending check-in

Safety Alert while offline

live-sharing expires offline

Finish PIN collides with Safety Exit

reschedule collides with reconnect

guardian I Reached Them collides with teen I'm Safe

duplicate notification/provider events

State resolution must be deterministic.

==================================================
PERFORMANCE / BATTERY AUDIT
==================================================

Check for:

continuous GPS
excessive timers
timer leaks
background task leaks
excessive rebuilds
network polling
duplicate notifications
database query amplification
unnecessary wakeups
ad work during Safety
companion work during Safety

Safety efficiency is a release requirement.

==================================================
VISUAL QA
==================================================

Actually render/inspect:

Safety Center
Emergency Panel
Active Job Safety
Check-In
Missed Check-In
Safety Attention
Connection Lost
Safety Battery Saver
Critical Battery
Travel Safety
Guardian Safety
Trusted Contact Event
Adult Connection Issue
Safety Contact
Safety Exit
Post-Incident
Report Flow
Evidence
Safety Review Hold
Admin Safety Case

Check:

small phone
normal phone
large phone
text scaling
reduced motion
Android
iOS-equivalent layout

No overflow.

==================================================
DO NOT BREAK OTHER SYSTEMS
==================================================

Do not unnecessarily redesign or rewrite:

Paywall
Companion Studio
Progression
RevenueCat
Stripe
Authentication
whole app theme
existing release pipeline

Only change them when required for proper Safety integration.

==================================================
VERSION / RELEASE
==================================================

Do not activate production.

Do not merge.

Do not push to a production branch.

Do not change marketplace activation gates.

Do not claim production-ready merely because code builds.

Keep separate:

CODE-CONTROLLED
DEVICE
PROVIDER
SECURITY/RLS
OPERATIONS
LEGAL/PRIVACY
IOS/MACOS

==================================================
SELF-AUDIT AS SKEPTIC
==================================================

Before final report, aggressively attempt to break:

RLS
teen location privacy
guardian boundaries
poster boundaries
trusted-contact boundaries
PIN replay
event replay
offline delivery state
Battery Saver logic
background location
live-share expiration
evidence privacy
admin privilege
retaliation protections
state machine transitions
notification privacy
Android lifecycle
iOS assumptions

Fix all code-controlled defects found.

==================================================
FINAL STATUS LANGUAGE
==================================================

Use ONLY:

IMPLEMENTED AND VERIFIED
IMPLEMENTED BUT EXTERNAL GATE REMAINS
DATA/UI ONLY
NOT IMPLEMENTED
BLOCKED

Never call something verified because:

a model exists
a field exists
a screen renders
a button exists
a placeholder exists
a mock exists

==================================================
FINAL REPORT FORMAT
==================================================

REAL MORT REPO:
<path>

SAFETY WORKTREE:
<path>

BRANCH:
<branch>

HEAD:
<SHA>

SAFETY SKILL:
<path>

FLUTTER ROOT:
<path>

REPOSITORY CLEAN:
YES/NO + details

--------------------------------

Safety Center:
<status>

Emergency Panel:
<status>

Emergency Open Sends Nothing:
<status>

Guardian + Trusted Alert:
<status>

60-Minute Live Sharing:
<status>

Guardian Cannot Start Tracking:
<status>

Manual I'm On My Way:
<status>

Poster ETA Privacy:
<status>

Nearby:
<status>

I'm Here:
<status>

Start PIN:
<status>

6-Min Check-Ins:
<status>

First Miss Reminder:
<status>

Second Miss Escalation:
<status>

2-Min Connection Lost:
<status>

5-Min Safety Contact Alert:
<status>

15-Min Safety Attention:
<status>

Battery Prediction:
<status>

Automatic Safety Battery Saver:
<status>

15% Battery Warning:
<status>

5% Critical Snapshot:
<status>

Dead-Phone Travel:
<status>

Dead-Phone Arrival:
<status>

Reschedule:
<status>

Reconnect:
<status>

Safety Exit:
<status>

Safety Exit Bypasses Finish PIN:
<status>

Finish PIN:
<status>

Final Safe Departure:
<status>

Guardian UX:
<status>

Trusted Contact UX:
<status>

Urgent Contact Poster:
<status>

Adult Safety UX:
<status>

Safety Contact:
<status>

Reports:
<status>

Evidence:
<status>

Blocking:
<status>

Retaliation Protection:
<status>

Safety Review Hold:
<status>

Moderation/Admin:
<status>

Audit Trail:
<status>

Offline First:
<status>

Reduced Motion:
<status>

Android:
<status>

iOS:
<status>

--------------------------------

Dart Format:
<result>

Flutter Analyze:
<result>

Flutter Tests:
<result>

Safety Tests:
<result>

RLS Adversarial:
<result>

Storage Isolation:
<result>

RPC Authorization:
<result>

Edge Functions:
<result>

Android Build:
<result>

iOS Validation:
<result>

Secret Scan:
<result>

--------------------------------

Runtime Errors:
<number>

Unauthorized Safety Data Access Found:
<number>

Remaining Placeholders:
<exact list or NONE>

Remaining Code Issues:
<exact list or NONE>

Remaining Security Issues:
<exact list or NONE>

Remaining External Gates:
<exact list or NONE>

Production Safety Activated:
NO

Merged:
NO

--------------------------------

FINAL VERDICT:

CODE_CONTROLLED_SAFETY_READY

or

SAFETY_NOT_READY

Include exact reasons.

==================================================
EXECUTE NOW
==================================================

Start with:

1. verify real MORT repo
2. verify worktrees
3. read the entire MORT Safety Skill
4. locate actual Flutter root
5. complete Safety-specific forensics
6. complete gap audit
7. implement sequentially
8. test each subsystem
9. run security/RLS audit
10. run skeptical self-audit
11. fix discovered defects
12. run final regression
13. produce certification report

Do not return another generic plan.

Do not switch to Payment OS.

Do not build a web replacement.

Do not stop after the first passing test.

Do not merge.

Do not activate production.

BEGIN.