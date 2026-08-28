# MORT Phase 9 Report

Updated: 2026-07-30

## Result

The code-controlled remote-push foundation is implemented and hosted. The FCM
provider is not configured, remote push remains disabled, and real-device
delivery is not claimed.

## Delivered

- Firebase provider abstraction with a disabled no-op implementation.
- Permission-aware token registration, rotation, account transfer, per-device
  and all-device revocation, and a ten-device account cap.
- Nine server-authoritative categories, preferences, IANA-zone quiet hours,
  and safety/security bypass.
- Generic lock-screen copy, UUID-only payload allowlist, and authenticated
  in-app state reload.
- Atomic queue claim/complete, bounded retry, invalid-token cleanup, and
  privacy-minimized delivery events.
- FCM HTTP v1 Edge sender using server-only OAuth service-account credentials.

## Applied Migrations

1. `20260730090000_fcm_remote_push_foundation.sql`
2. `20260730091000_fcm_device_limit_hardening.sql`
3. `20260730101000_fix_push_sanitizer_volatility.sql`

The volatility repair was added after linked database lint identified that the
sanitizer's JSON expression is `STABLE`, not `IMMUTABLE`. It passed a hosted
transaction rollback test before normal application.

## Verification

| Gate | Result |
|---|---|
| Hosted remote-push QA | PASS, registration, isolation, rotation, preferences, privacy, revocation, cap, cleanup |
| Edge Function unauthorized request | PASS, 401 |
| Edge Function authorized disabled-provider request | PASS, 200 and zero processed |
| `send-push` deployment | ACTIVE version 21, JWT verification true |
| Focused Flutter push tests | PASS, 17/17 |
| Database lint after repair | Push warning cleared |
| FCM credentials | Absent, as expected |
| Real-device FCM delivery | NOT RUN, external gate |

## Bugs Found And Fixed

1. PostgreSQL rejected a subquery inside a check constraint; the payload shape
   is now enforced with direct JSON type and key checks.
2. Hosted PostgreSQL did not expose the assumed `jsonb_object_length` helper;
   exact-key enforcement now uses supported JSON operators.
3. A test looked for an RPC name in the coordinator even though repository code
   owns the RPC; the contract now checks the correct layer.
4. Device registration was initially unbounded and account switching could
   collide on the active-device uniqueness rule; hosted hardening added the cap
   and collision-safe transfer.
5. The payload sanitizer had the wrong volatility declaration; a forward
   migration corrected it without changing behavior.

