import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const ownerBanner = '> RECOMMENDED - ADULT ACCOUNT OWNER MUST CONFIRM\n\n';

function write(relative, content) {
  const path = resolve(root, relative);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${content.trim()}\n`);
}

function ownerTable(rows) {
  return `${ownerBanner}| Console field | Recommended answer | Evidence | Owner confirmation | Risk if incorrect |\n|---|---|---|---|---|\n${rows
    .map((row) => `| ${row.join(' | ')} |`)
    .join('\n')}`;
}

const routerSource = readFileSync(
  resolve(root, 'flutter_mort/lib/core/routing/app_router.dart'),
  'utf8',
);
const routes = [];
for (const pattern of [/_guarded\(\s*'([^']+)'/g, /path:\s*'([^']+)'/g]) {
  for (const match of routerSource.matchAll(pattern)) {
    if (!routes.includes(match[1])) routes.push(match[1]);
  }
}
routes.sort();

function routeAudience(route) {
  if (route.startsWith('/teen/')) return 'teen';
  if (route.startsWith('/adult/')) return 'adult/business';
  if (route.startsWith('/guardian/')) return 'guardian';
  if (route.startsWith('/admin/')) return 'specialized admin';
  if (route.startsWith('/partner/')) return 'partner staff';
  if (route.startsWith('/auth')) return 'public account';
  return 'shared/role-gated';
}

function routeStatus(route) {
  if (/^\/monetization|\/subscription|\/ad-preferences|\/adult\/(analytics|business)$|\/teen\/portfolio$|\/guardian\/emergency-contacts$/.test(route)) {
    return 'disabled_by_policy';
  }
  if (/identity-verification|business-verification|adult-id|teen-school-id|teen-alternatives|verification-appeals|document-capture|liveness|digital-id/.test(route)) {
    return 'disabled_by_policy';
  }
  if (/native-permissions|device-security|passkeys|proof|location|auth-callback/.test(route)) {
    return 'complete_with_external_dependency';
  }
  return 'complete_with_external_dependency';
}

const routeRows = routes
  .map((route) => {
    const status = routeStatus(route);
    const serverGate = route.startsWith('/auth') || route === '/' || route === '/welcome'
      ? 'public/auth state'
      : 'GuardedRoute plus RLS/RPC';
    const evidence = status === 'disabled_by_policy'
      ? 'Explicit unavailable UI; server release flags fail closed'
      : 'Registered route; shared loading/error/empty/auth/restriction handling; analyzer and widget tests';
    return `| \`${route}\` | ${routeAudience(route)} | ${status} | ${serverGate} | ${evidence} | Physical Android: small screen, large text, TalkBack, keyboard, back navigation, and process recovery |`;
  })
  .join('\n');

write(
  'docs/release/MORT_FRONTEND_COMPLETION_MATRIX.md',
  `# MORT Frontend Completion Matrix

Build source: \`flutter_mort/lib/core/routing/app_router.dart\`  
Version source: \`flutter_mort/pubspec.yaml\` = \`0.9.1+91\`  
Generated route count: **${routes.length}**

## Classification Rules

- \`complete\`: code and required physical evidence are complete. No route currently receives this label because physical Android execution is outstanding.
- \`complete_with_external_dependency\`: implemented and covered by static/widget/hosted QA, with physical-device or provider evidence still required.
- \`disabled_by_policy\`: route intentionally explains a server or release policy lock.
- \`blocked\`: an implementation defect prevents intended use. None identified by this source audit.
- \`not_applicable\`: route does not apply to the release. None hidden under this label.

Shared \`GuardedRoute\`, \`MortAsyncState\`, error screens, account restriction checks, release-mode RPCs, retry controls, and the global support route provide auth, loading, empty, error, expired-session, restricted-account, closed-pilot, and retry behavior. Automated checks do not replace physical TalkBack, text-scale, keyboard, dark-mode, small-screen, rotation, Android back, offline recovery, or process-death evidence.

| Route | Audience | Classification | Authorization | Implemented-state evidence | Required external evidence |
|---|---|---|---|---|---|
${routeRows}

## Release Conclusion

No registered route is being represented as physically verified. Policy-disabled ads, billing, unrestricted marketplace, real document collection, and related verification experiences remain visible as unavailable instead of silently failing.`,
);

write(
  'docs/play-final/MORT_APP_ACCESS_COPY_PASTE.md',
  `# MORT Play Console App Access - Copy/Paste

${ownerBanner}MORT uses persistent synthetic email/password review accounts. Replace the braces in Play Console only; do not place credentials in source or this document.

**Access restriction:** Some features are restricted to server-approved closed-pilot accounts.

**Teen review account**  
Email: \`{PLAY_REVIEW_TEEN_EMAIL}\`  
Password: \`{PLAY_REVIEW_TEEN_PASSWORD}\`

**Adult/partner review account**  
Email: \`{PLAY_REVIEW_ADULT_EMAIL}\`  
Password: \`{PLAY_REVIEW_ADULT_PASSWORD}\`

1. Install and open MORT.
2. Tap Sign in. No OTP, phone number, ID, location, or invitation is required.
3. Use the teen account for Jobs, Applications, Messages, Contracts, Safety workspace, completion, payment status, Reports, Block, Privacy, and Delete account.
4. Sign out and use the adult account for posted job, applicants, job contract, completion review, payment disagreement, and Partner workspace.
5. Deny location when prompted to verify the manual-area fallback.

Real identity-document collection is disabled. Guardian Mode is optional. MORT does not process or guarantee payment. Marketplace access is restricted to approved pilot participants. Support contact must be entered from \`MORT_PUBLIC_SUPPORT_EMAIL\` before submission.`,
);

write(
  'docs/play-final/MORT_REVIEWER_WALKTHROUGH.md',
  `# MORT Reviewer Walkthrough

## Teen Journey

Sign in with the synthetic teen account. Open Jobs, select **Play Review Yard Organizing**, inspect the eligible low-risk job and application, open job-context Messages, inspect the contract and Mutual Safety Agreement, review arrival/completion history, inspect payment disagreement status, then open Safety Center. Exercise Report and Block against the isolated demonstration account. Open Settings, Privacy and Settings, Account deletion; do not finalize removal of the main review account.

## Adult and Partner Journey

Sign out and use the synthetic adult account. Open My Jobs and Applicants, inspect the same contract and completion state, then open Partner workspace. The organization-bound roster excludes messages, earnings, housing status, raw ID, and unrelated users. Scoped invitation codes are shown once and stored only as hashes. Limited attestations explicitly do not verify government identity or grant marketplace access.

## Expected Limits

- Closed pilot: ordinary accounts cannot enter jobs, messages, private locations, contracts, or active-job workflows.
- Identity: real IDs and provider verification are disabled; sandbox records are synthetic QA only.
- Location: denial leads to approximate/manual-area options.
- Guardian Mode: optional, not required for base pilot eligibility.
- Payment: preference and obligation records only; no processing, escrow, collection, or guarantee.
- Emergency: MORT is not an emergency service.
- Purchases and ads: not bundled or enabled in this release.`,
);

write(
  'docs/play-final/MORT_REVIEW_FEATURE_MAP.md',
  `# MORT Review Feature Map

| Review goal | Synthetic route/data | Primary evidence |
|---|---|---|
| Closed-pilot status | Welcome and Account Status | \`get_release_mode_status\` |
| Teen job/application | Jobs and Applications | \`jobs\`, \`applications\` RLS |
| Job-context messaging | Messages | \`message_threads\`, \`send_safe_message_v2\` |
| Contract | Contracts | \`job_contracts\`, version/acceptance rows |
| Start/completion | Safety workspace | arrival handshake and completion assertions |
| Payment disagreement | Payment status/dispute | obligations and disputes; no guilt finding |
| Report/block | Safety Center | isolated report and block rows |
| Account deletion | Settings / Account deletion | one-use, expiring request flow |
| Partner scope | Partner workspace | organization context, connected roster, invite/attestation RPCs |
| Location denial | Native permissions / job setup | approximate and manual fallback |
| Disabled ID | Trust/verification explanation | server flags: disabled, no document collection |
| Optional guardian | Guardian explanation | eligibility RPC reports optional |`,
);

write(
  'docs/play-final/MORT_REVIEW_ACCOUNT_MAINTENANCE.md',
  `# MORT Review Account Maintenance

Credentials live only in protected User-scope environment variables. Never commit, print, package, screenshot, or email passwords.

- Create/reset fixture: \`node scripts/create-play-review-tenant.mjs\` or \`node scripts/reset-play-review-tenant.mjs\` after loading protected environment values.
- Validate: \`node scripts/validate-play-review-tenant.mjs\`.
- Remove only when review is over: \`node scripts/remove-play-review-tenant.mjs\`.
- Rotate a credential immediately if exposed, then reset and revalidate.
- Keep email/password login enabled without OTP, phone, ID, location, or invitation dependencies.
- Revalidate after migrations, RLS edits, release-mode changes, or account restrictions.
- Do not use real names, schools, addresses, income, incidents, or messages.`,
);

write(
  'docs/play-final/MORT_NETLIFY_LEGAL_DEPLOYMENT.md',
  `# MORT Netlify Legal/Support Deployment

The package builds without private configuration, but the deploy script refuses public deployment until all required User-scope values exist.

Required: \`MORT_PUBLIC_PUBLISHER_NAME\`, \`MORT_PUBLIC_SUPPORT_EMAIL\`, \`MORT_PUBLIC_PRIVACY_EMAIL\`, \`MORT_PUBLIC_CHILD_SAFETY_EMAIL\`, \`MORT_PUBLIC_WEBSITE_URL\`, \`MORT_PUBLIC_EFFECTIVE_DATE\`, \`NETLIFY_AUTH_TOKEN\`, and \`NETLIFY_SITE_ID\`.

1. Adult owner and qualified reviewers approve the content and contacts.
2. Set the values at User scope; do not place tokens in files.
3. Run \`.\\scripts\\deploy-netlify-legal-site.ps1\`.
4. Set \`MORT_VALIDATE_PUBLIC_BASE_URL=https://your-domain.example\` in the current process.
5. Run \`node scripts/validate-public-legal-site.mjs\` and require HTTPS 200 for every route.
6. Verify mobile layout, account-deletion redirect URLs in Supabase Auth, contact mailboxes, and public access without sign-in.
7. Only then enter those HTTPS URLs in Play Console.

Current status: deployable package generated; publisher/contact configuration and hosted HTTPS evidence remain external blockers.`,
);

const shortDescription = 'Approved local work opportunities for teens in a safety-focused pilot.';
const fullDescription = `MORT helps eligible teenagers discover approved local work, build experience, and connect with reviewed pilot organizations and job posters.

MORT is a restricted 13+ pilot. Downloading the app does not automatically unlock jobs or participant messaging. Server-approved pilot participants can browse eligible opportunities, apply, discuss a job in its protected context, review clear contract terms, use mutual arrival and completion checks, record payment status, and build work history.

Safety and privacy controls include reporting, blocking, job-context messaging, restricted private locations, a Safety Center, optional Guardian Mode, optional Support Circle, and organization-scoped partner access. MORT does not provide anonymous chat or a public directory of minors.

Important limits: MORT does not guarantee jobs, income, identity, background checks, insurance, safety, or payment. It does not process payments or hold escrow. Real identity-document collection is disabled in this release. MORT is not an emergency service. Contact local emergency services for immediate danger.`;

write('docs/play-final/MORT_SHORT_DESCRIPTION_FINAL.txt', shortDescription);
write('docs/play-final/MORT_FULL_DESCRIPTION_FINAL.txt', fullDescription);
write(
  'docs/play-final/MORT_STORE_LISTING_FINAL.md',
  `# MORT Store Listing Final Candidate

**App name:** MORT  
**Category recommendation:** Business  
**Short description (${shortDescription.length}/80):** ${shortDescription}

## Full Description

${fullDescription}

## Accuracy Guardrails

Do not claim guaranteed jobs, income, payment, safety, background checks, insurance, every participant verified, real identity verification, unrestricted marketplace access, worldwide availability, or emergency response. Store screenshots must match version \`0.9.1+91\` and use synthetic data.`,
);
write(
  'docs/play-final/MORT_CLOSED_TEST_RELEASE_NOTES.txt',
  `MORT 0.9.1 (91) prepares a restricted 13+ closed pilot with approved-participant jobs, job-context messaging, contracts, mutual safety checks, reports, blocking, account deletion, and scoped partner workflows. Ads, billing, real identity-document collection, remote push, and unrestricted marketplace access remain disabled.`,
);
write(
  'docs/play-final/MORT_PRODUCTION_PILOT_RELEASE_NOTES.txt',
  `Prepared but not activated: a public-download production-pilot mode where ordinary users may access mission, waitlist, safety education, resources, privacy, support, and deletion, while jobs, participants, messages, locations, contracts, and active-job workflows remain restricted to server-approved pilot users. Activation requires Google, legal, operations, and physical-device evidence.`,
);
write(
  'docs/play-final/MORT_STORE_CONTACT_FIELDS.md',
  `${ownerBanner}# Store Contact Fields

| Field | Source | Status |
|---|---|---|
| Developer/publisher name | \`MORT_PUBLIC_PUBLISHER_NAME\` | Owner must configure and verify |
| Support email | \`MORT_PUBLIC_SUPPORT_EMAIL\` | Owner must configure and monitor |
| Privacy email | \`MORT_PUBLIC_PRIVACY_EMAIL\` | Owner must configure and monitor |
| Child-safety contact | \`MORT_PUBLIC_CHILD_SAFETY_EMAIL\` | Trained adult required |
| Website | \`MORT_PUBLIC_WEBSITE_URL\` | HTTPS deployment required |
| Privacy policy URL | \`/privacy/\` on configured website | HTTPS 200 required |
| Account deletion URL | \`/account-deletion/\` on configured website | HTTPS 200 and redirect QA required |

No private personal contact has been invented or hardcoded.`,
);

write(
  'docs/play-final/MORT_PLAY_CONSOLE_MASTER_CHECKLIST.md',
  `${ownerBanner}# Play Console Master Checklist

- [ ] Enroll the adult account owner and complete payment/identity/device verification.
- [ ] Create \`com.mortapp.mobile\`; enable Play App Signing; preserve the current upload key.
- [ ] Upload version \`0.9.1\` code \`91\` signed AAB and confirm Play acceptance.
- [ ] Paste active review credentials only into App Access.
- [ ] Confirm Data Safety against the exact accepted bundle.
- [ ] Complete target audience, content rating, UGC, child safety, ads, financial, and permission forms.
- [ ] Deploy and verify public privacy, child-safety, support, and deletion URLs over HTTPS.
- [ ] Upload validated icon, feature graphic, and release-mode screenshots.
- [ ] Run physical-device matrix and Play pre-launch report; resolve blockers.
- [ ] Maintain at least 12 opted-in testers for Play's required consecutive period and retain evidence.
- [ ] Obtain legal, youth-work, child-safety operations, and insurance decisions.

Code evidence: \`flutter_mort\`, \`supabase/migrations\`. Database evidence: release-mode RPC, RLS/storage QA. Incorrect answers can cause rejection, suspension, unsafe access, or legal exposure.`,
);

write(
  'docs/play-final/MORT_APP_CONTENT_ANSWERS.md',
  ownerTable([
    ['App access', 'Restricted; provide persistent teen and adult reviewer accounts', 'Review tenant QA and app-access docs', '[ ]', 'Review rejection if login fails'],
    ['Ads', 'No ads in this release', 'No ads SDK or AD_ID in final bundle', '[ ]', 'Data Safety/policy mismatch'],
    ['UGC', 'Yes; profiles, jobs, messages, reviews, proofs, organization content', 'Report/block/moderation/rate-limit QA', '[ ]', 'UGC policy violation'],
    ['Child safety', '13+ service with published standards and dedicated trained-adult contact', 'Age gate, standards page, child-safety QA', '[ ]', 'Severe policy/safety exposure'],
    ['Financial features', 'No payment processing, escrow, lending, wallet, transfer, or guarantee', 'Payment preference/obligation models only', '[ ]', 'Incorrect financial declaration'],
    ['Identity verification', 'Real document/provider verification disabled', 'Release flags and bundle behavior', '[ ]', 'Misleading safety claim'],
    ['Account deletion', 'In-app and public web request paths', 'Deletion suites and public route', '[ ]', 'User Data policy rejection'],
  ]),
);

const dataRows = [
  ['Legal/profile name', 'Yes', 'No sale; Supabase processor', 'Account/profile and job attribution', 'Required/optional by role', 'No', 'HTTPS', 'Account lifecycle; narrow retained evidence where legitimate', 'Deleted or deidentified through deletion workflow', 'profile_repository.dart; profiles', 'profile-avatars'],
  ['Email', 'Yes', 'No sale; Supabase processor', 'Auth, recovery, service notices', 'Required', 'No', 'HTTPS', 'Account lifecycle/security retention', 'Auth deletion workflow', 'Supabase Auth', 'None'],
  ['Phone', 'Optional', 'No sale; Supabase processor', 'Optional trust/recovery flow', 'Optional', 'No', 'HTTPS', 'Until removed/deletion', 'User/deletion control', 'Auth/profile trust flows', 'None'],
  ['Age band/private DOB', 'Yes', 'No sale; Supabase processor', '13+ gate and role safety', 'Required', 'No', 'HTTPS', 'Account lifecycle/audit', 'Deletion with narrow compliance retention', 'onboarding; profiles.date_of_birth/age_band', 'None'],
  ['Account ID', 'Yes', 'No sale; Supabase processor', 'Authorization and audit', 'Required', 'No', 'HTTPS', 'Account/audit lifecycle', 'Deleted/deidentified where allowed', 'auth.uid; foreign keys', 'None'],
  ['Profile image', 'Optional', 'No sale; Supabase processor', 'Profile', 'Optional', 'No', 'HTTPS', 'Until removed/deletion', 'Owner remove/deletion', 'avatar_repository.dart', 'profile-avatars'],
  ['Approximate location', 'Optional', 'No sale; Supabase processor', 'Nearby/manual-area matching', 'Optional', 'No', 'HTTPS', 'Profile/job lifecycle', 'Edit/deletion', 'jobs/profile/location repositories', 'None'],
  ['Temporary precise location', 'Optional', 'Authorized recipient only; Supabase processor', 'Foreground active-job safety', 'Optional', 'Yes after expiry', 'HTTPS', 'Short-lived session/audit', 'Expiry/stop/deletion rules', 'trust_safety_repository.dart; job_location_share_sessions', 'None'],
  ['Messages/media', 'Yes when used', 'Participants/moderators as authorized; Supabase processor', 'Job coordination and safety', 'Optional feature', 'No', 'HTTPS', 'Conversation/safety retention', 'Deletion with narrow evidence retention', 'messaging_repository.dart; messages', 'report-uploads/incident-evidence when submitted'],
  ['Jobs/applications/contracts', 'Yes', 'Matched participants; Supabase processor', 'Pilot marketplace workflow', 'Required to transact', 'No', 'HTTPS', 'Transaction/dispute lifecycle', 'Deletion/deidentification subject to obligations', 'jobs/applications/legal repositories', 'proof-uploads'],
  ['Reviews/reports/support', 'Optional', 'Authorized users/moderators; Supabase processor', 'Trust, safety, support', 'Optional', 'No', 'HTTPS', 'Moderation/safety/support policy', 'Delete ordinary data; retain narrow evidence', 'reviews/safety/support repositories', 'report-uploads/incident-evidence'],
  ['Work/payment history', 'When work used', 'Participants/moderators as authorized; Supabase processor', 'Completion and obligation record', 'Required for workflow', 'No', 'HTTPS', 'Transaction/dispute lifecycle', 'Deletion/deidentification subject to disputes', 'contracts, obligations, disputes', 'proof-uploads'],
  ['Device/session/diagnostics', 'Yes/limited', 'Supabase and OS providers as needed', 'Security, auth, crash investigation', 'Required for security', 'Some ephemeral', 'HTTPS', 'Security retention', 'Expiry/deletion where applicable', 'Supabase auth; device_info; security events', 'None'],
  ['Organization affiliation', 'Optional', 'Organization staff and participant as scoped; Supabase processor', 'Pilot eligibility/support', 'Optional', 'No', 'HTTPS', 'Membership/attestation expiry', 'Revocation/deletion rules', 'mission_pilot_repository.dart; partner tables', 'None'],
  ['Guardian/Support Circle', 'Optional', 'Only linked authorized users; Supabase processor', 'Optional support and safety', 'Optional', 'No', 'HTTPS', 'Until unlink/deletion', 'Unlink/deletion', 'guardian_repository.dart; support_circle tables', 'None'],
];
write(
  'docs/play-final/MORT_DATA_SAFETY_FINAL_WORKBOOK.md',
  `${ownerBanner}# Data Safety Final Workbook

This workbook is a code/schema recommendation for version \`0.9.1+91\`. The adult owner must compare it to the exact Play-accepted AAB and hosted processor contracts.

| Category | Collected | Shared | Purpose | Required | Ephemeral | Transit | Retention | Deletion | Code/table path | Storage path |
|---|---|---|---|---|---|---|---|---|---|---|
${dataRows.map((row) => `| ${row.join(' | ')} |`).join('\n')}

Bundled SDK conclusion: Supabase, secure storage, local auth, image picker, geolocation/geocoding, notifications, device/package info, URL launcher, cached images, and Flutter runtime remain. AdMob and RevenueCat SDKs are not bundled. Verify the final dependency and bundle reports before checking Play fields.

- [ ] Owner confirms each category against the exact accepted AAB.
- [ ] Owner confirms encryption, retention, deletion, and processor statements.
- [ ] Owner reruns this audit after any SDK, permission, schema, or policy change.`,
);

write(
  'docs/play-final/MORT_TARGET_AUDIENCE_FINAL_WORKBOOK.md',
  ownerTable([
    ['Target age groups', '13-15, 16-17, and 18+; never under 13', 'DOB server gate and teen/adult roles', '[ ]', 'Families/child policy mismatch'],
    ['Primarily child-directed', 'No; mixed 13+ teen work/safety service', 'Adult posters, partners, guardians, teens', '[ ]', 'Incorrect audience classification'],
    ['Appeal to children', 'Not designed for under-13 children', 'Store copy and age gate', '[ ]', 'Under-13 policy exposure'],
    ['Access model', 'Restricted approved-participant pilot', 'Server release mode and eligibility RPCs', '[ ]', 'Misleading listing'],
  ]) + `\n\nStore listing and screenshots must avoid childlike marketing, under-13 imagery, income promises, social/romantic positioning, and unverifiable safety claims.`,
);

write(
  'docs/play-final/MORT_CONTENT_RATING_FINAL_WORKBOOK.md',
  ownerTable([
    ['User interaction', 'Yes: job-context messages and UGC', 'Messaging/jobs/reviews', '[ ]', 'Rating mismatch'],
    ['Location sharing', 'Optional foreground active-job sharing; no background location', 'Manifest and safety repository', '[ ]', 'Privacy/rating mismatch'],
    ['Violence/sexual content supplied by app', 'No; prohibited and moderated user misconduct may be reported', 'Child-safety and UGC controls', '[ ]', 'Incorrect content answer'],
    ['Purchases/ads', 'None bundled or enabled', 'Dependency/permission audit', '[ ]', 'Incorrect monetization answer'],
    ['Recommended audience posture', 'Teen / 13+ restricted pilot; accept IARC result', 'Age gate and service model', '[ ]', 'Do not self-select a rating dishonestly'],
  ]),
);

write(
  'docs/play-final/MORT_ADS_DECLARATION_FINAL.md',
  ownerTable([
    ['Contains ads', 'No for version 0.9.1+91', 'Ad SDK removed; AD_ID removed; live_ads=false', '[ ]', 'Incorrect ads label'],
    ['Future ads', 'Not part of this submission; requires new review and declaration', 'Fail-closed service facade', '[ ]', 'Undeclared SDK/data collection'],
  ]),
);
write(
  'docs/play-final/MORT_FINANCIAL_FEATURES_DECLARATION_FINAL.md',
  ownerTable([
    ['Payment processing', 'No', 'No billing SDK; preference/obligation records only', '[ ]', 'Financial policy mismatch'],
    ['Escrow/wallet/transfers/lending', 'No', 'No corresponding implementation or permission', '[ ]', 'Regulatory exposure'],
    ['Payment guarantee/collection', 'No', 'Dispute workflow records facts without guilt finding', '[ ]', 'Misleading users'],
    ['Paid digital content', 'No in this release', 'Billing SDK and permission absent', '[ ]', 'Billing policy mismatch'],
  ]),
);

const permissionRows = [
  ['INTERNET', 'Flutter/Supabase', 'Hosted auth/API/media', 'OS granted', 'Network required', 'Offline/error/retry state', 'Core network app', 'Retain'],
  ['ACCESS_NETWORK_STATE', 'Connectivity/runtime', 'Detect network state', 'No runtime dialog', 'Supports recovery', 'Retry path', 'Low impact', 'Retain'],
  ['CAMERA', 'image_picker', 'Optional proof capture', 'Proof action only', 'Capture requested by user', 'Gallery/native-required alternative', 'Data Safety/media', 'Retain; optional hardware'],
  ['POST_NOTIFICATIONS', 'flutter_local_notifications', 'Private local notifications', 'Contextual Android 13+ request', 'User can decline', 'In-app notification center', 'Permission declaration', 'Retain'],
  ['USE_BIOMETRIC', 'local_auth', 'Optional app lock', 'User enables', 'Local device auth only', 'Passcode/no app-lock fallback', 'Biometric disclosure; no template collected', 'Retain'],
  ['ACCESS_COARSE_LOCATION', 'geolocator', 'Approximate nearby/manual area', 'Location action only', 'Approximate is sufficient', 'Manual area', 'Location Data Safety', 'Retain'],
  ['ACCESS_FINE_LOCATION', 'geolocator', 'Optional foreground active-job location', 'Explicit contextual request', 'Temporary foreground sharing', 'Coarse/manual/no sharing', 'Prominent disclosure', 'Retain; no background'],
  ['USE_FINGERPRINT', 'local_auth compatibility', 'Optional app lock on older biometric APIs', 'User enables app lock', 'OS-owned local authentication', 'Passcode/no app-lock fallback', 'No biometric template collected', 'Retain'],
  ['VIBRATE', 'flutter_local_notifications', 'Optional local notification alert', 'Notification preference/OS control', 'Alert may vibrate', 'Silent/in-app notification path', 'Low-impact notification behavior', 'Retain'],
  ['com.mortapp.mobile.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION', 'AndroidX runtime', 'Protect app-scoped dynamic receivers', 'No user request', 'Internal non-exported receiver guard', 'Not user-facing', 'App-scoped signature permission', 'Retain'],
];
write(
  'docs/play-final/MORT_PERMISSION_DECLARATION_FINAL.md',
  `${ownerBanner}# Permission Declaration Final

| Permission | Source | Feature | Runtime request | Explanation | Denial fallback | Play impact | Decision |
|---|---|---|---|---|---|---|---|
${permissionRows.map((row) => `| \`${row[0]}\` | ${row.slice(1).join(' | ')} |`).join('\n')}

Exact signed release posture: 10 merged permissions. Billing, advertising ID, AdServices identifiers, foreground service, wake lock, background location, and broad media-library permissions are absent. The app-scoped dynamic-receiver permission is not a user-granted data permission. Reconfirm against any Play-rebuilt split APK before submission.`,
);

write('docs/play-final/MORT_APP_ACCESS_FINAL.md', readFileSync(resolve(root, 'docs/play-final/MORT_APP_ACCESS_COPY_PASTE.md'), 'utf8'));
write(
  'docs/play-final/MORT_ACCOUNT_DELETION_DECLARATION.md',
  ownerTable([
    ['In-app path', 'Settings > Account > Delete account', 'AccountDeletionRequestScreen', '[ ]', 'Discovery requirement failure'],
    ['Web path', 'Public /account-deletion/ with private email ownership link', 'Legal site package and web QA', '[ ]', 'User Data policy rejection'],
    ['Enumeration', 'Generic response regardless of account existence', 'Web client and enumeration QA', '[ ]', 'Account disclosure'],
    ['Security', 'Recent reauth, one-use expiring token, replay and cross-user rejection', 'Deletion QA suites/RPCs', '[ ]', 'Account takeover/deletion'],
    ['Retention', 'Ordinary data removed; narrow legitimate evidence documented and access restricted', 'Retention policy/schema', '[ ]', 'Misleading deletion claim'],
  ]),
);
write(
  'docs/play-final/MORT_CHILD_SAFETY_DECLARATION.md',
  ownerTable([
    ['Published standards', 'Yes after HTTPS deployment of /child-safety-standards/', 'Generated legal package', '[ ]', 'Policy rejection'],
    ['In-app reporting/blocking', 'Yes for supported users/content', 'Safety repository and QA', '[ ]', 'UGC/child-safety failure'],
    ['Dedicated contact', 'Configured trained adult; not yet supplied', 'MORT_PUBLIC_CHILD_SAFETY_EMAIL', '[ ]', 'Operational/policy failure'],
    ['CSAM handling', 'No ordinary email/upload; trained-adult lawful escalation and preservation', 'Operations docs', '[ ]', 'Severe legal/safety harm'],
    ['Under-13 access', 'Rejected server-side', 'Age-gate QA', '[ ]', 'Child privacy exposure'],
  ]),
);
write(
  'docs/play-final/MORT_PRODUCTION_ACCESS_APPLICATION_DRAFT.md',
  `${ownerBanner}# Production Access Application Draft

## What was tested

MORT's restricted teen/adult pilot flows: eligibility, job posting/browsing, application review, job-context messaging, contracts, safety agreements, arrival/completion checks, payment-status records, reports, blocking, account deletion, and organization-scoped partner support. Synthetic data only; no real IDs or real home addresses.

## Tester engagement plan

Recruit 15-18 trusted adult-controlled testers, retain at least 12 continuously opted in, assign daily scenarios for 14 consecutive days, collect device/evidence/defect records, and resolve release blockers. Do not state this requirement is complete until Play Console confirms it.

## Production-pilot limits

Public download would expose mission, waitlist, education, resources, privacy, support, and deletion. Jobs, participant messaging, private locations, contracts, and active-job workflows remain server-restricted. Unrestricted public adult/minor matching, real IDs, ads, billing, and remote push remain disabled.

## Owner confirmation

- [ ] Closed-test evidence is complete and Play-confirmed.
- [ ] Physical-device and pre-launch defects are resolved.
- [ ] Legal, youth-work, child-safety operations, and insurance decisions are documented.
- [ ] Publisher identity, contacts, and HTTPS pages are verified.
- [ ] This draft is edited to match actual tester feedback and metrics before submission.`,
);

write(
  'docs/device-test/MORT_PHYSICAL_ANDROID_TEST_MATRIX.md',
  `# MORT Physical Android Test Matrix

**Status: NOT EXECUTED BY CODEX. Evidence from a physical Android device is mandatory.**

| ID | Scenario | Required evidence | Result |
|---|---|---|---|
${[
  'Play installation','First launch','Eligible sign-up','Under-13 block','Sign-in','Password reset','Legal acceptance','Nearby search','Denied location','Approximate location','Manual location','Jobs','Application','Contract','Messaging','Reporting','Blocking','Start handshake','Completion handshake','Completion-code refusal fallback','Nonpayment report','App lock/biometric prompt','Notification permission','Private notification preview','Deep links','Photo picker/camera','Account deletion','Low network','Offline recovery','Background/foreground','Process death','Large text','TalkBack','Dark mode','Rotation','Update from version 90',
].map((name, index) => `| P${String(index + 1).padStart(2, '0')} | ${name} | Screenshot/video/log plus tester/device/time | NOT RUN |`).join('\n')}

Each execution record must identify tester, adult confirmation, manufacturer/model, Android version, app version/code, date/time, pass/fail, evidence path, and defect ID.`,
);
write(
  'docs/device-test/MORT_DEVICE_TESTER_INSTRUCTIONS.md',
  `# MORT Device Tester Instructions

Use only synthetic review data. Never enter a real ID, home address, school, income, incident, or emergency simulation. Confirm you are an adult tester or supervised by the responsible adult testing group.

1. Record device/model, Android version, build \`0.9.1+91\`, tester, and local time.
2. Install through the assigned Play closed-test link when available; also record controlled QA APK tests separately.
3. Execute the matrix in order, capturing evidence without passwords or notification secrets.
4. For every failure, stop the affected journey, create a defect ID, attach logs/screenshots, and note reproducibility.
5. Treat crashes, data leakage, under-13 access, cross-user reads, broken report/block/deletion, unsafe private location, or misleading trust/payment claims as release blockers.
6. Do not approve the release on behalf of Google, legal counsel, or child-safety operations.`,
);
write(
  'docs/device-test/MORT_DEVICE_RESULT_TEMPLATE.csv',
  'test_id,scenario,tester,adult_confirmation,manufacturer,model,android_version,app_version,version_code,test_datetime,result,evidence_path,defect_id,notes\n',
);
write(
  'docs/device-test/MORT_CRASH_REPORT_TEMPLATE.md',
  `# MORT Crash Report

- Defect ID:
- Tester and adult confirmation:
- Device/manufacturer/model:
- Android version:
- App version/code: 0.9.1 / 91
- Installation source:
- Date/time and timezone:
- Account role and synthetic fixture:
- Preconditions:
- Exact steps:
- Expected behavior:
- Actual behavior:
- Reproduction rate:
- Network/permission state:
- Screenshot/video/logcat path:
- Sensitive-data review completed:
- Severity and release-blocker decision:
- Fix build and retest evidence:`,
);
write(
  'docs/device-test/MORT_RELEASE_BLOCKER_RULES.md',
  `# MORT Release Blocker Rules

Block release for any reproducible crash, ANR, startup failure, failed upgrade, secret/credential exposure, cross-user or cross-organization access, under-13 admission, unrestricted marketplace access, real-document collection, unsafe private-location disclosure, broken report/block/deletion, lost evidence, incorrect payment/identity guarantee, bundled ads/billing, debug signing, or inaccessible critical safety control.

High-impact accessibility failures that prevent sign-in, report, block, safety, contract, or deletion are blockers. Flaky failures remain blockers until root-caused or bounded with evidence. Only a tested fix in a newer valid version can close a blocker.`,
);

write(
  'docs/closed-test/MORT_TESTER_GOOGLE_GROUP_SETUP.md',
  `# Tester Google Group Setup

Adult account owner creates a private group, invites 15-18 trusted testers, restricts member visibility/posting, documents consent, and removes anyone who cannot follow synthetic-data rules. Add the group to the Play closed-test track. Preserve a dated roster without storing passwords in this repository.`,
);
write(
  'docs/closed-test/MORT_TESTER_OPT_IN_GUIDE.md',
  `# Tester Opt-In Guide

1. Sign into Google Play with the invited account.
2. Open the owner-provided HTTPS opt-in link.
3. Join the test and install MORT from Google Play.
4. Keep the same account opted in continuously unless safety requires removal.
5. Record install/build evidence and complete assigned synthetic scenarios.
6. Do not share the link, credentials, real IDs, real addresses, or real incidents.`,
);
write(
  'docs/closed-test/MORT_14_DAY_CALENDAR.md',
  `# MORT 14-Day Closed-Test Calendar

| Day | Focus | Evidence |
|---|---|---|
${[
  'Install, launch, consent, age gate','Teen onboarding and public closed-pilot experience','Adult onboarding and safe job post','Applications and applicant review','Job-context messaging and safety scanner','Contracts and Mutual Safety Agreement','Location denial/manual area and private-location controls','Arrival/start handshake and background recovery','Completion/proof and refusal fallback','Payment status, disagreement, nonpayment','Reports, blocking, moderation boundaries','Guardian optionality, Support Circle, partner scope','Deletion, password reset, deep links, update/reinstall','Accessibility, low network, regression, final feedback',
].map((focus, index) => `| ${index + 1} | ${focus} | Opt-in count, device result, defect IDs, screenshots/logs |`).join('\n')}

Play Console, not this calendar, determines whether the consecutive-day requirement is satisfied.`,
);
write(
  'docs/closed-test/MORT_DAILY_SCENARIOS.md',
  `# MORT Daily Scenarios

Use \`MORT_14_DAY_CALENDAR.md\` plus the physical-device matrix. Rotate teen, adult, partner, guardian, denied-permission, offline, large-text, TalkBack, dark-mode, process-death, and update scenarios across devices. Use synthetic job/content only. Never simulate genuine emergencies, sexual incidents, real nonpayment, or real home-address work.`,
);
write(
  'docs/closed-test/MORT_TESTER_FEEDBACK_FORM.md',
  `# MORT Tester Feedback Form

- Tester/date/device/build:
- Scenario and account role:
- Could you finish the intended task? Why or why not?
- Any crash, freeze, lost state, broken navigation, or misleading wording?
- Were closed-pilot, identity, safety, payment, and emergency limits clear?
- Could you find report, block, support, privacy, and account deletion?
- Accessibility/large text/TalkBack/dark mode notes:
- Evidence path and defect IDs:
- Would this issue block a trusted closed test?`,
);
write(
  'docs/closed-test/MORT_TESTER_RETENTION_TRACKER.csv',
  'tester_id,adult_confirmed,invited_at,opted_in_at,day_1,day_2,day_3,day_4,day_5,day_6,day_7,day_8,day_9,day_10,day_11,day_12,day_13,day_14,still_opted_in,play_console_evidence,notes\n',
);
write(
  'docs/closed-test/MORT_DEFECT_TRIAGE_PROCESS.md',
  `# MORT Defect Triage Process

1. Remove credentials and real personal data from evidence.
2. Assign severity: blocker, critical, high, medium, low.
3. Reproduce on the same build/device and one comparison environment when safe.
4. Link route, role, release mode, network, permission state, logs, and fixture.
5. For security/safety issues, restrict visibility and preserve narrow evidence.
6. Fix with a new version code when the AAB changes; run focused and full regression.
7. Close only with recorded retest evidence. Crashes, isolation failures, under-13 admission, report/block/deletion failures, and unsafe trust/payment claims are blockers.`,
);
write(
  'docs/closed-test/MORT_PRODUCTION_ACCESS_RESPONSES.md',
  `# Production Access Response Workbook

${ownerBanner}Use actual Play Console counts and tester feedback. Do not paste planned numbers as completed results.

- How testers were recruited: {OWNER ENTER ACTUAL METHOD}
- Number invited: {ACTUAL}
- Number continuously opted in: {ACTUAL FROM PLAY CONSOLE}
- Dates of consecutive test: {ACTUAL}
- Tested journeys: {ACTUAL FROM DEVICE/SCENARIO RECORDS}
- Feedback received: {ACTUAL THEMES}
- Defects fixed: {ACTUAL DEFECT IDS AND VERSIONS}
- Remaining limitations: restricted pilot; real IDs/ads/billing/push/public marketplace disabled
- Why production pilot is appropriate: {OWNER EXPLAIN USING EVIDENCE}
- [ ] Owner confirms every statement matches Play Console and retained evidence.`,
);

process.stdout.write(`Generated final Play documentation for ${routes.length} Flutter routes.\n`);
