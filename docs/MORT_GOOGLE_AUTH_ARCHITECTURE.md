# MORT Google Authentication Architecture

Version: `0.9.5+95`

Status: code implemented and hosted MORT controls deployed; Google provider
credentials and installed-app login remain owner-blocked.

## Selected Flow

MORT uses the official Supabase Flutter OAuth flow:

- `supabase_flutter` `2.16.0`
- GoTrue Dart `2.26.0`
- provider `OAuthProvider.google`
- PKCE through `AuthFlowType.pkce`
- system browser/external application, never an embedded WebView
- scopes exactly `openid email profile`
- native callback `com.mortapp.mobile://app/auth-callback`
- web callback `https://mort-web.vercel.app/auth-callback`
- Supabase provider callback `https://rakjydmgwwgtdislanbt.supabase.co/auth/v1/callback`

The Supabase SDK creates, exchanges, stores, refreshes, and removes the MORT
session. MORT does not separately persist or log a Google access token, refresh
token, ID token, or authorization code.

## Rejected Alternative

The native Google ID-token flow was not selected. It would add the Google native
SDK, native Android/iOS client configuration, and another token handoff without
solving an existing reliability problem. The current Supabase package directly
supports external-browser Google OAuth and forces Google to the external browser
on Android. One production flow reduces callback and account-linking ambiguity.

## Callback Handling

Android registers only the exact scheme/host pair. iOS registers the unique
application-ID scheme. `MortOAuthCallbackPolicy` additionally checks:

- exact native scheme and host
- exact HTTPS web host and path
- no alternate host or open redirect
- no bearer token in URL parameters
- safe provider cancellation and state-mismatch classification

Supabase Flutter owns the PKCE code exchange. MORT observes the supported Auth
state event, refreshes the protected profile, asks the server for account status,
and routes through `/account-status`. A launch gate blocks duplicate browser
sessions, a three-minute timeout exposes a safe retry, and duplicate callback
processing is idempotent in the client.

For cold-start and process-death recovery, MORT stores only the non-secret flow
purpose (`signIn` or `link`) and its start time in secure device storage. The
intent expires after ten minutes and is deleted at completion, cancellation, or
failure. No callback code or provider token is stored with it.

Custom schemes can be claimed by another installed application. PKCE prevents a
different app from exchanging MORT's intercepted code, but interception can still
cause denial of login. Replace the custom callback with a verified HTTPS Android
App Link and iOS Universal Link when MORT controls an approved domain and the
corresponding platform association files.

## Onboarding And Authorization

Google authenticates an email identity only. It does not determine DOB, age,
role, guardian authority, verification, marketplace eligibility, admin access,
payment eligibility, or payout eligibility.

The existing `on_auth_user_created` trigger creates one profile row with
`ON CONFLICT DO NOTHING`. It may suggest an initial provider display name but
does not overwrite a MORT display name. Role and DOB remain unset until the user
calls the protected `save_my_onboarding_profile` RPC. Existing profiles, avatars,
jobs, applications, messages, ratings, payment records, guardian links,
restrictions, and preferences are preserved.

Account status is resolved from the hosted profile before success routing.
Restricted and deletion-pending accounts do not regain marketplace access after
Google authentication.

## Identity Linking

Connected Accounts uses the official Supabase methods:

- `getUserIdentities()`
- `linkIdentity(OAuthProvider.google)`
- `unlinkIdentity(identity)`

Link/unlink requires an authenticated session and a sign-in no more than 15
minutes old. Unlinking requires another identity, confirmation, and password
reauthentication when an email/password identity is available. The hosted Auth
setting `security_manual_linking_enabled` is enabled.

The `record_my_auth_identity_event` RPC verifies `auth.uid()` and the current
`auth.identities` state before recording a minimal event. It accepts Google only,
is rate-limited, rejects direct client inserts, requires a prior verified link
before unlink, uses a client request UUID for idempotency, and stores no provider
token or Google profile data.

Supabase automatic verified-email linking must still be tested with an approved
Google account. The application does not implement its own email matching or
merge user data on the client.

## Profile Data

MORT does not copy or publish Google's profile photo. The authoritative avatar
remains a moderated, private, owner-prefixed Supabase Storage object with signed
display URLs and cache-versioned replacement/removal. Google display name is only
an editable first-login suggestion and never overwrites an existing profile.

## Failure Handling

The client distinguishes launching, waiting, callback processing, profile
completion, success, cancellation, browser failure, network failure, disabled
provider, invalid redirect, state mismatch, restriction, deletion pending,
internal failure, and safe retry. User-visible messages never echo provider
descriptions, callback queries, tokens, or authorization codes.

## Test Strategy

Automated tests cover callback host/path validation, open redirects, token-bearing
URLs, cancellation, state mismatch, duplicate launch/cooldown, exact platform
registration, minimum scopes, browser flow selection, provider-token nonuse,
server-owned audit writes, event replay, provider forgery, prior-link validation,
payload minimization, and cross-user event isolation.

Still required externally:

- configure Google Cloud branding and Web OAuth credentials
- enable Google in Supabase with the secret stored server-side only
- build with `GOOGLE_AUTH_ENABLED=true`
- complete real installed-app login, cancellation, callback, linking, unlinking,
  process-death, account deletion, and existing-password-account tests
- perform physical Android and iPhone accessibility/security testing
