> RECOMMENDED - ADULT ACCOUNT OWNER MUST CONFIRM

# Permission Declaration Final

| Permission | Source | Feature | Runtime request | Explanation | Denial fallback | Play impact | Decision |
|---|---|---|---|---|---|---|---|
| `INTERNET` | Flutter/Supabase | Hosted auth/API/media | OS granted | Network required | Offline/error/retry state | Core network app | Retain |
| `ACCESS_NETWORK_STATE` | Connectivity/runtime | Detect network state | No runtime dialog | Supports recovery | Retry path | Low impact | Retain |
| `CAMERA` | image_picker | Optional proof capture | Proof action only | Capture requested by user | Gallery/native-required alternative | Data Safety/media | Retain; optional hardware |
| `POST_NOTIFICATIONS` | flutter_local_notifications | Private local notifications | Contextual Android 13+ request | User can decline | In-app notification center | Permission declaration | Retain |
| `USE_BIOMETRIC` | local_auth | Optional app lock | User enables | Local device auth only | Passcode/no app-lock fallback | Biometric disclosure; no template collected | Retain |
| `ACCESS_COARSE_LOCATION` | geolocator | Approximate nearby/manual area | Location action only | Approximate is sufficient | Manual area | Location Data Safety | Retain |
| `ACCESS_FINE_LOCATION` | geolocator | Optional foreground active-job location | Explicit contextual request | Temporary foreground sharing | Coarse/manual/no sharing | Prominent disclosure | Retain; no background |
| `USE_FINGERPRINT` | local_auth compatibility | Optional app lock on older biometric APIs | User enables app lock | OS-owned local authentication | Passcode/no app-lock fallback | No biometric template collected | Retain |
| `VIBRATE` | flutter_local_notifications | Optional local notification alert | Notification preference/OS control | Alert may vibrate | Silent/in-app notification path | Low-impact notification behavior | Retain |
| `com.mortapp.mobile.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX runtime | Protect app-scoped dynamic receivers | No user request | Internal non-exported receiver guard | Not user-facing | App-scoped signature permission | Retain |

Exact signed release posture: 10 merged permissions. Billing, advertising ID, AdServices identifiers, foreground service, wake lock, background location, and broad media-library permissions are absent. The app-scoped dynamic-receiver permission is not a user-granted data permission. Reconfirm against any Play-rebuilt split APK before submission.
