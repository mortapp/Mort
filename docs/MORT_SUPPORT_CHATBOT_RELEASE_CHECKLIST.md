# MORT Support Chatbot Release Checklist

Candidate: `0.9.11+101`  
Status: signed local closed-test candidate, not upload-cleared

## Completed

- [x] Part A secure session persistence remains green.
- [x] Nine support migrations transaction-tested and applied remotely.
- [x] Sixteen support tables found with forced RLS and no missing table.
- [x] Private `support-attachments` bucket verified.
- [x] Thirteen JWT-verified support Edge Functions deployed.
- [x] External provider explicitly disabled server-side.
- [x] No AI/service-role/database secret in Flutter.
- [x] Deterministic levels 0-3 run before provider eligibility.
- [x] Human handoff creates a real idempotent support ticket.
- [x] Guardian and cross-user support access denied.
- [x] Staff access audited through RPCs.
- [x] Ordinary admins cannot inherit Support access without a specific active
  Support role assignment.
- [x] Staff assignment, queue ownership, internal notes, appeal routing,
  service-only aging alerts, and aggregate manager metrics verified remotely.
- [x] Assistant handoffs use a privacy-minimized structured summary and do not
  copy raw conversation content into queue metadata.
- [x] Per-user and global provider budgets enforced server-side.
- [x] Real private upload/download/expiry/isolation test passed.
- [x] Final deterministic evaluation passed 150/150.
- [x] Existing Supabase regression pack passed 31/31 scripts.
- [x] Flutter analysis passed with no issues.
- [x] Flutter tests passed: 223, with 2 expected skips and 0 failures.
- [x] Android API 36 native integration passed 1/1.
- [x] Flutter release web build passed.
- [x] Signed APK and AAB built with package `com.mortapp.mobile`, min SDK 24,
  target SDK 36, and existing upload certificate.
- [x] Source, privacy, APK, and AAB secret scans passed.

## Required Before Play Upload

- [ ] Sign in to Play Console and prove version code `101` is unused.
- [ ] Review the AAB manifest, Data safety form, content rating, target audience,
  child-safety standards, support contact, privacy policy, and app-access notes.
- [ ] Run update-in-place from the prior Play build on a physical Android phone.
- [ ] Run physical Google OAuth, force-close, phone-restart, logout, offline,
  notification, camera/photo, and accessibility tests.
- [ ] Staff the Support and safety queues with named, trained owners. Current
  hosted status is `Not staffed yet`; no response target is a commitment.

## Required Before Provider Activation

- [ ] Configure the provider key/model only in Supabase secrets.
- [ ] Complete vendor privacy/DPA/subprocessor review.
- [ ] Run model-specific 150+ evaluation plus multilingual and mutation tests.
- [ ] Validate timeout, 429, 5xx, cost cap, global cap, and failover behavior.
- [ ] Obtain teen-safety and human moderation approval.

## Required Before Public Marketplace

- [ ] Connect a real production identity-verification provider.
- [ ] Keep real ID collection disabled until legal and vendor review completes.
- [ ] Complete App Store/Play legal, privacy, age, guardian, moderation,
  evidence-retention, incident-response, and teen-safety reviews.
- [ ] Validate production push/crash monitoring and on-call response.
- [ ] Explicitly change the server marketplace flag only after all launch gates
  pass. The current public marketplace remains closed.

## iOS

- [ ] Build on macOS with the final iOS signing configuration.
- [ ] Test Keychain persistence, OAuth callbacks, notifications, camera/photo,
  background/foreground, VoiceOver, and deletion on physical iPhones.
- [ ] Complete TestFlight, App Store privacy labels, age rating, reviewer access,
  and child-safety review.

No iPhone, TestFlight, or App Store testing is claimed by this checklist.
