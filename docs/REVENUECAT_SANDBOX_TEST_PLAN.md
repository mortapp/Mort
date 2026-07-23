# RevenueCat Sandbox Test Plan

Run only on a real iPhone/TestFlight/sandbox environment. Codex did not perform real purchases.

## Setup

- App Store Connect IAP products exist and are approved/ready for sandbox.
- RevenueCat app is connected to the real App Store app.
- RevenueCat products are attached to entitlements.
- RevenueCat offerings/packages are published.
- RevenueCat webhook points to the Supabase `revenuecat-webhook` function and has the authorization header configured.
- Flutter build includes `IAP_ENABLED=true` and the public RevenueCat iOS SDK key.

## Tests

1. Open default paywall and confirm package price strings come from the store.
2. Cancel a purchase and confirm no entitlement or backend credit unlocks.
3. Buy `mort_plus_monthly`; confirm CustomerInfo has `mort_plus` and `mort_ad_free`.
4. Restore purchases; confirm entitlements remain active.
5. Buy `mort_username_change_token_1`; confirm RevenueCat webhook grants one backend username credit.
6. Consume a username credit through the app; confirm backend count decrements.
7. Buy `mort_job_boost_1`; confirm RevenueCat webhook grants one backend job boost credit.
8. Consume a job boost credit through backend flow; confirm moderation is still required.
9. Buy `mort_ad_free_lifetime`; confirm eligible ads hide.
10. Confirm RevenueCat Dashboard event history shows sandbox events.
11. Confirm Supabase `revenuecat_events` has idempotent event rows.

## Pass Criteria

- Purchase success is only accepted from RevenueCat SDK CustomerInfo and/or the Supabase webhook cache.
- Backend-only credits cannot be self-granted by users.
- No paid entitlement is required for safety or basic marketplace access.
