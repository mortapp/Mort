# Flutter iOS Test Plan

## Build Target

- Bundle id: `com.mortapp.mobile`
- iPhone first.
- Windows cannot locally build/run the final native iOS app.

## Required Testing

- Run on real iPhone through Mac/Xcode or cloud build path.
- Confirm Supabase Auth session restore.
- Confirm route guards by role.
- Confirm age gate behavior for under 13, teen 13-17, and adult/guardian 18+.
- Confirm iOS notification permission prompt.
- Confirm iOS photo/camera permission prompts.
- Confirm private proof upload path.
- Confirm private verification upload path.
- Confirm messaging scanner blocks unsafe/contact content.
- Confirm Safety Ping creates backend row and expected notification queue behavior.
- Confirm AdMob does not show on sensitive screens.
- Confirm AdMob test ads only before live approval.
- Confirm RevenueCat sandbox products, cancellation, restore, and empty offerings.
- Confirm RevenueCat CustomerInfo entitlement changes after purchase.
- Confirm `RevenueCatUI.presentCustomerCenter` works or gracefully returns an error.
- Confirm teen purchase notice appears for teen users.

## Not Done

iPhone manual testing is not done. TestFlight is not done.
