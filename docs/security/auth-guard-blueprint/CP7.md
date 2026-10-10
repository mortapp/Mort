# CP7 — trusted source and shared limits

Source parser: configured fixture header only, authenticated-by-runtime peer allowlist, missing/malformed/list/port/zone values reject; IPv6 reduces to /64 before HMAC. Other forwarding headers never influence identity. Hosted mode is refused. The live local redemption probe now derives keyed identity from its actual Deno socket peer, not from browser headers. The proxy-header parser is a local model; hosted upstream provenance/header guarantees are NOT certified.

Existing source/family/recipient/account/global quotas already live in PostgreSQL, contrary to an incomplete baseline absence claim. No duplicate counter or migration was added. Two separate PostgreSQL pools (four connections each) race the real issuance function. Three of four source-family requests are admitted; another source's recovery request remains admitted. The full parent issuance suite also proves source dispatch 5, recipient 5, account family 5, global 40 and one threshold alert at dispatch20. Active in-memory admission remains per-instance source2/global64 as a second layer; it is not claimed to be distributed concurrency admission.

RED: missing source helper; shared extension silently ignored and failed its executed assertion; missing pre-provider callback failed the installed-condition assertion after a real recovery. GREEN: six parser tests;77 named issuance/shared assertions;17 named real-hook recovery assertions. The recovery path retains five synthetic exhausted-source dispatch rows while independent real hook/SMTP/Continue/password replacement/new sign-in succeeds. No real mailbox.

| Check | Status |
|---|---|
| Configured header / spoofed forwarding / missing source / IPv6 | PASS, six local tests |
| Cross-pool source family ceiling | PASS actual DB |
| Recovery after another source exhaustion | PASS real provider hook and synthetic capture |
| Threshold20/40 and existing hourly boundaries | PASS actual issuance parent assertions |
| Hosted source-header provenance | BLOCKED: staging unapproved |
| Native migration and production activation | BLOCKED, unchanged |

Budget adjustment playbook (documentation only): obtain staging authorization first, record old/new quota configuration and reason in a credential-free audit event, test the source cap remains below global and the alert remains exactly half the approved budget, then obtain production authorization separately. The present SQL alert is fixed at20 for current40; arbitrary global-cap changes require an additive reviewed change to parameterize its 50% threshold. Do not edit applied migrations or adjust current caps. Undo any future authorized configuration by restoring the recorded old limits, never deleting quota events.

Self-audit: exact-HEAD scan/reruns pending; source provenance claims limited to socket-owned fixture/local parser; no redundant database layer; no threshold/history edits; cleanup from both successful suites completed. CP1/CP4 failures remain OPEN. Full certification false.
