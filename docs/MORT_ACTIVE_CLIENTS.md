# MORT Active Clients

Audit date: 2026-11-01 (backend target checked read-only)

| Client | Status | Evidence | Release claim |
|---|---|---|---|
| `flutter_mort` | Authoritative maintained mobile client | Flutter 3.41.2, 115 tests, Android release configuration, version 0.9.3+93 | Android closed-test candidate only |
| Root Expo app | Maintained reference client | TypeScript, Expo Router, 48-route web export, Expo Doctor 20/20 | Reference, not the Android 0.9.3 release |
| `swift_mort` | Reference-only native iOS work | Source inspection and parity documentation exist | No Xcode, archive, device, or TestFlight verification |
| Flutter web build | Temporary browser preview | Release web build passes with native IAP and ads disabled | Not a substitute for native iPhone testing |

The current hosted backend target is Supabase project `jxbnrkasktbhtiujkhay`, confirmed in the current Flutter release profile and by the read-only Supabase project listing. Historical reports for prior projects do not establish current hosted readiness. A client is not promoted to a release client merely because its source exists.

