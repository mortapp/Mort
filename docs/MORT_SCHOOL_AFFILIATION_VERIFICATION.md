# MORT School Affiliation Verification

## Implemented zero-budget path

A signed-in teen may call `request_school_email_affiliation` only with the already-confirmed Supabase Auth email on that account. The normalized domain must be an approved `school_domains` record in the same verification environment. An approved domain creates an affiliation signal; an unknown production domain creates a pending restricted review request and grants nothing.

The only seeded domain is synthetic `mort.test` sandbox data for QA. No real school is pre-approved.

## Meaning and privacy

School email verification confirms access to an approved school or program account. It does not equal government ID verification, prove age/enrollment, authenticate a document, or guarantee safety. School name is private by default, there is no public school-based user search, and the system does not use school affiliation for advertising.

Admin domain decisions require the `affiliation_reviewer` role, an access reason, a case ID, an official HTTPS source, environment binding, an audit event, and an expiry. Ordinary users cannot create or approve domains. Manual document evidence remains disabled until legal/privacy review, trained reviewers, retention/deletion policy, and secure evidence operations exist.
