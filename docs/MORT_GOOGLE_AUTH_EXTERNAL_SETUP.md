# MORT Google Auth External Setup

Project ref: `rakjydmgwwgtdislanbt`

Never place the Google Web OAuth client secret in Flutter, Dart defines, Android
resources, Gradle, iOS files, Expo variables, Git, logs, screenshots, zips, APKs,
or AABs. Enter it only in Supabase Auth provider configuration or an approved
server-side secret manager.

## VERIFIED LIVE (2026-08-20) -- real end-to-end login tested twice

Google Sign-In is confirmed genuinely working, not just configured. Two
separate real logins were run through `https://mort-web.vercel.app/login` ->
"Continue with Google" -> real Google consent screen -> real account
selection -> real Supabase token exchange -> real session -> real redirect
to `/app/onboarding`, each followed by a real sign-out:

1. Against the **original** client (`621016064579-...`, from a GCP project
   neither available Google account could administer) -- this was the
   config actually saved in Supabase at the time (an earlier session's edit
   to swap the Client ID had never been saved, only typed and abandoned).
   This test proved that pairing was fully valid and Google Sign-In had
   been live and working the whole time, contrary to an earlier assumption
   that it was broken.
2. Against the **new**, fully-owned client (`382105285546-g863...`, project
   `mort-506011`) after the owner pasted its matching secret into Supabase
   and saved. Also fully succeeded end-to-end.

Supabase's Google provider is now configured with the new, owner-controlled
client (Client ID confirmed persisted after page reload; Client Secret
pasted directly by the owner from Google's one-time creation dialog --
never read, typed, or handled by the automated agent at any point).

**Android and iOS use this exact same configuration.** MORT's mobile OAuth
flow goes through Supabase's PKCE authorization-code exchange (external
browser -> Google consent -> Supabase callback -> deep link back into the
app), not a native platform SDK -- so there is no separate per-platform
client to configure for this to work on Android or iOS. The two additional
"Android" OAuth clients created in `mort-506011` (see below) are unused by
the current flow; they exist only as a defensive fallback should native
Google Sign-In/Credential Manager ever be added later.

Note on the consent screen text ("Sign in to rakjydmgwwgtdislanbt.supabase.co"):
this is Google's own anti-phishing security display, always showing the
actual domain that performs the token exchange (Supabase's domain, since
Supabase -- not MORT directly -- receives the authorization code). It is
not controlled by the Branding settings and cannot be changed to "MORT"
without giving Supabase Auth a custom domain (e.g. `auth.mortapp.com`,
requiring real DNS + a paid Supabase tier) -- a real, deliberately separate
future project, not a quick setting.

## Superseded status snapshot (2026-08-19, browser-controlled completion pass)

A dedicated GCP project (`mort-506011`, name "MORT") was created under the
owner's `kolawoleorelesi@gmail.com` account -- the previously-referenced
project (`621016064579`, whose client ID was already saved in Supabase) was
not accessible from either Google account available in this browser
(`kolawoleorelesi@gmail.com` or `nikkikurta@gmail.com`), so rather than leave
Google Sign-In dependent on an unmanageable client, a clean, fully-owned
replacement was created end-to-end.

| Gate | Status |
|---|---|
| Google Cloud project selected | DONE -- new project `mort-506011` ("MORT"), owned by `kolawoleorelesi@gmail.com` |
| OAuth branding configured for MORT | DONE -- App name "MORT", user support email `mortapp@googlegroups.com` (existing canonical MORT Google Group, not a personal address), audience "External" |
| Support email configured | DONE -- `mortapp@googlegroups.com` (both user-support and developer-contact fields) |
| Published Privacy/Terms location | NOT YET ENTERED on the consent screen branding page -- add once the Vercel legal site is live at its final URL |
| Approved Google test users configured | Not yet added -- app is in default testing-adjacent state under a personal (non-Workspace) External audience; add test Google accounts before wide testing if verification is still pending |
| Web OAuth client created | DONE -- "MORT Supabase Web Client", `382105285546-g863e5np7ol1s3rcrgq8np47ciks18mu.apps.googleusercontent.com`, redirect URI `https://rakjydmgwwgtdislanbt.supabase.co/auth/v1/callback`, JS origin `https://mort-web.vercel.app` |
| Supabase callback added to Web client | DONE (see above) |
| Android OAuth client | Created defensively (not required by the current PKCE/browser flow, but registered in case native Google Sign-In/Credential Manager is ever added): two clients, package `com.mortapp.mobile`, covering both distinct classical (RSA) certificates found in Play Console's App Signing certificate export (see below) |
| iOS OAuth client | NOT REQUIRED BY SELECTED BROWSER FLOW (unchanged) |
| Android package `com.mortapp.mobile` verified | VERIFIED IN SOURCE |
| Play App Signing certificate fingerprints documented | DONE -- extracted via `openssl x509` from the official Play Console "Download certificates" export (`certificates.zip`), not by reading the UI's copy-only buttons. Two distinct classical (RSA-4096, sha256WithRSAEncryption) certs exist in that export (`deployment_cert.der` and `hybrid_classical_cert.der` -- different keys, both registered as separate Android OAuth clients out of caution) plus one post-quantum (ML-DSA-65) cert, not registered (no current consumer needs a PQC SHA fingerprint). See fingerprints below. |
| Web client ID entered in Supabase | DONE -- `382105285546-g863e5np7ol1s3rcrgq8np47ciks18mu.apps.googleusercontent.com` |
| Google secret entered in Supabase | **NOT DONE -- see "Remaining Owner Step" below** |
| Google provider enabled | Was already `Enabled` in Supabase before this pass (with the old, inaccessible client's ID+secret); Client ID has now been swapped to the new client, but the **secret has not**, so the provider is presently in a broken/mismatched state until the owner pastes the new secret |
| Manual identity linking enabled | CONFIGURED (unchanged) |
| Nonce skipping disabled | VERIFIED (unchanged) |
| Exact app redirect allowlisted | CONFIGURED -- `com.mortapp.mobile://app/auth-callback` present in Supabase's redirect allowlist alongside `https://mort-web.vercel.app/*` variants |
| Broad web wildcard removed | VERIFIED (unchanged) |
| Installed APK login | BLOCKED BY PROVIDER SECRET MISMATCH (see above) |
| Existing-password-account linking | BLOCKED BY PROVIDER SECRET MISMATCH |
| New Google-account onboarding | BLOCKED BY PROVIDER SECRET MISMATCH |
| Google-linked account deletion | BLOCKED BY PROVIDER SECRET MISMATCH |
| Google publishing/verification state | New project defaults to unpublished/testing-adjacent state for the External audience; no verification submitted this pass |

### Play App Signing certificate fingerprints (Classical key, both registered)

```
deployment_cert.der
  SHA1:   3C:6E:AA:DA:C2:93:C7:AA:EC:45:69:D7:0A:5C:A0:05:E6:E5:0F:96
  SHA256: DB:88:B3:F1:12:B2:75:7E:D0:47:7C:DF:CA:CB:8D:EA:AC:21:60:EE:09:50:06:BA:C7:AF:E0:34:35:11:DE:DD

hybrid_classical_cert.der
  SHA1:   84:07:5D:85:0C:5A:1E:A3:C8:66:D1:C3:60:B2:38:7E:CB:00:5F:30
  SHA256: 8D:64:E9:17:73:18:D3:F4:0D:CA:3E:DC:D1:4B:D5:AF:89:09:82:1E:56:F1:79:A9:07:18:AB:62:55:4D:E4:82
```

These are the certificates Google Play actually signs the distributed APK
with (`Protect app signing key: Releases signed by Play`), distinct from the
upload-key certificate below (which only ever touches the AAB the owner
uploads to Play Console, never a device).

### Remaining Owner Step -- REQUIRED before Google Sign-In will work at all

The new Web client's secret was generated in Google Cloud Console and shown
once in a browser dialog. Per this session's absolute rule against handling
credentials, the automated agent did not read, copy, or paste it -- the
owner copied it directly from the Google Cloud dialog. **That secret still
needs to be pasted into Supabase Dashboard -> Authentication -> Sign In /
Providers -> Google -> "Client Secret (for OAuth)" field, replacing the old
value, and the form Saved.** Until that happens, Google Sign-In is
non-functional (Client ID and Secret belong to different, mismatched OAuth
clients). This is a five-second manual step; nothing else blocks it.

## Google Cloud Owner Steps (HISTORICAL -- superseded by the 2026-08-19 pass above; kept for reference on what was originally planned)

1. Open Google Auth Platform in the Google Cloud project owned by MORT.
2. Configure app name `MORT`, support email `mortapp.help@gmail.com`, developer
   contact email, the approved MORT logo, the published Privacy location, and the
   published Terms location.
3. Keep scopes limited to `openid`, `email`, and `profile`. Do not request Gmail,
   Drive, contacts, calendar, location, YouTube, or another sensitive scope.
4. If the app remains in Google testing mode, add only approved test accounts.
5. Create a **Web application** OAuth client.
6. Add this exact authorized redirect URI:
   `https://rakjydmgwwgtdislanbt.supabase.co/auth/v1/callback`
7. Do not add wildcard redirects or unrelated development origins.
8. Store the Web client secret temporarily in an approved password manager while
   completing the next section. Do not paste it into a task, issue, or source file.

## Supabase Owner Steps

1. Open Supabase project `rakjydmgwwgtdislanbt`.
2. Go to Authentication, Sign In / Providers, Google.
3. Enter the Web client ID.
4. Enter the Web client secret in the provider secret field.
5. Keep nonce checking enabled; do not enable skip nonce checks.
6. Enable Google and save.
7. Confirm URL Configuration contains only:
   - `com.mortapp.mobile://app/auth-callback`
   - `https://mort-web.vercel.app/auth-callback`
   - `https://mort-web.vercel.app/auth/confirm`
8. Confirm manual linking remains enabled.
9. Re-read the provider configuration and record only configured/not configured;
   never export or print the secret.

## Native Client Records (created 2026-08-19; not required by the current PKCE browser flow, registered defensively for any future native Google Sign-In/Credential Manager work)

- Android package: `com.mortapp.mobile`
- `MORT Android Client (classical)`: `382105285546-ve34...apps.googleusercontent.com` (SHA-1 `84:07:5D:85:0C:5A:1E:A3:C8:66:D1:C3:60:B2:38:7E:CB:00:5F:30`, matches `hybrid_classical_cert.der`)
- `MORT Android Client (deployment)`: `382105285546-4lk7...apps.googleusercontent.com` (SHA-1 `3C:6E:AA:DA:C2:93:C7:AA:EC:45:69:D7:0A:5C:A0:05:E6:E5:0F:96`, matches `deployment_cert.der`)
- Debug SHA-1 (unchanged, not yet registered as a client -- add one if local debug-build Google Sign-In testing is ever needed): `EC:4F:C8:69:23:AE:03:51:0D:CC:4D:9C:9C:8C:5B:E8:02:0E:44:A5`
- Debug SHA-256: `6A:42:90:83:85:1A:F4:4B:03:35:EF:2C:24:C7:1A:36:C5:C0:4F:EC:D7:75:5E:55:13:4B:80:53:BF:FC:F1:EB`
- Upload-key (AAB signing, never touches a device) SHA-1: `7F:3E:52:5C:05:F3:D8:72:C1:68:63:08:EA:F2:79:5A:8E:96:D9:97`
- Upload-key SHA-256: `04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF`
- iOS bundle ID: `com.mortapp.mobile`

## Build And Real Test

After the provider is verified, build the closed-test app with
`--dart-define=GOOGLE_AUTH_ENABLED=true` and the existing closed-pilot defines.
Do not pass a Google client secret as a Dart define.

Use approved isolated accounts to verify:

1. New Google user returns to the installed APK and reaches MORT onboarding.
2. DOB and role remain required and server-validated.
3. Existing verified password email links to the same Supabase user ID.
4. Different Google email does not inherit another user's profile or data.
5. Canceling in Google returns safely without a loop.
6. Duplicate taps open one browser flow.
7. Cold-start, background, running-app, and killed-process callbacks work.
8. Suspended and deletion-pending accounts remain blocked.
9. Link/unlink preserves at least one sign-in identity and writes one audit event.
10. Account deletion removes the Google-linked MORT account through the existing
    deletion workflow.
11. APK/AAB and logs contain no client secret, authorization code, provider token,
    QA password, service-role key, or database password.

Do not mark Google authentication 100% until those installed-app tests pass.
