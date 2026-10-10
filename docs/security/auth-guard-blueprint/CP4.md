# CP4 checkpoint — BLOCKED

RED findings first:
1. The first actual native catalog run exposed an uncovered existing synthetic mort-fixture bucket. A rollback-only reproduction isolated it; adding that owned fixture bucket to the restrictive scope produced a clean rollback-only catalog.
2. The second run attempted direct SQL deletion of an empty Storage probe bucket. Storage has a direct-delete safeguard. The empty residual was removed through Storage API status200; remainingcount0. The harness uses the supported API and retains redacted error classification. Exact original stderr-hash replay remains pending.
3. The third run failed Fresh private subscriber receives actual published change at lifecycle-restore. Fresh private join and published-table REST controls passed before that failure; revocation and password-change published controls passed earlier. Publication membership/cache/OID and missing-client-heartbeat hypotheses remain untested. No complete native gate PASS is claimed.

| Check | Status |
|---|---|
| Native catalog unit tests |3 RED then3 GREEN |
| Native helper creation |RED missing helper before implementation |
| Actual native catalog scope |Actual buckets/policies/grants/publication membership; no source regex table inventory |
| Restrictive policy design |Storage allowlist plusownedlegacyfixturebucket; private-topic-prefix scope; published-table policy; flag off initially |
| Named private buckets |Disposable eleven names, synthetic placeholder contents; actualStorageAPI creation/read/cleanup |
| Published restore fresh control |FAIL after fixed4000ms observation window |
| Complete native runtime suite |BLOCKED afterthree diagnostic attempts |
| Source and artifact impact |No applied migration, hosted change, mail, APK/AAB or95 unrelated path modification |

All three attempt reports remain in private TEMP logs. Third failure captured named assertion, phase and six-role snapshot; Auth/DB/Realtime/Storage/PostgREST running/no pause/restart/OOM. Snapshot known-credential/email-presence booleans false. Guard runs as a child, not an owned container; absent container evidence is not a PASS. Revisit CP4 once at the end. IndependentCP5 may continue. FullGuardCertified remainsfalse.

A1 scope reviewed; A2 immutable lock verified; A3 native catalog RED/GREEN and missing helper RED retained; A4 FAILED fresh-control, so gateBLOCKED; A5 no existing deadline relaxed; A6 committed scan pending; A7 final cleanup flagoff; A8 no exact-head nativePASS; A9 scope corrected (wholeG14notcomplete fromPostgREST-onlyproof); A10 no hosted/DNS/mail/production action.
