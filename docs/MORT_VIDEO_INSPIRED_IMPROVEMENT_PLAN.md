# MORT Video-Inspired Improvement Plan

Date: 2026-07-10

This plan converts the video's UX psychology ideas into original MORT-specific improvements. It does not copy the video's app examples, wording, visuals, or brand.

| Original pattern | Why it works | MORT adaptation | Screens affected | Backend affected | RevenueCat affected | Safety risk | Difficulty | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Smart defaults | Users scan and adjust faster than they invent from scratch. | Recommend city/state-only locality, safe availability windows, and "Not set" payment preference. | Age, profile, availability, payment | No schema change | None | Low, if defaults are safe | Low | P0 |
| Progress starts above zero | Momentum increases completion. | Treat account creation as onboarding progress and show a 7-step meter. | Onboarding hub, age, role, profile, skills, availability, payment, safety | Profile completion now waits for final safety pledge | None | Low | Medium | P0 |
| Value before ask | Users trust a product that gives first. | Keep job browsing/applying basics and safety tools free before optional paid perks. | Welcome, monetization, paywalls | None | Paywall copy only | Low | Low | P0 |
| Ownership/investment | People value what they build. | Let users build role, profile, skills, availability, and preferences before final setup completion. | Onboarding | Profile/payment persistence | None | Low | Medium | P0 |
| Loss/status framing | Inaction feels concrete when tied to something real. | Use only safety-framed reminders: "If a job feels wrong, stop and report." Do not use fear to sell. | Safety, reports, paywalls | None | None | Medium if abused | Low | P1 |
| Price context | Prices feel clearer when tied to value. | Show RevenueCat package price strings next to optional benefit context and free-path reminders. | Paywalls | None | Package display copy | Low | Low | P0 |
| No blank empty states | Empty states should convert to safe next action. | Add next-step cards and checklist copy to onboarding placeholders. | Skills, availability | No schema change yet | None | Low | Low | P1 |
| Trust signal before conversion | Users need safety confidence before account/purchase asks. | Place safety-free copy above paid offerings. | Monetization home, paywalls | None | None | Low | Low | P0 |
| Restore/manage clarity | Subscription control reduces anxiety. | Keep restore/manage visible and explain no unlock without RevenueCat/backend confirmation. | Paywall, restore, manage | Entitlement checks unchanged | Existing RevenueCat | Low | Low | P0 |

## Implemented In This Pass

- Onboarding now routes through profile -> skills -> availability -> payment -> safety instead of skipping intermediate steps.
- Profile save no longer marks onboarding complete automatically.
- Final safety pledge marks onboarding complete in Supabase.
- Onboarding screens show progress and role-specific helper copy.
- Skills and availability steps no longer have disabled dead save buttons.
- RevenueCat status now reports web/unsupported before generic IAP-disabled status.
- Paywall cards disable native paywall launch when unavailable.
- Plan cards add free-path and backend-confirmation reminders.

## Still Additive Later

- Persist skills/interests to a dedicated table.
- Persist availability preferences to a dedicated table.
- Add profile completion analytics without collecting unsafe location detail.
- Add saved-job folders and goal analytics behind optional entitlements.
- Add TestFlight native purchase and ad validation.
