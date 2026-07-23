# MORT Free iPhone Web Testing Plan

This is the no-Apple-Developer-fee path for opening MORT on an iPhone through Safari and installing it to the Home Screen as a PWA.

## What This Preview Is

- Flutter Web release build served from a public host such as Netlify or Vercel.
- Uses the hosted Supabase project through the public anon key configured at build time.
- Uses web-safe UI paths for RevenueCat, AdMob, and proof upload.
- Lets you test navigation, auth, onboarding, job browsing, applications, messaging screens, reports, blocking, admin screens, monetization copy, and general mobile layout.
- Uses MORT PWA metadata, dark theme, and Home Screen install naming.

## What This Preview Is Not

- Not native iOS testing.
- Not TestFlight.
- Not App Store review.
- Not a native purchase test.
- Not native AdMob testing.
- Not iOS push notification testing.
- Not final camera/photo permission testing.
- Not production-ready.

## Build Command

Run from `C:\Users\micha\Mort`:

```powershell
.\scripts\build-web-preview.ps1
```

The script reads only public Supabase browser values from `SUPABASE_URL` / `SUPABASE_ANON_KEY` or `EXPO_PUBLIC_SUPABASE_URL` / `EXPO_PUBLIC_SUPABASE_ANON_KEY`. It fails if `.env.local` contains `SUPABASE_SERVICE_ROLE_KEY`.

Manual equivalent from `C:\Users\micha\Mort\flutter_mort`:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build web --release --dart-define=SUPABASE_URL=$env:SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY --dart-define=WEB_PREVIEW_MODE=true --dart-define=IAP_ENABLED=false --dart-define=ADS_ENABLED=false --dart-define=USE_TEST_ADS=true
```

## iPhone Steps

1. Deploy `C:\Users\micha\Mort\flutter_mort\build\web` to Netlify, Vercel, or another HTTPS host.
2. Open the deployment URL in Safari on iPhone.
3. Tap Share.
4. Tap Add to Home Screen.
5. Keep the name as MORT.
6. Tap Add.
7. Open MORT from the Home Screen icon.

## Required Checks

- The app opens without a blank screen in Safari.
- Add to Home Screen shows the MORT title and icon.
- Supabase auth can reach the hosted project.
- Purchase screens show RevenueCat disabled/setup status on web instead of crashing.
- Ad placements stay hidden or disabled on web.
- Proof upload says native app required in web preview.
- No feature claims native iPhone validation.
- Onboarding completes only after the final safety acknowledgement.

## Before Real Users

- Finish native iPhone QA through Apple Developer Program, EAS/TestFlight, or an equivalent signed iOS build path.
- Verify App Store privacy labels, teen safety policies, Terms, Privacy Policy, moderation escalation, report handling, data retention, and emergency/safety language.
- Confirm RevenueCat products and App Store Connect products match.
- Confirm AdMob is reviewed and uses test ads before live ads.
- Confirm push notifications on real devices.
