# Marketplace safety contract verification plan

## Scope
Application submission/state, private job location, server-computed distance bands, and block-aware messaging. This change does not enable the marketplace, publishing, payments, or Stripe.

## Production facts captured read-only (2026-10-31)
- Target project: jxbnrkasktbhtiujkhay.
- Jobs, job_applications, messages, conversations, conversation_members, and user_blocks have RLS enabled and forced.
- Authenticated has SELECT-only grants on job_applications and messages. Direct application INSERT and message INSERT are not granted.
- job_applications(job_id, applicant_id) already has a unique constraint.
- mort_submit_job_application already checks teen role, active account, DOB/age range, age verification, own-job prevention, and blocks. It does not recheck the eligibility RPC's guardian requirement, release gate, applications_open flag, expiry, or active poster status in its own transaction.
- update_my_job_application_status locks the application row and limits actions to poster view/shortlist/reject/accept and applicant withdraw from submitted/shortlisted. Acceptance delegates to the existing assignment workflow.
- mort_send_message checks blocks, but its check is not serialized against a concurrent block insert.
- jobs.exact_address is on the API-exposed jobs table. No private job-location or user-coordinate table exists. The live jobs table had zero rows and zero non-null exact addresses at inspection.
- profiles has city/region/approximate_area but no trusted coordinate origin. PostGIS is not installed.

## Candidate contracts
1. Submission calls the existing eligibility RPC in-transaction after locking the job, then rechecks open/approved/applications-open/expiry/active-poster. The existing unique constraint is the duplicate race guard.
2. Application status stays on the existing row-locking RPC and existing enum; no second state machine is introduced.
3. Exact addresses move to private.job_locations; jobs.exact_address is forced NULL. Exact location is returned only to poster, accepted applicant, or staff.
4. Geocoder output is ingested through service-role-only functions. Client distance values and raw coordinates are never accepted or returned. The teen distance RPC returns coarse bands.
5. Message inserts and block writes take the same deterministic transaction advisory lock per user pair. The message trigger checks both block directions after the lock.

## Required verification before production
- Apply the candidate migration to a local Supabase database matching production migrations. Do not use production as a test target.
- Run the catalog assertions in supabase/tests/marketplace_safety_contracts.sql and the repository's pgTAP/database test suite.
- Fixture tests: eligible teen submit; underage/unverified/inactive teen; missing guardian for guardian-required job; closed/unapproved/expired/application-closed job; inactive poster; self-application; both block directions; duplicate concurrent application; allowed and forbidden application transitions; private-address access for poster/accepted applicant/staff versus unrelated teen; no raw coordinates in API output; geocoder writes denied to anon/authenticated; missing origin and each distance band.
- Use two independent database sessions for send-vs-block race tests in both directions. Confirm the transaction acquiring the pair lock after block commit cannot insert a message.
- Audit every app and Edge Function call site that reads jobs.exact_address, submits applications, reads distance, or sends messages. Job create/edit RPCs must stop writing jobs.exact_address and use the private location workflow.
- Run Supabase security and performance advisors after the isolated migration.
- Keep public_marketplace_closed=true, new_job_publishing_disabled=true, and payment controls disabled until all tests and call-site audits pass.

## Known blockers
- No trusted geocoder or consented approximate teen-origin source is currently present. The candidate private origin table requires consent_at and consent_version, and its ingestion RPC rejects non-teen/inactive users. The service-role ingestion functions define the trust boundary; they are not a geocoding provider. Distance bands cannot be enabled until a vetted geocoder and origin-consent flow are connected.
- Existing job create/edit RPCs must be audited and updated to store exact addresses through the service-role-only private.set_job_private_address path. The NULL constraint intentionally fails closed until that integration is complete.
- The catalog test is not a substitute for fixture-driven authorization and concurrency tests. Those tests have not been run here: no paid Supabase branch was created, and this session has no local Docker/Postgres runtime.
