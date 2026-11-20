# iOS guarded password recovery: source compatibility review

Date: 2026-11-19
Scope: PR #109, branch `fix/server-enforced-password-guard-20261116`, commits
`9237e094d1070dc4817ae26794673e6f5e82ae2d` ("complete guarded password recovery flow") and
`fff15e54093aeeef72d12a22b2388f8b19a1981a` ("validate recovery callback and jwt expiry"), read
together with `dc61fd2` (password-guard sign-up) and `origin/main` at `8af02bd`.

Method: source review only. The iOS app was **not** built, compiled, run, signed or submitted
(per instruction). Every statement below is from reading the source at the commits named.

## Verdict

**Not compatible / not mergeable as-is. One P0 defect blocks everything else.**

`9237e09` replaced `ios/MORTIOSV8/Services/LiveRepositories.swift` (1,944 lines at `9237e09^`)
with only its last 292 lines. The file at the branch head begins mid-token:

```
egory, detail: String, jobId: String?) async throws {
```

Consequences, all verified with `git show` / `git grep` on the branch head:

1. The file cannot compile (it starts inside a function signature; there are no imports or type
   declarations).
2. `LiveAuthService` and every other live repository class defined in the first ~1,650 lines are
   gone, including sign-in, the `dc61fd2` password-guard sign-up, `sendPasswordReset`, `signOut`,
   `deleteAccount`, profiles, jobs, applications and messaging repositories.
3. `establishPasswordRecoverySession(...)` and `updatePassword(_:)` are declared in
   `ServiceProtocols.swift` and implemented only in `PreviewRepositories.swift` (which throws
   `notConfigured`). `git log --all -S establishPasswordRecoverySession -- ios/MORTIOSV8/Services/LiveRepositories.swift`
   finds no commit on any branch that ever contained a live implementation.
4. Therefore the `/auth/v1/user` server check and the `password-guard` `update_password` request
   the task asked me to verify **do not exist in the source**. They cannot be reviewed; they must
   be written.

Fix required: restore `LiveRepositories.swift` from `9237e09^` (re-applying the 37-line
`dc61fd2` sign-up change, which is in that parent), then add the two live methods. Suggested
shape is in the "Required implementation" section below.

## Item-by-item review

| # | Item | Where | Result |
|---|---|---|---|
| 1 | Parse `com.mortapp.mobile://app/auth-callback` | `MORTIOSV8App.swift` `recoveryParameters(from:)` | PASS (source). Requires scheme `com.mortapp.mobile`, host `app`, path `/auth-callback`; reads only the fragment. The scheme is registered in `ios/project.yml` (`CFBundleURLSchemes`). A unit test rejects an `https://attacker.example` URL. |
| 2 | Token extraction | same | PASS with a note. `access_token`, `refresh_token`, `expires_in`, `type` are extracted from the fragment; duplicate keys keep the first value. `expires_in` defaults to `3600` when missing (it is then capped by JWT `exp`, see 4). |
| 3 | Establish recovery session | `MortSession.beginPasswordRecovery` → `auth.establishPasswordRecoverySession` → `SupabaseClient.establishRecoverySession` | **FAIL (P0).** `SupabaseClient.establishRecoverySession` exists, but nothing calls it: the live `AuthService` method that should call it is missing (see verdict). |
| 4 | JWT `sub` / `exp` validation | `SupabaseClient.establishRecoverySession` | PASS (source), as a client-side sanity check. Requires 3 segments, base64url-decodes the payload, `sub` must be a UUID, `exp` in the future, `0 < expires_in <= 86400`, a non-empty refresh token, and the stored expiry = min(`expires_in`, `exp - now`). No signature check, which is expected on a client; the server check in item 5 is what makes this safe. |
| 5 | `/auth/v1/user` server check | should be in `LiveAuthService.establishPasswordRecoverySession` | **MISSING (P0).** Without it, a structurally valid but forged/revoked token is written to the session store. It cannot be used to change the password (the server rejects it), but the UI would show the recovery form instead of "link unavailable". |
| 6 | password-guard `update_password` | should be in `LiveAuthService.updatePassword` | **MISSING (P0).** No request to `/functions/v1/password-guard` with `action: update_password` exists in iOS source. A direct `PUT /auth/v1/user {password}` would be rejected by migration `20261116130000` (verified on the replica: `P1-bypass recovery session cannot set a password directly`). |
| 7 | Success and sign-out | `MortSession.updatePassword` | PASS (source). On success it calls `auth.signOut()`, sets phase `.signedOut` and an "updated" notice; `PasswordRecoveryView` shows the success panel. `signOut` on `main` posts `/auth/v1/logout` (GoTrue default scope is global) then clears the local session. Note `signOut` is itself lost in the truncation. |
| 8 | Invalid / malformed links | `recoveryParameters` + `establishRecoverySession` | PARTIAL. Wrong scheme/host/path → ignored. Missing `type=recovery` or a missing token → ignored silently (falls through to the signed-in deep-link gate), so the user sees nothing. Malformed JWT → `unauthorized` → "Reset link unavailable" screen. |
| 9 | Expired links | — | **FAIL (P2).** When the email OTP is expired or already used, GoTrue redirects with `#error=access_denied&error_code=otp_expired&error_description=…`, with no tokens and no `type`. The app ignores it silently instead of showing `PasswordRecoveryUnavailableView`. Fix: if the callback path matches and `error_code` is present, set `recoveryFailed = true`. An expired *access token* in an otherwise valid fragment is rejected by the `exp` check (PASS). |
| 10 | Replayed links | server | PASS (server-side, verified on the replica). The email token is single-use in GoTrue; the password-guard attestation is single-use (`P1-bypass attestation is single-use (replay rejected)`). Reopening the same callback URL inside the access-token lifetime re-shows the form; any password set still goes through password-guard. After a successful change, global sign-out revokes the refresh token. |
| 11 | Network outage | `MortSession.beginPasswordRecovery` / `updatePassword` | PASS by design (source). Errors map to `authError`; no fallback path writes a password. Cannot be confirmed end-to-end because the live methods are missing. |
| 12 | Password-guard outage | server | PASS (server-side, replica). password-guard fails closed (`leaked_password_check_unavailable`, `password_guard_unconfigured`); the database trigger rejects unattested writes. |
| 13 | Existing signed-in session | `handle(url:)` | NOTE (P3). A recovery link opened while another account is signed in overwrites the stored session without signing the first account out. Low risk; consider signing out first. |
| 14 | Reset email redirect | `sendPasswordReset` (on `main`) | **FAIL (P1).** `main` posts `/auth/v1/recover` with only `email`; no `redirect_to`. GoTrue then uses the project Site URL, so the email link never opens `com.mortapp.mobile://app/auth-callback`. Fix: send `redirect_to: "com.mortapp.mobile://app/auth-callback"` and add that URL to the Auth redirect allow-list on QA (and later production, with approval). |
| 15 | Client policy hints | `PasswordRecoveryView` | NOTE. The form only requires 12 characters and a match; the server also requires upper, lower, digit and symbol. The server is authoritative; the hint text should mention complexity so users are not surprised by `password_complexity_required`. |
| 16 | Secrets in client | all iOS files in the diff | PASS. No service-role key, attestation secret or provider secret appears in iOS source. |

## Required implementation (suggested, not committed)

```swift
func establishPasswordRecoverySession(accessToken: String, refreshToken: String, expiresIn: Int) async throws {
    try await client.establishRecoverySession(accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn)
    do {
        let user: AuthTokenResponse.User = try await client.get(path: "/auth/v1/user")
        guard user.id == (await client.storedSession())?.userId else { throw MortError.unauthorized }
    } catch {
        await client.clearSession()
        throw MortError.unauthorized
    }
}

func updatePassword(_ password: String) async throws {
    let result: PasswordGuardResponse = try await client.post(
        path: "/functions/v1/password-guard",
        body: ["action": "update_password", "password": password]
    )
    guard result.ok else { throw MortError.rejected("Choose a different password.") }
}
```

The error mapping should reuse the password-guard codes (as Flutter's `PasswordGuard.messages`
does) so `leaked_password_compromised`, `password_complexity_required` and
`leaked_password_check_unavailable` reach the user.

## API-level evidence that the server side is compatible

The local production replica (catalog parity with production, plus pending migrations
`20261116120000` and `20261116130000`) was rebuilt and run on 2026-11-19:
`password: 45/45, journeys 53/53, authz 108/108`. The recovery cases it covers (the same API calls
the iOS client must make): recovery email requested; link yields a recovery session (303);
recovery session cannot set a password directly; leaked password rejected through
password-guard; acceptable password accepted and sign-in works; attestation single-use.
Log: `docs/qa/evidence/2026-11-19/replica-run.log`.

## Not done

No build, compile, simulator, device, TestFlight or App Store action was taken.
