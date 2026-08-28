# Onboarding Button Logic Audit

Date: 2026-07-10

## Routes Audited

- `/onboarding`
- `/onboarding/age`
- `/onboarding/role`
- `/onboarding/profile`
- `/onboarding/skills`
- `/onboarding/availability`
- `/onboarding/payment`
- `/onboarding/safety`

## Findings Fixed

- Profile setup previously marked onboarding complete immediately. Fixed: profile save now persists progress with `completeOnboarding: false`.
- Profile setup previously jumped directly to safety. Fixed: it now routes through skills, availability, and payment.
- Skills and availability showed disabled save buttons. Fixed: removed fake/dead save actions and kept honest continue actions.
- Final safety rules previously only navigated away. Fixed: it now updates Supabase onboarding completion before returning to account status.

## Current Button Behavior

| Screen | Primary CTA | Result |
| --- | --- | --- |
| Onboarding hub | Start age gate | Opens DOB age gate |
| Age gate | Continue | Routes to role selection based on DOB age band |
| Role selection | Teen / Adult / Guardian | Routes to profile with selected role |
| Profile | Save profile | Saves profile, keeps onboarding incomplete, routes to skills |
| Skills | Continue | Routes to availability |
| Availability | Continue | Routes to payment |
| Payment | Save payment preference | Saves payment preference, routes to safety |
| Safety | I understand - finish setup | Marks onboarding completed in Supabase, routes to account status |

## Safety Requirements

- Required age, role, profile, payment-preference explanation, and safety pledge are not bypassed.
- Under-13 users remain blocked.
- Teen/adult role mismatch remains blocked.
- Admin self-selection remains unavailable.

## Remaining Work

- Add persisted skill/interests editor.
- Add persisted availability editor.
- Add analytics for onboarding drop-off after privacy review.
- Add automated widget tests for the full route sequence.
