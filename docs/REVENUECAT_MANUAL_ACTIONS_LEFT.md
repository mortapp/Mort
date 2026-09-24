# RevenueCat Manual Actions Left

- Review and finish the default paywall design in RevenueCat Paywalls Builder using docs/REVENUECAT_PAYWALL_BUILDER_PROMPTS.md.
- Set REVENUECAT_WEBHOOK_AUTH_HEADER as a Supabase Edge Function secret and pass it to this setup script only when creating/updating the RevenueCat webhook integration.

## Always Manual Before Real Users

- Create/approve matching App Store Connect IAP products for real iOS builds.
- Connect the real App Store app instead of relying only on the RevenueCat Test Store.
- Run sandbox purchases on a real iPhone or TestFlight build.
- Review App Store privacy, legal, teen-safety, and monetization copy.

## Exact Paywall Dashboard Steps

Repeat these steps for each offering listed above:

1. Open RevenueCat Dashboard.
2. Select project `projc545d148`.
3. Open **Paywalls**.
4. Click **Create paywall**.
5. Choose **Use a template**, **Create from scratch**, or **AI Editor**.
6. Select the `default` MORT Pro offering.
7. Paste or adapt the matching prompt from `docs/REVENUECAT_PAYWALL_BUILDER_PROMPTS.md`.
8. Verify the package selector uses the offering's packages.
9. Use RevenueCat/App Store price strings; do not hardcode target prices as final truth.
10. Confirm no safety feature, basic applying, basic Guardian Mode, report/block, or Safety Ping is paywalled.
11. Save, publish, then rerun `node scripts/qa-revenuecat-api.mjs`.
