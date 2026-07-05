# MORT

MORT is a Flutter mobile app prototype for iOS and Android. It is designed as a clean black, white, and gray local hustle app for teens ages 13 to 17.

## Built Features

- Teen hustle marketplace with local jobs, one-tap acceptance, active job check-ins, completion, XP, and payout math.
- Adult verified job posting flow with identity/payment/address status and locked posting when verification is off.
- Motion Feed with wins, level-ups, team hustles, and a local leaderboard.
- Safe chat interface with direct messages, group chats, unread states, and scam shield scanning.
- Wallet with cash and Cash App payout paths, MORT service cut preview, earnings, badges, and savings goals.
- Shield screen with emergency alert, parent alerts, device trust, human check, bot score, payout lock, linked accounts, and account fail-safes.
- Apple and Google sign-in screen with a human verification gate.

## Run

```sh
flutter pub get
flutter run
```

For a browser preview:

```sh
flutter run -d chrome
```

## Production Notes

The UI uses structured in-app demo data. A production version should connect the same flows to verified auth, guardian consent, adult KYC, location/radius rules, moderation, payment compliance, audit logs, and server-side scam/bot detection.
