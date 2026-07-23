# Onboarding Video-Inspired Upgrades

Date: 2026-07-10

## Principles Applied

- Never start from zero: account creation counts as progress.
- Use smart defaults: city/state only, "Not set" payment preference, daylight-first teen availability guidance.
- Let users build ownership: role, profile, safe skills, availability, and preferences.
- Keep required safety/legal steps non-skippable.
- Avoid dead buttons.

## Teen Onboarding

- Age gate explains why DOB is required.
- Teen role explains job discovery, report/block, safety tools, and guardian awareness.
- Profile copy reinforces city/state only and no exact addresses.
- Skills step suggests safe categories such as yard help, pet care, tutoring, cleaning, errands, creative help, and event setup.
- Availability step recommends after-school, weekends, and daylight-first windows.
- Payment preference defaults to "Not set" and explains MORT does not process money.
- Final safety pledge is required before onboarding completion.

## Adult/Business Onboarding

- Adult role explains safe job posting, applicant review, verification, and moderation.
- Availability copy nudges clear start/end expectations.
- Payment preference copy avoids escrow/payment-processing claims.
- Job boosts remain outside onboarding and never bypass review.

## Guardian Onboarding

- Guardian role explains supervision, alerts, linked teen overview, approvals, and privacy boundaries.
- Guardian Mode basics remain free.
- Guardian Plus can add organization/digest value later without locking basic safety.

## Button Logic

- Hub starts age gate or safety rules.
- Age gate routes teen DOB to teen role path and adult DOB to adult/guardian role path.
- Role selection disables teen for adult age band and adult/guardian for teen age band.
- Profile save persists profile progress and routes to skills.
- Skills continues to availability with no fake save.
- Availability continues to payment with no fake save.
- Payment preference persists to Supabase and routes to safety.
- Safety pledge updates `profiles.onboarding_completed = true` and returns to account status.

## Backend Notes

- No destructive database change was made.
- Existing `profiles` and `payment_preferences` tables are reused.
- Skills and availability are currently educational/setup steps; persisted multi-select storage can be added later with additive schema changes.

## Limitations

- Skills/interests and availability are not yet saved as structured data.
- Guardian linking is still handled elsewhere in the app.
- Native permission education still needs TestFlight validation.
