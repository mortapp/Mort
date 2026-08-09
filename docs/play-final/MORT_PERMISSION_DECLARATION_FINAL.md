> RECOMMENDED - ADULT ACCOUNT OWNER MUST CONFIRM

# Permission Declaration Final

| Permission | Source | Feature | Runtime request | Explanation | Denial fallback | Play impact | Decision |
|---|---|---|---|---|---|---|---|
| `INTERNET` | Flutter/Supabase | Hosted auth/API/media | OS granted | Network required | Offline/error/retry state | Core network app | Retain |
| `ACCESS_NETWORK_STATE` | Connectivity/runtime | Detect network state | No runtime dialog | Supports recovery | Retry path | Low impact | Retain |
| `CAMERA` | image_picker | Optional proof capture | Proof action only | Capture requested by user | Gallery/native-required alternative | Data Safety/media | Retain; optional hardware |
| `POST_NOTIFICATIONS` | Firebase Messaging manifest | Future remote notifications; disabled in closed test | Only after provider activation and contextual request | User can decline | In-app notification center | Permission declaration | Retain for compiled provider; disclose disabled state |
| `USE_BIOMETRIC` | local_auth | Optional app lock | User enables | Local device auth only | Passcode/no app-lock fallback | Biometric disclosure; no template collected | Retain |
| `ACCESS_COARSE_LOCATION` | geolocator | Approximate nearby/manual area | Location action only | Approximate is sufficient | Manual area | Location Data Safety | Retain |
| `ACCESS_FINE_LOCATION` | geolocator | Optional foreground active-job location | Explicit contextual request | Temporary foreground sharing | Coarse/manual/no sharing | Prominent disclosure | Retain; no background |
| `USE_FINGERPRINT` | local_auth compatibility | Optional app lock on older biometric APIs | User enables app lock | OS-owned local authentication | Passcode/no app-lock fallback | No biometric template collected | Retain |
| `WAKE_LOCK` | Firebase Messaging manifest | Provider delivery support; disabled in closed test | No user request | Compiled provider support only | Remote delivery remains disabled | No location or screen wake API exposed by MORT | Retain while provider is bundled |
| `com.google.android.c2dm.permission.RECEIVE` | Firebase Messaging manifest | Receive provider messages after future activation | No user request | Compiled provider support only | Remote delivery remains disabled | Reaudit before activation | Retain while provider is bundled |
| `com.mortapp.mobile.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX runtime | Protect app-scoped dynamic receivers | No user request | Internal non-exported receiver guard | Not user-facing | App-scoped signature permission | Retain |

Exact signed `0.9.14+104` APK posture: 11 merged uses-permissions. Billing,
advertising ID, AdServices identifiers, foreground service, background location,
`VIBRATE`, and broad media-library permissions are absent. The app-scoped
dynamic-receiver permission is not a user-granted data permission. Reconfirm
against any Play-rebuilt split APK before submission.
