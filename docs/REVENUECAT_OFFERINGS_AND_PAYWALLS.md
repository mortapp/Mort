# RevenueCat Offerings And Paywalls

## Offerings

### default

- Display name: MORT Pro
- Current offering target: yes
- Setup status: already_exists
- Packages: $rc_weekly -> mort_pro:weekly, $rc_monthly -> mort_pro:monthly, $rc_annual -> mort_pro:annual, $rc_lifetime -> lifetime


## Paywalls

| Offering | Status |
| --- | --- |
| default | created_shell |

RevenueCat paywalls must avoid dark patterns, fake urgency, fake discounts, and any "pay to be safe" copy.

## Manual Paywall Setup

The RevenueCat API returned `422 parameter_error Paywall validation failed` for the visual paywall creation attempts. Finish paywall design in the Dashboard:

1. Open RevenueCat Dashboard.
2. Select the project resolved by the matching RevenueCat API key: `projc545d148`.
3. Open **Paywalls**.
4. Click **Create paywall**.
5. Choose a template, start from scratch, or use AI Editor.
6. Attach the paywall to the `default` MORT Pro offering only.
7. Use the matching copy from `docs/REVENUECAT_PAYWALL_BUILDER_PROMPTS.md`.
8. Use RevenueCat/App Store returned package price strings; the pricing numbers in docs are targets, not final app truth.
9. Confirm the copy says free remains useful and safety tools stay free.
10. Save and publish the paywall, then rerun `node scripts/qa-revenuecat-api.mjs`.
