# MORT — Get in Motion

A teen-safe local hustle marketplace for ages 13+. Native iOS app built with SwiftUI (MVVM, service protocols, Supabase-ready).

> **Not** a child-directed (<13), dating, banking, loans, crypto, gambling, medical, tobacco, or real-money payment app. No in-app payment processing, wallet, or escrow.

---

## Requirements

- Xcode 16+ (targets iOS 18+; some polish uses availability guards)
- A Mac to build/run
- (Later) Apple Developer account for device builds, TestFlight, and App Store

## Run it

1. Open `MORT.xcodeproj` in Xcode.
2. Select an iPhone simulator (portrait).
3. Press **Run** (⌘R).

The app launches into the splash → onboarding → role-based dashboard. You can also tap **“Explore a demo dashboard”** on the Welcome screen to jump straight into any role.

---

## Architecture

```
MORT/
├── App/            RootView, AppEnvironment (service container)
├── Theme/          Colors, typography, spacing, backgrounds
├── Models/         Enums + data models (Codable, nonisolated)
├── Services/       Protocols + Mock implementations + SupabaseConfig
├── Stores/         SessionStore (@Observable) — auth/onboarding/session
├── Components/     Mort* reusable UI (Button, TextField, Card, JobCard, …)
├── Auth/           Login, Signup, Verify email
├── Onboarding/     Splash, Welcome, DOB, Username, Role, Terms, Notifications, Transportation
├── Teen/           Teen dashboard + tabs
├── AdultBusiness/  Adult/Business dashboard, Post Job, Manage Jobs, Applicants, Disputes
├── ParentGuardian/ Parent dashboard, Linked teens, Alerts, Settings
├── Admin/          Admin dashboard, Reports queue, Moderation, Users, Jobs, Action log
├── Jobs/           Feed, Detail, Apply, My Jobs
├── Messages/       Conversation list, Chat (scanner before send)
├── Notifications/  Notifications list
├── Profile/        Profile, Edit profile (bio scanner), Blocked users
├── Safety/         SafetyScanner (logic), Check-in, Trusted circle
└── Reports/        ReportSheet, Reports/Disputes
```

### Data flow

Views depend on **service protocols** via `@Environment(\.services)`, never on concrete types. `AppServices.mock` wires the demo layer today; swap individual services for live Supabase ones in one place.

`SessionStore` (an `@Observable`) drives top-level routing: `splash → onboarding → underageBlocked → home`, and routes `home` to the correct dashboard per `UserRole`.

---

## Safety scanner

`Safety/SafetyScanner.swift` is pure, reusable logic. It detects and classifies:

- Contact info: phone, email, street address, URLs
- Payment tags: Cash App, Venmo, Zelle, PayPal, etc.
- Social handles: Snapchat, Instagram, TikTok, Discord, etc.
- Off-platform contact attempts
- Adult content, drugs, alcohol, tobacco/vapes, weapons, gambling, crypto/scam, dangerous tools
- Unsafe/late-night meetups, harassment/threats, hate speech, spam/scams

It returns `SafetyScanResult { severity: .safe / .warn / .block, matches, message }`.

**Where it's wired:**
- **Post Job** — scans all fields + schedule before creating a job (blocks on severe content).
- **Chat** — scans every message; blocked messages are never sent (`MessageService.sendMessage` throws `.blockedContent`).
- **Apply to job** — scans the applicant message.
- **Edit profile** — scans the bio.

Friendly warning shown everywhere: **“Keep contact and unsafe details off MORT for safety.”**

---

## Supabase

Config lives in `Services/SupabaseConfig.swift` (public **anon key only** — never the service_role key, never logged).

The app currently runs on **mock services** (in-memory `MockStore`) so it works end-to-end without a backend. To go live:

1. In Xcode: **File → Add Package Dependencies →** `https://github.com/supabase/supabase-swift`
2. Create a shared client with `SupabaseConfig.url` / `SupabaseConfig.anonKey`.
3. Replace each `Mock*Service` with a live implementation (each has a `// TODO: Supabase` marker).
4. Create the tables/bucket below and add Row Level Security policies per role.

**Tables to prepare:** `profiles`, `jobs`, `job_applications`, `conversations`, `messages`, `notification_events`, `reports`, `blocked_users`, `guardian_links`, `trusted_circle_contacts`, `safety_pings`, `admin_actions`, `moderation_queue`, `ad_reward_events`, `user_reward_balances`, `safety_scans`, `rate_limit_events`.

**Storage bucket:** `profile-avatars`.

---

## Permissions

Declared in `project.pbxproj` (`INFOPLIST_KEY_*`) for real-device builds:

- Camera — “MORT uses the camera for profile photos and job proof photos.”
- Photo Library — “MORT uses your photo library so you can choose profile photos and upload job proof images.”
- Location When In Use — “MORT uses your location to help show nearby jobs and support safety check-ins.”
- Notifications — requested at runtime (copy in the onboarding step).

---

## Real vs. mock

| Area | Status |
| --- | --- |
| UI / navigation / routing | Real |
| Safety scanner | Real (local logic) |
| Onboarding + age gate + role rules | Real |
| Data (jobs, messages, profiles, reports, …) | Mock (`MockStore`, in-memory) |
| Auth | Mock (validates format, no real session) |
| Avatar upload | Mock (returns placeholder URL) |
| Payments | None by design |

---

## What needs Xcode / Apple later

- Signing team & bundle ID for device builds and TestFlight.
- Live Supabase wiring (package + service implementations + RLS).
- Real push notification entitlement + `UNUserNotificationCenter` request.
- App Store metadata, screenshots, privacy nutrition labels.

## Test first after downloading

1. Splash → Welcome → **Explore a demo dashboard** for each role.
2. Full signup: enter a DOB **under 13** (should block), then 13–17 (teen), then 18+ (role choice).
3. Post a job containing a phone number or “venmo” → see it blocked/warned.
4. Open a chat and try sending “text me 555-123-4567” → blocked.
5. Edit profile bio with an Instagram handle → blocked.
6. Teen → Safety tab → check in; Admin → Reports queue → resolve a report.
// Paste Rork code for this file here
