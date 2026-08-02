# MORT App Store Submission Packet

This packet is a draft for owner review. It is not an App Store submission and
does not claim Apple approval.

## App Identity

| Field | Value |
|---|---|
| Name | MORT |
| Bundle ID | `com.mortapp.mobile` |
| Version/build | `0.9.12 (102)` |
| Category | Teen-safe local jobs marketplace |
| Release scope | Closed test; public marketplace closed |
| Backend | Hosted Supabase project `rakjydmgwwgtdislanbt` |

## Review Notes

MORT lets users 13-17 discover age-appropriate local work while adults and
businesses can post and review applications. Guardian Mode is optional. The
build includes reporting, blocking, Safety Ping, PIN start/end confirmation,
private proof upload, safety-scanned messaging, account restriction, account
deletion, and role-authorized administration.

This candidate does not process payments, hold funds, provide escrow, collect
real identity documents, run production identity verification, deliver remote
push, show ads, sell IAP, or claim staffed emergency response. Disabled screens
state those limits. The public marketplace remains closed.

## Required Metadata

- Owner-approved subtitle, keywords, description, support URL, marketing URL,
  privacy URL, and account-deletion URL.
- iPhone screenshots from the real submitted build, including accessibility and
  closed-test state where relevant.
- Accurate age rating and child-safety/UGC declarations.
- App Privacy answers mapped to the current SDK inventory and hosted data model.
- Review credentials entered only in App Store Connect, never this document.
- Contact person authorized to answer safety, privacy, and review questions.

## Permission Copy

- Camera: capture job proof, profile photos, or a safety attachment when chosen.
- Photo library: select job proof, a profile photo, or a safety attachment when chosen.

Location and notification prompts must be tested at point of use. The current
closed-test release does not enable production remote notification delivery.

## External Approval Gates

Apple Developer membership, signing, macOS/Xcode archive, physical iPhone QA,
TestFlight/Beta App Review, legal/privacy/teen-safety approval, named support and
moderation staffing, and App Review are not completed.
