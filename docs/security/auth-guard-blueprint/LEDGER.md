# MORT Auth Guard checkpoint ledger

Baseline: `dccf5eb5b14eebdb15f8f5a4ebe11c9d9fe604a6` on `feature/mort-age-aware-auth-social`.

CP0 IN_PROGRESS. Baseline units: Node 99, Deno 37, web 8 passed. New lock tests: 2 RED then 2 GREEN. Exact committed checks and push pending.

- CONFIRMED: Branch and reported dccf5eb candidate — git rev-parse, branch and ls-remote executed
- INSPECTED_SOURCE_AND_HISTORICAL_REPORTS_ONLY: Existing guard components and three historical clean recovery runs — Not rerun at CP0; no runtime PASS inherited
- HISTORICAL_EVIDENCE_ONLY: 16 request-gate assertions and 34/32 fixture catalog — Existing exact-head report inspected; must rerun CP3
- CONTRADICTED: Missing computed certification / hardcoded false — certify.mjs invokes computeCertification and derives the field
- INSPECTED_INCOMPLETE: Other listed not-done mechanisms — New-gate password/restore, native resource catalog, key ring, source admission and final series remain incomplete
- SOURCE_INSPECTION_ONLY: Four views, private avatar bucket and 44 Edge callers — Prior classification inspected; CP4/5 reverify; no hosted reads
- CONFIRMED_SOURCE_ABSENCE_OR_INCOMPLETE: No jwt-path-register / no key ring / per-instance admission — Directory inventory and shared implementation; CP7/8 required
- RETAINED_OPEN: Four unexplained failures — Historic report; causes unproven
- BLOCKED_OR_NOT_RUN: Blocked hosted/device/mail gates — Hosted/mail authorization absent; emulator now approved but not run
- HISTORICAL_ONLY: Source snapshot 25f934e and earlier candidates — Not current candidate

No runtime gate inherits a historical PASS. All external gates BLOCKED; mail sent 0.
