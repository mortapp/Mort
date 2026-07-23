# iPhone QA Test Plan

Project location:

```powershell
C:\Users\micha\Mort
```

Local env file:

```powershell
C:\Users\micha\Mort\.env.local
```

Do not commit `.env.local`.

## Backend QA Status - 2026-07-08

Local backend QA is verified against Docker Supabase:

- local Supabase started at `http://127.0.0.1:54321`
- migration reset succeeded
- private Storage buckets verified
- generated Supabase types compiled
- smoke test passed
- local test users/data created
- RLS QA passed
- Expo web export passed
- Expo Doctor passed `20/20`
- `npx expo start --localhost --port 8081` started Metro at `http://localhost:8081` and was stopped cleanly

The old Supabase project `rakjydmgwwgtdislanbt` was also intentionally rebuilt and remotely verified:

- backup and schema audit completed before destructive work
- MORT migration applied
- private Storage setup applied
- `send-push` deployed and invoked
- QA users/data created
- `pnpm run qa:old-project-smoke` passed
- `pnpm run qa:old-project-rls` passed
- required Expo/build/security checks passed

Monetization backend/code integration was also added:

- RevenueCat wrappers and paywall/restore/manage screens
- AdMob wrappers and guarded ad slots
- additive monetization backend migration
- old-project smoke/RLS rerun after monetization backend changes

This is local and rebuilt-remote backend verified. It is not iPhone manual tested, TestFlight verified, App Store reviewed, legal/privacy reviewed, or teen-safety launch approved.

RevenueCat purchases and AdMob ads require EAS development/preview builds for real iPhone verification. Expo Go/web export are not sufficient for final purchase/ad validation.

## Start On Windows

```powershell
cd "$env:USERPROFILE\Mort"
pnpm install
pnpm check
pnpm lint
npx expo-doctor
npx expo start
```

When Expo prints the QR code, open the Camera app or Expo Go on the iPhone and scan the QR code. For iPhone testing against local Supabase from a physical device, confirm the phone can reach the dev machine/network or use a staging Supabase project.

## What Expo Go Can Test

- React Native screens and navigation
- Supabase Auth sign-up/sign-in
- onboarding age gate and role selection
- job feed/detail/application flows
- guardian approval flows
- messaging scanner
- reports/blocking
- in-app notification list
- support/legal screens
- most image picker flows if Expo Go supports the module on the current SDK

## What Requires EAS Dev/Preview Build

- production-like iOS notification permission behavior
- reliable Expo push token registration tied to the EAS project id
- any native config that Expo Go does not include
- TestFlight rehearsal

Create preview build:

```powershell
npx eas login
npx eas init
npx eas build -p ios --profile preview
```

Windows can run Expo and EAS cloud builds, but cannot locally build iOS through Xcode.

## Role Flow

1. Sign up teen user.
2. Confirm onboarding incomplete route.
3. Try under-13 DOB and confirm blocked.
4. Complete teen onboarding with age 13-17.
5. Sign out.
6. Sign up adult user with age 18+.
7. Complete adult onboarding.
8. Submit adult verification.
9. Promote a real admin externally.
10. Sign in as admin and approve verification.
11. Sign in as guardian with age 18+.
12. Accept teen invite.

## Marketplace Flow

1. Verified adult posts a job.
2. Teen opens feed and job detail.
3. Teen applies.
4. Guardian approves.
5. Adult accepts or rejects.
6. Teen uploads proof only after accepted.
7. Adult opens signed proof preview.
8. Adult marks complete or disputed.

## Safety Flow

1. Send safe chat message.
2. Attempt unsafe message with phone/email/social/payment text and confirm scanner blocks.
3. Report a user/message/job.
4. Block a user.
5. Confirm blocked messaging fails.
6. Send Safety Ping as teen.
7. Confirm guardian/admin notification rows.

## Push Flow

1. Use an EAS preview build on a real iPhone.
2. Enable push notifications in profile.
3. Confirm `push_tokens` has an active iOS token.
4. Confirm a `notification_events` row exists.
5. Invoke `send-push` in local/staging:

```powershell
$env:SUPABASE_FUNCTION_URL="https://<project-ref>.supabase.co/functions/v1/send-push"
$env:SUPABASE_FUNCTION_JWT="<temporary-function-jwt-or-anon-key-for-staging>"
$env:SEND_PUSH_INVOKE_SECRET (server-side only placeholder)"<same-secret-set-on-edge-function>"
.\scripts\invoke-send-push.ps1 -BatchSize 25
```

6. Check `notification_events.status` and `push_tokens.last_error`.

## Image Picker Flow

1. Test verification image upload as adult.
2. Test proof upload as teen on accepted application.
3. Test signed proof preview as adult.
4. Confirm private buckets are not public.

## Monetization Flow

1. Use an EAS development or preview build on a real iPhone; Expo Go cannot fully test RevenueCat or AdMob.
2. Open voluntary paywall screens and confirm "Keep using free" remains available.
3. Confirm RevenueCat missing-offering/setup states do not fake prices or success.
4. Confirm Restore Purchases and Manage Subscription screens are visible.
5. Confirm username settings show free changes, validate unsafe names, and save valid names.
6. Confirm AdMob banner/rewarded IDs are configured, while interstitial/native remain disabled until IDs exist.

iPhone manual testing has not been done.

## Bug Notes

Record each bug with:

- iPhone model and iOS version
- Expo Go or EAS build id
- signed-in role
- screen name
- exact steps
- expected result
- actual result
- screenshot or screen recording
- Supabase row/function error if visible

Do not claim App Store approval is guaranteed. Legal, teen safety, labor, privacy, and UGC moderation review are separate launch requirements.

