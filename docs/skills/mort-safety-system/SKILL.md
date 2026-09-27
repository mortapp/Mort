---
name: mort-safety-system
description: Use when planning, implementing, auditing, testing, or reviewing MORT Safety Center, active-job safety, travel safety, guardian/trusted-contact safety, battery/offline behavior, safety reports, moderation, evidence, or safety-related release gates.
---

# MORT Safety System

## Purpose

MORT is a teen-first local work marketplace. Safety is a cross-cutting product boundary that overrides growth, monetization, engagement, cosmetics, and convenience.

This skill is authoritative for MORT Safety Center UX, active-job safety, travel safety, battery/offline handling, Start/Finish PINs, guardian/trusted-contact behavior, adult/business safety behavior, reports/evidence/moderation, privacy, accessibility, and release gating.

## Non-negotiable invariants

1. Safety features are free.
2. Pro never weakens, bypasses, accelerates, or improves safety treatment.
3. Ads, companions, promotions, and decorative motion never obstruct safety-critical UI.
4. Exact teen location is never exposed to the poster during routine travel/job flows.
5. Unsafe/unknown states fail closed.
6. MORT never claims an alert, emergency call, staff escalation, or delivery succeeded unless the underlying action is actually confirmed.
7. Safety Exit always lets the teen leave without requiring the poster's Finish PIN.
8. Missed check-ins, offline state, or dead battery alone never cause strikes, trust loss, XP loss, bad ratings, no-show status, suspension, or abandonment findings.
9. Guardian safety must not become covert continuous surveillance.
10. Privileged safety, verification, moderation, evidence, and payment mutations are server-authoritative and auditable.

---

# 1. Safety Center Home

Use the current MORT visual system: black, white, silver, graphite/charcoal, restrained cool blue. Use amber for attention and restrained red only for urgent/emergency states.

## Main status card

Normal:
- `You're Safe`
- no active safety alerts
- linked guardian state
- trusted contact state

During a job:
- `Job Safety Active`
- job title/category
- remaining job time
- next 6-minute check-in
- battery percentage
- connection state
- Safety Battery Saver state

## Primary actions

- Emergency / Panic
- I'm Safe
- Leave This Job during an active job
- Call 911 inside Emergency

## Safety Center sections

- Current Safety Status
- Active Job Safety
- Battery & Device
- People Looking Out for You
- Live Safety Sharing
- Reports & Help
- Safety Settings
- Who Can See What

The teen must always be able to see what MORT is sharing and with whom.

Normal transparency example:
- Guardian: job safety status, travel status, check-in status
- Trusted contact: safety events only
- Live location: Off

During live sharing:
- Guardian: live location
- Trusted contact: live location
- sharing countdown shown

---

# 2. Emergency / Panic UX

Opening Emergency does NOT automatically send an alert.

The Emergency panel opens instantly with:
- no PIN
- no password
- no biometric requirement
- no paywall
- no ad
- no companion
- no promotional content
- no unnecessary animation

Header:
- `MORT Safety`
- `Need help?`
- `Choose what you need. You're always allowed to leave a job.`

## Alert My Safety Contacts

When tapped:
- notify linked guardian
- notify trusted/emergency contact
- include teen name
- active job
- timestamp
- current confirmed location
- battery state
- connection state
- last successful check-in
- begin 60-minute live location sharing
- record safety event server-side
- do not show `Sent` until backend acknowledgment

Teen sees:
- Guardian notified
- Trusted contact notified
- live-sharing countdown
- Stop Sharing
- Extend 60 Minutes

## Call 911

Open the device-native emergency call interface.

Never claim:
- `911 contacted`
- `Police dispatched`

unless a real OS/provider integration confirms it.

Safe wording:
- `Emergency call opened`

## Leave This Job

Show one fast confirmation:

`Leave this job for safety?`
`You do not need the poster's permission or Finish PIN to leave.`

Actions:
- Leave Now
- Stay at Job

If Leave Now:
- set Safety Exit
- stop normal active-work flow
- bypass Finish PIN
- preserve job/check-in/evidence state
- notify guardian + trusted contact
- send adult/business a neutral Safety Exit notice
- restrict retaliation paths
- offer post-incident support

## Share Live Location

Starts 60-minute live sharing with guardian + trusted contact.

Does NOT notify the poster by itself.

Teen can:
- stop early
- extend another 60 minutes

Guardian/trusted contact cannot extend it.

---

# 3. Offline Emergency Behavior

If Emergency is open without network:

Show:
- `No data connection`
- MORT cannot reach safety contacts through the app right now

Keep available:
- Call 911
- Call Guardian
- Call Trusted Contact
- Leave Job

Queue the MORT safety event locally where appropriate.

Display:
- `Safety alert waiting to send`

On reconnect + backend acknowledgment:
- `Safety alert sent · <time>`

Never show `Sent` before confirmation.

---

# 4. Active Job Safety Lifecycle

Normal sequence:

`Arrive → Start PIN → In Progress → 6-minute check-ins → Finish PIN → Final Safety Check → Completed`

Safety may interrupt at any point.

## Arrival

Teen taps `I'm Here`.

Show:
- job
- poster/business
- Enter Start PIN

The adult/business has the temporary Start PIN in their job view.

Valid Start PIN:
- confirms two-sided start
- moves job to In Progress
- enables active safety monitoring

Invalid PIN:
- remain Awaiting Start PIN
- rate-limit repeated attempts
- surface Safety/help
- never trap the teen at the location

## Start PIN rules

- temporary
- scoped to one job
- not reusable
- does not suppress Safety
- adult cannot mark the job started on behalf of the teen

---

# 5. Six-Minute Check-Ins

While `In Progress`, create a safety check-in every 6 minutes.

UI:
- `Quick safety check`
- `Everything okay?`

Actions:
- I'm Safe
- I Need Help
- Leave Job

A check-in is a safety state transition, NOT a requirement to turn on high-accuracy GPS every 6 minutes.

## First missed check-in

If device is still online:
- remind teen
- guardian is not notified yet
- no penalty

## Second consecutive missed check-in

If device is still online:
- move to Safety Attention
- notify guardian
- bring trusted contact into escalation path
- show stronger safety actions
- no penalty

Do not call it an emergency unless the teen or circumstances create one.

## I'm Safe after escalation

- record safe response
- notify already-involved guardian/trusted contact
- resume normal 6-minute cadence
- return UI to calm state

## I Need Help

Open the same Emergency panel.

Opening it alone sends nothing.

---

# 6. Connection Lost / Dead Phone

Missed check-ins and offline device are separate systems.

## 0–2 minutes
- quietly retry
- preserve last safety state
- no alarm

## At 2 minutes
- state becomes `Connection Lost`
- record last successful check-in
- last valid location
- last battery percentage
- job/travel state
- timestamp

## At 5 minutes
- notify guardian
- notify trusted contact

Use calm language:
- `MORT can't reach this device`
- `This does not necessarily mean the teen is in danger.`

## At 15 minutes
- escalate to `Safety Attention`

Guardian/trusted contact actions:
- Call Teen
- Message Teen
- View Last Known Location
- View Active Job
- Urgent Contact Poster
- Emergency Options
- I Reached Them

Never auto-accuse the teen.

## Device reconnect

Notify involved recipients:
- `Device reconnected`

Restore the appropriate prior safety session.

If travel had been active, ask:
- `Are you still on your way?`
  - Yes, Continue Trip
  - No, Stop Trip

Do not silently restart expired/stopped route tracking.

---

# 7. Battery-Aware Safety

MORT evaluates:
- current battery percentage
- recent drain rate
- estimated travel time
- expected remaining job duration
- safety margin

Do not claim an exact battery-death time.

Use confidence labels:
- Battery looks sufficient
- Battery may not last
- Battery critically low

## Around 30%

Evaluate more aggressively.

If battery may not last:
- warn teen
- recommend system Low Power Mode/Battery Saver
- recommend charger / portable charger

## At 25%

If predicted battery is insufficient:
- automatically enable MORT `Safety Battery Saver`

Show:
`Safety Battery Saver On`
`MORT is reducing nonessential activity to keep safety features available.`

Reduce:
- companion animations
- decorative animation
- ad refresh
- unnecessary analytics sync
- noncritical background refresh
- nonessential network activity
- nonessential location precision

Keep:
- Safety Center
- emergency actions
- check-ins
- job status
- important messages
- minimum safety syncing

Teen may disable it manually after a warning.

## At 15%
- show low-battery warning

## At 5%
- show critical-battery warning
- attempt a minimal final safety snapshot

Minimal snapshot:
- active job
- timestamp
- last valid location
- last successful check-in
- battery percentage
- travel/job state
- active safety-sharing state

Battery telemetry stays device-side as much as possible and is uploaded only for legitimate safety purposes.

## Hard battery rule

Safety monitoring must not itself become the reason the phone dies.

---

# 8. Battery-Efficient Location Strategy

Normal travel/job:
- adaptive low-power location
- no continuous high-accuracy GPS polling
- reduce updates when stationary
- modestly increase when moving
- briefly wake around relevant safety transitions
- batch/minimize network activity

Emergency Live Sharing:
- higher-frequency location may be used
- dynamically back off under critical battery

Safety traffic gets priority over:
- ads
- companions
- analytics
- cosmetics
- decorative effects

---

# 9. Pre-Job Readiness UX

After a teen accepts a job, show a lightweight Job Ready Check.

Recommend:
- charge phone before leaving
- turn on system Low Power Mode/Battery Saver if needed
- bring portable charger if available
- bring regular charger when possible
- keep MORT notifications enabled

Do not block job attendance because battery is low.

If the OS does not allow programmatic Low Power Mode activation, provide guidance/settings shortcut only. Never pretend it was enabled.

---

# 10. Manual Travel Safety

Travel tracking starts only when the teen manually taps:
- `I'm On My Way`

Do not auto-start based only on movement or schedule.

Explain:
- MORT will use location for travel safety/ETA
- poster sees arrival status, not live location

Teen sees:
- On My Way
- ETA
- battery
- connection
- Safety Center
- Cancel Trip

Adult/business sees:
- On the way
- ETA range
- `Nearby` when roughly within 10 minutes estimated travel time
- `Arrived` only after teen taps `I'm Here`

Poster never gets an exact moving GPS dot.

---

# 11. Guardian vs Trusted Contact During Travel

Guardian:
- gets quiet notification when teen manually starts travel
- can view job safety status
- cannot view exact live location unless a defined safety event/share activates it

Trusted contact:
- gets no routine travel notification
- only participates in real safety/offline escalation events

---

# 12. Phone Dies While Traveling

If teen manually started travel and device goes offline while approaching the job:

Do NOT mark `No Show`.

Use:
- `Arrival Connection Issue`
- `Worker Connection Issue`

If last valid route state showed roughly <=10 minutes travel time from the job, adult/business should see one of several neutral rotating messages, such as:

1. `MORT lost connection with <Teen> while they were close to your job location. Their phone had very low battery and may have powered off unexpectedly.`
2. `<Teen> was approaching your job when their device went offline unexpectedly. This may be a battery or connection issue. They should not be treated as a no-show yet.`
3. `We last received <Teen>'s status near your job location, but their device is now unreachable.`

Always show:
- Wait for Worker
- Reschedule Job
- Cancel for Connection/Safety Issue

`Reschedule Job` must always be available.

No automatic:
- no-show
- strike
- trust reduction
- XP loss
- bad rating
- suspension
- abandonment finding

Poster sees only generalized proximity and connection state, not exact last GPS.

---

# 13. Teen Arrives With Dead Phone

Adult/business may use:
- `Worker Arrived but Device Unavailable`

Actions:
- Wait for Device
- Reschedule
- Report Arrival Issue

Do NOT offer:
- `Start Job for Teen`

Adult cannot impersonate the teen's side of the Start PIN handshake.

---

# 14. Guardian Safety UI

Guardian home safety card supports:

Normal:
- teen okay
- no active job

Upcoming:
- upcoming job
- safety monitoring starts with travel/job

Travel:
- on the way
- ETA
- travel safety active
- exact location sharing off

Active job:
- job
- started time
- latest successful check-in
- connection state

Do not notify guardian every 6 minutes for successful check-ins.

Notify only meaningful changes:
- second consecutive missed check-in
- connection loss escalation
- Safety Alert
- live sharing starts/stops/extends
- Safety Exit
- device reconnect
- teen marks safe after escalation

## Guardian may normally see

- active/upcoming job status
- job title/category
- scheduled time
- travel status
- ETA range
- arrival state
- job started state
- latest safety check-in state
- connection state
- Safety Battery Saver state
- safety alert state

Normally hidden:
- full private message history
- exact live GPS
- historical location trail
- private reports
- evidence uploads
- unrelated sensitive data
- poster private phone number

---

# 15. Trusted Contact UI

Trusted contact is emergency support, not parental monitoring.

During an active safety event they may see:
- teen name
- active safety event
- job context
- authorized live/last-known location
- battery/connection state
- Call Teen
- Message Teen
- Urgent Contact Poster
- Emergency Options
- I Reached Them

They do not receive:
- routine job/travel notifications
- full job history
- full profile management
- unrelated teen data

---

# 16. I Reached Them

Guardian/trusted contact can tap:
- `I Reached Them`

Ask:
`Were you able to confirm <Teen> is okay?`

Options:
- Yes, They're Safe
- I Reached Them, But They Need Help
- Cancel

If safe:
- record confirming person
- relationship
- timestamp
- safety event ID
- keep monitoring for device reconnect

This does not equal a teen device check-in if the teen phone is still offline.

If help is needed:
- open Emergency Options

---

# 17. Live Sharing Recipient UX

During active 60-minute sharing, guardian/trusted contact may see:
- live map
- last updated
- battery
- connection
- active job
- last check-in
- remaining sharing time

Actions:
- Call Teen
- Message Teen
- View Active Job
- Urgent Contact Poster
- Emergency Options

At expiry:
- live updates stop
- show `Live location sharing ended`
- map freezes at last shared location

If teen extends:
- notify recipients
- start new 60-minute window

Guardian cannot remotely extend or silently start tracking.

---

# 18. Urgent Contact Poster

During a defined safety event, guardian/trusted contact may access:
- poster MORT display name
- business name
- verification state
- relevant active-job details

Never expose:
- private phone number
- private email
- unrelated private information

Use temporary in-app:
- `Safety Contact`

The channel:
- is scoped to the active safety event
- is logged
- closes when the safety event closes
- does not create a permanent contact relationship

Quick messages may include:
- Is <Teen> currently with you?
- Their phone is offline. Please let us know if they arrived safely.
- Please remain available in MORT.

---

# 19. Adult / Business Safety UX

Normal accepted job:
- worker
- job
- scheduled time
- normal actions
- no guardian/location information

Travel:
- On the way
- ETA range
- Nearby
- Arrived

No exact live GPS.

Start:
- temporary Start PIN
- waiting for teen confirmation
- successful start → Job In Progress

Active:
- Safety monitoring active
- do not expose individual six-minute check-ins

If MORT needs the poster involved:
- neutral message: `MORT Safety is checking on this job. Please remain available in the app.`

During stronger safety state:
- `A MORT Safety status is active for this job`
- Open Job
- Respond to Safety Contact

---

# 20. Poster Quick Safety Responses

Temporary Safety Contact may offer:
- <Teen> is here with me
- <Teen> left the job
- I have not seen <Teen> yet
- The job ended
- I need help too

Poster claims are evidence/status updates, not automatic truth and not automatic closure.

---

# 21. Adult/Business Safety Exit View

When teen uses Safety Exit, poster sees:
- `Job ended through MORT Safety`
- worker ended job using a safety exit
- job stopped

Actions:
- Remain Available
- View Job Status
- Contact MORT Support

Do not reveal:
- private teen reason
- guardian info
- trusted-contact identity
- live location
- private report/evidence

---

# 22. Retaliation Protection

After:
- Panic
- Safety Exit
- Report Person
- Report Job
- Block

Temporarily restrict retaliation routes such as:
- immediate negative ratings
- false no-show marking
- abusive messaging
- payment manipulation
- retaliatory reporting
- repeated contact pressure

Use a backend state such as:
- `Safety Review Hold`

Legitimate payment/dispute processing must still continue under policy.

---

# 23. Finish PIN and Final Safety Check

Normal completion:
- teen taps Finish Job
- adult provides temporary Finish PIN
- teen enters it
- move to Final Safety Check

Ask:
- `Did you leave the job safely?`

Actions:
- Yes, I'm Safe
- I Need Help

Only after safe finish confirmation:
- close normal active safety monitoring
- move to Completed
- proceed to normal payment/review flows

Safety Exit bypasses Finish PIN.

Adult cannot freely force-complete the teen's side.

If PIN flow fails:
- Completion Problem
- support/dispute workflow

---

# 24. Adult Safety Concerns

Adults/businesses may also use:
- Report Safety Concern
- End Job for Safety

Possible concerns:
- threatening behavior
- unexpected person
- property damage
- unsafe behavior
- need to end job
- other

Adult reports are taken seriously but do not automatically establish teen guilt.

Adult Safety End:
- stops normal work state
- preserves evidence
- notifies teen neutrally
- prevents immediate retaliatory rating behavior
- opens review/support
- does not require Finish PIN

---

# 25. Post-Incident UX

After teen says they are safe:

Show:
- `You're safe now`
- `What would you like to do next?`

Actions:
- Report What Happened
- Upload Evidence
- Contact MORT Support
- Reschedule / Close Job
- Do This Later

No mandatory report before leaving.

---

# 26. Report What Happened

Use progressive, short reporting.

Categories may include:
- I felt unsafe
- Poster threatened or harassed me
- Job was different from what was posted
- Asked to do something unsafe
- Someone touched me or blocked me from leaving
- Sexual or inappropriate behavior
- Payment problem
- Tried to move communication off MORT
- Location felt unsafe
- Something else

Allow multiple selections.

Then optional free text:
- as much or as little as the teen wants

Evidence is optional.

---

# 27. Evidence

Supported evidence may include:
- photos
- screenshots
- video
- audio where legally/policy appropriate
- MORT message references
- job/work photos
- receipts/proof
- existing relevant time/location metadata
- other files

Evidence rules:
- private storage
- scoped/signed access
- ownership/relationship checks
- no public URLs
- no automatic poster access
- staff-access audit trail
- retention/deletion policy
- file-type validation
- malware validation where appropriate
- metadata minimization
- preserve original upload timestamp/hash where useful

If upload fails:
- keep the report
- allow evidence to be added later

---

# 28. Blocking

After an incident, teen may block poster.

Effects:
- no new direct messages
- no new job invitations
- no normal profile contact
- no normal future matching
- staff retains necessary safety/dispute access
- controlled system communication may continue for required administrative/payment purposes

Do not tell poster:
- `<Teen> blocked you`

Use neutral availability language.

---

# 29. Safety Review Hold

During severe safety activity, `Safety Review Hold` may allow:
- support communication
- evidence upload
- staff review
- legitimate payment/dispute work
- guardian safety access
- relevant system notifications

Temporarily restrict:
- retaliatory ratings
- abusive direct messages
- arbitrary no-show marking
- destructive evidence deletion
- unilateral completion rewriting

---

# 30. Moderation / Admin UX

Safety queue cards may contain:
- job
- teen
- poster
- status
- Safety Exit yes/no
- device state
- evidence count
- prior relevant report count

Staff actions:
- review report
- review authorized evidence
- review relevant messages
- review safety timeline
- temporarily restrict account
- suspend job/poster
- request information
- escalate internally
- resolve
- refer payment/dispute
- preserve evidence
- close with rationale

## Staff privilege separation

General Support:
- ordinary job/account help
- no unrestricted sensitive evidence

Safety Reviewer:
- safety reports
- relevant evidence/messages/timeline

Verification Reviewer:
- identity/school ID scope

Payments/Disputes:
- payment-relevant evidence only

High-Privilege Admin:
- exceptional access
- always audited

No client-provided `admin=true` authority.

---

# 31. Audit Trail

Record:
- safety alert created/sent/acknowledged
- guardian/trusted contact opened status
- urgent poster contact opened
- live sharing started/stopped/extended
- device disconnected/reconnected
- check-in state changes
- Safety Exit
- report submitted
- evidence uploaded
- staff viewed evidence
- restrictions applied
- case status changed
- payment team referenced case
- resolution
- appeal opened/resolved

No silent high-privilege edits.

---

# 32. Appeals and False Reports

If MORT restricts/suspends/bans:
- show reason category
- decision date
- affected features
- appeal path
- evidence/comment submission

Preserve original audit history.

Unsubstantiated report does NOT equal malicious false report.

Only repeated, evidence-supported abuse of reporting should be reviewed for misuse.

---

# 33. Teen-Facing Case Status

Show simple states:
- Submitted
- Evidence received
- Under review
- Resolved

Do not fabricate response-time guarantees.

Dedicated Safety Support case thread may allow:
- more information
- more evidence
- status questions
- continued-contact reports
- job/payment questions

Serious cases must be able to escalate to human review.

---

# 34. Safety Notification Privacy

Lock-screen notifications should reveal the minimum necessary.

Do not expose:
- exact sensitive incident details
- sexual/grooming content
- detailed evidence
- exact live location

Use minimal text such as:
- `MORT Safety Alert`
- `Open MORT for details`

---

# 35. Safety State Model

Keep job state separate from safety state.

Job states may include:
- Accepted
- Traveling
- Arrived
- InProgress
- Completed
- Cancelled
- Disputed
- Suspended

Safety states may include:
- SafetyNormal
- CheckInDue
- CheckInMissed1
- SafetyAttention
- ConnectionLost
- LiveSafetySharing
- SafetyAlert
- SafetyExit
- SafetyReviewHold
- Resolved

Do not collapse all combinations into one giant job-status enum.

---

# 36. Guardian State Model

Guardian may see:
- NoActiveJob
- UpcomingJob
- TravelActive
- JobSafetyActive
- CheckInOverdue
- ConnectionLost
- SafetyAttention
- LiveSafetySharing
- SafetyExit
- Resolved

Guardian cannot remotely create LiveSafetySharing.

---

# 37. Trusted Contact State Model

Trusted contact normally:
- Inactive

Then during safety events:
- SafetyEventActive
- ConnectionLost
- SafetyAttention
- LiveSafetySharing
- SafetyExit
- Resolved

No routine job monitoring.

---

# 38. Adult/Business State Model

Poster-facing states may include:
- WorkerAccepted
- WorkerTraveling
- WorkerNearby
- WorkerArrived
- AwaitingStartPin
- JobInProgress
- WorkerConnectionIssue
- SafetyStatusActive
- AwaitingFinishPin
- CompletionProblem
- SafetyReviewHold
- Completed

Never expose private teen safety internals.

---

# 39. Safety Components

Prefer reusable components such as:
- SafetyStatusCard
- SafetyActionButton
- BatterySafetyCard
- ConnectionStatusCard
- CheckInSheet
- EmergencyPanel
- LiveSharingCard
- GuardianSafetyCard
- TrustedContactAlertCard
- PosterSafetyNotice
- SafetyTimeline
- SafetyContactThread
- ReportCategoryPicker
- EvidenceUploader
- SafetyCaseStatus
- SafetyReviewHoldBanner
- SafetyBatterySaverBanner

Follow existing MORT architecture rather than creating a duplicate design system.

---

# 40. Accessibility

All Safety UI must support:
- large touch targets
- screen-reader labels/semantics
- no color-only meaning
- text scaling
- reduced motion
- one-hand reach for emergency actions
- no gesture-only required action
- no critical timed action that disappears too quickly

Reduced Motion:
- no dramatic slides
- no pulsing
- no bounce
- use simple state/fade transitions

---

# 41. Offline-First Safety

Critical local safety UI must remain usable when network is unavailable:
- Call 911
- Call Guardian
- Call Trusted Contact
- Leave Job
- Safety Center
- last known job details
- queued report draft

Network-required actions must show:
- `Waiting to send`

not:
- `Sent`

until acknowledged.

---

# 42. Safety Analytics Restrictions

Allowed reliability telemetry may include:
- alert delivery latency
- connection-loss rate
- check-in delivery failures
- Safety Battery Saver activation
- safety-screen crash/failure rates

Never use safety telemetry for:
- behavioral ads
- marketing profiles
- ad targeting
- monetization targeting

Never target ads based on:
- panic usage
- safety reports
- guardian alerts
- safety location events

---

# 43. Kill Switches / Feature Flags

High-risk optional automation may use server-side kill switches:
- live-sharing provider malfunction
- notification provider failure
- background-location defect
- broken safety-message action

Kill switches may disable optional automation.

They must NOT remove core emergency access:
- Safety Center
- Call 911
- Leave Job
- basic offline safety actions

---

# 44. Completion Standard

A safety feature is not PASS merely because:
- a data model exists
- placeholder UI exists
- a route exists
- a mock card renders

It is PASS only when the end-to-end behavior is implemented, authorization boundaries are enforced, negative paths are exercised, and the result is visually verified.

Required verification includes:

- Safety Center opens
- Emergency panel opens instantly
- opening Emergency sends nothing
- alert reaches guardian + trusted contact
- 60-minute live sharing works
- guardian cannot secretly start live sharing
- manual I'm On My Way works
- poster sees privacy-safe ETA/status only
- 6-minute check-ins work
- first miss only reminds
- second online miss escalates
- offline 2/5/15 logic works
- Start PIN works
- Finish PIN works
- Safety Exit bypasses Finish PIN
- Safety Battery Saver auto-activates under the approved rule
- critical-battery snapshot works
- dead-phone travel/arrival flow works
- Reschedule is available during connection issues
- reconnect behavior works
- evidence/report flow works
- retaliation protections work
- admin audit trail works
- RLS blocks unauthorized access
- ads/companions never appear on restricted safety surfaces
- reduced motion works
- offline states never lie about delivery
- Android and iOS have equivalent intended behavior

## Final rule

If any critical safety path is ambiguous, unauthorized, unverified, or dependent on an unavailable provider, keep that path fail-closed and report the remaining gate explicitly.
