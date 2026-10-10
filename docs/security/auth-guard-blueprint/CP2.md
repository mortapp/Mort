# CP2 checkpoint — code verified

| Check | Result |
|---|---|
| Exact candidate |75c64777d4fd1f64c30a560db22fbd62b503e796 |
| Node / Deno / web-browser |116 /38 /9 passed |
| Committed scan |2640 exact matching tracked blobs;0 findings |
| Complete gate registry |G01–G35 and H01–H12; tested completeness/order |
| Evidence controls |Missing, stale, empty, duplicate, bad digest, direct flag mutation rejected |
| Inventory |Counts derived; immutable matrix pin preserved |
| Local certification |Requires all local gates plus three complete serial reports at the same HEAD |
| Computed result |NOT_CERTIFIED; fullGuardCertified=false |
| Feature remote |Matches candidate; guard-cp2-75c6477 tag pushed |

Evidence file C:/Users/micha/Mort/guard-evidence/cp2-75c6477.json, SHA256675311e7e2ce9cca91ba8bd141f5941330cead4730a73e81df18ba0a6118d6f5. CP1 remains blocked by its incomplete recovery streak; historic failures remain open. No hosted/mail/artifact changes.95 unrelated fingerprints preserved. No applied migration edited. The main runtime certifier now requires both historical gate certification and blueprint gate certification. Unit assertions do not certify the unexecuted runtime gates.

Audit correction: the first CP1 exact Node extraction captured only47 initial entries, omitting nodeFiles.push additions. It was not accepted as the full suite; corrected extraction ran112. CP2 extraction includes all pushes and ran116.
