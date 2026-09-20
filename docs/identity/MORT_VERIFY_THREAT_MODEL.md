# MORT Verify Threat Model

## Protected assets

- minor school-ID images
- school affiliation
- claimed and reviewed age band
- reviewer decisions
- internal review/audit state

## Primary threats and controls

**Self-verification forgery.** Private state has no client table access. Final decisions require reviewer-only RPCs and a trigger that verifies assignment plus document access.

**Cross-user ID theft.** Storage upload paths are owner/session bound. Reads have no owner-facing public policy; reviewer reads require current role, assignment, and short-lived grant.

**Reviewer misuse.** Queue access requires role, case ID, and access reason. Document access is separately granted and expires. Decisions revoke assignments and evidence grants after use.

**School-email overclaiming.** A school-domain signal is only affiliation. It never proves age by itself and never grants marketplace access alone.

**Age guessing.** Approval requires reviewed DOB evidence that independently supports the same 13–15 or 16–17 band. Otherwise age remains unresolved.

**Duplicate/replayed document.** Exact processed-image SHA-256 reuse across accounts is flagged for review. It is a risk signal, not automatic guilt or automatic rejection.

**Indefinite raw-document retention.** Evidence gets a deletion deadline and a service-only purge path. Active review grants temporarily prevent cleanup; explicit preservation can extend retention.

**Production accidental activation.** Production submissions require server control mode production plus legal, privacy, reviewer-readiness, and production-enable flags. Default state is sandbox/fail-closed.

## Known limitations

Exact image hashing does not detect perceptually similar photos, crops, or re-photographed IDs. No automated face-recognition decision is made. No model is allowed to independently establish legal identity or age.

A separate school-email address challenge is not yet delivered by a transactional-email provider; the current affiliation route requires the confirmed MORT account email itself to be the approved school email. This limitation must remain visible until a dedicated delivery adapter is configured and tested.
