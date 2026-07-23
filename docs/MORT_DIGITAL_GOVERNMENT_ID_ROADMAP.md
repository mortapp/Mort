# MORT Digital Government ID Roadmap

Status: architecture prepared; all client and policy flags disabled.

## Required protocol

1. The authenticated server creates a one-use session bound to account, platform, environment, expected issuer, credential type, nonce hash, requested minimal attributes, and expiry.
2. The platform presents a user-consented signed credential. Screenshots and locally parsed document text are never accepted.
3. A trusted server validates signature/chain, issuer, type, nonce, audience/account binding, required age result, and validity.
4. The server atomically consumes the session, records a minimized event, and rejects replay, expiry, unknown issuer, missing validation, account mismatch, and environment mismatch.
5. Only a successful current production event under an enabled policy may create the precise `Government digital ID verified` indicator.

The implemented service-only RPCs and tables enforce these boundaries. No raw credential payload, portrait, full address, document image, or private key is stored in the trust tables.

## Before activation

MORT needs platform approval, issuer and jurisdiction policy, cryptographic verifier implementation, key rotation and outage handling, privacy/legal review, retention/deletion rules, user appeal, incident runbooks, accessibility review, and real-device tests. Unsupported devices must receive a truthful unavailable state, not a lower-integrity substitute.
