import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname.replace(/^\/(.:)/, "$1");
const output = join(root, "docs", "mobile");
mkdirSync(output, { recursive: true });

const androidTest = "83 Flutter tests pass; Android 16 emulator native-plugin smoke and optimized APK launch passed; physical-device flow testing pending";
const iosTest = "Source and static parity inspected; macOS build and physical iPhone test pending";

const shared = (id, capability, service, permission, web, fallback, limitation) => ({
  featureId: id,
  capability,
  androidUiStatus: "implemented in shared Flutter UI",
  androidServiceStatus: service,
  androidPermissionStatus: permission,
  androidTestStatus: androidTest,
  iosUiStatus: "implemented in shared Flutter UI and mapped in SwiftUI reference",
  iosServiceStatus: service,
  iosPermissionStatus: permission,
  iosTestStatus: iosTest,
  webStatus: web,
  fallbackBehavior: fallback,
  knownLimitation: limitation,
});

const records = [
  shared("MOB-001", "Authentication", "Supabase Auth repository implemented; native sessions use encrypted storage", "no runtime permission", "supported with browser session storage", "setup-required and retry states", "Native secure-storage migration signs existing native sessions out once"),
  shared("MOB-002", "DOB age gate", "server-backed profile onboarding implemented", "no runtime permission", "supported", "manual MM/DD/YYYY entry", "Legal age and youth-work eligibility still require jurisdiction review"),
  shared("MOB-003", "Role selection and onboarding", "role-scoped Supabase profile flow implemented", "no runtime permission", "supported", "resume incomplete onboarding", "Real-user marketplace remains closed"),
  shared("MOB-004", "Job feed", "hosted Supabase job queries and filters implemented", "no runtime permission", "supported", "manual filters and retry", "No offline job cache"),
  shared("MOB-005", "Job posting", "draft/publish RPC flow implemented", "no runtime permission", "supported", "save draft", "Jurisdiction and production verification gates remain external launch blockers"),
  shared("MOB-006", "Applications", "eligibility, apply, guardian, and adult review RPC flows implemented", "no runtime permission", "supported", "clear blocked-state reasons", "No physical-device end-to-end run in this pass"),
  shared("MOB-007", "Messaging", "Supabase messaging with safety scanner implemented", "Android screenshots blocked on message routes; iOS Flutter screen protection not native-wired", "supported", "report/block and retry", "Screenshot blocking is Android-native only in Flutter; SwiftUI reference remains separate"),
  shared("MOB-008", "Notification center", "Supabase notification rows implemented", "POST_NOTIFICATIONS on Android; iOS notification request supported", "notification rows supported; browser push not configured", "in-app notification center", "Remote Android FCM and native APNs token persistence are not connected to the Expo-token backend contract"),
  shared("MOB-009", "Legal center", "versioned legal documents and acceptance RPCs implemented", "no runtime permission", "supported", "plain-language summaries", "Drafts still require counsel and teen-safety review"),
  shared("MOB-010", "Contracts and payment records", "immutable contract versions, preferences, obligations, disputes, and exports implemented", "no runtime permission", "supported", "private evidence/support flow", "No payment processing or escrow"),
  shared("MOB-011", "Start handshake", "existing short-lived hashed arrival code and person-match confirmation implemented", "device authentication available for sensitive actions", "supported", "cancel and safety escalation", "Current backend is an arrival handshake, not the newer fully mutual cryptographic start protocol"),
  shared("MOB-012", "Completion handshake", "dual checkout exists; cryptographic completion challenge and anti-withholding fallback not implemented", "no additional permission", "same limitation", "private completion/dispute evidence", "Not implemented on either platform; parity does not mean completion protocol is finished"),
  shared("MOB-013", "General-area job search", "manual city/state filter plus user-initiated one-shot device area resolution implemented", "foreground coarse/fine location only; no background permission", "manual city/state only", "manual city/state always available", "No radius/PostGIS search; device geocoder can fail or return a broad region"),
  shared("MOB-014", "Temporary safety location", "backend-authorized temporary coarse share and stop/expiry UI implemented", "foreground location only; sharing off by default", "manual coarse text path", "manual safety context and Safety Ping", "No continuous native location stream; exact teen location is not shared with posters"),
  shared("MOB-015", "Reports", "private report and moderation flow implemented", "Android screenshots blocked on report routes", "supported", "support and emergency guidance", "No guarantee of emergency response"),
  shared("MOB-016", "Blocking", "server-backed user blocking implemented", "no runtime permission", "supported", "report remains available", "Block behavior still needs multi-device manual QA"),
  shared("MOB-017", "Safety Circle", "privacy-limited trusted-contact backend and UI implemented", "notifications optional", "supported", "feature can remain unused", "Not emergency monitoring and not unrestricted account access"),
  shared("MOB-018", "Optional Guardian Mode", "optional linking, approval, permissions, and unlinking implemented", "notifications optional", "supported", "teen can continue without optional mode unless a job policy separately requires approval", "Legal consent requirements are separate and jurisdiction-specific"),
  shared("MOB-019", "Discreet Mode", "privacy preferences and hidden-content guidance implemented", "native app lock optional", "supported with reduced native controls", "generic notification copy and manual privacy choices", "Cannot guarantee concealment from device owners, operating systems, or network administrators"),
  shared("MOB-020", "Earnings goals", "server-backed goals implemented", "no runtime permission", "supported", "manual updates", "Not financial advice or a bank account"),
  shared("MOB-021", "Future Independence", "mission planning UI and backend records implemented", "no runtime permission", "supported", "resource directory", "No guarantee of housing, employment, legal, or financial outcomes"),
  shared("MOB-022", "Resource directory", "allowlisted private resource records implemented", "no runtime permission", "supported", "support ticket", "Coverage and availability depend on reviewed partner data"),
  shared("MOB-023", "App lock", "Flutter lifecycle lock with encrypted local settings implemented", "device owner authentication", "unavailable", "web session controls", "Android and iOS real-device behavior not yet tested"),
  shared("MOB-024", "Device authentication", "local_auth uses OS biometric/PIN/pattern/passcode result only", "USE_BIOMETRIC/USE_FINGERPRINT on Android; NSFaceIDUsageDescription on iOS", "unavailable", "password/session controls", "Does not verify identity, age, address, or safety"),
  shared("MOB-025", "Passkeys", "capability detection and server-disabled explanation implemented", "platform authenticator when future server policy enables it", "browser capability detection only", "password sign-in", "Enrollment remains disabled pending relying-party, recovery, and cross-platform QA"),
  shared("MOB-026", "Camera capture", "image_picker capture implemented for proof/profile/report paths", "CAMERA on Android; NSCameraUsageDescription on iOS", "native capture unavailable", "system file/photo selection", "Real ID collection remains disabled; physical-device permission flow untested"),
  shared("MOB-027", "Photo picker", "system picker and privacy re-encoding implemented", "no broad Android media permission; selected/full photo access on iOS", "file picker supported", "camera or file selection", "Large/unsupported image edge cases still need device QA"),
  shared("MOB-028", "Deep links", "mort://app custom scheme and Supabase PKCE callback route implemented", "browsable intent on Android; URL scheme on iOS", "HTTPS callback route supported", "open app and restore session manually", "Verified Android App Links and iOS Universal Links need a real domain and association files"),
  shared("MOB-029", "Account deletion", "device-authenticated support request implemented because no self-delete RPC exists", "device authentication on native", "native authentication unavailable", "manual support ticket", "Request is not instant deletion and retention review is required"),
  shared("MOB-030", "Data export", "authorized payment-dispute evidence export implemented", "Android screenshots blocked on export route", "supported", "support request", "Full account-wide portability export is not implemented"),
  shared("MOB-031", "Accessibility", "semantic Material controls, labels, scalable text, and adaptive controls implemented", "no runtime permission", "supported", "accessible manual entry paths", "VoiceOver/TalkBack audits on physical devices are pending"),
  shared("MOB-032", "Dark mode", "shared MORT dark theme implemented", "no runtime permission", "supported", "single consistent theme", "Light theme is not implemented"),
  shared("MOB-033", "Offline and degraded states", "loading, empty, error, retry, and setup-required states implemented", "network state available on Android", "supported error states", "manual retry", "No offline mutation queue or cached marketplace data"),
  shared("MOB-034", "Session management", "Supabase session restore, sign-out, active sessions, and encrypted native persistence implemented", "Android screenshots blocked on active-session route", "browser storage", "reauthenticate and sign in again", "Native secure-storage migration intentionally invalidates the old unencrypted persisted session"),
];

writeFileSync(
  join(output, "MORT_PLATFORM_CAPABILITY_MATRIX.json"),
  `${JSON.stringify({ generatedAt: new Date().toISOString(), records }, null, 2)}\n`,
);

const rows = records.map((record) =>
  `| ${record.featureId} | ${record.capability} | ${record.androidServiceStatus} | ${record.iosServiceStatus} | ${record.webStatus} | ${record.knownLimitation} |`,
);
const markdown = `# MORT iOS / Android Parity Matrix

## Evidence boundary

Flutter is the authoritative shared client. Android source, tests, merged manifest, an unsigned release APK, and a temporary debug-key-signed optimized APK were validated on Windows. The optimized APK launched on an Android 16 emulator and the native-plugin integration smoke passed. No physical Android device, macOS iOS build, physical iPhone, TestFlight, or Play Console test was performed. A capability marked implemented can still have a documented product, provider, legal, or device-testing limitation.

| ID | Capability | Android | iOS | Web | Known limitation |
|---|---|---|---|---|---|
${rows.join("\n")}

## Result

- Android is not intentionally missing a capability that the shared Flutter iOS target exposes.
- Android now exceeds the prior Flutter state for app lock, device authentication, sensitive-screen capture protection, foreground-area lookup, release manifest hardening, and build verification.
- Equal status is not used to disguise missing work: mutual completion codes, full account export, native push token delivery, verified domain links, passkeys, offline caching, and device testing remain incomplete on both targets or are explicitly platform-limited.
`;
writeFileSync(join(output, "MORT_IOS_ANDROID_PARITY_MATRIX.md"), markdown);

console.log(`Wrote ${records.length} audited mobile capability records.`);
