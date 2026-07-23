# iPhone Manual Test Plan

Run on a real iPhone/TestFlight build. These tests were not performed by Codex on Windows.

## Account And Core App

- Sign up.
- Sign in.
- Restore session after force quit.
- DOB age gate rejects under-13 and routes teen/adult/guardian correctly.
- Teen onboarding, adult onboarding, guardian onboarding, and admin-guard behavior work.
- Job feed loads.
- Apply flow works.
- Post job works for adult/business user.
- Guardian approval flow works.
- Messaging safety scanner blocks unsafe messages.
- Reports and blocking work.
- Proof upload works with camera and photo library.
- Push notification permission prompt appears on iOS.
- Safety Ping works.

## Monetization

- RevenueCat offerings load.
- Custom fallback paywall shows route-specific packages:
  - main/default
  - ad-free
  - username change
  - job boost
- Purchase cancellation is handled without unlocking perks.
- Sandbox purchase success updates CustomerInfo.
- Restore purchases refreshes CustomerInfo.
- Webhook delivery updates backend cache/credits.
- Username token purchase grants backend username credit.
- Job boost purchase grants backend job boost credit.
- Ad-free entitlement hides eligible ads.
- No safety, messaging, Guardian Mode basic, report/block, proof, verification, payment, or admin screen is paywalled.

## Ads

- Banner test ads load only where allowed.
- Rewarded test ads load only where allowed.
- No ads appear on restricted safety/account/payment/admin screens.
- Ad-free entitlement hides eligible ad slots.
