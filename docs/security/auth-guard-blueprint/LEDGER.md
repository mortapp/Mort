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

CP0 completed at5ff33c1; remote equals commit. Initial zero-file scan INVALID; corrected archive scan2626/0. CP1 in progress: six RED tests, focused27 GREEN.

CP1 BLOCKED at03173c0 (remote equals). Node112/Deno38/web9 passed; committed scan2637/0. Three-run recovery streak absent; failures U6/U7 remain open. No threshold changed. CP2 continues independently; CP1 revisit reserved for end.

CP2 DONE at75c6477; remote equals. ExactNode116/Deno38/web9; committed scan2640/0. Evidence SHA256675311e7e2ce9cca91ba8bd141f5941330cead4730a73e81df18ba0a6118d6f5. Full certification remains derivedfalse; NOT_CERTIFIED. CP3 prerequisite rerun started.

CP3 DONE at a1bb1dc:66 runtime assertions; fixed30s nine combinations; generation proof;400requests/20concurrent/pool8. Node118/Deno38/web9; scan2644/0. Native Storage/Realtime CP4 begins; no hosted changes.

CP4 BLOCKED afterthree diagnostic attempts: restored fresh native publication subscriber failed. Revisit once at end. WholeG14 corrected toNOT_RUN because CP3 covered onlyPostgREST. CP5 independent providergetUser evidence begins.

CP4 pushed/tagged atd32f0c8. Exact archive blobs2652, scan0; Node122/Deno38/web9. Archive dependency/history failures were setup failures, fixed without changing assertions. Evidence SHA2563ae5287aff9d6bf815fa23dba48d225b206d432ca429b821c198f08168d14c32.

CP5 DONE atb544443: SDK13/Node126/Deno38/web9, scan2657/0; remote equals. CP6 BLOCKED byCP4, no migration written. CP7 independent source-admission work begins.

CP6 pushed/tagged473db94 with scan2658/0. CP7 source parser6GREEN, actual shared77GREEN, limited-source real recovery17GREEN. Existing PostgreSQL hourly limits already present; no duplicate counters or cap changes. Exact newHEAD checks pending.

CP7 DONE at4478796: exactNode126/Deno44/web9; scan2663/0; remoteequals. CP8 BLOCKED after three integration diagnostics; primitive7/diagnostics11/plan1 GREEN, exact checkpoint verification pending. No hosted execution.

CP8 pushed8948e19, exact128Node/51Deno/9browser, scan2672/0. CP9 BLOCKED: provider complexity notconfigured, protectedsignupcopy lacksmax128. Namedtests1GREEN2RED; no provider parity or Flutterruntimeclaim. CP10 continues.

CP9 pushed7f72650; exactcontract1PASS2FAIL, scan2675/0,remoteequals. CP10 actualrecoverylogging23 and auditretention GREEN; knownINFOaddress17/Authaudit7 perprofile retained. ExactHEAD checks pending.

CP10 DONE at0d6d6b7: exact129Node/52Deno/9browser, retention8/logging23, scan2680/0, remoteequals. CP11 BLOCKED afterthree attempts; helper4GREEN but no streaming/promotion PASS. Underlying basebackup failure unproven.

CP11 pushedd21520c: exact133Node/52Deno/9browser, scan2684/0. CP12 localcrawl GREEN; live readonly findings recorded. HS-2 previewcleanupcredential/capability missing; owner requested. Preview0, hosted0, messages0. CP13-16 notexecuted.
