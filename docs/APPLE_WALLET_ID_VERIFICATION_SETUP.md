# Apple Verify with Wallet Setup

Status: Swift provider types and disabled availability UI are implemented; no entitlement or request is active.

## Prepared source

`AppleWalletIdentityProvider`, `WalletIdentityRequest`, `WalletIdentityPresentation`, and `WalletIdentityVerificationResult` define minimal-attribute requests, consent text, nonce/session binding, and a server-validation result boundary. The disabled implementation cannot grant trust locally.

## Activation sequence

1. Join the Apple Developer Program and confirm the use case and supported jurisdiction.
2. Request and receive Apple's required Verify with Wallet entitlement/approval for bundle `com.mortapp.mobile`.
3. Add the capability only to the reviewed native target and provisioning profile.
4. Request only justified attributes, preferably an age-over threshold/age band. Given/family name, portrait, or address require separately documented necessity.
5. Create requests from server-issued nonces and explain each requested attribute before consent.
6. Send the signed presentation to a protected backend verifier. Validate signature, issuer, type, nonce, account binding, freshness, and expiration before recording a result.
7. Test cancellation, unsupported device/jurisdiction, invalid signature, replay, expired credential, wrong account, and data minimization on physical supported devices.
8. Complete App Store privacy disclosure, privacy policy, legal, and teen-safety review.

No screenshot, local decode, or Swift return value may approve identity. Apple Developer membership, entitlement approval, Mac/Xcode signing, and a physical iPhone are still required.

Reference: [Apple Verify with Wallet](https://developer.apple.com/wallet/verify-with-wallet/)
