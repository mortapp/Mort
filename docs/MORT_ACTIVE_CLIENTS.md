# MORT Active Clients

Audit date: 2026-07-22

| Client | Status | Evidence | Release claim |
|---|---|---|---|
| `flutter_mort` | Authoritative maintained mobile client | Flutter 3.41.2, 115 tests, Android release configuration, version 0.9.3+93 | Android closed-test candidate only |
| Root Expo app | Maintained reference client | TypeScript, Expo Router, 48-route web export, Expo Doctor 20/20 | Reference, not the Android 0.9.3 release |
| `swift_mort` | Reference-only native iOS work | Source inspection and parity documentation exist | No Xcode, archive, device, or TestFlight verification |
| Flutter web build | Temporary browser preview | Release web build passes with native IAP and ads disabled | Not a substitute for native iPhone testing |

The shared hosted backend is Supabase project `rakjydmgwwgtdislanbt`. Legacy clients were preserved. A client is not promoted to a release client merely because its source exists.
