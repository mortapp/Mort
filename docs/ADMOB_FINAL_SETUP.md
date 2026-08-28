# AdMob Final Setup

## Config Verified

- iOS App ID: `ca-app-pub-9412242686563958~6217664808`
- iOS Banner Ad Unit: `ca-app-pub-9412242686563958/2438237282`
- iOS Rewarded Ad Unit: `ca-app-pub-9412242686563958/1223146979`
- `app-ads.txt`: `google.com, pub-9412242686563958, DIRECT, f08c47fec0942fa0`

## Runtime Rules

- `ADS_ENABLED` defaults to `false`.
- `USE_TEST_ADS` defaults to `true`.
- Ads are disabled on web.
- Ad-free entitlement hides eligible ads.
- No interstitial or native ad unit is configured, so those formats must remain disabled.
- Do not show ads on auth, safety, chat/messaging, guardian approval, proof upload, verification, payment, admin, report/block, or Safety Ping screens.

## Before Real Ads

1. Add real iPhone test devices in AdMob.
2. Run banner and rewarded test-ad flows on a real device.
3. Confirm ad-free entitlement hides eligible ad slots.
4. Confirm safety/admin/payment/chat/proof/verification screens never show ads.
5. Host `app-ads.txt` at the root of the developer website.
6. Complete AdMob app review.
