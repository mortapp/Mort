# MORT Google OAuth Branding External Gate

## Verified Hosted Screen

On the final signed Android flow, Chrome reached `accounts.google.com`. Google's
screen displayed exactly:

`Sign in to continue to rakjydmgwwgtdislanbt.supabase.co`

Evidence screenshot:
`artifacts/release-0.9.13+103/reports/emulator-google-oauth-host.png`

The OAuth PKCE redirect targeted `com.mortapp.mobile://app/auth-callback`. No
credential, authorization code, token, email, or password was captured.
Cancellation returned to MORT and re-enabled the Google button.

## Why Code Cannot Finish Branding

The Flutter client must use the hosted Supabase Auth endpoint. Replacing the
host in app copy does not change the provider-controlled Google screen. A real
fix requires owner-controlled external configuration:

1. Choose and verify an auth subdomain owned by MORT.
2. Configure DNS and the Supabase custom domain feature for the project.
3. Update Google OAuth authorized origins/redirect URIs and consent branding.
4. Re-verify the production Android OAuth client/package/signing certificate.
5. Repeat the hosted screen test and capture the exact final wording.

This work may require a paid Supabase capability and domain/provider owner
approval. No plan was upgraded and no DNS/provider setting was improvised.

## Gate

Status: **EXTERNALLY BLOCKED - OWNER/DNS/PROVIDER CONFIGURATION**.

The OAuth code path is usable for closed testing, but the raw project host is
not acceptable as finished public branding.
