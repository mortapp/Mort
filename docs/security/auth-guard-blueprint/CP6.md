# CP6 — BLOCKED by CP4 native restore fresh control

No migration is written or applied. CP3 proves the PostgREST gate and CP5 proves provider SDK revocation. CP4 has not proved the complete native Storage/Realtime restore path: its fresh published-change subscriber failed. Packaging that mechanism into a migration before the required proof would violate the prerequisite.

Manual rollback design, pending proof: flag false restores optional session enforcement; reset only the fixture-owned pre-request setting; preserve existing ownership policies, auth users, journal and guard tables. Never delete sessions or erase the journal as rollback. A reviewable additive migration and actual off/on parity are deferred until the native mechanism passes. No rollback is executed as a substitute for missing coverage.

| Gate | Status |
|---|---|
| Additive migration creation/application | BLOCKED: CP4 prerequisite |
| Off/on full standing-suite parity | NOT RUN: migration absent |
| Sequential four-role migration review | NOT RUN: migration absent |
| Hosted changes | BLOCKED by owner |
| Existing applied migrations | UNCHANGED |

Audit: prerequisite recorded, no empty tests counted, no migration or threshold rewritten, no hosted/mail/artifact action. CP7 may continue independently. Revisit CP6 after the single reserved CP4 revisit at the end if its prerequisite closes.
