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
