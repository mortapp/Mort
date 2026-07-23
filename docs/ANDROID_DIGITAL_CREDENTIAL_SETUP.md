# Android Digital Credential Setup

Status: server protocol and Flutter unsupported state are prepared; Android integration is not active.

## Planned integration

- use Android Credential Manager digital credential APIs on supported versions/devices
- request the minimum age/identity attributes justified by policy
- bind each request to a server-generated nonce, authenticated account, environment, issuer, credential type, and short expiry
- validate the signed credential on the backend against a reviewed issuer trust configuration
- atomically reject replay, expiry, unknown issuer/type, account mismatch, and missing validation
- provide a truthful unsupported-device fallback without accepting screenshots or document text

Flutter Web only detects WebAuthn/passkey capability and displays digital ID as unavailable; it does not invoke Android credentials.

Activation requires Android native implementation, issuer/jurisdiction policy, backend verifier, privacy/legal review, Play disclosure, recovery/appeal UX, and real Android-device testing.

Reference: [Android Credential Manager digital credentials](https://developer.android.com/identity/digital-credentials)
