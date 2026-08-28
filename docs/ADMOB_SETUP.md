# AdMob Setup

AdMob iOS App ID configured for MORT:

```text
ca-app-pub-9412242686563958~6217664808
```

This is an app-level ID. It is not an ad unit ID.

Provided iOS ad units:

- Banner: `ca-app-pub-9412242686563958/2438237282`
- Rewarded: `ca-app-pub-9412242686563958/1223146979`

Still needed:

- iOS interstitial ad unit ID
- iOS native ad unit ID
- Android app ID and ad unit IDs if Android is launched later

The app keeps interstitial/native IDs blank until real units are provided. Android uses a public Google test app id fallback in native config so accidental Android development builds do not crash before Android monetization setup.

## app-ads.txt

The repo includes:

```text
public/app-ads.txt
```

with:

```text
google.com, pub-9412242686563958, DIRECT, f08c47fec0942fa0
```

This is not enough by itself. AdMob crawls the developer website listed in the App Store/Google Play listing. The same file must be deployed at the root of that website:

```text
https://your-developer-website.com/app-ads.txt
```

## Native Build Requirement

`react-native-google-mobile-ads` uses native code. The plugin is configured in `app.config.ts`, and native changes require an EAS development/preview build before real-device testing.

Expo Go is not enough to fully verify AdMob.

Official docs used:

- React Native Google Mobile Ads setup: https://docs.page/invertase/react-native-google-mobile-ads
- Google maximum ad content rating: https://support.google.com/admob/answer/7562142

## Safety Rules

Ads are disabled by default with:

```text
EXPO_PUBLIC_ADS_ENABLED=false
EXPO_PUBLIC_USE_TEST_ADS=true
```

MORT blocks ads on:

- onboarding and auth
- Safety Ping and Safety Center
- report/block
- chat/messages
- guardian approvals
- proof upload/review
- verification upload
- payment preferences
- admin queues
- paywalls
- account restriction/ban screens

Teen and unknown users default to conservative treatment:

- non-personalized ad requests
- teen/age-restricted treatment where supported
- max ad content rating no higher than teen-safe settings
- no rewarded ads for teens until legal review approves specific placements

## Consent And ATT

AdMob consent/UMP and App Tracking Transparency are not complete yet. The app delays measurement initialization in native config, but a real consent flow still needs dashboard and iPhone testing.

Do not enable real ads before:

- UMP/consent flow is configured
- ATT decision is reviewed
- App Store privacy disclosures are complete
- teen-safe ad policy is reviewed
- EAS iPhone build is tested
