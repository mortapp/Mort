# iOS and TestFlight

MORT is iPhone-first with bundle identifier `com.mortapp.mobile`.

## Local iPhone Testing

```powershell
cd "$env:USERPROFILE\Mort"
pnpm install
pnpm check
npx expo-doctor
npx expo start
```

Use Expo Go for JS/auth/data smoke tests where supported. Use an EAS preview build for production-like native permission behavior, push notifications, and TestFlight rehearsal.

## EAS Setup

```powershell
npx eas login
npx eas init
npx eas build -p ios --profile preview
```

Before production submission:

```powershell
npx eas build -p ios --profile production
npx eas submit -p ios --profile production
```

## Apple Requirements

- Active Apple Developer account.
- Apple credentials or App Store Connect API key configured in EAS.
- Bundle id registered as `com.mortapp.mobile`.
- `EXPO_PUBLIC_PROJECT_ID` set to the EAS project id.
- `eas.json` `ascAppId` and `appleTeamId` filled before App Store submission.

## Permissions To Verify

- iOS notification permission for application, guardian, safety, and message alerts.
- Photo library permission for proof, verification, and report uploads.
- Camera permission if camera capture is tested for uploads.

## Privacy And Safety

Before App Store review, MORT needs production legal pages and review-ready safety material:

- Privacy Policy
- Terms of Service
- Community Guidelines
- minor/teen safety explanation
- UGC moderation, report, and block explanation
- Guardian Mode explanation
- payment preference disclaimer: no payments, escrow, payouts, card entry, or card storage
- adult/business verification disclaimer: internal review only, not a government identity check or safety guarantee

Do not claim App Store approval is guaranteed. Minor safety, labor rules, local marketplace risk, and UGC moderation should be reviewed by counsel before public launch.

## Windows Limitation

Windows can run Expo and EAS cloud builds, but cannot locally build native iOS through Xcode. Use EAS Build or a Mac for native iOS builds.
