# MORT minimum-age and hybrid identity policy

## Non-negotiable eligibility rule

- MORT is strictly for people aged 13 or older.
- No account under age 13 may complete signup, onboarding, or access any role-protected MORT surface.
- No parent/guardian override, school document, or manual exception can make an under-13 user eligible.
- DOB is immutable after first save. Corrections require a separately authorized review process; do not add a self-service DOB edit.
- Role is derived from DOB: ages 13–17 are always `teen`; ages 18+ may be `adult` or `guardian`.
- A self-reported DOB is an eligibility screen, not independent proof of age. The separate age/identity verification gate remains pending until an approved provider or documented review flow is available.

## Email rules

- Ages 13–17: require a Supabase-confirmed mailbox on an exact, active domain in `private.school_email_domains`.
- Ages 18+: any normally confirmed email provider is acceptable, including personal email.
- School email is not proof of age and does not replace school identity evidence or independent age verification.
- Domain matching is exact; never infer parent domains, subdomains, or sibling domains.

## Hybrid identity evidence policy

### Ages 13–17

1. Verified school email on an approved exact domain.
2. Current school-issued student photo ID when the school issues one.
3. If the school does not issue a photo ID, accept official enrollment confirmation or direct confirmation from an authorized school administrator.
4. School email or school ID alone does not prove that the user is at least 13.

### Ages 18+

- Require a valid, unexpired government-issued photo ID: driver's license, state ID card, or passport.
- Do not accept school ID as a substitute for adult government ID.

## Backend RPC contract

- `save_my_initial_dob_v1(p_date_of_birth date)`
  - Authenticated only.
  - Rejects missing/future DOB and age below 13.
  - DOB is immutable once saved.
  - Returns `{ ok: true, age_band: 'minor' | 'adult', minimum_age: 13 }` on success.
  - Under-13 result: `{ ok: false, code: 'minimum_age_required', field: 'date_of_birth' }`.
- `save_my_onboarding_account_v2(...)`
  - Remains the authoritative onboarding save.
  - Rechecks DOB and derives role server-side.
  - For ages 13–17, requires a Supabase-confirmed school email whose exact domain is active in the private registry.
- `get_my_verification_requirements_v1()`
  - Authenticated only.
  - Returns the applicable evidence route and current provider availability.
  - Under-13/missing DOB is ineligible.
  - Teen options: `school_photo_id`, `official_enrollment_confirmation`.
  - Adult option: `government_photo_id`.
  - Currently reports `submissions_enabled: false` and `provider_status: 'unavailable'`.
  - Do not treat this response as proof of verification.

## Flutter implementation requirements for Codex

- Collect DOB at the beginning of signup, before role selection or account use.
- Validate DOB locally for clear feedback, but treat server RPC/database enforcement as authoritative.
- Pass `date_of_birth` metadata on email signup so the Auth profile bootstrap can reject under-13 DOBs in the same transaction. Ordinary email signup without DOB metadata is rejected with `MORT_DOB_REQUIRED` (except invited users).
- For OAuth signup, carry the DOB through the authenticated callback and call `save_my_initial_dob_v1` before navigating to onboarding. If it fails, sign out and do not enter the app.
- Do not trust a client-provided role. Display teen role for ages 13–17; only offer adult/guardian for ages 18+.
- Call `get_my_verification_requirements_v1()` and render the correct teen/adult evidence instructions.
- For teens, display school-email requirement and school-ID/enrollment-confirmation alternatives.
- For adults, display government-photo-ID requirement.
- Do not build an ID upload flow until a production verification provider, secure evidence storage, retention policy, reviewer workflow, and deletion controls are approved.
- Never upload identity documents to public buckets or store raw ID images in profile metadata.
- Keep the marketplace, publishing, and payments disabled until independent age assurance, identity verification, legal publication, backups, and all other release gates pass.

## Required tests

- Under-13 DOB rejected by signup UI and server action.
- Under-13 DOB metadata rejected by Auth profile bootstrap transaction.
- Under-13 DOB rejected by `save_my_initial_dob_v1` and `save_my_onboarding_account_v2`.
- 13th birthday today is eligible; one day before is not.
- Future and malformed DOB rejected.
- DOB cannot be changed or cleared after first save.
- Ages 13–17 always resolve to teen; an adult role cannot be assigned.
- Ages 18+ cannot remain teen.
- Minor with unconfirmed school email rejected.
- Minor with confirmed Gmail/unlisted domain rejected.
- Minor with confirmed approved exact school domain may proceed to pending review.
- Adult with confirmed personal email is not blocked by the school-email rule.
- Teen school photo ID and enrollment-confirmation options are displayed; adult government ID is displayed.
- No identity submission is accepted while the provider is unavailable.
- No under-13 account reaches any protected dashboard, API action, job application, or publishing route.

## Privacy and safety

- Collect only the minimum evidence required.
- Do not ask users to email IDs or upload them to MORT support.
- Prefer a specialist identity provider with document authenticity checks, age extraction, and liveness where appropriate.
- Use short retention, encryption, strict reviewer access, audit logs, and deletion controls for any future evidence.
