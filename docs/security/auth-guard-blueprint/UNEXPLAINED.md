# Unexplained failures

## U1 — OPEN

Ingress connection-refused flake. Original cause unproven; a later pass is not a diagnosis.

- UNTESTED: Host sleep, hibernate or Docker pause
- UNTESTED: Startup health or dependency race
- UNTESTED: Pool exhaustion or lock wait
- UNTESTED: Auth restart
- UNTESTED: Windows subprocess, output pipe, antivirus or disk stall
- UNTESTED: Container memory pressure
- UNTESTED: Guard race or retry defect

## U2 — OPEN

Recovery subprocess nonzero exit. Original cause unproven; a later pass is not a diagnosis.

- UNTESTED: Host sleep, hibernate or Docker pause
- UNTESTED: Startup health or dependency race
- UNTESTED: Pool exhaustion or lock wait
- UNTESTED: Auth restart
- UNTESTED: Windows subprocess, output pipe, antivirus or disk stall
- UNTESTED: Container memory pressure
- UNTESTED: Guard race or retry defect

## U3 — OPEN

signed-expiry-wait Docker timeout before original lifetime elapsed. Original cause unproven; a later pass is not a diagnosis.

- UNTESTED: Host sleep, hibernate or Docker pause
- UNTESTED: Startup health or dependency race
- UNTESTED: Pool exhaustion or lock wait
- UNTESTED: Auth restart
- UNTESTED: Windows subprocess, output pipe, antivirus or disk stall
- UNTESTED: Container memory pressure
- UNTESTED: Guard race or retry defect

## U4 — OPEN

First pre-request startup failed with unclassified diagnostics. Original cause unproven; a later pass is not a diagnosis.

- UNTESTED: Host sleep, hibernate or Docker pause
- UNTESTED: Startup health or dependency race
- UNTESTED: Pool exhaustion or lock wait
- UNTESTED: Auth restart
- UNTESTED: Windows subprocess, output pipe, antivirus or disk stall
- UNTESTED: Container memory pressure
- UNTESTED: Guard race or retry defect

## U5 — OPEN

First CP1 recovery run ended in generic startup/suite error without assertion identity. Later delivery failure is independently explained by expired fixture TLS; do not inherit that diagnosis. Startup fetch race and shared TLS cause remain untested for the first run.

## U6 — OPEN
Exact a826 run2: delivery failed, exit1 after3346ms. Missing SMTP category. Later diagnostic recovery pass is not a diagnosis.

## U7 — OPEN
Exact03173c0: store connection_deadline at399ms; original100ms pool deadline preserved. Containers running/no pause/restart/OOM. Host scheduling, cold socket setup and database contention hypotheses remain untested.

## U8 — OPEN
Native fresh published change not received after restore within fixed4000ms. Phase and assertion captured. All containersrunning/no pause/restart/OOM. Publication membership/OID/cache-rebind and missing-client-heartbeat hypotheses remain untested; no rerun diagnosis claimed.

## U9 — OPEN

CP8 working source above4478796: current/new-key recovery failed at new-key-redemption, then new-key-hook (ring-enabled-hook-stores-kid); exit1. Last stderr90bytes SHA25645614585460ee8f03293be8baa144fa02b6835f423a231acb2384f650477c973. Underlying concurrency/latency/store cause unproven. Applied v1-only validation is a separate deterministic source mismatch; its adapter fix does not explain these later failures. Three attempts, one final revisit reserved.

## U10 — EXPLAINED (fixture cleanup)

CP8 SQLSTATE23503 at operation_grants_capability_digest_fkey. Read-only catalog confirmed dependency; failing cleanup reproduced in a transaction. Grant-first cleanup executed successfully on the same owned fixture. Original primary integration failures remain open; cleanup success does not close U9.

## U11 — OPEN

CP11 above0d6d6b7: base backup failed twice, exit1/stderr158bytes/SHA2563c1251d66d4016867f4ee62261187e48e0a3aa65340098fcd82c4a7cccc5a935. Temporary replication HBA rule left fingerprint unchanged. Binary-only version probe passed, ruling out missing pg_basebackup executable. Actual stderr cause still unproven; no fourth integration attempt. One final revisit reserved.

## U12 — EXPLAINED (subprocess timestamp race)

Exact2f4c1d3 Node run: lifecycle start/completion differed by1ms (start12:33:00.972Z versus completion.973Z),134passed1failed. begin and runStep captured UTC independently with logging between them. Deterministic regression delays start logging5ms and reproduces the same assertion. Shared single captured start fixes it; no timing threshold relaxed. The failed2f4c1d3 run remains recorded, and newHEAD requires all reruns.
