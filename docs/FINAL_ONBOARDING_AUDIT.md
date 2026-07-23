# Final Onboarding Audit

- Progress now uses eight consistent positions from hub through final safety acknowledgement.
- DOB is entered as `MM/DD/YYYY`, checked for a real calendar date, future dates, implausible age, under-13 access, and role mismatch, then stored as ISO `YYYY-MM-DD`.
- Admin cannot be self-selected.
- Profile is saved with `onboarding_completed=false`.
- Payment preference is saved before safety completion and defaults to `none`.
- Only the final safety acknowledgement calls `completeOnboarding()`.
- Restricted accounts are stopped before incomplete-onboarding access.
- Profile, payment, and final completion prevent duplicate submissions.

Remaining: skills and availability are explanatory steps because the current schema has no complete availability model. Teen `skills` exists in the schema but the cross-role onboarding UI does not yet persist a structured selection. This must not be described as saved data.
