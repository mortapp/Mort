# CP8 key ring — BLOCKED

New RED findings first:
- Three integration diagnostic attempts failed: old-key-hook; then new-key-redemption after the adapter fix; then new-key-hook. Last named assertion: ring-enabled-hook-stores-kid. This remaining intermittent failure has no proven cause. No threshold changed. One final revisit reserved.
- Applied issue_event requires a v1 envelope. New ring envelope v2 was incompatible. The disposable fixture adapter now installs the full versioned ciphertext atomically after the existing v1 validator; applied migrations unchanged. Later runs progressed beyond old-key recovery. This does not certify the entire integration.
- Cleanup failed SQLSTATE23503 at operation_grants_capability_digest_fkey. Grant-first cleanup is tested against the owned fixture; primary failure remains recorded.

| Scope | Status |
|---|---|
| Seven cryptographic keyring tests | GREEN (working source; exact commit rerun pending) |
| Current/previous ring, twenty-minute equality boundary, missing/unknown kid, tampered ciphertext, invalid clock | Named unit assertions only |
| Provider-originated ring recovery integration | BLOCKED after three diagnostic attempts |
| Plan-only rotation script | GREEN; no hosted execution |
| Real key manager rehearsal | BLOCKED staging approval |
| Full guard certification | false; computed gates incomplete |

The hook, worker and guard accept an optional protected CryptoKey ring only in existing local_fixture mode. Legacy fixture dependencies remain supported. New ring HMACs store kid in owned fixture metadata; ciphertext binds kid into AES-GCM associated data. Previous keys reject at the fixed absolute retirement deadline. Hosted key loading and product migrations are not installed. SMTP in this ring probe is a mock acknowledgement; no delivery claim.

Diagnostics now expose reviewed fixed assertion/stage labels, never arbitrary exception text. Eleven diagnostic tests pass. Tests were RED before implementation; invalid-clock test failed with six existing passes then all seven passed. Plan test failed missing module then passed.

Audit deviation: the reused temporary CP4 unit runner overwrote raw CP4 retry log filenames during later CP5/CP7 runs. Original CP4 tool output and hash-bound checkpoint report remain; those overwritten retry files are not historical CP4 evidence. Future logs must use candidate-specific names.

External email count0. Hosted unchanged. Artifacts unchanged. Unrelated95 paths protected.
