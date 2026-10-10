# CP1 checkpoint — BLOCKED

New RED findings first:
- U6: exact a826 second recovery run failed the delivery assertion; child exit 1 after 3346 ms. The captured diagnostics did not identify SMTP category. A later pass is not a diagnosis.
- U7: exact03173c0 recovery failed store initialization with connection_deadline after399 ms. The100 ms pool connection deadline was preserved. Container snapshots showed running/no pause/restart/OOM; host scheduling and cold-connection hypotheses remain unproven.

| Check | Status | Evidence scope |
|---|---|---|
| Immutable lock | PASS | Fixed core digest c3832ce41552ccb8dadcdaf5dfc919678fac2fb40354cd03772bc22c54a0ae4b |
| Node diagnostics/regressions | PASS |112 tests at03173c0 |
| Deno units | PASS |38 tests at03173c0 |
| Web/browser | PASS |9 tests including one real Chromium test at03173c0 |
| Committed scan | PASS |2637 files,0 findings at03173c0 |
| Three consecutive recovery runs | BLOCKED |Not established; individual failures retained |
| Windows system power request | TESTED |Process request succeeded/released; no one-hour run claimed |
| Hosted/real mail/artifacts | UNCHANGED |Zero real mail;95 unrelated path fingerprints match |

## Audit findings
The initial CP0 zero-file scan was invalid and the premature push is retained in the ledger. CP1 fixed step-name validation without changing health attempts, renewed only the expired synthetic TLS root using the original two-day lifetime and strict verification, and added fixed-category SMTP diagnostics. The most recent connection failure has a named cause category but its underlying delay remains unexplained. Guard runs as an ephemeral child: there is no owned guard container to inspect; its child stderr is captured. No claim of hosted or guard-container telemetry certification is made.

CP1 was pushed to feature/mort-age-aware-auth-social at03173c004dbb650362d5661359a6a9767cd395c7; ls-remote matched. Tag guard-cp1-blocked-03173c0 records BLOCKED status. The blueprint three-attempt rule permits independent CP2 work; CP1 will be revisited once at the end.
