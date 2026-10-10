# CP3 checkpoint — local fixture verified

| Check | Status / scope |
|---|---|
| Candidate |a1bb1dc1b9577e03e4d07488082773367743eead |
| Existing prerequisite |16 actual assertions rerun at75c6477 |
| New runtime set |66 assertions at exacta1bb1dc |
| Revocation table/view/RPC |Denied within359ms; reason Session ended; fresh controls passed |
| Admin password table/view/RPC |Denied within1899ms; fresh controls passed |
| Restore table/view/RPC |Denied within5434ms; restored old session retained; generation fence proved |
| Credential fence conclusion |Actual Admin path removed old session. Trigger-alone retirement is not claimed |
| Anon / service role / flag off |Paired controls passed; service-role unsafe-gate mutation demonstrated RED then original gate GREEN |
| Bounded load |400 requests,20 concurrent, pool8,7403.61ms elapsed within60000ms |
| Load p50 off/on |43.34ms /69.47ms; delta26.13ms |
| Load p95 off/on |190.09ms /180.15ms; negative delta is sample noise, not proof of improvement |
| Node / Deno / web-browser |118 /38 /9 passed at exactcandidate |
| Committed scan |2644 blobs match candidate,0 findings |
| Cleanup / logs |Flag off, authenticator config reset, accounts removed; audited owned logs clean |
| Feature remote |Matches candidate; guard-cp3-a1bb1dc pushed |

Evidence: C:/Users/micha/Mort/guard-evidence/cp3-a1bb1dc.json, SHA25667b64e309f0cbcf51d083eda54cd6bf72bff94b2004c9c19f7fb950385ef885c.
Role-skip mutation: C:/Users/micha/Mort/guard-evidence/cp3-a1bb1dc-service-mutation.json, SHA25659d7eb5c7fb7d371ed1579595dd331797181b0b3f1f5a5ddc02f009977bba49d.

## Self-audit
A1 scope: guard harness and checkpoint docs only;95 unrelated fingerprints preserved. A2 immutable lock passed. A3 lifecycle no-op extension was RED before enabling it; load/pool tests RED before implementation; later service-role positive assertion was proved sensitive using a temporary local unsafe gate, restored and cleaned. A4 every lifecycle denial paired with fresh success, including session/generation reason. A5 fixed30000ms lifecycle,60000ms load,4000ms request deadlines; pool tightened toapproved8 rather than a threshold relaxation. A6 committed scan and known-generated-secret sink audit passed. A7 flag defaults and final state off. A8 exactcommit/hash/cleanup/log proof retained. A9 no hosted or trigger-alone claims. A10 feature push/tag only; no hosted/mail/DNS/artifact changes.

Audit correction: CP2 inspection missed a remaining magic191 validation in cases.mjs. CP3 removed it and made the main certifier validate mappings against the actual pinned inventory. CP2 regression tests reran at this candidate. Historical gates are not re-certified by that unit result. CP1 remains BLOCKED; fullGuardCertified remains false. The service mutation proof followed the feature push; CP3 final audit was completed afterward. This sequencing deviation is recorded, not concealed.
