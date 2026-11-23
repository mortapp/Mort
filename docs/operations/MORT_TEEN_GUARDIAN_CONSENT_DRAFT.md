# Teen guardian consent: disposable-replica review contract

This is a proposal, not approved policy or a production migration. Do not apply it to a hosted project, expose these RPCs to released clients, put the SQL on an approval/apply list, or use real youth identities or evidence. Existing optional Guardian Mode remains independent.

## Flutter replica preflight

The pending teen's account-status screen has a read-only draft card. It defaults off and needs `MORT_TEEN_CONSENT_REPLICA_DRAFT=true`, `internal_test` / `automated_test`, BrowserStack fixtures off, and a TLS terminator for a disposable replica on a loopback hostname (or Android emulator host alias `10.0.2.2`). Use only a trusted certificate and synthetic users. It does not work on hosted QA or production and does not change eligibility or navigation. The card displays only the server-returned state and version, with a generic unavailable message for errors, and stores no identifiers from the response. Assent, guardian discovery and decision, withdrawal, staff attestation, and public copy are deliberately not wired; those require policy approval, approved notices, and a dedicated hosted-QA design and rollout.

## Version 1 contract

The self-only `get_teen_guardian_consent_status_v1()` response has exactly this successful shape:

```json
{"ok":true,"contract_version":1,"consent_version":1,"status":"required","request_id":null,"expires_at":null}
```

| Stable `status` | Meaning |
| --- | --- |
| `required` | No current-version request; a prior version never substitutes. |
| `awaiting_teen_assent` | An authorized request awaits this pending teen's separate assent. |
| `awaiting_guardian_consent` | This pending teen assented; the guardian has not accepted. |
| `ready_for_staff_review` | Both current-version actions are recorded for the same request; staff must independently approve all existing prerequisites. |
| `consent_recorded` | Both actions are recorded and the teen is no longer pending. This is not an authorization verdict. |
| `expired` | An unsigned request is past the acceptance deadline. |
| `withdrawn` | A participant closed the current request. |
| `invalidated` | An active admin closed the current request for an allowlisted reason. |
| `guardian_not_eligible` | The assigned account fails current guardian eligibility; staff must review. |

`request_id` is nullable and opaque. It is returned for the two awaiting states, ready/recorded states, and `guardian_not_eligible`, so the teen can identify the current request when withdrawing. `expires_at` is the deadline for the unsigned actions and is returned only in the two awaiting states. There is no guardian ID, contact data, proof handle, staff identity, or review reason in the response. Non-teen authenticated callers get `{"ok":false,"code":"not_eligible"}`; unauthenticated calls are denied by database grants.

| RPC | Scope and successful result |
| --- | --- |
| `attest_teen_guardian_authority_v1(p_teen_id,p_guardian_id,p_authority_ref,p_consent_version)` | An authenticated admin whose profile is active may attest authority for an identified pending teen and currently eligible active guardian. Returns `{ok:true,code:"authority_attested",request_id,expires_at}`. The opaque UUID references a separate authorized case review and cannot be reused. An administrator must not be either participant. |
| `record_teen_guardian_assent_v1(p_request_id,p_consent_version)` | The assigned pending teen explicitly assents to the current request and version. Returns `{ok:true,code:"teen_assent_recorded"}`. |
| `accept_teen_guardian_consent_v1(p_request_id,p_consent_version)` | The assigned, active guardian explicitly accepts that same request and version, after the teen assents and before expiry. The guardian's confirmed email, age, current legal acceptance and approved identity verification are evaluated by the server. Returns `{ok:true,code:"guardian_consent_recorded"}`; it may queue review, never activates the teen or grants access to the teen's profile, messages or optional monitoring. No guardian discovery/delivery UI is part of the draft. |
| `withdraw_teen_guardian_consent_v1(p_request_id)` | Either signed-in participant may close their exact request. Returns `{ok:true,code:"consent_withdrawn"}`. An already-signed guardian need not remain in good standing to withdraw. |
| `invalidate_teen_guardian_consent_v1(p_request_id,p_reason_code)` | An authenticated active admin may close a request using `authority_invalid`, `policy_recheck` or `guardian_no_longer_eligible`. Returns `{ok:true,code:"consent_invalidated"}`. |

In-scope application failures return `{ok:false,code}`: `request_unavailable` for unrelated/unknown IDs, wrong participant, duplicate/closed requests and ineligible state; `consent_version_required` for a missing/obsolete version value; `administrator_required` for non-admin or suspended admin; `reason_required` for an invalid invalidation reason. Replay is never success, creates no second record, and does not tell an unrelated caller whether that request exists. Existing staff activation RPC result formats stay unchanged. The SQL is closed to anonymous/service roles and its private RLS table/helpers have no direct application-role grants.

## Activation and withdrawal

- **Authority is not age or identity**: Staff attestation assumes a separate relationship-authority review. This draft does not verify custody, authenticate a source record, or accept proof files. The one-use case reference is random, not a document number, URL, digest of personal data, or a substitute for verifying authority. Only synthetic opaque fixtures are used here.
- **Activation**: Both staff RPCs use the same common eligibility decision. The teen still needs completed onboarding, published legal acceptance, school email, and approved age and school verification. The profile-write trigger adds a backstop for new activations, not a change to existing active records. Optional accepted invitations/links and the skipped monitoring choice are not signals of mandatory consent. Signing does not create a link.
- **Serialization**: The teen profile row is acquired before updating the consent record or role queue. Direct review first reads the request's owner, acquires the profile lock, then locks and rereads the same request. The existing status RPC locks in the same order. This serializes accept, withdrawal, role review, and deduplication for that teen. Guardian qualification is reread, not locked across every independent account, auth, and verification change. A cross-account lifecycle and lock-order exercise remains required before rollout.
- **Closure**: A pending teen remains pending when the request is withdrawn or invalidated. For a recorded request of an active teen, the same transaction closes the record and moves that teen to `suspended`. No automatic reactivation. No Auth deletion, deletion-state change, erasure, or changes to separately optional links or records. The replica checks marketplace denial and deletion-status access; a complete support, safety, deletion, messaging, optional guardian and cached-session access matrix is still required.
- **Evidence**: The private table retains request/account references, version, checkpoints, and close actor/reason. No proof binary, signature image, note, contact details or IP is collected. No cascading foreign keys are introduced in this draft. This intentionally does not decide how audit evidence is purged, minimized, pseudonymized, held, or reconciled with a confirmed account deletion. Do not promote any form of the table until a per-record retention and deletion policy is signed off.

## Approval and validation gates

- **Product, counsel and trust/safety**: Approve who qualifies, authority verification and staff separation of duties, current notice and assent language, request delivery and recovery, seven-day draft request window, accepted-consent duration, consent expiry/guardian qualification changes, transition and notice for existing teens, withdrawal/appeal/reconsideration and support/safety access, plus retention and deletion. Technical identity approval alone must never substantiate the authority attestation. No published legal or safety content is changed here.
- **Backend, security and client**: Exercise authority proof provenance, approved step-up authentication, role and concurrent changes across all guarded surfaces, account ageing and correction, backend/web/mobile rendering and session behavior, restore/rollback, and legal-version transitions. Reject expired invitations and stale enrollment records without ever backfilling consent from optional links. Do not exercise privilege boundaries on the production host.
- **Reproduce**: Inspect the secretless `MORT guardian consent draft (disposable replica)` Actions job. Run `RUN_GUARDIAN_CONSENT_DRAFT=1 scripts/qa/replica/build-and-test.sh` only on a dedicated disposable machine/CI runner. The parity check is against the recorded sanitized baseline fingerprint; the subsequent test applies local pending migrations and then the excluded draft SQL. Review `journeys.json`, `authz.json`, and `replica-fingerprint.txt`. The workflow does not upload local actor credentials.
