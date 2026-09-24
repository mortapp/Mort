# RevenueCat Manual Actions Left

- No additional RevenueCat API setup action was detected by the latest script run.

## Always Manual Before Real Users

- Create and activate the matching Google Play Console products/base plans.
- Run a license-tester purchase, renewal, cancellation, restoration, and webhook delivery on a real Android device.
- Create/approve matching App Store Connect IAP products for real iOS builds.
- Connect the real App Store app instead of relying only on the RevenueCat Test Store.
- Run sandbox purchases on a real iPhone or TestFlight build.
- Review App Store privacy, legal, teen-safety, and monetization copy.

## Paywall maintenance

The default MORT Pro paywall is managed with `scripts/configure-mort-paywall.mjs`. Review the remote draft, published status, copy, and all four package selectors before changing it. Rerun `node scripts/qa-revenuecat-api.mjs` after a change.
