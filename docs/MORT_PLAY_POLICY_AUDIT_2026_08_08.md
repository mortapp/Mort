# MORT Google Play Policy Revalidation

Reviewed: 2026-08-08

Release boundary: Flutter `0.9.14+104`, package `com.mortapp.mobile`, closed
pilot, public marketplace disabled.

Status: CODE-CONTROLLED REQUIREMENTS VERIFIED; PLAY CONSOLE, HOSTED CONTACT,
LEGAL, MODERATION STAFFING, AND PUBLICATION APPROVALS REMAIN EXTERNAL.

This document is not a Play approval, legal opinion, Data Safety submission, or
content rating. The adult Play account owner must reconcile every declaration
against the exact accepted AAB and the hosted behavior visible during review.

## Current Official Requirements

| Area | Current official requirement | MORT result |
|---|---|---|
| Target API | Starting August 31, 2026, new mobile apps and updates must target Android 16 / API 36 or higher. | Code/build target is API 36; exact AAB inspection is required before upload. |
| 16 KB pages | New apps and updates targeting Android 15+ must support 16 KB page sizes. | Repository alignment QA exists; rerun against the final AAB/APK and retain the report. |
| Account deletion | Apps with account creation need an in-app deletion path and a functional web request resource. | In-app request, server processor, enumeration resistance, and public web source exist. HTTPS deployment and operational ownership remain external gates. |
| UGC | Terms acceptance, prohibited-content rules, reporting, blocking, and ongoing moderation appropriate to the UGC surface are required. | Versioned acceptance, separate report/block actions, moderation queues, appeals, and RLS are implemented. Trained and staffed moderation is not verified. |
| Child safety | Anonymous/random chat and apps declared Social or Dating have specific published-standards, feedback, CSAM/CSAE handling, legal-compliance, and contact obligations. | MORT does not provide anonymous or random chat. Child-safety standards and in-app feedback exist, but public deployment, final Play category, named contact, legal procedure, and staffing require owner/legal action. |
| Target audience | Ages 13-15 and 16-17 may still be children under local law; Console selections must accurately match the product. | Under-13 access is rejected; intended groups are 13-15, 16-17, and 18+. Owner/legal must confirm locale scope and Console answers. |
| Photos/video | Infrequent media access should use the system picker; broad `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` access requires a qualifying core use and declaration. | MORT uses user-initiated capture/picker flows and declares no broad media permission. |
| AI content | Generative AI experiences must prevent prohibited content and provide responsible feedback/reporting controls. | External generative AI is disabled in the closed pilot. Deterministic Support safety routing remains enabled and tested. Re-audit before enabling a provider. |
| Developer verification | Android apps must be registered to a developer with a verified identity under the 2026 rollout. | The package identity is preserved. Console identity/registration status cannot be verified from source and remains an owner-side gate. |

## Exact Release Boundary

- Real payments, ads, IAP, public marketplace access, production identity
  verification, external AI, remote push delivery, and crash/product analytics
  are disabled in the closed-test profile.
- Job-context one-to-one messaging is participant-scoped. Unsolicited global,
  anonymous, and random chat are not product features.
- Guardian Mode is optional and is not represented as universal legal consent.
- Exact home/job address release is staged and participant-scoped; nearby job
  distance is not calculated or displayed.
- Report, block, Safety Center, Support, and account deletion remain free and
  reachable without monetization.

## Console And Human Gates

- Complete Data Safety from the final AAB SDK inventory and hosted behavior.
- Complete Target Audience and IARC questionnaires without copying draft
  answers blindly.
- Publish attorney-reviewed privacy, terms, community, child-safety, deletion,
  and support resources over HTTPS; replace all contact placeholders.
- Provide durable reviewer access through Play Console only.
- Confirm the package remains registered to the verified developer account and
  that version code `104` is unused before upload.
- Designate and staff moderation, Support, safety escalation, and a child-safety
  point of contact before opening the marketplace.

## Official Sources

- Target API timeline:
  https://support.google.com/googleplay/android-developer/answer/11926878
- Target API policy:
  https://support.google.com/googleplay/android-developer/answer/16561298
- 16 KB page-size support:
  https://developer.android.com/guide/practices/page-sizes
- Account deletion:
  https://support.google.com/googleplay/android-developer/answer/13327111
- User-generated content:
  https://support.google.com/googleplay/android-developer/answer/9876937
- UGC moderation guidance:
  https://support.google.com/googleplay/android-developer/answer/12923286
- Child Safety Standards:
  https://support.google.com/googleplay/android-developer/answer/14747720
- Target audience settings:
  https://support.google.com/googleplay/android-developer/answer/9867159
- Photo and Video Permissions:
  https://support.google.com/googleplay/android-developer/answer/14115180
- AI-Generated Content:
  https://support.google.com/googleplay/android-developer/answer/14094294
- Android developer verification:
  https://developer.android.com/developer-verification

