# MORT Review Access Maintenance 0.9.6

`play-review@mortapp.test` is a reserved identifier, not an account. Do not create a Supabase user, password, magic link, OTP, invitation, Google identity, role, or entitlement for it.

- The mobile app accepts only the exact ASCII lowercase identifier after trimming ordinary outer ASCII whitespace.
- The local reviewer session is nonpersistent and contains no access token or user JWT.
- Migration `20260726024327_reserve_play_reviewer_identifier.sql` blocks Auth creation before insert and email changes before update.
- Run `node scripts/qa-play-reviewer-isolation.mjs` after Auth, RLS, PIN, or admin-control changes.
- Keep legacy synthetic QA account credentials in protected environment variables only. They are for backend regression, not Play Console reviewer access.
- Never commit, print, package, screenshot, or email a service-role key, database password, Supabase access token, signing secret, or provider secret.
