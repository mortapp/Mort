# Server-enforced password protection (Free plan) — 2026-11-16

Project: `jxbnrkasktbhtiujkhay` (production). Status: implemented in the repo,
verified on the local production replica, **not applied to production**.

## Why this exists

| Option | Availability on the current Free plan |
|---|---|
| Native leaked-password protection (HIBP) | Pro plan and above ([Supabase password security](https://supabase.com/docs/guides/auth/password-security)) |
| Password Verification Attempt hook | Teams/Enterprise ([Supabase auth hooks](https://supabase.com/docs/guides/auth/auth-hooks)) — and it runs on sign-in, not on password set |
| Before User Created hook | Available, but its payload has no password |
| Previous app-side check (`leaked-password-check`) | Required a JWT, so it returned 401 at signup; Flutter failed open. A direct `auth.signUp`/`updateUser` call skipped it entirely. **No effective protection.** |

## Design

1. `supabase/functions/password-guard` (verify_jwt = false) is the only
   supported way to set a password:
   - `signup`: email, password, date_of_birth, display_name, redirect_to.
   - `update_password`: user's access token (normal or recovery session).
2. It enforces the MORT policy (≥12 characters, upper, lower, digit, symbol,
   ≤72 bytes, no control characters, must not contain the email/local part)
   and the HIBP k-anonymity range check (only a 5-hex SHA-1 prefix leaves
   the function). **HIBP failure fails closed** (503
   `leaked_password_check_unavailable`).
3. It then calls Supabase Auth itself with the **anon/publishable key only**
   (never the service role), carrying a single-use attestation
   `v1.<purpose>.<nonce>.<exp>.<hmac>` (HMAC-SHA256, 5-minute lifetime) in user
   metadata. The token never reaches the client; responses are stripped.
4. Production-baseline migration `20261116130000_server_enforced_password_attestation.sql`:
   - `BEFORE INSERT` on `auth.users`: any non-empty password requires a valid
     `signup` attestation bound to `lower(email)`.
   - Deferred constraint trigger on `UPDATE OF encrypted_password`: any new
     non-empty password requires a valid `update_password` attestation bound
     to the user id, checked at commit (GoTrue writes the password, then the
     metadata, in one transaction).
   - Nonces are recorded in `private.password_attestation_uses` (RLS deny-all,
     no client grants) — replay is rejected.
   - The token is stripped from `raw_user_meta_data` and `auth.identities.identity_data`.
   - The HMAC key is read from Vault (`mort_password_attestation_secret`).
     Missing key → every password write fails closed.

## Evidence (local production replica, `scripts/qa/replica/password.mjs`)

Weak (5 kinds), leaked, invalid input (4 kinds), HIBP outage, acceptable
signup + confirmation + sign-in; direct GoTrue signup without/with forged,
wrong-subject, expired, wrong-purpose attestations; direct password change
(weak and strong); cross-user attestation; replay; recovery session direct
change; recovery through the guard; metadata-only update; repeated sign-in;
passwordless (OAuth-shaped) insert; invites. Results are in the CI artifact
`production-replica-acceptance/password.json`.

Unit tests: `supabase/functions/password-guard/password_guard_test.ts`.

## Compatibility

| Flow | Result |
|---|---|
| Email sign-in | Unchanged (no password write; production hashes are bcrypt cost 10 and DB hash encryption is off, so GoTrue does not rewrite hashes on sign-in) |
| Google / Apple OAuth | Unchanged (OAuth users have no password) |
| Password reset | Email link unchanged; the new password is set through the guard |
| Flutter sign-up / recovery | Updated in this PR (also fixes D1: sign-up now sends `date_of_birth`) |
| iOS (Swift) client | Updated in this PR to collect DOB and call password-guard; source-only change, no iOS build or release performed |
| Expo app | Reference-only, already fails closed |
| Dashboard/admin "create user" with a password | **Blocked by design**. Staff provisioning must use the passwordless Supabase invite flow; after the recipient accepts the invite and has a session, the recipient sets their password through password-guard (update_password). Do not create staff users with a preset password. |
| Magic-link/OTP auto-signup | **Blocked** (GoTrue generates a random password). Not used by MORT |

## Residual risk — this is NOT equivalent to native protection

- A Postgres superuser/owner can still write hashes directly (same as native).
- All signups reach GoTrue from the Edge Function's egress IP. The guard
  therefore applies a database-backed, cross-isolate signup quota before
  calling Auth: 20 globally/hour, 10 per source-IP hash/hour, and 5 per
  email hash/hour. Only hashes and bucket counters are stored. If the quota
  RPC or database is unavailable, signup fails closed with 503. Keep the
  Supabase Auth per-IP signup ceiling above the guard's global quota; adjust
  both together if the launch volume requires a higher cap. CAPTCHA remains
  a separate anti-automation improvement, not a substitute for the shared cap.
- The default Supabase SMTP sender has a very low hourly email limit;
  configure custom SMTP before launch (separate gate).
- An HIBP outage blocks signups and password changes (deliberate fail-closed).
- If Supabase later enables at-rest password-hash encryption for the project,
  sign-in re-encryption would be rejected and users could not sign in. Watch
  for `MORT_PASSWORD_ATTESTATION_*` errors in Auth logs after any Supabase
  platform change; rollback below.
- HMAC comparison in SQL is not constant-time (exploitation would require
  timing a bcrypt-dominated request over the network; considered negligible).
- **Recommendation: upgrade to Pro and enable native leaked-password
  protection as well.** Keep this guard (it also enforces the composition
  policy and DOB contract).

## Deployment (requires owner approval — not done)

1. Generate a 32-byte random HMAC secret.
2. Store it in Supabase Vault as mort_password_attestation_secret.
3. Set MORT_PASSWORD_ATTESTATION_SECRET for the password-guard Edge Function.
4. Confirm SUPABASE_SERVICE_ROLE_KEY is available to the Edge Function runtime.
   It is used only server-side to call the service-role-only signup quota RPC.
5. Deploy password-guard with verify_jwt=false from supabase/config.toml.
6. Smoke test with a weak password (expect 422); this creates no account.
7. Release updated Flutter and iOS clients before applying database enforcement.
   Both clients must collect DOB and use password-guard. No old client may write
   passwords directly once the migration is active.
8. Apply 20261116130000_server_enforced_password_attestation.sql.
9. Run fresh-user signup acceptance on each released app, test password
   recovery, and verify that the shared quota is enforced across instances.

## Key rotation

Rotation must update both copies together, briefly blocking in-flight
signups (tokens live ≤5 minutes):
`select vault.update_secret((select id from vault.secrets where name='mort_password_attestation_secret'), '<new>');`
then `supabase secrets set MORT_PASSWORD_ATTESTATION_SECRET=<new>`. Rotate on
suspected exposure or annually.

## Staff account provisioning

The migration intentionally rejects password-bearing Auth Admin API/dashboard
user creation because it bypasses the password policy and HIBP check. The
supported staff provisioning path is: (1) an authorized operator sends a
passwordless email invitation with Supabase inviteUserByEmail; (2) the staff
recipient accepts the invitation and establishes a session; (3) the recipient
sets their own password through password-guard update_password. The invite
does not grant a staff role; staff role assignment remains a separate,
authorized server-side operation. Never place a preset password in an invite
or bypass the guard for a staff account.

## Rollback

```sql
drop trigger if exists mort_password_attestation_on_insert on auth.users;
drop trigger if exists mort_password_attestation_on_password_change on auth.users;
drop trigger if exists mort_strip_consumed_password_attestation on auth.users;
drop trigger if exists mort_strip_password_attestation on auth.identities;
```
Functions and the nonce table can stay. The Flutter client keeps working
after rollback (the guard still forwards to Auth).
