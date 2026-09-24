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
| default | published |

RevenueCat paywalls must avoid dark patterns, fake urgency, fake discounts, and any "pay to be safe" copy. The published default paywall uses MORT branding and store-returned prices. Run `node scripts/qa-revenuecat-api.mjs` after each remote paywall edit.
