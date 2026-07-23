# MORT Profile Persistence Root Cause

## Verified defect mechanism

The previous Flutter repository issued direct PostgREST `update` and `upsert` calls against `profiles`, ignored the returned row count, and then treated the absence of a thrown exception as a successful save. A Postgres RLS update can affect zero rows without producing the persisted record the UI expected. The client therefore had no proof that the displayed values were committed.

Profile setup also split one logical save across a profile upsert and a second profile-details update. A failure between those requests could leave partial state. Avatar writes similarly depended on a separate direct profile update after Storage upload.

Evidence before repair:

- `ProfileRepository.saveProfileDetails` awaited a direct update but did not request or validate a returned row.
- `saveProfileDetails` then performed a separate `get_my_profile` read, allowing stale or concurrent state to be mistaken for the write result.
- `saveProfile` and `saveProfileDetails` were two distinct transactions.
- Success navigation occurred after those client calls rather than after parsing one canonical server response.

This report does not claim that every observed failure was caused by the same network, cache, or RLS event. The release-blocking cause of the false-success behavior was the missing persisted-row contract itself.

## Security context

The existing sensitive-field trigger correctly blocked role, verification, account-status, and test-account forgery, but the broad self-update policy was not a canonical profile API. The repaired path derives the user from `auth.uid()` and accepts no target user ID.
