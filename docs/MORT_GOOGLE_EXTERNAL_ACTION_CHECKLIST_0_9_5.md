# MORT Google External Action Checklist 0.9.5

Architecture: Supabase Auth browser PKCE using the system browser/custom tab.
MORT does not use an embedded WebView and does not ship a Google client secret.

| Owner action | Status |
|---|---|
| Google Cloud project selected | OWNER ACTION REQUIRED |
| OAuth branding configured | OWNER ACTION REQUIRED |
| Support email configured | OWNER ACTION REQUIRED |
| Privacy Policy URL configured | OWNER ACTION REQUIRED |
| Terms URL configured | OWNER ACTION REQUIRED |
| Testing users configured while OAuth remains in testing | OWNER ACTION REQUIRED |
| Web OAuth client created | NOT CONFIGURED |
| Supabase callback `https://rakjydmgwwgtdislanbt.supabase.co/auth/v1/callback` added | NOT VERIFIED |
| Android OAuth client created | NOT REQUIRED FOR SELECTED BROWSER PKCE FLOW |
| Android package `com.mortapp.mobile` verified | VERIFIED IN APK/AAB |
| Debug SHA-1 recorded if owner later adds a native client | OWNER ACTION REQUIRED |
| Release SHA-1 recorded if owner later adds a native client | OWNER ACTION REQUIRED |
| Release SHA-256 recorded if owner later adds a native client | OWNER ACTION REQUIRED |
| Web client ID entered in Supabase | NOT CONFIGURED |
| Google client secret entered only in Supabase | NOT CONFIGURED |
| Supabase Google provider enabled | BLOCKED; PROVIDER DISABLED |
| Native callback `com.mortapp.mobile://app/auth-callback` allowlisted | CONFIGURED |
| Web callback `/auth-callback` allowlisted | CONFIGURED |
| Installed APK real Google login | BLOCKED BY PROVIDER CONFIGURATION |
| Existing password account linking | BLOCKED BY PROVIDER CONFIGURATION |
| New Google account onboarding | BLOCKED BY PROVIDER CONFIGURATION |
| Cancellation/error handling | VERIFIED BY CODE AND UNIT TESTS ONLY |
| Google-linked account deletion | BLOCKED BY PROVIDER CONFIGURATION |
| OAuth publishing/verification state reviewed | OWNER ACTION REQUIRED |

After credentials are configured, rerun the installed-app login, new-user
onboarding, existing-account linking, unlink-last-method rejection, cancellation,
process-death callback, session persistence, and account deletion matrix. Do not
record or paste the Google client secret into this repository or any mobile build.
