# MORT Android Permission Matrix

Release target: `com.mortapp.mobile`, Flutter `0.9.14+104`, closed pilot.

| Permission/capability | Why it exists | Request timing | Denial behavior | Closed-pilot state |
| --- | --- | --- | --- | --- |
| `INTERNET` | Hosted Supabase and approved provider APIs | No runtime prompt | Network error with retry | Required |
| `ACCESS_NETWORK_STATE` | Detect connectivity before retrying | No runtime prompt | Continue with normal network failures | Required |
| `CAMERA` | User-selected profile/proof/document capture | Only after **Use camera** | Photo Picker or Settings guidance | Synthetic document QA only |
| `POST_NOTIFICATIONS` | Job and safety notification delivery | Contextual explanation before prompt | In-app notifications remain | Optional |
| `USE_BIOMETRIC` | Local app-lock convenience | Only when user enables app lock | PIN/session path remains | Optional, not identity proof |
| `USE_FINGERPRINT` | Legacy local-auth compatibility in the merged manifest | Same contextual app-lock flow | App lock remains off or uses fallback | Optional, not identity proof |
| `ACCESS_COARSE_LOCATION` | Approximate local job discovery | When user selects nearby search | Manual area entry remains | Optional |
| `ACCESS_FINE_LOCATION` | Foreground location for explicitly selected workflows | Contextual, foreground only | Coarse/manual area fallback | Optional |
| `WAKE_LOCK` | Compiled Firebase Messaging provider | No runtime prompt; provider disabled in closed test | Remote delivery remains unavailable | No location or screen-wake feature exposed by MORT |
| `com.google.android.c2dm.permission.RECEIVE` | Compiled Firebase Messaging provider | No runtime prompt; provider disabled in closed test | Remote delivery remains unavailable | Reaudit before activation |
| `com.mortapp.mobile.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX app-scoped receiver protection | No runtime prompt | Not user-facing | Signature-scoped internal guard |

The exact signed `0.9.14+104` APK contains 11 merged uses-permissions.
`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, broad storage, Billing, `AD_ID`, Privacy
Sandbox ad permissions, and foreground-service permissions are absent or
explicitly removed from the merged release manifest. `WAKE_LOCK` is retained
only for the compiled Firebase Messaging provider; it has no runtime prompt and
does not enable background location. `VIBRATE` is absent. Camera, location, and fingerprint hardware
are marked optional. Cleartext traffic and Android backup are disabled. Media
selection uses the system picker. Ads and purchases remain excluded from the
closed-pilot binary.

Validation: `scripts/qa-android-permission-minimization.mjs` and the merged release manifest inspection must pass for every AAB.
