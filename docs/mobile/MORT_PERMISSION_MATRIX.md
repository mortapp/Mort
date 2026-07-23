# MORT Mobile Permission Matrix

| Capability | Android release | iOS Flutter source | Default | Fallback | Status |
|---|---|---|---|---|---|
| Internet | `INTERNET`, `ACCESS_NETWORK_STATE` | network access by platform | required for hosted Supabase | setup/error/retry state | APK verified |
| Camera | `CAMERA`; camera hardware optional | `NSCameraUsageDescription` | asked only after camera action | system photo/file picker | native status plugin passed on emulator; prompt/capture device QA pending |
| Photos | Android system Photo Picker; no broad media permission | `NSPhotoLibraryUsageDescription` | selected item only | camera or file picker | no-broad-permission path passed on emulator; picker device QA pending |
| Notifications | `POST_NOTIFICATIONS` | runtime notification request | opt-in | in-app Supabase notification center | remote delivery provider missing |
| Device authentication | `USE_BIOMETRIC`, legacy `USE_FINGERPRINT` merged by plugin | `NSFaceIDUsageDescription` | app lock off | password/session controls | capability plugin passed on emulator; real prompt/device QA pending |
| Location | `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION` | `NSLocationWhenInUseUsageDescription` | off until user taps current-area action | manual city/state | native status plugin passed on emulator; permission/geocoder device QA pending |
| Background location | absent | no Always description or location background mode | unavailable | temporary manual/coarse safety context | intentionally not requested |
| Advertising ID / Ad Services | removed | iOS AdMob ID remains configured but ads default off | disabled | no ad | policy/provider setup required before enabling |
| Billing | removed from current Android build | RevenueCat code guarded by `IAP_ENABLED=false` | disabled | free core workflows | Play/App Store setup required before enabling |

No permission is presented as proof of identity or safety. Location permission does not enable poster access to a teen's live location.
