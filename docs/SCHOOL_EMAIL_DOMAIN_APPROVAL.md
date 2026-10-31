# MORT school email domain approval

## Policy

- Users aged 13–17 must use a confirmed email address whose exact domain is active in `private.school_email_domains`.
- Users aged 18 or older may use ordinary personal email providers, subject to normal Supabase email confirmation and MORT review.
- A school email is not proof of age and does not replace identity/age verification, account review, guardian safeguards, or release approval.
- Domain matching is exact. No wildcard, parent-domain inheritance, or public email-provider exception exists.
- The registry is fail-closed. An empty registry means no minor can complete account onboarding until a school domain has been reviewed and approved.

## Approval procedure

An authorized MORT operator must verify each domain before activating it:

1. Confirm the school is a real, currently operating educational institution using an official school or district website.
2. Confirm the exact email domain is published by that institution or confirmed by its IT administrator through an independently verified institutional contact.
3. Confirm the institution actually issues student mailboxes on that exact domain. A domain merely owned by a school, vendor, alumni group, or parent organization is not enough.
4. Record the official evidence URL or the independently verified administrator confirmation in `verification_source`.
5. Activate only the exact domain. Do not activate broad hosting providers, shared district/vendor domains, or consumer email domains.
6. Re-review when a school changes providers or the evidence becomes stale. Suspend a domain immediately if control or eligibility is uncertain.

Never approve a domain based only on a user-submitted email address, screenshot, or claim. Do not add a domain to make a test account pass.

## Operator activation

Run this only after the evidence review above. Use a trusted Supabase dashboard session for the active production project `jxbnrkasktbhtiujkhay`. Do not expose service-role credentials to clients.

```sql
insert into private.school_email_domains (
  domain, school_name, status, verification_source, verified_at, approved_by
)
values (
  'exact-school-domain.edu',
  'Official school name',
  'active',
  'https://official-school-site.example/email-information',
  now(),
  auth.uid()
)
on conflict (domain) do update
set school_name = excluded.school_name,
    status = 'active',
    verification_source = excluded.verification_source,
    verified_at = excluded.verified_at,
    approved_by = excluded.approved_by,
    updated_at = now();
```

Replace every example value with verified evidence. Do not run the example literally.

To suspend a domain:

```sql
update private.school_email_domains
set status = 'suspended', updated_at = now()
where domain = 'exact-school-domain.edu';
```

## Enforcement

The production onboarding RPC derives minor status from DOB, requires `auth.users.email_confirmed_at`, and checks the exact email domain against this registry. A database trigger rejects an email change to a non-approved domain for profiles whose stored DOB indicates age 13–17.

Supabase email confirmation remains responsible for proving mailbox access. Do not set `email_confirmed_at` manually. A school-domain approval alone does not verify an individual mailbox.

## Required release tests

Before considering the policy complete, test through real authenticated signup/onboarding and email-change flows:

- Minor + confirmed Gmail: rejected with `school_email_required`.
- Minor + unconfirmed school mailbox: rejected with `school_email_verification_required`.
- Minor + confirmed mailbox on an unlisted domain: rejected with `school_email_required`.
- Minor + confirmed mailbox on an approved exact domain: may continue to the normal pending-review state; age verification and review remain pending.
- Minor changes email to Gmail or another unapproved domain: database rejects the email update.
- Adult + confirmed Gmail: allowed through the school-email gate and still subject to all other checks.

A SQL helper check is not a substitute for these end-to-end tests. Keep marketplace publishing, marketplace access, and payments disabled until every independent production release gate is approved.
