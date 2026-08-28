# MORT iOS / Android Parity Matrix

## Evidence boundary

Flutter is the authoritative shared client. Android source, tests, merged manifest, an unsigned release APK, and a temporary debug-key-signed optimized APK were validated on Windows. The optimized APK launched on an Android 16 emulator and the native-plugin integration smoke passed. No physical Android device, macOS iOS build, physical iPhone, TestFlight, or Play Console test was performed. A capability marked implemented can still have a documented product, provider, legal, or device-testing limitation.

| ID | Capability | Android | iOS | Web | Known limitation |
|---|---|---|---|---|---|
| MOB-001 | Authentication | Supabase Auth repository implemented; native sessions use encrypted storage | Supabase Auth repository implemented; native sessions use encrypted storage | supported with browser session storage | Native secure-storage migration signs existing native sessions out once |
| MOB-002 | DOB age gate | server-backed profile onboarding implemented | server-backed profile onboarding implemented | supported | Legal age and youth-work eligibility still require jurisdiction review |
| MOB-003 | Role selection and onboarding | role-scoped Supabase profile flow implemented | role-scoped Supabase profile flow implemented | supported | Real-user marketplace remains closed |
| MOB-004 | Job feed | hosted Supabase job queries and filters implemented | hosted Supabase job queries and filters implemented | supported | No offline job cache |
| MOB-005 | Job posting | draft/publish RPC flow implemented | draft/publish RPC flow implemented | supported | Jurisdiction and production verification gates remain external launch blockers |
| MOB-006 | Applications | eligibility, apply, guardian, and adult review RPC flows implemented | eligibility, apply, guardian, and adult review RPC flows implemented | supported | No physical-device end-to-end run in this pass |
| MOB-007 | Messaging | Supabase messaging with safety scanner implemented | Supabase messaging with safety scanner implemented | supported | Screenshot blocking is Android-native only in Flutter; SwiftUI reference remains separate |
| MOB-008 | Notification center | Supabase notification rows implemented | Supabase notification rows implemented | notification rows supported; browser push not configured | Remote Android FCM and native APNs token persistence are not connected to the Expo-token backend contract |
| MOB-009 | Legal center | versioned legal documents and acceptance RPCs implemented | versioned legal documents and acceptance RPCs implemented | supported | Drafts still require counsel and teen-safety review |
| MOB-010 | Contracts and payment records | immutable contract versions, preferences, obligations, disputes, and exports implemented | immutable contract versions, preferences, obligations, disputes, and exports implemented | supported | No payment processing or escrow |
| MOB-011 | Start handshake | existing short-lived hashed arrival code and person-match confirmation implemented | existing short-lived hashed arrival code and person-match confirmation implemented | supported | Current backend is an arrival handshake, not the newer fully mutual cryptographic start protocol |
| MOB-012 | Completion handshake | dual checkout exists; cryptographic completion challenge and anti-withholding fallback not implemented | dual checkout exists; cryptographic completion challenge and anti-withholding fallback not implemented | same limitation | Not implemented on either platform; parity does not mean completion protocol is finished |
| MOB-013 | General-area job search | manual city/state filter plus user-initiated one-shot device area resolution implemented | manual city/state filter plus user-initiated one-shot device area resolution implemented | manual city/state only | No radius/PostGIS search; device geocoder can fail or return a broad region |
| MOB-014 | Temporary safety location | backend-authorized temporary coarse share and stop/expiry UI implemented | backend-authorized temporary coarse share and stop/expiry UI implemented | manual coarse text path | No continuous native location stream; exact teen location is not shared with posters |
| MOB-015 | Reports | private report and moderation flow implemented | private report and moderation flow implemented | supported | No guarantee of emergency response |
| MOB-016 | Blocking | server-backed user blocking implemented | server-backed user blocking implemented | supported | Block behavior still needs multi-device manual QA |
| MOB-017 | Safety Circle | privacy-limited trusted-contact backend and UI implemented | privacy-limited trusted-contact backend and UI implemented | supported | Not emergency monitoring and not unrestricted account access |
| MOB-018 | Optional Guardian Mode | optional linking, approval, permissions, and unlinking implemented | optional linking, approval, permissions, and unlinking implemented | supported | Legal consent requirements are separate and jurisdiction-specific |
| MOB-019 | Discreet Mode | privacy preferences and hidden-content guidance implemented | privacy preferences and hidden-content guidance implemented | supported with reduced native controls | Cannot guarantee concealment from device owners, operating systems, or network administrators |
| MOB-020 | Earnings goals | server-backed goals implemented | server-backed goals implemented | supported | Not financial advice or a bank account |
| MOB-021 | Future Independence | mission planning UI and backend records implemented | mission planning UI and backend records implemented | supported | No guarantee of housing, employment, legal, or financial outcomes |
| MOB-022 | Resource directory | allowlisted private resource records implemented | allowlisted private resource records implemented | supported | Coverage and availability depend on reviewed partner data |
| MOB-023 | App lock | Flutter lifecycle lock with encrypted local settings implemented | Flutter lifecycle lock with encrypted local settings implemented | unavailable | Android and iOS real-device behavior not yet tested |
| MOB-024 | Device authentication | local_auth uses OS biometric/PIN/pattern/passcode result only | local_auth uses OS biometric/PIN/pattern/passcode result only | unavailable | Does not verify identity, age, address, or safety |
| MOB-025 | Passkeys | capability detection and server-disabled explanation implemented | capability detection and server-disabled explanation implemented | browser capability detection only | Enrollment remains disabled pending relying-party, recovery, and cross-platform QA |
| MOB-026 | Camera capture | image_picker capture implemented for proof/profile/report paths | image_picker capture implemented for proof/profile/report paths | native capture unavailable | Real ID collection remains disabled; physical-device permission flow untested |
| MOB-027 | Photo picker | system picker and privacy re-encoding implemented | system picker and privacy re-encoding implemented | file picker supported | Large/unsupported image edge cases still need device QA |
| MOB-028 | Deep links | mort://app custom scheme and Supabase PKCE callback route implemented | mort://app custom scheme and Supabase PKCE callback route implemented | HTTPS callback route supported | Verified Android App Links and iOS Universal Links need a real domain and association files |
| MOB-029 | Account deletion | device-authenticated support request implemented because no self-delete RPC exists | device-authenticated support request implemented because no self-delete RPC exists | native authentication unavailable | Request is not instant deletion and retention review is required |
| MOB-030 | Data export | authorized payment-dispute evidence export implemented | authorized payment-dispute evidence export implemented | supported | Full account-wide portability export is not implemented |
| MOB-031 | Accessibility | semantic Material controls, labels, scalable text, and adaptive controls implemented | semantic Material controls, labels, scalable text, and adaptive controls implemented | supported | VoiceOver/TalkBack audits on physical devices are pending |
| MOB-032 | Dark mode | shared MORT dark theme implemented | shared MORT dark theme implemented | supported | Light theme is not implemented |
| MOB-033 | Offline and degraded states | loading, empty, error, retry, and setup-required states implemented | loading, empty, error, retry, and setup-required states implemented | supported error states | No offline mutation queue or cached marketplace data |
| MOB-034 | Session management | Supabase session restore, sign-out, active sessions, and encrypted native persistence implemented | Supabase session restore, sign-out, active sessions, and encrypted native persistence implemented | browser storage | Native secure-storage migration intentionally invalidates the old unencrypted persisted session |

## Result

- Android is not intentionally missing a capability that the shared Flutter iOS target exposes.
- Android now exceeds the prior Flutter state for app lock, device authentication, sensitive-screen capture protection, foreground-area lookup, release manifest hardening, and build verification.
- Equal status is not used to disguise missing work: mutual completion codes, full account export, native push token delivery, verified domain links, passkeys, offline caching, and device testing remain incomplete on both targets or are explicitly platform-limited.
