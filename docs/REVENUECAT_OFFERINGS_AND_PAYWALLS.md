# RevenueCat Offerings And Paywalls

## Offerings

### default

- Display name: Default MORT Perks
- Current offering target: yes
- Setup status: already_exists
- Packages: monthly -> mort_plus_monthly, annual -> mort_plus_yearly, lifetime -> mort_plus_lifetime, ad_free -> mort_ad_free_lifetime

### teen_perks

- Display name: Teen Perks
- Current offering target: no
- Setup status: already_exists
- Packages: monthly -> mort_plus_monthly, annual -> mort_plus_yearly, lifetime -> mort_plus_lifetime, username_change -> mort_username_change_token_1, profile_style -> mort_profile_style_pack

### adult_pro

- Display name: Adult Pro
- Current offering target: no
- Setup status: already_exists
- Packages: monthly -> mort_adult_pro_monthly, job_boost -> mort_job_boost_1

### guardian_plus

- Display name: Guardian Plus
- Current offering target: no
- Setup status: already_exists
- Packages: monthly -> mort_guardian_plus_monthly

### ad_free

- Display name: Ad-Free
- Current offering target: no
- Setup status: already_exists
- Packages: lifetime -> mort_ad_free_lifetime

### username_change

- Display name: Username Change
- Current offering target: no
- Setup status: already_exists
- Packages: token -> mort_username_change_token_1

### job_boost

- Display name: Job Boost
- Current offering target: no
- Setup status: already_exists
- Packages: boost -> mort_job_boost_1


## Paywalls

| Offering | Status |
| --- | --- |
| default | already_exists |
| teen_perks | already_exists |
| adult_pro | already_exists |
| guardian_plus | already_exists |
| ad_free | already_exists |
| username_change | already_exists |
| job_boost | already_exists |

RevenueCat paywalls must avoid dark patterns, fake urgency, fake discounts, and any "pay to be safe" copy.

## Manual Paywall Setup

The RevenueCat API returned `422 parameter_error Paywall validation failed` for the visual paywall creation attempts. Finish paywall design in the Dashboard:

1. Open RevenueCat Dashboard.
2. Select project `b2454250`.
3. Open **Paywalls**.
4. Click **Create paywall**.
5. Choose a template, start from scratch, or use AI Editor.
6. Attach the paywall to the matching offering: `default`, `teen_perks`, `adult_pro`, `guardian_plus`, `ad_free`, `username_change`, or `job_boost`.
7. Use the matching copy from `docs/REVENUECAT_PAYWALL_BUILDER_PROMPTS.md`.
8. Use RevenueCat/App Store returned package price strings; the pricing numbers in docs are targets, not final app truth.
9. Confirm the copy says free remains useful and safety tools stay free.
10. Save and publish the paywall, then rerun `node scripts/qa-revenuecat-api.mjs`.
