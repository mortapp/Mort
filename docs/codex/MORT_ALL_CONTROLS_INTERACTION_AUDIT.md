# MORT All Controls Interaction Audit

## Scope and Machine Inventory

The generated release inventory is in
`docs/release/MORT_ROUTE_ACTION_INVENTORY_0_9_13_103.{md,csv,json}`.

- Flutter routes inventoried: 188
- Expo reference routes: 46
- unresolved builders: 0
- direct routes checked: 55
- guarded direct routes: 36
- public routes: 19
- route entries without a direct named test: 132
- Flutter source files scanned by design/navigation QA: 152

This report does not claim that 132 routes received manual emulator taps.

## Control Families

| Screen/control family | Route or service | Authorization | Loading/success/error/offline/duplicate behavior | Evidence |
| --- | --- | --- | --- | --- |
| Welcome, sign-in, create, reset, Terms, Privacy | Auth router and `AuthRepository` | Public, then Supabase session | Google in-progress state is cancellable; email actions show bounded errors; repeated submit is disabled | Public sign-in, Google start/cancel, and create navigation exercised on API 36; auth contract tests passed |
| DOB and role setup | Profile setup route and atomic profile repository | Authenticated self | Field focus/errors, encrypted recovery, stable request ID | Widget/contracts plus hosted profile QA |
| Profile/avatar | Profile repository and private avatar storage | Authenticated self | Specific picker/permission errors; exact processed preview; bounded upload/write/signed-URL timeouts | Avatar and profile tests passed; physical camera/gallery not run |
| Job feed/detail/save/apply | Jobs/application repositories | Authenticated role and RLS | Repository loading/error/offline states; server authorization; no client-only success | Hosted lifecycle/application/RLS tests |
| Eight-step job creation | Job repository and server RPC | Adult/business server gate | Field focus, searchable choice, encrypted recovery, idempotent submit, truthful publication state | Hosted hardening tests; no credentialed emulator completion |
| Guardian and safety controls | Guardian/safety repositories and RPCs | Participant/server policy | Fail-closed provider states; protected writes; cleanup-safe tests | Full hosted regression |
| Messaging/report/block | Messaging/moderation repositories and RPCs | Conversation participant/server policy | Safety scanner, rate limits, blocking, error states | Full hosted regression |
| PIN/evidence/payment preference | Lifecycle/evidence/payment contract RPCs | Assigned participants/server policy | Concurrency, proof gates, preference-only copy, no payment processing | Full hosted regression and native PIN semantics tests |
| Admin/support | Admin/support repositories and RPCs | Server-verified admin/support | No client role elevation; deterministic support and external-AI disabled state | Full hosted regression |

## Source Smell Scan

`rg` found no reachable `TODO`, `FIXME`, `HACK`, `print`, `debugPrint`, fake
delay, or empty `onPressed`/`onTap` callback in `flutter_mort/lib`. Feature
screens contain no direct Supabase calls; the only direct RPC boundaries found
outside repositories are core auth startup and operational telemetry.

## Verdict

No unresolved route builder or known empty callback remains. Automated evidence
does not equal every-control physical interaction. The exact-final credentialed
role matrix, camera/gallery, notifications, account deletion, and network
condition controls remain manual gates.
