# iPhone Web Preview Test Plan

Use this checklist after deploying the Flutter Web build.

## Device Setup

- Use an actual iPhone with Safari.
- Use the HTTPS deployment URL, not `localhost`.
- Add MORT to the Home Screen before running the full pass.
- Keep notes separate from native iPhone/TestFlight QA.

## Smoke Test

- Launch from Safari.
- Launch from the Home Screen icon.
- Confirm the splash/welcome screen renders.
- Confirm the app is portrait-friendly and has no obvious overflow.
- Confirm back navigation and tabs do not trap the user.
- Confirm the PWA title shows MORT.

## Supabase Hosted Backend

- Sign up or sign in with a test account.
- Confirm onboarding reads and writes data through the hosted Supabase project.
- Confirm job feed loads from Supabase.
- Confirm creating or applying for a job does not depend on Docker, local Supabase, or this PC.

## Safety Flows

- Open report/block screens.
- Open Safety Ping.
- Confirm these are not paywalled.
- Confirm teen-safety copy is visible.

## Monetization Web Guard

- Open MORT Plus, Ad-Free, Username Change, Job Boost, Adult Pro, and Guardian Plus routes.
- Confirm RevenueCat screens do not crash on web.
- Confirm purchase actions report disabled/setup status when `IAP_ENABLED=false`.
- Confirm prices are not hardcoded as app truth when RevenueCat/App Store package data is unavailable.
- Confirm native RevenueCat launch buttons are disabled when unsupported.

## Ads Web Guard

- Browse job feed and other non-sensitive surfaces.
- Confirm native AdMob widgets do not crash on web.
- Confirm sensitive screens never show ads.
- Confirm web preview uses `ADS_ENABLED=false`.

## Proof Upload Web Guard

- Open the proof upload screen.
- Confirm it says native app required.
- Confirm the choose-photo action is disabled.
- Do not treat this as camera/photo QA.

## Known Web Preview Limits

- Native purchases are not tested.
- Native AdMob is not tested.
- iOS push notifications are not tested.
- Camera/photo picker behavior is not fully tested.
- App Store subscription management is not tested.
- Real TestFlight install behavior is not tested.
