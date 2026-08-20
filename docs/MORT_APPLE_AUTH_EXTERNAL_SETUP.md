# MORT Apple Auth External Setup

Project ref: `rakjydmgwwgtdislanbt`

Never place the Apple private key (.p8 file), Team ID + Key ID + private key
JWT material, or any generated client secret in Flutter, Dart defines,
Android resources, Gradle, iOS files, Expo variables, Git, logs,
screenshots, zips, APKs, or AABs. Enter it only in Supabase Auth provider
configuration or an approved server-side secret manager.

## Status: ENGINEERING COMPLETE, EXTERNAL_BLOCKED (2026-08-19/20)

The Dart/Flutter side of Apple Sign-In is built, tested, and committed --
it reuses the exact same architecture already verified live for Google
(see `docs/MORT_GOOGLE_AUTH_EXTERNAL_SETUP.md`): a browser-based Supabase
PKCE authorization-code exchange (external browser -> Apple consent ->
Supabase callback -> deep link back into the app), not a native
`AuthenticationServices`/`ASAuthorizationController` SDK. This is why no
`sign_in_with_apple` Flutter package was added -- the same reasoning that
kept `google_sign_in` out of the Google implementation applies here.

What exists in code right now:

- `AuthRepository.signInWithApple()`, `linkAppleIdentity()`,
  `unlinkAppleIdentity()` -- generalized from the Google implementation via
  a shared `_OAuthProviderInfo` value type, using Apple's own documented
  scope set (`'name email'`, not Google's `'openid email profile'`).
- `AppConfig.appleAuthEnabled` (`APPLE_AUTH_ENABLED` dart-define, defaults
  `false`) and a matching `MortReleaseConfiguration.appleAuthEnabled`
  validation gate, mirroring `googleAuthEnabled` exactly -- Apple Auth can
  be enabled independently of Google Auth per build.
- `AppleAuthSection` (`lib/features/auth/apple_auth_screens.dart`) -- an
  Apple-branded "Continue with Apple" button on the same sign-in/sign-up
  screen as Google's button, gated on `AppConfig.appleAuthEnabled`, hidden
  entirely when the flag is off.
- `ConnectedAccountsScreen` (`lib/features/auth/google_auth_screens.dart`)
  extended with an Apple identity card and Connect/Disconnect Apple
  buttons, alongside the existing Google and password identity cards.
- `test/apple_auth_contract_test.dart` -- 7 passing assertions mirroring
  `google_auth_contract_test.dart`'s coverage for the parts that apply to
  Apple (PKCE flow, scopes, gating, callback identity, UI branding,
  connected-accounts wiring, no embedded secrets).
- `test/google_auth_contract_test.dart` -- re-verified, all 13 original
  assertions still pass unchanged; the Google implementation's strings and
  behavior were preserved byte-for-byte during the generalization.

What is genuinely blocked and requires the account owner, not this
session: everything below. No Apple Developer session exists in this
browser (a real sign-in page with an empty email field, no cached
identity) -- this was not typed into, per the standing rule against typing
into external account logins with no session.

## Apple Developer Owner Steps (REQUIRED, none of this can be done from here)

Requires an active Apple Developer Program membership (paid, ~$99/year)
under the owner's own Apple ID.

1. Sign in to [developer.apple.com/account](https://developer.apple.com/account).
2. Under **Certificates, Identifiers & Profiles -> Identifiers**, open the
   existing App ID for `com.mortapp.mobile` (or create it if it does not
   exist yet) and enable the **Sign In with Apple** capability.
3. Under **Identifiers**, create a new **Services ID** (a distinct
   identifier from the App ID, e.g. `com.mortapp.mobile.signin`). This
   Services ID is what Supabase calls the Apple "Client ID" -- it is the
   web-facing identity Apple's OAuth authorize endpoint sees, analogous to
   Google's Web OAuth client.
4. Configure that Services ID's **Sign In with Apple** settings:
   - Primary App ID: the `com.mortapp.mobile` App ID from step 2.
   - Domains and Subdomains: `rakjydmgwwgtdislanbt.supabase.co`
   - Return URLs: `https://rakjydmgwwgtdislanbt.supabase.co/auth/v1/callback`
5. Under **Keys**, create a new key with the **Sign In with Apple**
   capability enabled, associated with the App ID from step 2. Apple shows
   the private key (`.p8` file) exactly once at creation -- download and
   store it in an approved secret manager immediately. Record the **Key
   ID** shown alongside it.
6. Record the account's **Team ID** (visible on the Membership page).
7. You now have four pieces of information Supabase needs: the Services ID
   (step 3), the Team ID (step 6), the Key ID (step 5), and the `.p8`
   private key file contents (step 5). None of these are secrets you type
   into MORT's app code -- they go directly into Supabase in the next
   section.

## Supabase Owner Steps

1. Open Supabase project `rakjydmgwwgtdislanbt`.
2. Go to Authentication, Sign In / Providers, Apple.
3. Enter the **Client IDs** field with the Services ID from step 3 above
   (e.g. `com.mortapp.mobile.signin`). If a native app-based flow is ever
   added later, the App ID bundle identifier can be added here too,
   comma-separated -- not required for the current browser-based flow.
4. Enter the **Team ID**, **Key ID**, and paste the full contents of the
   `.p8` **Private Key** file into their respective fields. Supabase
   generates and rotates the actual JWT client secret from these
   automatically -- there is no separate "client secret" to type in, unlike
   Google.
5. Enable Apple and save.
6. Confirm URL Configuration still contains only the existing allowlisted
   redirects (unchanged by adding Apple):
   - `com.mortapp.mobile://app/auth-callback`
   - `https://mort-web.vercel.app/auth-callback`
   - `https://mort-web.vercel.app/auth/confirm`
7. Confirm manual identity linking remains enabled (shared setting, not
   per-provider).
8. Re-read the provider configuration and record only configured/not
   configured; never export or print the private key or generated secret.

## Build And Real Test

After the provider is verified, build the closed-test app with
`--dart-define=APPLE_AUTH_ENABLED=true` alongside the existing
`GOOGLE_AUTH_ENABLED=true` and closed-pilot defines. Do not pass the
Apple private key or Team/Key ID as a Dart define -- they belong only in
Supabase.

Use approved isolated Apple ID accounts to verify, mirroring the Google
test list in `docs/MORT_GOOGLE_AUTH_EXTERNAL_SETUP.md`:

1. New Apple user returns to the installed app and reaches MORT onboarding.
2. DOB and role remain required and server-validated (Apple never supplies
   either).
3. Existing verified password email links to the same Supabase user ID.
4. A different Apple ID, or Apple's private-relay email, does not inherit
   another user's profile or data.
5. Canceling in Apple's consent screen returns safely without a loop.
6. Duplicate taps open one browser flow.
7. Cold-start, background, running-app, and killed-process callbacks work.
8. Suspended and deletion-pending accounts remain blocked.
9. Link/unlink preserves at least one sign-in identity and writes one audit
   event (`apple_linked`/`apple_unlinked`, mirroring Google's
   `google_linked`/`google_unlinked`).
10. Account deletion removes the Apple-linked MORT account through the
    existing deletion workflow.
11. App bundle and logs contain no private key, generated client secret,
    authorization code, provider token, QA password, service-role key, or
    database password.
12. **iOS specifically**: since this is a browser-based flow rather than
    the native `ASAuthorizationController` API, confirm Apple's App Store
    Review Guideline 4.8 is still satisfied -- MORT already offers a
    third-party sign-in option (Google) and must offer an equivalent
    Apple option with comparable data-minimization; the current design
    (no extra data collection beyond name/email, same as Google) is
    intended to satisfy this, but this must be confirmed against Apple's
    current guideline text at submission time, not assumed from this
    document.

Do not mark Apple authentication 100% until those installed-app tests pass.

## iOS entitlement note (deliberately not added this session)

A native Sign In with Apple implementation normally requires the
`com.apple.developer.applesignin` entitlement in
`ios/Runner/Runner.entitlements`, wired into
`ios/Runner.xcodeproj/project.pbxproj`'s `CODE_SIGN_ENTITLEMENTS` build
setting -- normally added automatically by Xcode's "+Capability" button.

Because MORT's implementation is the same browser-based OAuth flow already
used for Google (not the native `AuthenticationServices` framework), this
entitlement is not required for the flow built this session to function.
Hand-editing `project.pbxproj` from this Windows session, without Xcode to
verify the result, was deliberately avoided -- an incorrectly wired
build-setting reference is a plausible way to silently break the iOS build
in a way undetectable without a Mac. If a future session adds a native
Apple Sign-In implementation instead (e.g. for the one-tap Face ID
experience), add the capability through Xcode directly on a Mac, which
will generate and wire the entitlements file correctly.
