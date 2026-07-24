# MORT Google Auth External Setup

Project ref: `rakjydmgwwgtdislanbt`

Never place the Google Web OAuth client secret in Flutter, Dart defines, Android
resources, Gradle, iOS files, Expo variables, Git, logs, screenshots, zips, APKs,
or AABs. Enter it only in Supabase Auth provider configuration or an approved
server-side secret manager.

## Current Status

| Gate | Status |
|---|---|
| Google Cloud project selected | OWNER ACTION REQUIRED |
| OAuth branding configured for MORT | OWNER ACTION REQUIRED |
| Support email `mortapp.help@gmail.com` configured | OWNER ACTION REQUIRED |
| Published Privacy location configured | OWNER ACTION REQUIRED |
| Published Terms location configured | OWNER ACTION REQUIRED |
| Approved Google test users configured | OWNER ACTION REQUIRED |
| Web OAuth client created | OWNER ACTION REQUIRED |
| Supabase callback added to Web client | OWNER ACTION REQUIRED |
| Android OAuth client | NOT REQUIRED BY SELECTED BROWSER FLOW |
| iOS OAuth client | NOT REQUIRED BY SELECTED BROWSER FLOW |
| Android package `com.mortapp.mobile` verified | VERIFIED IN SOURCE |
| Debug signing fingerprints documented | VERIFIED |
| Release signing fingerprints documented | VERIFIED |
| Web client ID entered in Supabase | NOT CONFIGURED |
| Google secret entered in Supabase | NOT CONFIGURED |
| Google provider enabled | NOT CONFIGURED |
| Manual identity linking enabled | CONFIGURED |
| Nonce skipping disabled | VERIFIED |
| Exact app redirect allowlisted | CONFIGURED |
| Broad web wildcard removed | VERIFIED |
| Installed APK login | BLOCKED BY PROVIDER SETUP |
| Existing-password-account linking | BLOCKED BY PROVIDER SETUP |
| New Google-account onboarding | BLOCKED BY PROVIDER SETUP |
| Google-linked account deletion | BLOCKED BY PROVIDER SETUP |
| Google publishing/verification state | OWNER ACTION REQUIRED |

## Google Cloud Owner Steps

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

## Optional Native Client Records

The selected Supabase browser flow does not use Android or iOS OAuth client IDs.
If Google later requires platform clients for another approved feature, use:

- Android package: `com.mortapp.mobile`
- Debug SHA-1: `EC:4F:C8:69:23:AE:03:51:0D:CC:4D:9C:9C:8C:5B:E8:02:0E:44:A5`
- Debug SHA-256: `6A:42:90:83:85:1A:F4:4B:03:35:EF:2C:24:C7:1A:36:C5:C0:4F:EC:D7:75:5E:55:13:4B:80:53:BF:FC:F1:EB`
- Release SHA-1: `7F:3E:52:5C:05:F3:D8:72:C1:68:63:08:EA:F2:79:5A:8E:96:D9:97`
- Release SHA-256: `04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF`
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
