# TestFlight Checklist

- Run `eas login`.
- Run `eas init`; the app configuration lives in `app.config.ts`.
- Confirm `ios.bundleIdentifier` is `com.mortapp.mobile`.
- Configure Apple Developer signing credentials through EAS.
- Fill `submit.production.ios.ascAppId` and `appleTeamId` in `eas.json`.
- Build for iPhone/TestFlight from Windows with `eas build -p ios --profile preview`.
- Add production Supabase redirect URLs.
- Confirm notification, camera, and photo-library prompts on a real iPhone.
- Validate onboarding for under-13, teen, adult, guardian, and admin users.
- Validate RLS with separate real Supabase users.
- Verify adults cannot post until business verification is approved.
- Verify teen applications can enter `guardian_pending` and guardians can approve or reject.
- Verify messages containing phone numbers, email addresses, or banned terms are rejected by `send_safe_message`.
- Verify report/block flows hide blocked users and create moderation queue records.
- Verify proof upload and proof review from application records.
- Verify in-app notification rows and Expo push-token registration.
- Verify no payment processing, escrow, card entry, or payout credential storage appears in the app.
- Windows can run Expo and EAS builds, but Expo CLI 57 skips local iOS native project generation on Windows. Use EAS Build or run `npx expo prebuild --platform ios` on macOS/Linux with Node installed.
