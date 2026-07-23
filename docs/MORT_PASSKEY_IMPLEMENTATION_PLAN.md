# MORT Passkey Implementation Plan

## Current state

Passkeys are disabled by the hosted trust policy and current Supabase Auth configuration. The Flutter Web client performs real capability checks for a secure context, the WebAuthn `PublicKeyCredential` API, and a reported platform authenticator, but it never starts a fake registration ceremony. The trust profile reads registered credential count from Supabase Auth and always classifies a passkey as account security, not legal identity.

## Activation requirements

1. Explicitly opt into the supported Supabase passkey configuration and confirm SDK compatibility.
2. Configure and review the relying-party ID and all production/staging origins.
3. Implement create, list, rename, revoke, account recovery, new-device alert, and revoke-other-session UX.
4. Verify no private passkey material is stored by MORT.
5. Test Safari/iPhone, macOS Safari, Chromium, Android, cross-device recovery, lockout, lost-device, and origin-mismatch cases.
6. Enable the server policy flag only after security review.

Passkey success must never grant provider identity, digital-government-ID, or screening status.

References: [Supabase passwordless auth](https://supabase.com/docs/guides/auth/auth-passwordless), [W3C WebAuthn](https://www.w3.org/TR/webauthn-3/)
