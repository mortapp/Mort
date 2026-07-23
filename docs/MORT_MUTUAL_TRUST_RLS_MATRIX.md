# MORT Mutual Trust RLS and Storage Matrix

## Scope and result

- Project: `rakjydmgwwgtdislanbt`
- Verification date: 2026-07-17
- Change model: additive migrations only; no reset or table drop
- Remote mutual-trust QA: 19/19 suites passed in one consolidated run
- Cross-user isolation QA: 30/30 checks passed
- Private Storage QA: identity, incident, avatar, proof, and business-verification isolation passed
- Service-role use: QA and server administration only; never present in Flutter, Swift, Expo, `.env.local`, or public build configuration

`Allowed` below means the narrow server-checked operation is available. It does not mean unrestricted table or object access.

## Identity and verification

| Resource | Account owner | Job participant | Guardian / Safety Circle | General admin or support | Specialized reviewer | Enforcement and evidence |
| --- | --- | --- | --- | --- | --- | --- |
| `identity_verifications` | Minimized own status through `get_my_identity_verification`; no client status mutation | Denied | Denied | Denied | Production review remains unavailable until provider and trained-reviewer readiness | Forgery QA passed; sandbox and expired records do not grant production eligibility |
| `identity_verification_evidence` | Direct upload and registration disabled | Denied | Denied | Denied | Unavailable until production readiness | Disabled/sandbox collect no ID document; school-ID, adult-ID, cross-user, and guardian denial passed |
| `identity_verification_appeals` | May submit and view own appeal status | Denied | Denied | Denied | Authorized review roles | Appeal never auto-restores access; expiration QA passed |
| `verification_referee_requests` | Own manual-exception request only | Denied | Denied unless separately designated through future reviewed process | Denied | Verification or child-safety reviewer | Teen alternatives QA passed without requiring school ID |
| `verification_evidence_access_grants` | Denied | Denied | Denied | Denied | Grant holder and authorized reviewer | Reason, actor, evidence, and maximum 15-minute expiry required |
| `verification_audit_events` | Denied from raw audit table | Denied | Denied | Denied | Authorized verification, incident, or legal roles | Admin evidence access logging QA passed |
| `identity_risk_signals` | Denied | Denied | Denied | Denied | Authorized safety/verification roles | Users cannot self-set duplicate, liveness, screening, or address results |
| Storage `identity-evidence` | Upload, update, copy, move, list, and delete denied | Denied | Denied | Denied | Unavailable until production readiness and trained-reviewer authorization | Private bucket; no authenticated insert/update policy; hosted lockdown QA passed |

## Incidents, reporting, and evidence

| Resource | Reporter / participant | Unrelated user | General admin or support | Specialized safety role | Enforcement and evidence |
| --- | --- | --- | --- | --- | --- |
| `reports` | Submit only through `submit_safety_report`; own authorized status only | Denied | Denied unless specialized | Moderator/safety roles by explicit policy | Mutual teen/adult reporting passed |
| `safety_incidents` | Participant-safe projection through `get_my_incident_cases` | Denied | Denied | Incident/child/senior safety roles | Incident isolation QA passed for users and unprivileged admin |
| `incident_participants` | No unrestricted direct roster | Denied | Denied | Authorized incident roles | Prevents discovery of witnesses, accused users, and support contacts |
| `incident_evidence` | May submit to own case; no unrestricted listing or registered deletion | Denied | Denied | Metadata manifest and reasoned grant | SHA-256, retention, preservation, and access audit supported |
| `incident_evidence_access_grants` | Denied | Denied | Denied | Authorized grant holder | Short-lived, reasoned access only |
| `incident_timeline_events` / actions / assignments | Participant sees only approved public case status | Denied | Denied | Role- and assignment-restricted | Restricted notes and enforcement history never enter participant payloads |
| `incident_preservation_orders` | Denied | Denied | Denied | Incident manager or legal reviewer | Preservation QA passed; user deletion of preserved evidence denied |
| `incident_law_enforcement_requests` | Denied | Denied | Denied | Legal-request reviewer only | Draft process still requires counsel, request validation, and trained staff |
| `incident_appeals` | Appropriate participant may submit/view own appeal | Denied | Denied | Authorized safety reviewer | Appeal does not automatically reverse enforcement |
| `message_safety_evidence` | Raw blocked text denied, including recipient | Denied | Denied | Child/senior safety roles only | Sexual-content and threat preservation QA passed |
| Storage `incident-evidence` | Participant upload to authorized case; registered delete denied | Denied | Denied | Logged, reasoned access only | Private bucket, metadata-only discovery, hashes, and preservation lock passed |

## Job, location, and real-world safety

| Resource | Teen / adult participant | Unrelated user | Guardian / Safety Circle | Specialized staff | Enforcement and evidence |
| --- | --- | --- | --- | --- | --- |
| `job_safety_plans` | Accepted job participants only | Denied | Denied unless a separate selected summary permission applies | Safety roles when incident-authorized | Expected people, visibility, transport, equipment, cadence, and disclosures |
| `job_safety_agreements` | Both participants independently confirm current version | Denied | Denied | Incident-authorized staff | `in_progress` transition fails until both confirm; material changes reset confirmation |
| `job_private_locations` | Exact job address only through checked release RPC after acceptance and both confirmations | Denied | Denied by default | Restricted incident/legal access only | Address privacy and release-stage QA passed |
| `job_location_share_sessions` | Explicit owner/recipient, job-bound, visible, expiring, stoppable | Denied | Only if teen explicitly selects that trusted contact | Incident-authorized staff | Coarse-area web path; no constant tracking requirement |
| `job_arrival_handshakes` | Assigned participants only | Denied | Denied | Incident-authorized staff | Short-lived rotating code; wrong code and replay rejected |
| `job_checkins` | Job participant only | Denied | Only through separately granted alert | Safety escalation role | Missed check-in escalation is server-only |
| `safety_cancellations` | Job participant may cancel for safety | Denied | Denied by default | Incident-authorized staff | No automatic reputation penalty; serious reason creates incident |
| `trusted_relationships` / `blocks` | Owner-controlled no-contact state | Denied | Denied | Safety role when incident-authorized | Blocking stops ordinary contact and stops active location share |

## Optional support and account security

| Resource | Teen | Linked contact | Unrelated guardian | Admin | Enforcement and evidence |
| --- | --- | --- | --- | --- | --- |
| `safety_circle_members` | Creates invitation, selects individual permissions, may unlink | Receives only granted alert categories; may unlink | Denied | Safety role only when authorized | Permission isolation and bilateral unlink QA passed |
| `guardian_connections` | Guardian Mode remains voluntary and separately configurable | Existing bounded Guardian Mode permissions only | Denied | Authorized support/safety role | Verified teen without guardian can apply and message after acceptance |
| Identity evidence through either support system | Denied from support relationship | Denied | Denied | Specialized verification grant only | Guardian and Safety Circle cannot read school/government ID evidence |
| `account_security_events` | Own privacy-safe session references and concern reports | Denied | Denied | Authorized safety roles | Tokens and raw credentials are never returned; account-sharing QA passed |
| `reviews` | Author sees own pending review; subject sees only after mutual reveal and moderation approval | Denied while nonpublic | Denied | Authorized moderator | Blind reveal, duplicate-side prevention, and checked report flow passed |

## Advisor interpretation

The provider-safe baseline began with 84 warnings and zero errors: 82 authenticated `SECURITY DEFINER` callable warnings, one anonymous callable warning for the minimized trust-badge RPC, and one Auth leaked-password warning. The anonymous grant has now been revoked. The 2026-07-18 hosted rerun returned 83 WARN, 3 INFO, and 0 ERROR findings: 82 authenticated function findings, one plan-limited Auth finding, and three deny-by-default RLS/no-policy INFO rows. Every function finding is reconciled individually in `docs/MORT_84_SECURITY_WARNING_RECONCILIATION.md`.

This is not a claim that every callable function is risk-free. Any new or changed `SECURITY DEFINER` function still requires manual body, grant, `search_path`, ownership, and abuse-limit review.

Leaked-password protection is **DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT**. The Free plan cannot enable the HaveIBeenPwned control. Current mitigations are password length and complexity, Auth rate limiting, email verification, RLS, account restrictions, and secure reset flow. When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors.

## Remaining validation

- A selected identity vendor must validate document authenticity, live liveness, address evidence, and duplicate identity signals.
- Trained verification, child-safety, incident, and legal-request staff must validate operational access and escalation procedures.
- Counsel must approve retention, screening, adverse-action, emergency disclosure, youth-work, and lawful-request processes.
- Mac/Xcode compilation, physical document capture, real arrival behavior, APNs, and physical iPhone testing have not been performed.
