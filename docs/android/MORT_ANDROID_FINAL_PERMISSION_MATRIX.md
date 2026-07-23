# MORT Android Permission Matrix

Release target: `com.mortapp.mobile`, Flutter `0.9.2+92`, closed pilot.

| Permission/capability | Why it exists | Request timing | Denial behavior | Closed-pilot state |
| --- | --- | --- | --- | --- |
| `INTERNET` | Hosted Supabase and approved provider APIs | No runtime prompt | Network error with retry | Required |
| `ACCESS_NETWORK_STATE` | Detect connectivity before retrying | No runtime prompt | Continue with normal network failures | Required |
| `CAMERA` | User-selected profile/proof/document capture | Only after **Use camera** | Photo Picker or Settings guidance | Synthetic document QA only |
| `POST_NOTIFICATIONS` | Job and safety notification delivery | Contextual explanation before prompt | In-app notifications remain | Optional |
| `USE_BIOMETRIC` | Local app-lock convenience | Only when user enables app lock | PIN/session path remains | Optional, not identity proof |
| `USE_FINGERPRINT` | Legacy compatibility declared by the local-auth plugin | Same contextual app-lock flow | App lock remains off or uses fallback | Optional, not identity proof |
| `VIBRATE` | Notification alert behavior declared by the notifications plugin | Controlled by notification settings | Silent/in-app notification path remains | Optional |
| `ACCESS_COARSE_LOCATION` | Approximate local job discovery | When user selects nearby search | Manual area entry remains | Optional |
| `ACCESS_FINE_LOCATION` | Foreground location for explicitly selected workflows | Contextual, foreground only | Coarse/manual area fallback | Optional |
| `com.android.vending.BILLING` | Google Play purchases | Play purchase action | Free core remains available | Compiled, runtime-disabled |

`AD_ID`, Privacy Sandbox ad permissions, foreground service, and wake lock are removed from the merged manifest. Camera, location, and fingerprint hardware are marked optional. Cleartext traffic and Android backup are disabled. No storage permission is declared because the system Photo Picker is used. Ads remain excluded and Google Play Billing remains disabled until console/provider verification is complete.

Validation: `scripts/qa-android-permission-minimization.mjs` and the merged release manifest inspection must pass for every AAB.
