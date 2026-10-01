# MORT school directory and email gate (redesign branch)

Status on 2026-09-30: code prepared and locally tested in a rolled-back PostgreSQL transaction. No hosted migration or student-domain approval has occurred. Build 114 is unchanged.

## Separation of concerns

- `public.schools` and `public.school_aliases` contain public school names, district, city, type, and an official source URL. Anonymous users can search **listed** schools. They cannot write entries or see suspended schools.
- `public.school_domains` remains the pre-existing private review record. A listed school does **not** imply that its website or staff email domain is valid for student accounts.
- `private.school_domain_assignments` is the additional exact school/domain decision with `student_allowed`, review evidence, and expiry. No production assignment is seeded.
- `private.teen_school_email_bindings` records a teen's chosen school and approved domain without putting the email or school name on a public profile. The current confirmed primary `auth.users.email` is rechecked whenever marketplace access is evaluated. A changed email or suspended assignment removes eligibility immediately.
- Teen role assignment and direct profile role writes require a current binding. Marketplace authorization also uses that binding for users under 18, including synthetic test accounts. Existing Safety, support, legal, and account-control authorization is untouched.

The directory migration lists 16 Indianapolis schools. Names were checked against their [school sites](https://www.herronriverside.org/), [Pike High School](https://phs.pike.k12.in.us/), [Lawrence Township](https://www.ltschools.org/schools), [Decatur Central](https://www.decaturproud.org/central-high), [Chapel Hill 7th & 8th Grade Center](https://chc.wayne.k12.in.us/about/about-us), [Ben Davis High School](https://bdhs.wayne.k12.in.us/), [North Central High School](https://nc.msdwt.k12.in.us/), and [Indianapolis Public Schools](https://www.myips.org/enrollment-options/high-school-options). Indiana Math and Science Academy West is listed by its [school site](https://west.imsaindy.org/). These sources establish names and locations only; none was used to approve a student email domain.

## Current account transition

An Auth identity may exist without a MORT role so a user can recover access to Safety and account controls. The age RPC stores DOB and rejects under-13 users. A teen role is granted only after the confirmed login email matches an approved exact domain assigned to the selected school. OAuth identities are subject to the same role and marketplace checks. Direct `profiles.role` writes are covered by a trigger. An existing teen without a current binding cannot start new marketplace activity; the account remains available for Safety and email replacement. School email is required only while the recorded age is under 18.

The Flutter signup/onboarding path and staff review queue still need to be connected before this can be considered an end-to-end strict teen signup feature. Existing role-less Auth identity creation is not blocked before email confirmation. Any future Auth hook for pre-creation rejection must be configured and tested separately; it is not claimed by these migrations.

## Local proof and limits

`supabase/tests/classic_school_directory.sql` and `classic_school_email_gate.sql` pass against `supabase_db_mort-mobile` after the new migrations, all inside `BEGIN`/`ROLLBACK`. Cases cover 16 listed names, alias search, anonymous read-only access, suspended school exclusion, no approved production domain, wrong school/personal email rejection, denied direct teen role assignment, confirmed email binding, synthetic sandbox marketplace access, email change, unconfirmed email, and suspended assignment. The local DB has no committed schema or data changes from this run.

The local database reports migration ledger head `20260925214000` while later Safety objects are present. The school dry run uses the database's actual current schema. It is not a hosted migration certificate. Hosted schema and any production student-domain evidence require separate review before deployment.
