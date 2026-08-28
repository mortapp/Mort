# App Store Connect Product Matrix

Pricing targets are planning targets only. App Store Connect and RevenueCat package price strings are the runtime source of truth.

| Product ID | Type | Target price | RevenueCat entitlement | Offering/package | App copy | Review notes | Screenshot needed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `mort_plus_monthly` | Auto-renewable subscription | $0.99/month | `mort_plus`, `mort_ad_free` | `default/monthly`, `teen_perks/monthly` | Optional style, convenience, filters, saved folders, and ad-free eligible browsing. | Free job applying, Guardian Mode basics, report/block, Safety Ping, and safety scanner stay free. | Main Plus paywall |
| `mort_plus_yearly` | Auto-renewable subscription | $7.99/year | `mort_plus`, `mort_ad_free` | `default/annual`, `teen_perks/annual` | Same optional Plus perks at yearly cadence. | No fake urgency or forced upgrade. | Main Plus paywall |
| `mort_plus_lifetime` | Non-consumable | $14.99 one-time | `mort_plus`, `mort_ad_free`, `mort_lifetime` | `default/lifetime`, `teen_perks/lifetime` | One-time optional MORT Plus unlock. | Confirm non-consumable restore behavior. | Main Plus paywall |
| `mort_ad_free_lifetime` | Non-consumable | $1.99 one-time | `mort_ad_free` | `default/ad_free`, `ad_free/lifetime` | Removes eligible ads on safe browsing screens. | No ads should appear on safety/auth/chat/verification/admin/payment screens regardless. | Ad-free paywall |
| `mort_username_change_token_1` | Consumable | $1.99 | `mort_username_change_token` | `teen_perks/username_change`, `username_change/token` | One optional username change token after free changes. | Token must sync through RevenueCat webhook and backend credit. | Username token paywall |
| `mort_profile_style_pack` | Non-consumable | $0.99 | `mort_profile_style_pack` | `teen_perks/profile_style` | Optional profile style pack. | Purely cosmetic; no safety or access feature locked. | Teen perks paywall |
| `mort_adult_pro_monthly` | Auto-renewable subscription | $2.99/month | `mort_adult_pro` | `adult_pro/monthly` | Templates, applicant sorting, and job insights for adults/businesses. | Verification and moderation are never bypassed. | Adult Pro paywall |
| `mort_guardian_plus_monthly` | Auto-renewable subscription | $1.99/month | `mort_guardian_plus` | `guardian_plus/monthly` | Weekly digests and organization; basic Guardian Mode stays free. | Must not imply payment is needed for teen safety. | Guardian Plus paywall |
| `mort_job_boost_1` | Consumable | $1.99 | `mort_job_boost` | `adult_pro/job_boost`, `job_boost/boost` | Optional extra visibility for reviewed jobs. | Boosts never bypass safety review, moderation, or verification. | Job Boost paywall |

## Subscription Group Suggestion

- Group name: `MORT optional memberships`.
- Include `mort_plus_monthly`, `mort_plus_yearly`, `mort_adult_pro_monthly`, and `mort_guardian_plus_monthly` only if Apple review accepts the role-specific subscription grouping. Otherwise use separate groups for teen/user Plus, Adult Pro, and Guardian Plus.
