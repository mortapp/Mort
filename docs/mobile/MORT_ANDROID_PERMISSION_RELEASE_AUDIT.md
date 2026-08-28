# MORT Android Permission Release Audit

> Status: closed-test publication candidate dated 2026-07-20. Not legal approval, not a public launch, and not a production-readiness claim.

The release manifest retains `WAKE_LOCK` for the compiled Firebase Messaging provider. It remains a normal install-time capability with no runtime prompt and is not permission for background location or a foreground service. The final AAB inventory controls if it differs from this source audit.

| Permission | Requester | Feature / current use | Runtime and denial behavior | Disclosure / Data Safety | Decision |
|---|---|---|---|---|---|
| `android.permission.INTERNET` | MORT manifest | Supabase Auth/API, approved HTTPS image fetches | Install-time; offline states and retry when unavailable | Network transfer of declared account/content data | Keep |
| `android.permission.ACCESS_NETWORK_STATE` | MORT manifest | Detect degraded/offline state | Install-time; app still allows retry | App interaction/diagnostic context; no analytics claim | Keep |
| `android.permission.CAMERA` | MORT manifest / image_picker | Optional proof capture for enabled job workflow; never identity documents | Contextual request after user taps camera; photo picker/manual continuation on denial; settings guidance on permanent denial | User photo/file collection when submitted | Keep while proof camera remains enabled |
| `android.permission.POST_NOTIFICATIONS` | MORT manifest | Contextual local/push notification permission | Never at first launch; deny leaves in-app state available; settings guidance on permanent denial | Notification token only if push registration is configured | Keep |
| `android.permission.USE_BIOMETRIC` | MORT manifest / local_auth | App lock and sensitive-action confirmation | Requested only after opt-in; password/session path remains; never called legal identity | On-device biometric result only; biometric data is not collected by MORT | Keep |
| `android.permission.ACCESS_COARSE_LOCATION` | MORT manifest / geolocator | Nearby Jobs/general area and approved active-job feature | User-triggered; approximate accepted; manual area fallback | Approximate location is optional and declared | Keep |
| `android.permission.ACCESS_FINE_LOCATION` | MORT manifest / geolocator | Optional foreground precision where user approves | User-triggered; precise is optional; approximate/manual fallback; no background access | Precise temporary location must be declared if sent/stored | Keep, monitor |
| `android.permission.USE_FINGERPRINT` | AndroidX Biometric 1.1.0 | Compatibility path for biometric prompt | Same behavior as USE_BIOMETRIC | On-device only | Keep, transitive compatibility |
| `android.permission.VIBRATE` | flutter_local_notifications | Notification vibration where OS/user permits | Install-time; no functional failure if vibration disabled | No personal data | Keep |
| `android.permission.WAKE_LOCK` | Firebase Messaging | Permit reliable FCM handling while the device is idle | Install-time; no user prompt | No additional personal data | Keep while `firebase_messaging` is compiled in |
| `com.mortapp.mobile.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX Core 1.18.0 | Signature-only protection for non-exported dynamic receivers | No user prompt; only same-signature apps can hold it | No user data category | Keep, platform security permission |

## Required interaction rules

- No background location permission or service.
- No location request during first launch or onboarding.
- No poster receives live teen location or residential coordinates.
- System Photo Picker is preferred over broad media access; no READ_MEDIA permission is declared.
- Lock-screen notification copy must omit addresses, housing status, incident detail, private messages, and precise location.
- Camera remains prohibited for disabled identity-document flows.
