# MORT Verify Architecture

## Purpose

MORT Verify is a teen-specific verification subsystem for ages 13–17. It keeps three claims separate:

- school affiliation
- age-band assurance
- identity assurance

No single school-domain signal grants marketplace access, and a school email does not prove age.

## Current deployment state

The hosted schema is installed, but production collection is disabled. The control row defaults to sandbox mode and requires legal approval, privacy approval, trained reviewers, and an explicit production enable before ordinary accounts can submit real school-ID evidence.

Synthetic/test accounts can exercise the sandbox path without opening the public marketplace or payments.

## Verification flow

A teen session starts from the DOB already stored on the account. Under-13 and 18+ claims are rejected from the teen flow. A session records only the claimed band 13–15 or 16–17.

School affiliation uses the existing approved school-domain system. The account email must already be confirmed by Supabase Auth and match an approved school/program domain. Unknown domains go to restricted affiliation review and grant no trust signal.

School-ID capture is normalized on-device before upload: orientation is baked, dimensions are capped, and the image is re-encoded as JPEG. The object is written to a private user/session path in the private teen-school-id bucket.

The teen then submits the session to a restricted verification queue. A reviewer must claim the case, obtain a short-lived document grant, and inspect the evidence before a decision can change verification state.

Approval requires all of the following:
- verified school affiliation
- current school ID
- school matches the affiliation
- name match
- no suspected tampering
- usable DOB evidence on the reviewed ID
- observed age band matches the account-derived teen band

If the school ID does not independently support age, the result is age_evidence_required rather than guessed or auto-approved.

## Trust boundaries

Client code cannot update private verification state directly. Authoritative state changes occur through SECURITY DEFINER RPCs with a pinned empty search_path and caller/role checks.

Raw school-ID objects are never public profile data. Reviewer reads require both an active review assignment and an unexpired document access grant.

Production identity-provider activation, live marketplace payments, public marketplace activation, ads/IAP, and external AI are not enabled by this feature.
