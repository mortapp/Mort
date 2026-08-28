# MORT Android Emulator Matrix

Generated: 2026-08-01 (America/Indianapolis)

Release under test: `0.9.12+102`, closed-test profile. Public marketplace,
identity verification, payments, remote push delivery, ads, IAP, external AI,
and crash reporting remain disabled.

## Device Evidence

| Item | Result |
|---|---|
| AVD | `Medium_Phone_API_36.1` |
| Android API | 36 |
| ABI | `x86_64` |
| Display | 1080 x 2400 at 420 dpi |
| Data partition | 5.8 GB total, 4.2 GB free during QA |
| Signed APK | `mort-closed-test-0.9.12.apk` |
| Final APK SHA-256 | `2B44D32877FCB6AF0AFBBA880BF382C56F7E2121D2AE7D7293D6CA5C10DA128E` |
| Install evidence | Pre-permission-hardening `0.9.12+102` APK installed after removing the debug-signed package |
| Launch evidence | That APK's main activity resumed with PID `6666`; fatal log scan empty |
| Final APK device retest | Blocked when the constrained AVD command timed out before returning evidence |
| Host limitation | AVD repeatedly dropped offline after launch; screenshot and extended lifecycle automation blocked |

## Fifty-Journey Matrix

`100% VERIFIED` means the named boundary passed its cited automated or emulator
check. It does not imply a full physical-device journey.

| # | Journey | Status | Evidence or remaining check |
|---:|---|---|---|
| 1 | Install exact final signed APK | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | Equivalent 0.9.12 APK passed; final hash retest blocked by AVD |
| 2 | Cold launch exact final signed APK | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | Equivalent build reached `MainActivity`; final hash retest blocked by AVD |
| 3 | Launch fatal/Flutter error scan | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | Equivalent build scan was empty; repeat against final hash |
| 4 | Warm relaunch | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | AVD disconnected before continuation |
| 5 | Force-stop and restart | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | Repeat on stable emulator/physical Android |
| 6 | Background and foreground | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | Repeat on stable emulator/physical Android |
| 7 | Rotation/activity recreation | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | Portrait UI is locked; recreation still needs device check |
| 8 | Uninstall/reinstall boundary | 100% VERIFIED | Debug package removed; signed package installed cleanly |
| 9 | Package/version/SDK contract | 100% VERIFIED | `com.mortapp.mobile`, `0.9.12+102`, min 24, target 36 |
| 10 | Release permission minimization | 100% VERIFIED | APK/AAB verification; forbidden ad, audio, storage, background-location permissions absent |
| 11 | Offline startup with saved session | 100% VERIFIED | Bounded retry and preserved-session widget tests |
| 12 | Valid restored session routing | 100% VERIFIED | Server-authoritative teen route test |
| 13 | Revoked refresh token | 100% VERIFIED | Local session cleared without private navigation |
| 14 | Auth stream error | 100% VERIFIED | Saved session retained; no destructive logout |
| 15 | Email/password Auth boundary | 100% VERIFIED | Hosted smoke and Auth/RLS regression |
| 16 | Google OAuth PKCE configuration | 100% VERIFIED | Callback, scope, profile bootstrap, and server audit tests |
| 17 | Real Google account picker | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | Requires real device/account interaction |
| 18 | DOB age gate | 100% VERIFIED | Date parsing, calendar validation, and hosted onboarding tests |
| 19 | Under-13 denial | 100% VERIFIED | Server/client age-gate contracts |
| 20 | Teen onboarding resume/completion | 100% VERIFIED | Hosted resumable-onboarding suite |
| 21 | Adult/business onboarding | 100% VERIFIED | Hosted account-type/business-name enforcement |
| 22 | Guardian onboarding without forced link | 100% VERIFIED | Hosted guardian path and optional-mode suite |
| 23 | Job feed pagination/cache | 100% VERIFIED | Keyset pagination, dedupe, stale-label tests |
| 24 | Adult job creation/publication | 100% VERIFIED | Server validation and marketplace state-machine QA |
| 25 | Teen application | 100% VERIFIED | Caller-bound application and isolation QA |
| 26 | Adult application review | 100% VERIFIED | Owned-job review and unrelated-adult denial |
| 27 | Accept exactly one applicant | 100% VERIFIED | Multi-user isolation check 8/30 |
| 28 | Start-job PIN | 100% VERIFIED | Idempotency, replay, and concurrency QA |
| 29 | End-job PIN/completion | 100% VERIFIED | Lifecycle and contract-transition QA |
| 30 | Proof upload/access | 100% VERIFIED | Private bucket, MIME, owner and outsider isolation checks |
| 31 | Safety-scanned messaging | 100% VERIFIED | Participant send/read and outsider denial QA |
| 32 | Mutual reporting | 100% VERIFIED | Teen/adult independent report isolation QA |
| 33 | Block/unblock | 100% VERIFIED | Payload-bound action and privacy QA |
| 34 | Safety Ping | 100% VERIFIED | Routine/urgent budgets, no-dispatch copy, location rejection |
| 35 | Guardian link | 100% VERIFIED | Hashed invite and visibility checks |
| 36 | Guardian unlink/age-out | 100% VERIFIED | Immediate access removal and audit checks |
| 37 | Job cancellation/dispute | 100% VERIFIED | Immutable statements, independent appeal, no money movement |
| 38 | Local notification routing | 100% VERIFIED | Destination allowlist and role routing tests |
| 39 | Real remote push delivery | CODE-COMPLETE / PROVIDER APPROVAL REQUIRED | FCM foundation passed; runtime intentionally disabled |
| 40 | Deterministic support assistant | 100% VERIFIED | Auth, citation, idempotency, injection, and isolation QA |
| 41 | Human support handoff | CODE-COMPLETE / STAFFING REQUIRED | Queue/RLS passed; service remains explicitly unstaffed |
| 42 | Account deletion workflow | 100% VERIFIED | In-app/web/worker state-machine contracts; production operator still required |
| 43 | Admin route/data authorization | 100% VERIFIED | Role guard, restricted RPCs, reviewer-isolation QA |
| 44 | Storage isolation | 100% VERIFIED | Nine private buckets and 18 policies; no public bucket |
| 45 | Role/verification/credit forgery | 100% VERIFIED | Multi-user checks 21-23/30 |
| 46 | Large-text PIN/safety layouts | 100% VERIFIED | Flutter widget and first native integration pass |
| 47 | Secure PIN semantics | 100% VERIFIED | Progress exposed; entered value excluded from semantics |
| 48 | Reduced-motion/focus behavior | 100% VERIFIED | Shared-control widget regression |
| 49 | Device frame/memory profiling | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | AVD dropped before `gfxinfo`/memory capture |
| 50 | Physical Android end-to-end pass | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | Physical device was not available |

## Coverage Boundary

Only API 36 on one x86_64 emulator was available. API 24/28/33/34/35,
low-memory devices, tablets, foldables, OEM permission variants, accessibility
services, biometric hardware, real camera/gallery, real notifications, and a
real Google chooser require manual device-lab coverage.
