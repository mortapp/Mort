# MORT Verify Test Results

This document is updated as verification evidence is produced.

## Implemented automated contracts

- Teen verification status model keeps school, age, and identity results separate.
- Final client status is verified only when all required server results are verified.
- CI source contract asserts production gates remain off for closed-test/reviewer profiles.
- CI source contract asserts approval requires school affiliation plus school-ID/DOB age evidence.
- CI source contract asserts Storage helpers bind to auth.uid().
- CI source contract asserts review transitions require active assignment and raw-evidence access.
- CI source contract asserts retention is service-only and backed by a Storage-removal worker.

## Hosted schema checks

- New private verification tables: RLS enabled, no direct client policies.
- teen-school-id bucket: private, JPEG-only, 8 MB maximum.
- New public RPCs: anonymous execute revoked.
- SECURITY DEFINER functions: empty search_path.
- Retention worker deployed with JWT verification enabled and an additional service-role key comparison.

## Still required before production collection

- exact-head repository CI must pass,
- synthetic multi-user hosted tests must exercise cross-user Storage/RPC denial and reviewer-role boundaries,
- school-domain data for real institutions needs an approved source/review process,
- separate secondary school-email delivery is not configured,
- legal/privacy approval and trained reviewer operations remain false,
- physical Android QA is still required,
- production collection must remain disabled until all of the above are resolved.
