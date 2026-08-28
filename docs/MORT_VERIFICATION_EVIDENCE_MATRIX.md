# MORT Verification Evidence Matrix

Status: future provider/policy design reference only. None of these identity-document routes are active or accepted by the hosted app. Current mode is disabled, sandbox is document-free QA only, and final acceptable evidence requires an approved provider, legal review, retention/deletion controls, trained staff, and production testing.

| Account path | Evidence route | Minimum evidence | Required result set | Public output | Reviewer access |
| --- | --- | --- | --- | --- | --- |
| Teen primary | School photo ID | Current school photo credential plus ownership evidence when required | age 13-17, identity matched, ownership/liveness passed, email verified | Identity verified, age-band eligible, expiration only | Verification reviewer or senior safety moderator through logged grant |
| Teen alternative | State ID, learner permit, passport, or passport card | Government credential plus ownership evidence | age 13-17, identity matched, ownership/liveness passed, email verified | Same as teen primary | Same restricted grant |
| Teen school account | Verified school account | Provider assertion or controlled school-account evidence | age 13-17, account control established, email verified, manual review as required | Same as teen primary; no school name | Metadata queue plus restricted evidence only if collected |
| Teen program | Accredited program or youth-organization ID | Current program credential and ownership evidence | age 13-17, program validity reviewed, ownership result, email verified | Same as teen primary; no program name | Restricted grant |
| Teen exception | Manual trusted-referee review | Written exception reason; contact is collected only through an approved future process | manual review, age evidence, identity corroboration, documented decision | Verification status only | Verification reviewer; no automatic approval |
| Adult | Government ID | Driver license, state ID, passport, passport card, or approved equivalent; ownership evidence; private address document if needed | age 18+, identity match, liveness/ownership, email, phone, address validation | Identity verified, adult age band, expiration | Verification reviewer or senior safety moderator through logged grant |
| Business | Owner identity plus business evidence | Verified owner identity and separate business document submitted through business verification | owner identity verified; business name/type/document reviewed | Business verification status and safe business label | Admin business queue under business RLS; identity evidence remains separate |

## Reserved Schema Values - Not Active Intake

The schema retains historical/future enum values including `school_photo_id`, `drivers_license`, `state_id`, `learner_permit`, `passport`, `passport_card`, `other_government_id`, `school_account_assertion`, `accredited_program_id`, `youth_organization_id`, `homeschool_document`, `supporting_document`, `ownership_selfie`, and `address_document`. Their presence does not authorize collection. Server-side Storage and RPC controls reject identity-document intake in disabled and sandbox modes.

## Collection Rules

- Current collection rule: collect no real identity document or identity selfie.
- Collect the minimum evidence needed for the selected route.
- Do not put school name, student number, full ID number, residence, document path, or image in a public profile.
- Reject unsupported MIME types, oversized objects, malformed paths, path traversal, and duplicate registration conflicts.
- Hashes are server-associated integrity and duplicate-review signals, not public identifiers and not proof of authenticity by themselves.
- Manual exception routes require human review and never become automatic acceptance.

## Not Yet Implemented As A Verified Result

Automated document authenticity, NFC/chip validation, authoritative school-account federation, vendor liveness, phone ownership, address provider validation, and background screening are not connected. The production provider implementation is unavailable, and the UI must not request documents or display vendor-backed claims until every production gate is live.
