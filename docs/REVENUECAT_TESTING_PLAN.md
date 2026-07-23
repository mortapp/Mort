# RevenueCat Testing Plan

## Automated

- Run `node scripts/qa-revenuecat-api.mjs` to verify API access, app discovery, products, entitlements, offerings, packages, paywalls, and webhook config.
- Run `node scripts/qa-revenuecat-config.mjs` to verify Flutter uses public SDK keys and no server secrets are committed.
- Run `node scripts/qa-revenuecat-webhook.mjs` only with the webhook authorization header available in the current shell.
- Run `node scripts/qa-monetization-rls.mjs` after the additive Supabase migration is applied.
- Run `node scripts/qa-username-credits.mjs` to verify username and job boost credit RLS.

## Manual

- Test RevenueCat purchase, cancellation, restore, and Customer Center on a real iPhone/TestFlight sandbox build.
- Confirm RevenueCat CustomerInfo updates after sandbox purchases.
- Confirm webhook event delivery from the RevenueCat dashboard after manual webhook configuration.
- Confirm App Store Connect products and prices match the app review submission.
