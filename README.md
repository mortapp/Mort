# MORT

MORT is an iOS-first Expo React Native app for a teen-safe local hustle marketplace. Teens aged 13-17 find jobs, adults/businesses post jobs, guardians can supervise, and admins moderate safety, verification, jobs, users, reports, support, and proof uploads.

Slogan: Earn nearby. Move smart.

## Stack

- Expo React Native with TypeScript and Expo Router
- Supabase Auth, Postgres, Realtime-ready tables, Storage, RLS, and Edge Functions
- Direct Supabase queries from the app using the anon key only
- Expo Notifications for device push-token registration and in-app notification rows
- Expo Image Picker for proof, report, and verification uploads
- RevenueCat SDK wrappers for premium/ad-free entitlements
- AdMob SDK wrappers with teen-safe placement guards
- EAS Build/TestFlight-ready iOS configuration

## Local Setup

1. Install dependencies:

   ```bash
   pnpm install
   ```

2. Copy `.env.example` to `.env.local` and fill in your local or fresh staging Supabase project URL and anon key. No real secret belongs in source control or the zip.

3. Apply the Supabase schema to local Docker Supabase, a fresh staging project, or a reviewed branch:

   ```bash
   supabase link --project-ref <fresh-staging-project-ref>
   supabase db push
   supabase functions deploy send-push
   ```

   The old Supabase project ref `rakjydmgwwgtdislanbt` was intentionally rebuilt on 2026-07-08 after backup and destructive-risk confirmation. See `docs/OLD_PROJECT_REBUILD_REPORT.md` before using or modifying it again.

4. Run locally:

   ```bash
   pnpm start
   ```

## Required Supabase Setup

- Enable email/password auth in Supabase Auth.
- Add deep-link redirect URLs for local/dev and production builds:
  - `mort://`
  - `exp://127.0.0.1:8081`
  - your Expo development URLs
- Apply `supabase/migrations/202607070001_initial_mort.sql` with `supabase db push` only on a fresh project, Supabase branch, or reviewed staging project. Do not run `supabase db reset` against production or a data-bearing project.
- Deploy `supabase/functions/send-push`.
- Set Edge Function secrets:
  - `SEND_PUSH_INVOKE_SECRET`

Hosted Supabase Edge Functions provide runtime-managed `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`; do not place service-role keys in Expo/mobile files. The Expo app never uses a service-role key. Admin privileges are represented by `profiles.role = 'admin'` and are protected by Supabase RLS policies. Promote admins only from a trusted server, SQL console, or Supabase dashboard.

## iOS Build

The app is configured with bundle identifier `com.mortapp.mobile` and iOS permission strings for notifications, camera, and photo library. Before TestFlight:

```bash
eas build:configure
eas build --platform ios --profile preview
eas submit --platform ios --profile production
```

Run `eas init` to attach the project to EAS, set `EXPO_PUBLIC_PROJECT_ID`, then fill `ascAppId` / `appleTeamId` in `eas.json` before submission. The app configuration lives in `app.config.ts`.

Windows can run Expo, typechecks, web export, and EAS cloud builds. Expo CLI 57 does not generate the local `ios/` native project on Windows; run `npx expo prebuild --platform ios` on macOS or a Linux/WSL distro with Node, or use EAS Build for iPhone/TestFlight.

## Safety Model

- Date-of-birth onboarding blocks users under 13.
- Teen accounts are limited to users aged 13-17.
- Adult/business accounts require internal verification before job posting.
- Guardian connections require invite and approval.
- Teen applications can require guardian approval and move to adult review after guardian approval.
- Guardian Mode can pause a linked teen's apply/message activity.
- Message sends go through the `send_safe_message` Postgres RPC, which blocks contact-sharing, off-platform/social/payment handles, secrecy pressure, and other unsafe terms.
- Reports and blocks are first-class tables with RLS.
- Proof/verification/report buckets stay private. Proof previews use signed URLs for application participants.
- Push tokens, payment preferences, support tickets, admin action logs, notification rows, and conversation participants are first-class tables with RLS.
- Notification events are queued in Postgres and processed by the `send-push` Edge Function.
- Admin dashboard screens read moderation queues protected by RLS.
- Payment preferences are preference-only metadata: cash, Cash App tag, Square link, or flexible. MORT does not process payments, hold funds, provide escrow, or store payment credentials.

## Checks

```bash
pnpm check
pnpm lint
pnpm build
npx expo export --platform web
npx expo-doctor
```

Before pushing to GitHub, run:

```powershell
.\scripts\secret-scan.ps1
```

## Monetization

MORT now includes guarded RevenueCat and AdMob integration code:

- `react-native-purchases`
- `react-native-purchases-ui`
- `react-native-google-mobile-ads`
- RevenueCat paywall/restore/manage screens
- AdMob app ID config for iOS
- `public/app-ads.txt`
- additive Supabase monetization tables and RLS

Ads and IAP are disabled by default until dashboard setup, consent, EAS builds, iPhone testing, and legal/App Store review are complete.

See:

- `docs/REVENUECAT_SETUP.md`
- `docs/ADMOB_SETUP.md`
- `docs/MONETIZATION_PLAN.md`
- `docs/ADS_AND_IAP_SAFETY.md`
- `docs/MONETIZATION_BACKEND_REPORT.md`

## Old Project Rebuild

The old Supabase project `rakjydmgwwgtdislanbt` has been rebuilt into the current MORT backend baseline and remote QA passed:

- `pnpm run qa:old-project-smoke`
- `pnpm run qa:old-project-rls`

This is backend verification only. iPhone real-device testing, TestFlight, App Store review, legal/privacy review, and teen-safety launch review are still required before real users.
