import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const date = '2026-07-20';

function write(relative, content) {
  const path = resolve(root, relative);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${content.trim()}\n`);
}

const status = `> Status: closed-test publication candidate dated ${date}. Not legal approval, not a public launch, and not a production-readiness claim.`;

write('docs/mobile/MORT_PLAY_SIGNING_SETUP.md', `
# MORT Google Play Upload Signing Setup

${status}

## Implemented signing boundary

- Application ID: \`com.mortapp.mobile\`.
- Upload key alias: \`mort-upload\`.
- Private keystore: \`C:\\Users\\micha\\MortSecrets\\android\\mort-upload-key.jks\` (outside the repository).
- Local credential source: Windows DPAPI-protected CLIXML outside the repository, or all four \`MORT_UPLOAD_*\` environment variables.
- Gradle release tasks fail when signing values are missing or incomplete. There is no debug fallback.
- Public certificate report: \`docs/mobile/MORT_UPLOAD_CERTIFICATE_REPORT.md\`.

Required environment names are \`MORT_UPLOAD_KEYSTORE_PATH\`, \`MORT_UPLOAD_KEY_ALIAS\`, \`MORT_UPLOAD_STORE_PASSWORD\`, and \`MORT_UPLOAD_KEY_PASSWORD\`. Never put values in Git, ZIP files, screenshots, chat, \`.env.local\`, Flutter source, or Play listing documents.

## Build and verify

\`powershell
.\\scripts\\build-play-aab.ps1
.\\scripts\\verify-play-aab.ps1
.\\scripts\\build-closed-test-apk.ps1
\`

The AAB build targets \`rakjydmgwwgtdislanbt\`, fixes release stage to \`closed_test\`, fixes operational mode to \`closed_pilot\`, disables public marketplace and real identity verification, disables ads and IAP, obfuscates Dart code, and stores symbol files outside the repository at \`C:\\Users\\micha\\MortSymbols\android\\0.9.0+90\`.

## Play App Signing

1. The adult account owner creates the app in Play Console with package \`com.mortapp.mobile\`.
2. Enroll in Play App Signing. Google protects the app-signing key; MORT keeps the separate upload key.
3. Upload \`build/play/mort-closed-test.aab\` only after \`verify-play-aab.ps1\` passes.
4. Compare Play Console's upload-certificate SHA-1 and SHA-256 with the checked-in public certificate report.
5. Never upload or share the JKS. Only the signed AAB and public certificate may leave the release machine.
6. Confirm the Play Console maximum prior version code is lower than 90. This repository cannot inspect Play upload history.

Official reference: https://developer.android.com/studio/publish/app-signing
`);

write('docs/mobile/MORT_KEY_RECOVERY_PLAN.md', `
# MORT Upload-Key Recovery Plan

${status}

## Ownership

The adult Play Console account owner is accountable for access recovery. The founder uses a separately invited Google account. Password sharing is prohibited.

## Required protected copies

Before the first Play upload, the adult owner must create two offline, encrypted backups containing the upload JKS and recoverable credentials. One copy should be on BitLocker-encrypted removable media in a locked location; the second should be in an approved password manager or encrypted vault controlled by the adult owner. The repository's DPAPI credential file is machine/user-bound and is not, by itself, a cross-machine recovery backup.

Never place the key or password in source ZIPs, ordinary cloud project folders, email, shared drives, group chat, screenshots, issue trackers, or documentation. Record the alias, certificate fingerprints, creation date, expiration, storage custodians, and last restore-test date without recording the private key or password.

## Restore drill

Quarterly, on an offline protected machine, restore the JKS and credentials, run \`keytool -list -v\`, and compare the SHA-256 fingerprint to \`MORT_UPLOAD_CERTIFICATE_REPORT.md\`. Do not generate a replacement key merely to test recovery.

## Loss or compromise

1. Stop uploads and remove release access from affected accounts.
2. Have the adult owner review Play Console activity and Google account sessions.
3. Follow Play Console's upload-key reset process; do not change the package ID or app-signing key casually.
4. Generate a new upload key through an approved release machine, update the public certificate record, and invalidate the old local credentials.
5. Document the incident without putting credentials in the incident record.
`);

write('docs/mobile/MORT_VERSIONING_POLICY.md', `
# MORT Mobile Versioning Policy

${status}

The single version source is \`flutter_mort/pubspec.yaml\`. Current candidate: \`0.9.0+90\` (Android versionName 0.9.0, versionCode 90).

- \`0.x.x\`: development, internal test, and closed pilot.
- \`1.0.0\`: unavailable until separate production approval.
- Android versionCode must increase for every Play upload and must exceed every code already known to Play Console.
- Never reuse or lower a Play versionCode, including after a rejected release.
- Read with \`node scripts/read-mobile-version.mjs --json\`.
- Increment with \`node scripts/increment-android-version.mjs --name 0.9.1 --code 91\`; the script refuses a non-increasing code.
- Confirm Play Console's latest artifact before every upload because local source cannot prove remote version history.
`);

write('docs/mobile/MORT_ANDROID_PERMISSION_RELEASE_AUDIT.md', `
# MORT Android Permission Release Audit

${status}

The prior merged release manifest contained 11 permissions. \`WAKE_LOCK\`, inherited from a bundled Google measurement dependency, is explicitly removed for this closed test. The final AAB inventory controls if it differs from this source audit.

| Permission | Requester | Feature / current use | Runtime and denial behavior | Disclosure / Data Safety | Decision |
|---|---|---|---|---|---|
| \`android.permission.INTERNET\` | MORT manifest | Supabase Auth/API, approved HTTPS image fetches | Install-time; offline states and retry when unavailable | Network transfer of declared account/content data | Keep |
| \`android.permission.ACCESS_NETWORK_STATE\` | MORT manifest | Detect degraded/offline state | Install-time; app still allows retry | App interaction/diagnostic context; no analytics claim | Keep |
| \`android.permission.CAMERA\` | MORT manifest / image_picker | Optional proof capture for enabled job workflow; never identity documents | Contextual request after user taps camera; photo picker/manual continuation on denial; settings guidance on permanent denial | User photo/file collection when submitted | Keep while proof camera remains enabled |
| \`android.permission.POST_NOTIFICATIONS\` | MORT manifest | Contextual local/push notification permission | Never at first launch; deny leaves in-app state available; settings guidance on permanent denial | Notification token only if push registration is configured | Keep |
| \`android.permission.USE_BIOMETRIC\` | MORT manifest / local_auth | App lock and sensitive-action confirmation | Requested only after opt-in; password/session path remains; never called legal identity | On-device biometric result only; biometric data is not collected by MORT | Keep |
| \`android.permission.ACCESS_COARSE_LOCATION\` | MORT manifest / geolocator | Nearby Jobs/general area and approved active-job feature | User-triggered; approximate accepted; manual area fallback | Approximate location is optional and declared | Keep |
| \`android.permission.ACCESS_FINE_LOCATION\` | MORT manifest / geolocator | Optional foreground precision where user approves | User-triggered; precise is optional; approximate/manual fallback; no background access | Precise temporary location must be declared if sent/stored | Keep, monitor |
| \`android.permission.USE_FINGERPRINT\` | AndroidX Biometric 1.1.0 | Compatibility path for biometric prompt | Same behavior as USE_BIOMETRIC | On-device only | Keep, transitive compatibility |
| \`android.permission.VIBRATE\` | flutter_local_notifications | Notification vibration where OS/user permits | Install-time; no functional failure if vibration disabled | No personal data | Keep |
| \`android.permission.WAKE_LOCK\` | Google measurement transitive dependency | No approved closed-test feature | Not requested at runtime | Unnecessary background behavior concern | Remove with manifest merger rule |
| \`com.mortapp.mobile.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION\` | AndroidX Core 1.18.0 | Signature-only protection for non-exported dynamic receivers | No user prompt; only same-signature apps can hold it | No user data category | Keep, platform security permission |

## Required interaction rules

- No background location permission or service.
- No location request during first launch or onboarding.
- No poster receives live teen location or residential coordinates.
- System Photo Picker is preferred over broad media access; no READ_MEDIA permission is declared.
- Lock-screen notification copy must omit addresses, housing status, incident detail, private messages, and precise location.
- Camera remains prohibited for disabled identity-document flows.
`);

write('docs/legal/MORT_CHILD_SAFETY_STANDARDS.md', `
# MORT Child Safety Standards

${status}

MORT has zero tolerance for CSAM, CSAE, grooming, sexual solicitation, sextortion, trafficking, romantic or sexual adult-minor interactions, sexual jobs or services, requests for sexual images, attempts to move sexual conversations off-platform, threats involving private images, and evasion after blocking.

These standards apply to profiles, jobs, applications, job-contextual messages, reviews, proofs, reports, portfolios, and organization content. Users receive in-app report and block controls where applicable. Messaging requires an eligible shared job context and server checks for blocks, restrictions, pilot eligibility, and role rules. MORT has no anonymous chat, random chat, searchable minor directory, or unrestricted unsolicited adult messaging.

Moderation may block content, remove jobs, restrict accounts, preserve minimal access-controlled evidence, and escalate to trained authorized adults or lawful authorities. A minor tester must never review sexual-safety evidence. Suspected CSAM must not be downloaded, forwarded, emailed, or placed in normal tickets or group chat.

The public version is generated at \`web/public/child-safety-standards/index.html\`. Before deployment, an authorized adult child-safety point of contact and monitored address must replace the marked placeholder.

Official Google policy references:
- https://support.google.com/googleplay/android-developer/answer/9878809
- https://support.google.com/googleplay/android-developer/answer/14747720
`);

write('docs/operations/MORT_CHILD_SAFETY_CONTACT_PROCESS.md', `
# MORT Child-Safety Contact Process

${status}

## Required adult owner

The designated contact must be an authorized adult trained to discuss MORT's CSAE prevention, moderation, evidence boundaries, escalation, and enforcement. The contact name and monitored address are manual release blockers and must be entered in Play Console and the public standards page before submission.

## Intake

1. Use restricted case tooling, not group chat or ordinary email attachments.
2. Record source, reporter, affected account/job/message identifiers, timestamp, immediate-danger indicator, and whether content may be CSAM.
3. Acknowledge non-emergency intake without promising an outcome or response time that staffing cannot meet.
4. Restrict the involved accounts/contact when the risk threshold is met.
5. Route sexual-safety evidence only to trained adults; no minor reviewer access.
6. Preserve lawful metadata and system records. Never ask a child to resend sexual material.

MORT is not an emergency service. Immediate danger requires local emergency services. Private case material and credentials never enter Play reviewer instructions or tester chat.
`);

write('docs/operations/MORT_CSAM_RESPONSE_AND_ESCALATION.md', `
# MORT CSAM Response and Escalation

${status}

Potential CSAM is a high-severity restricted event. Do not download, duplicate, forward, screenshot, or email suspected material. Stop ordinary review, preserve the minimum identifiers and access logs already held by the system, restrict access, and escalate to the designated trained adult. The adult must follow applicable preservation, reporting, and emergency law with qualified counsel and the appropriate reporting organization or law-enforcement channel. Do not invent a report, promise NCMEC filing, or destroy evidence outside the approved legal process.

Required record: case ID, detection source, system object ID, timestamps, access history, restriction action, legal/reporting decision owner, report reference when lawfully made, retention/hold authority, and closure review. Raw material is never copied into the case narrative.
`);

write('docs/operations/MORT_CSAE_ENFORCEMENT_STANDARD.md', `
# MORT CSAE Enforcement Standard

${status}

Prohibited conduct includes grooming, sexual solicitation, sextortion, trafficking, sexual adult-minor contact, sexual jobs, requests for sexual images, threats involving private images, block evasion, and moving sexual conversations off-platform. Credible signals may cause immediate message blocking, job removal, contact prevention, account restriction, restricted evidence preservation, and trained-adult escalation.

Human review must use least access, conflict checks, no minor reviewers, documented reason codes, and an appeal path that does not expose reporters or illegal content. Safety restrictions need not wait for a criminal finding. A cleared false positive should restore access and record the correction. Automation is triage, not final authority.
`);

write('docs/operations/MORT_MISSING_MINOR_ESCALATION.md', `
# MORT Missing-Minor Escalation

${status}

MORT does not provide tracking or emergency response. A report that a minor is missing or in immediate danger must be routed to a trained adult immediately. Tell the reporter to contact local emergency services; do not delay that step while investigating MORT records. Preserve only relevant account, job, message, timestamp, and authorized location-release records under restricted access. Do not broadcast a teen's address or live location to posters, testers, group chat, or unassigned staff. Any lawful disclosure requires documented authority, scope, recipient, and audit trail.
`);

write('docs/play/MORT_UGC_RELEASE_AUDIT.md', `
# MORT UGC Release Audit

${status}

| Surface | Terms/rules | Report/block | Moderation/enforcement | Retention/deletion | Rate/abuse control |
|---|---|---|---|---|---|
| Profiles | Legal acceptance and prohibited-content rules | User report and block | Admin restriction, appeal | Ordinary profile deletion; safety records separate | Profile/server write controls |
| Jobs | Poster rules, legal acceptance, prohibited work | Job and poster report/block | Scanner, removal, pilot eligibility | Account/job policy and preserved dispute evidence | Job creation rate limit |
| Applications | Job-context rules | Participant/user report/block | Status gating and guardian/adult review | Account deletion plus transaction retention | Application rate limit |
| Direct messages | Job-context safety rules | Message report and user block | Scanner, blocked-message evidence, restrictions | Participant content plus bounded safety retention | Send rate limit and spam scanning |
| Reviews | Accuracy/non-retaliation rules | User/report path | Admin moderation and appeal | Account/content policy | Eligibility and one-review constraints |
| Proof uploads | Minimal authorized proof only | Application/report path | Private storage and assigned access | Storage retention/deletion process | Type/size/path checks |
| Reports | Truthful private reporting | N/A; reporter protected | Restricted moderation queue | Safety/legal retention | Report rate limit |
| Portfolio | Rights/privacy/prohibited content | User report/block | Moderation and removal | User deletion except holds | Upload limits |
| Organization content | Authorized business information | Organization/user report | Partner/admin review | Contract/safety retention | Role and permission checks |

Before a first message, the server must confirm a shared eligible job/application context, both accounts' restrictions, block state, age/pilot policy, and messaging role authorization. Anonymous/random chat and global minor messaging are prohibited.
`);

write('docs/play/MORT_PLAY_DATA_SAFETY_WORKBOOK.md', `
# MORT Google Play Data Safety Workbook

${status}

This is a source-and-backend inventory, not a Play Console submission. The adult account owner must reconcile it against the exact uploaded AAB and current Google form. Data stored in Supabase is still collected because it leaves the device. HTTPS is enforced. Service-provider processing is not marked as third-party sharing here, subject to contract/legal confirmation.

## Proposed high-level answers for this closed-test build

- App collects user data: **Yes**.
- Data encrypted in transit: **Yes**, HTTPS-only client and network security configuration.
- Users can request deletion: **Yes**, in-app reauthenticated request and public email-link flow.
- Data shared for advertising: **No in this build**; AdMob is disabled and ad identifier permissions are removed.
- Payments/purchases: **No in this build**; IAP and billing permission are disabled. Payment preference records are not card/payment processing.
- Real identity documents/biometrics: **Not collected**; provider verification and document collection are disabled.
- Third-party SDKs bundled but disabled: RevenueCat and Google Mobile Ads code require detection review in Play SDK Index and the final AAB. Their runtime initialization is disabled; this statement must be revisited if the artifacts show otherwise.

Use the companion collection, SDK, and retention CSVs as the item-by-item entry worksheet. Do not submit until a real public privacy URL, adult publisher identity, support contact, and exact AAB SDK scan are complete.

Official form guidance: https://support.google.com/googleplay/android-developer/answer/10787469
`);

const collectionRows = [
  ['Data type','Collected','Shared','Purpose','Required','Encrypted in transit','Deletion','Retention','SDK/service','User disclosure','Source evidence'],
  ['Name/display name','Yes','No','Account/profile and job context','Required after onboarding','Yes','Ordinary profile deletion','Account life plus approved holds','Supabase','Privacy policy/profile UI','profiles.display_name; profile_repository.dart'],
  ['Email','Yes','No','Authentication, recovery, deletion verification','Required','Yes','Auth deletion process','Auth/security retention','Supabase Auth','Auth and privacy policy','Supabase Auth; auth_repository.dart'],
  ['Phone','Optional','No','Closed-pilot/contact trust when enabled','Optional','Yes','Account deletion review','Security/pilot policy','Supabase','Privacy and profile disclosure','auth users / pilot eligibility'],
  ['Date of birth and age band','Yes','No','13+ gate and role eligibility','Required for onboarding','Yes','Ordinary profile deletion subject to holds','Eligibility/audit policy','Supabase Postgres','Age gate and privacy policy','profiles.dob; enforce_profile_completion'],
  ['User IDs','Yes','No','Authorization, ownership, audit','Required','Yes','Pseudonymized/deleted by process','Security/legal records may remain','Supabase','Privacy policy','Auth UUID and FK schema'],
  ['Approximate location','Optional','No','Nearby area and job matching','Optional','Yes','Account/job deletion rules','Job/interaction retention','geolocator, geocoding, Supabase','Contextual permission/privacy policy','location services and jobs'],
  ['Precise temporary location','Optional','No','User-invoked foreground feature only','Optional','Yes','Deletion and bounded workflow','No background tracking; approved record only','geolocator, Supabase when submitted','Runtime permission and privacy policy','Android manifest; location service'],
  ['Messages','Yes','No','Job-context communication and safety','Optional to use messaging','Yes','Account deletion subject to safety holds','Safety/dispute retention','Supabase','Messaging rules/privacy policy','messages table; messaging_repository.dart'],
  ['Photos/files','Optional','No','Proof, avatar, portfolio where enabled','Optional','Yes','Storage deletion subject to holds','Category-specific','image_picker, Supabase Storage','Picker disclosure/privacy policy','uploads_repository.dart; storage policies'],
  ['Job/application activity','Yes','No','Marketplace workflow and closed-pilot QA','Core feature','Yes','Account/job deletion rules','Contract/dispute/safety retention','Supabase','Terms/privacy','jobs/applications schema'],
  ['App interactions','Yes','No','Rate limiting, audit, feature operations','Core service','Yes','Policy-based','Security/abuse windows','Supabase','Privacy policy','rate_limit_events and audit tables'],
  ['Diagnostics','Limited','No','Startup/network error handling and server logs','Operational','Yes','Policy-based','Infrastructure log window','Flutter/Supabase','Privacy policy','no crash analytics SDK configured'],
  ['Device identifiers','Limited','No','Session security/device context where provided','Operational','Yes','Account/security process','Security retention','device_info_plus, Supabase Auth','Privacy policy','device info service; no ad ID permission'],
  ['Safety reports','Yes','No','Abuse response and enforcement','Optional','Yes','May be retained after account deletion','Safety/legal hold','Supabase','Report flow/privacy policy','reports and restricted evidence tables'],
  ['Support communications','Optional','No','Resolve user requests','Optional','Yes','Deletion request subject to support retention','Support/safety policy','Supabase','Support/privacy','support_tickets/messages'],
  ['Payment preference','Optional','No','Record off-platform preference only','Optional','Yes','Account/job deletion rules','Work/dispute record','Supabase','Terms/payment UI','profiles.payment_preference; no processing'],
  ['Earnings/work records','Optional','No','Work completion and user records','Feature dependent','Yes','Account deletion subject to lawful retention','Contract/dispute policy','Supabase','Terms/privacy','job contracts/obligations'],
  ['Organization affiliation','Optional','No','Closed-pilot eligibility and role scope','Pilot dependent','Yes','Account/pilot deletion process','Pilot/audit retention','Supabase','Pilot disclosure','partner memberships/enrollments'],
];
write('docs/play/MORT_PLAY_DATA_COLLECTION_INVENTORY.csv', collectionRows.map((row) => row.map((cell) => `"${cell.replaceAll('"', '""')}"`).join(',')).join('\n'));

const sdkRows = [
  ['SDK/package','Bundled','Initialized in closed test','Data behavior in current build','Permission impact','Review action','Evidence'],
  ['supabase_flutter / Supabase','Yes','Yes','Auth and declared app data sent to hosted project','INTERNET, network state','Declare all backend collection','pubspec.lock; SupabaseService'],
  ['flutter_secure_storage','Yes','Yes','Stores session/security values on device','None','No off-device collection by itself','pubspec.lock'],
  ['local_auth','Yes','On user opt-in/action','On-device biometric result; no biometric template sent to MORT','USE_BIOMETRIC, USE_FINGERPRINT','Disclose as device authentication, not identity proof','pubspec.lock; device_authentication_service.dart'],
  ['image_picker','Yes','On user action','Selected/captured media sent only after user submits','CAMERA','Declare photos/files','pubspec.lock; uploads_repository.dart'],
  ['geolocator / geocoding','Yes','On user action','Foreground location/area only','COARSE, FINE','Declare optional location; verify geocoding provider terms','pubspec.lock; location service'],
  ['flutter_local_notifications','Yes','Contextual','Local notification display; no FCM SDK detected','POST_NOTIFICATIONS, VIBRATE','Sensitive preview QA','pubspec.lock'],
  ['purchases_flutter / RevenueCat','Yes','No (IAP_ENABLED=false)','No intended runtime purchase collection; native code remains bundled','BILLING removed','Check final AAB/Play SDK declaration; do not enable','AppConfig and RevenueCatService guard'],
  ['google_mobile_ads','Yes','No (ADS_ENABLED=false)','No intended ad request; native code remains bundled','AD_ID/AdServices removed; WAKE_LOCK removed','Check final AAB/Play SDK declaration; do not enable','AppConfig and manifest remove rules'],
  ['device_info_plus / package_info_plus','Yes','Feature dependent','Local device/app metadata; only declared server submission counts','None','Verify no analytics submission','pubspec.lock/source'],
  ['cached_network_image','Yes','On approved image display','Fetches approved HTTPS media','INTERNET','Ensure signed/private URLs and cache policy','pubspec.lock'],
  ['FCM/Firebase Messaging','No Flutter dependency detected','No','No Flutter FCM collection claimed','None','Reaudit if added','pubspec.lock'],
];
write('docs/play/MORT_PLAY_SDK_DATA_INVENTORY.csv', sdkRows.map((row) => row.map((cell) => `"${cell.replaceAll('"', '""')}"`).join(',')).join('\n'));

const retentionRows = [
  ['Category','Ordinary retention','Deletion treatment','Possible retained subset','Authority/review'],
  ['Auth/profile','Account life','Remove/anonymize after verified request','Security/audit linkage where required','Account deletion SOP'],
  ['Jobs/applications/contracts','Workflow plus dispute window','Delete/deidentify where no obligation remains','Contract, wage, dispute, fraud evidence','Legal and labor review required'],
  ['Messages','Job context and safety window','Delete ordinary content where allowed','Reported/threat evidence under bounded hold','Safety/legal review'],
  ['Photos/proofs','Workflow-specific','Delete storage objects when no hold','Dispute/safety evidence only','Storage retention job required'],
  ['Reports/incidents','Case life','Not automatically erased with ordinary profile','Minimal evidence, decisions, lawful reports','Restricted trained-adult process'],
  ['Location','Shortest approved workflow window','Delete with associated job/account where allowed','Authorized incident or legal hold only','No background history'],
  ['Rate/security logs','Abuse/security window','Age out by security schedule','Active incident/legal hold','Security owner'],
  ['Support','Ticket life plus review window','Delete ordinary ticket data where allowed','Safety/legal request evidence','Support/privacy owner'],
  ['Account deletion requests','Audit life','Retain request/status record after completion','Fingerprint, timestamps, retention summary','Service-role process'],
];
write('docs/play/MORT_PLAY_DATA_RETENTION_MATRIX.csv', retentionRows.map((row) => row.map((cell) => `"${cell.replaceAll('"', '""')}"`).join(',')).join('\n'));

write('docs/play/MORT_PLAY_REVIEW_ACCESS_INSTRUCTIONS.md', `
# MORT Play Review Access Instructions

${status}

## Secure credential fields for Play Console only

- Reviewer username: [LOAD FROM PROTECTED MORT PLAY REVIEW CREDENTIAL STORE]
- Reviewer password: [LOAD FROM PROTECTED MORT PLAY REVIEW CREDENTIAL STORE]

Credentials are intentionally excluded from source, Git, ZIPs, logs, screenshots, and this document. They must be entered only in Play Console App access by an authorized release manager.

## Reviewer steps

1. Install the closed-test build and open MORT.
2. Sign in with the synthetic reviewer credential supplied in Play Console.
3. Confirm the app presents itself as MORT without test-track branding.
4. Review the synthetic profile, test jobs, applications, job-context messages, report/block controls, Safety Center, payment-preference-only copy, and Settings → Account → Delete account.
5. Use only records labelled Play Review or synthetic. No real minor, address, identity document, incident, or production participant is present.

## Deliberately disabled

Public marketplace access, unrestricted adult participation, real identity-document verification, real ID uploads, payments, escrow, subscriptions, paid boosts, AdMob, and background location are disabled. These are policy controls, not review defects. Reviewer fixtures remain test-account isolated and do not bypass blocks, RLS, age rules, or messaging context.

Support contact: [ADULT REVIEW SUPPORT EMAIL - REQUIRED IN PLAY CONSOLE]. No QR code or secondary factor is currently required; update these instructions if that changes.
`);

write('docs/play/MORT_PLAY_STORE_LISTING.md', `
# MORT Play Store Listing

${status}

- App name: **MORT - Teen Jobs & Local Help**
- Package: \`com.mortapp.mobile\`
- Release track: closed test
- Category recommendation: Business (not Social or Dating); Play review controls the final classification.
- Contact, website, privacy, child-safety, and deletion URLs: manual placeholders must be replaced with deployed HTTPS URLs.

Do not claim guaranteed safety or payment, verified/background-checked users, insurance, emergency response, legal approval, public availability, or worldwide support. Screenshots must use synthetic Play Review fixtures only.
`);

write('docs/play/MORT_PLAY_SHORT_DESCRIPTION.txt', `Safer local work tools for teens, adults, and guardians.`);

write('docs/play/MORT_PLAY_FULL_DESCRIPTION.txt', `
MORT helps eligible teenagers age 13 and older explore local work, build experience, and coordinate with job posters and organizations.

MORT tools include role-based onboarding, a job feed, applications, optional Guardian Mode, job-context messaging, reporting and blocking, proof workflows, payment-preference records, and safety controls.

Job availability and marketplace actions depend on account, role, and server-verified eligibility. Identity verification is not currently available. MORT does not process or escrow real-world job payments, guarantee jobs or payment, provide insurance, background-check every adult, guarantee safety, or provide emergency response.

Guardian Mode is optional. Messaging is not anonymous or random; it is restricted to eligible job context and server safety checks. Users can report and block profiles, jobs, and messages through supported in-app controls.

In immediate danger, leave the situation and contact local emergency services. MORT is not an emergency service.
`);

write('docs/play/MORT_PLAY_RELEASE_NOTES.txt', `
MORT 0.9.0

- Adds release-signed Android packaging.
- Keeps marketplace actions subject to account eligibility and identity verification availability.
- Adds reauthenticated in-app account deletion requests and external deletion support.
- Includes synthetic reviewer access, report/block controls, contextual location permissions, and safety disclosures.
- MORT does not process or escrow real-world job payments.
`);

write('docs/play/MORT_PLAY_CONTENT_RATING_WORKBOOK.md', `
# MORT Play Content Rating Workbook

${status}

Proposed answers require final Play Console review:

- User-generated content: yes (profiles, jobs, applications, messages, reviews, proofs).
- User-to-user communication: yes, job-contextual and eligibility gated; not anonymous/random chat.
- Location sharing: limited job location/area at authorized workflow stages; no public/live teen location.
- Purchases/ads/gambling: no in first closed test.
- Sexual content, dating, romantic matching: prohibited and not a feature.
- Violence, drugs, weapons, profanity: prohibited job/content categories; reports may reference harmful conduct privately.
- Personal information exchange: constrained by job context, safety reminders, age/pilot rules, and optional Guardian Mode; this requires a careful Families/social-feature policy review because ages 13-15 are in target audience.

Do not answer solely from this draft. Run the questionnaire against the exact app and all reachable UGC.
`);

write('docs/play/MORT_PLAY_TARGET_AUDIENCE_WORKBOOK.md', `
# MORT Play Target Audience Workbook

${status}

Select only age groups 13-15, 16-17, and 18+. Do not select under-13 groups. MORT server onboarding rejects age below 13 and enforces teen 13-17 versus adult/guardian/admin 18+ roles.

MORT is not a dating, anonymous chat, random chat, or child-directed entertainment product. It has job-contextual social features involving teens and adults, so the adult account owner must complete Google Play Families/Target Audience review accurately, including safety reminders and any required adult action before minors exchange personal information. Guardian Mode is optional and must not be misrepresented as universal legal consent.

Publicly displayed minor information excludes exact date of birth, exact age, school, housing status, residential address, private messages, and live precise location. Public minor directories and unrestricted unsolicited adult messaging are prohibited.
`);

write('docs/play/MORT_PLAY_APP_ACCESS_WORKBOOK.md', `
# MORT Play App Access Workbook

${status}

- Restricted access: yes; authentication required for core workflows.
- Review credentials: stored outside repository and entered manually in Play Console.
- Account type: synthetic test account with \`is_test_account=true\`.
- Data isolation: RLS prevents test accounts from reading ordinary production participant records; review jobs are marked test/synthetic.
- Login: email/password on first screen; no QR or MFA unless Play Console instructions are updated.
- Disabled features: public marketplace, real ID, payments, ads, IAP, escrow, background location.
- Account deletion: Settings → Account → Delete account; enter current password and type DELETE.
- External deletion: deployed \`/account-deletion/\` URL using email magic-link ownership verification.
`);

write('docs/play/MORT_PLAY_POLICY_DECLARATION_CHECKLIST.md', `
# MORT Play Policy Declaration Checklist

${status}

- [ ] Adult account owner identity, payment profile, phone, email, and Android-device verification complete.
- [ ] App category and target audience accurately selected; no under-13 group.
- [ ] Content rating reflects UGC, job-context communication, and location.
- [ ] Data Safety matches the exact signed AAB and backend.
- [ ] Public HTTPS privacy policy, child-safety standards, support, and account-deletion URLs deployed and tested.
- [ ] Authorized adult publisher/contact placeholders replaced.
- [ ] Child-safety point of contact designated in Play Console.
- [ ] In-app reporting and blocking tested with reviewer fixture.
- [ ] App access credentials entered in Play Console only.
- [ ] Ads declaration says disabled/no ads for this artifact; no ad identifier permissions.
- [ ] Billing/financial declaration reflects no processing, escrow, subscriptions, or paid features.
- [ ] Location declaration is foreground only; no background permission.
- [ ] News, health, government, financial, dating, and social-category declarations answered accurately.
- [ ] Play App Signing enrolled and upload certificate fingerprints matched.
- [ ] Version code confirmed greater than every prior Play upload.
- [ ] Pre-launch report reviewed; severe findings resolved or release blocked.
- [ ] 12-testers/14-continuous-days requirement confirmed for this account in Play Console.
`);

write('docs/play/MORT_STORE_ASSET_MANIFEST.md', `
# MORT Play Store Asset Manifest

${status}

| Asset | Required target | Status / rule |
|---|---|---|
| Play icon | 512×512 PNG, no transparency rules violated | Existing source icon must be exported and visually inspected |
| Feature graphic | 1024×500 JPG/PNG | Not yet approved; create with MORT public-product positioning |
| Phone screenshots | At least 2, recommended polished set | Capture only synthetic Play Review data on physical/emulated approved devices |
| Tablet screenshots | Only if tablet support is claimed | Do not claim until tablet QA passes |
| App name/descriptions | Docs in this package | Draft complete, adult review required |
| Support email | Monitored adult-owned address | Manual blocker |
| Website/privacy/safety/deletion URLs | Deployed HTTPS pages | Manual Netlify/domain blocker |

Never show real names, faces, addresses, school names, messages, credentials, incident data, moderation evidence, or false verification badges. Each screenshot should visibly use synthetic jobs/general locations and should not imply a public launch.
`);

write('docs/security/MORT_ANDROID_RELEASE_THREAT_REVIEW.md', `
# MORT Android Release Threat Review

${status}

## Verified source controls

- HTTPS-only Android network policy; cleartext disabled.
- Hosted Supabase project fixed to \`rakjydmgwwgtdislanbt\` by release scripts.
- No service-role, database password, Supabase access token, provider secret, or signing password is passed as a Dart define.
- Secure session storage uses \`flutter_secure_storage\`; Supabase owns refresh/session handling.
- Release signing fails closed and is checked against the upload certificate.
- Public marketplace, identity-document verification, IAP, and ads are false compile-time flags.
- Custom \`mort://app\` deep link is routed through authenticated app state; universal HTTPS links are not claimed.
- Cleartext, localhost, private development IPs, verbose content logging, message crash logging, and coordinate analytics are prohibited.

## Residual threats and gates

- A compiled public Supabase anon key is expected and not privileged; RLS remains the security boundary.
- RevenueCat and Google Mobile Ads native code remains bundled while disabled. The final AAB/Play SDK scan must be reviewed for transitive behavior and policy declarations.
- Obfuscation symbols must be retained outside the repo for every uploaded version.
- Physical process-death, secure-storage, biometric, notification-preview, photo-picker, deep-link, and offline tests remain required.
- Play Console version history, pre-launch report, SDK warnings, and signing enrollment are external manual checks.
- External legal pages need real adult publisher/contact values and an HTTPS deployment.
`);

write('docs/play/MORT_14_DAY_CLOSED_TEST_PLAN.md', `
# MORT 14-Day Closed-Test Plan

${status}

Recruit 24 adults/eligible participants to preserve coverage and attrition margin. Maintain at least 12 continuously opted-in testers for 14 consecutive days if Play Console applies the new-personal-account rule. The Console's displayed requirement controls. Testers receive no Console access and no private safety evidence.

Target coverage: Android 10-16 where available; Samsung, Pixel, Motorola, low-memory/budget, small and large screens; Wi-Fi, cellular, slow network, and offline recovery. No tester needs every device.

| Day | Focus | Evidence |
|---|---|---|
| 1 | Play install, launch, sign-in, production identity, consent | Device/version/install notes |
| 2 | Registration, under-13 denial, password reset, role onboarding | Age and auth outcomes |
| 3 | Job feed, manual area, denied/approximate/precise location | Permission screenshots without addresses |
| 4 | Synthetic posting/application and Guardian Mode paths | Workflow IDs only |
| 5 | Job-context messages, scanner, report, block | Sanitized results |
| 6 | Start/completion handshake and proof picker/camera | Synthetic media only |
| 7 | Payment-preference and nonpayment workflow; no processing | Copy and state checks |
| 8 | Safety Ping, notification permission and private previews | No incident/location detail on lock screen |
| 9 | Biometrics, app lock, background/foreground, process death | Recovery behavior |
| 10 | Deep links, expired session, logout/revocation, offline retry | Auth/navigation evidence |
| 11 | Accessibility, screen reader, large text, dark mode, rotation | Accessibility defects |
| 12 | Low battery/memory, slow cellular, image upload recovery | Performance notes |
| 13 | Account deletion in-app and external web flow | Request/status only, synthetic accounts |
| 14 | Update from prior test build, regression, final survey | Version transition and feedback summary |

Release blockers include startup/login failure, unavailable report/block/deletion, under-13 onboarding, marketplace/ID enablement, cross-user exposure, live teen location exposure, debug signing, policy URL mismatch, secret detection, and fatal plugin errors.
`);

write('docs/play/MORT_TESTER_ONBOARDING.md', `
# MORT Closed-Test Tester Onboarding

${status}

1. Join only through the Play opt-in URL using the invited Google account and remain opted in continuously for the requested 14 days.
2. Install and update through Google Play, not a shared APK, for the formal closed-test evidence.
3. Use only supplied synthetic accounts/data. Do not enter a real minor's identity, address, incident, school, government ID, or payment card.
4. Confirm the app presents itself as MORT and truthfully explains unavailable marketplace or identity-verification actions.
5. Report device model, Android version, app version, steps, expected/actual behavior, and a sanitized screenshot when safe.
6. Never capture credentials, private messages, addresses, or safety cases. Send urgent real-world danger to emergency services, not the tester group.
7. Testers do not get Play Console, Supabase, moderation, or key access.
`);

write('docs/play/MORT_DAILY_TEST_SCENARIOS.md', `
# MORT Daily Closed-Test Scenarios

${status}

Run the scenario matching the 14-day plan, then a five-minute daily smoke: cold launch, sign in, open synthetic feed, open one job, navigate to Safety Center, verify report/block entry points, background/foreground, and sign out. Each day record device/OS/app version, network, permission state, pass/fail, defect ID, severity, and whether the tester remained opted in. Never manufacture a pass or reuse evidence from another device.

Permission variants must include deny, permanent deny, approximate, and manual fallback. Auth variants include expired session, wrong password, reset, revoked session, and offline recovery. UGC variants include clean, spam, unsafe, blocked-user, and no-job-context messaging. Account deletion uses disposable synthetic accounts only.
`);

write('docs/play/MORT_TESTER_FEEDBACK_FORM.md', `
# MORT Closed-Test Feedback Form

${status}

- Tester code (no full legal name):
- Date/time and timezone:
- Device brand/model and Android version:
- MORT version/build:
- Installed/updated through Play: yes/no
- Network and permission state:
- Scenario:
- Expected result:
- Actual result:
- Reproduction steps:
- Frequency: once/intermittent/always
- Severity: critical/high/medium/low
- Accessibility impact:
- Privacy/safety impact:
- Sanitized screenshot/video available: yes/no
- Did any real personal, location, message, credential, or incident data enter the report: yes/no (if yes, stop and alert the adult test lead privately)
- One thing that felt clear:
- One thing that felt confusing:
- Suggested improvement:
`);

write('docs/play/MORT_PRODUCTION_ACCESS_ANSWERS_DRAFT.md', `
# MORT Production-Access Answers Draft

${status}

Do not submit this before the 14-day test ends; replace bracketed evidence with actual results.

## About the closed test

We recruited [COUNT] testers from [NON-SENSITIVE SOURCES]. At least [COUNT] remained continuously opted in for [DAYS] days. Testers used authentication, age gating, synthetic job/app workflows, job-context messaging, reporting/blocking, permission denial paths, account deletion, accessibility, and update behavior across [DEVICE SUMMARY]. Feedback was collected through Play private feedback and the structured MORT form. Main themes were [ACTUAL THEMES].

## About the app

MORT is intended for eligible users 13+ in a controlled local-work pilot, including teens, adult job posters, and optional guardians. It provides job-context coordination and safety controls; it does not guarantee safety/payment or provide public marketplace access in this build. Expected first-year production installs must be selected honestly from the Console ranges after pilot evidence exists.

## Readiness changes

Based on test evidence, we changed [ACTUAL CHANGES AND VERSION CODES]. We will not claim unrestricted production readiness while public verification, legal/safety staffing, insurance, physical-device closure, and operational approvals remain incomplete. Production access from Google would not itself authorize public marketplace activation.
`);

write('docs/play/MORT_PLAY_ACCOUNT_OWNER_RESPONSIBILITIES.md', `
# MORT Play Account Owner Responsibilities

${status}

The founder's adult father remains the legal Play account owner, uses his own Google account and identity, accepts owner agreements, verifies contact/payment/device requirements, and remains accountable for submissions. He must enable two-step verification, configure recovery methods, store backup codes offline, review activity, approve high-risk access, and never share his password. Government ID, payment details, recovery codes, and personal documents never enter this repository.

The founder is invited through Users and permissions with a separate account and least privilege. Testers receive no Console access. Only approved release managers upload verified bundles; only the owner handles owner-only agreements and account recovery.
`);

write('docs/play/MORT_PLAY_USER_PERMISSION_MATRIX.md', `
# MORT Play Console User Permission Matrix

${status}

| Role | Account/admin | Release upload | Store listing/policy | Financial | Users/permissions |
|---|---|---|---|---|---|
| Adult account owner | Full owner duties | Approve/perform | Approve | Owner-only minimum | Invite/remove and audit |
| Founder/developer | No owner transfer | Closed-test release only if needed | Draft/edit if granted | None | None |
| Release manager | No account settings | Upload/promote assigned app tracks | View required declarations | None | None |
| Policy/safety reviewer | No account settings | None | View/edit assigned declarations | None | None |
| Tester | No Console access | None | None | None | None |

Review quarterly and remove dormant access immediately. Use separate accounts and two-step verification; never share owner credentials.
`);

write('docs/play/MORT_PLAY_ACCOUNT_RECOVERY_PLAN.md', `
# MORT Play Account Recovery Plan

${status}

The adult owner maintains two-step verification, at least two recovery methods, offline backup codes, a current recovery email/phone, and a verified Android device. Backup codes and identity/payment documents stay outside the repo. Test recovery quarterly without disabling protections. If compromised, revoke sessions, change credentials from a trusted device, review Play activity/users/releases, remove unknown access, contact Google support, and suspend uploads. Upload-key compromise follows the separate key recovery plan.
`);

write('docs/ios/MORT_IOS_RELEASE_BLOCKERS.md', `
# MORT iOS Release Blockers

${status}

Flutter iOS source remains aligned, but Windows cannot perform the required Xcode archive, signing, entitlement, privacy-manifest, or physical-iPhone validation. No iPhone test, TestFlight upload, App Store review, Apple payment review, APNs validation, or production camera/photo behavior is claimed. Apple Developer membership, adult account ownership, Mac/Xcode build, signed archive, real-device privacy/permission tests, and legal/store review remain blockers. Android closed testing must not be represented as iOS validation.
`);

write('docs/ios/MORT_APPLE_ACCOUNT_OWNER_PLAN.md', `
# MORT Apple Account Owner Plan

${status}

When funding is available, an authorized adult creates/owns the Apple Developer account with their own identity, agreements, payment, recovery, and two-factor authentication. The founder receives a separately invited least-privilege account. No password, government ID, payment detail, certificate private key, or recovery code enters the repository. Do not purchase membership as part of this pass.
`);

write('docs/ios/MORT_TESTFLIGHT_READINESS_CHECKLIST.md', `
# MORT TestFlight Readiness Checklist

${status}

- [ ] Adult Apple account and paid membership available.
- [ ] Mac with supported Xcode and Flutter versions.
- [ ] Bundle ID \`com.mortapp.mobile\` registered and signing configured.
- [ ] Privacy manifest/required-reason APIs and entitlements audited.
- [ ] APNs and notification permissions tested on a real iPhone.
- [ ] Camera, Photo Picker, location, biometrics, deep links, secure storage, and process death tested on real devices.
- [ ] IAP/AdMob remain disabled unless separately reviewed and configured.
- [ ] App Store privacy, age rating, child safety, support, and deletion URLs completed.
- [ ] Archive, symbol upload, TestFlight review, and tester feedback pass.
`);

write('docs/play/MORT_GOOGLE_PLAY_MANUAL_STEPS.md', `
# MORT Google Play Console Manual Steps

${status}

1. Adult father creates/verifies the personal developer account and enables two-step verification without sharing credentials.
2. Create app **MORT - Teen Jobs & Local Help**, default language English (US), app, free, with package \`com.mortapp.mobile\`.
3. Invite founder/release manager with least privilege.
4. Complete app setup, target audience (13-15, 16-17, 18+ only), content rating, Data Safety, child-safety contact, ads=no, and app-access credentials.
5. Deploy public pages over HTTPS; replace adult publisher/contact placeholders; enter exact privacy, child-safety, support, website, and deletion URLs.
6. Enroll in Play App Signing and compare upload certificate SHA-1/SHA-256.
7. Confirm no existing Play artifact has versionCode 90 or higher.
8. Upload \`mort-play-closed-test.aab\` to internal test first, review automated checks/SDK warnings/pre-launch report, then promote the same verified candidate to closed test if clean.
9. Create a closed-testing email/Google Group list, publish opt-in link, and maintain at least 12 continuously opted-in testers for 14 days if required by the Console.
10. Record actual feedback, fixes, versions, crashes, ANRs, accessibility and policy issues. Apply for production access only after the Console requirement and evidence are complete.

Google's current new-personal-account guidance: https://support.google.com/googleplay/android-developer/answer/14151465
`);

process.stdout.write('Built MORT Google Play policy, safety, listing, and operations documents.\n');
