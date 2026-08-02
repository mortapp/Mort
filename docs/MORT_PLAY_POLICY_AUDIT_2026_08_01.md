# MORT Google Play Policy Audit

Reviewed: 2026-08-01

Status: CODE AND DRAFT AUDIT COMPLETE; PLAY CONSOLE, LEGAL, CONTACT, STAFFING,
AND PUBLICATION APPROVALS INCOMPLETE

This is not a Play approval, legal opinion, Data Safety submission, content
rating, or production-readiness claim. It reviews current repository evidence
against current official Google Play guidance. The adult Play account owner
must reconcile every answer against the exact accepted AAB and hosted behavior.

## Current Release Boundary

- Intended target groups: 13-15, 16-17, and 18+; under 13 rejected.
- Job-context UGC and one-to-one messaging exist; anonymous/random chat and
  unsolicited global minor messaging are prohibited.
- Public marketplace and production identity verification are disabled.
- Real payments, ads, IAP, external AI, remote push delivery, and crash/product
  analytics are disabled.
- Guardian Mode is optional and is not represented as universal legal consent.

## Audit Results

| Area | Repository evidence | Current result | Required external action |
|---|---|---|---|
| App copy | Age gate, safety reminders, report/block, job-context messaging, identity/payment limits, deletion, and Support routes exist | CODE-CONTROLLED PASS | Physical-device and exact-release copy review |
| Terms and UGC | Versioned acceptance/re-consent engine; report/block; coded moderation; appeals; three new inactive legal drafts | CODE-CONTROLLED PASS, LEGAL PENDING | Attorney approval, publication, effective dates, trained ongoing moderation |
| Website | Privacy, terms, community, safety, child-safety, prohibited jobs, disputes, deletion, support, and contact pages exist in `web/public` | DEPLOYMENT BLOCKED | Deploy HTTPS; replace publisher/support/privacy/child-safety placeholders; test every URL |
| App access | Reviewer/demo architecture exists | CONSOLE PENDING | Owner enters durable reviewer access in Play Console only and verifies exact build |
| Data Safety | Source and backend workbooks exist; hosted Supabase collection is treated as collection | OWNER REVIEW PENDING | Scan exact AAB/SDKs and submit current form; include approximate/temporary precise location and any enabled provider |
| Target audience | Draft selects 13-15, 16-17, 18+ only | OWNER/LEGAL PENDING | Confirm local-law child treatment and accurate Families answers in Console |
| Content rating | UGC, messaging, limited location sharing, and harmful user reports are documented | CONSOLE PENDING | Complete IARC against every reachable feature and exact build |
| Child Safety | Public standards source and in-app feedback/reporting exist | OPERATIONS PENDING | Deploy standards, designate a named trained-adult point of contact, approve lawful CSAM/CSAE procedure |
| Account deletion | In-app request and public ownership-verified web request exist; processor architecture is deployed | URL/OPERATIONS PENDING | Deploy functional deletion URL, confirm processor secret/operations, approve retention exceptions |
| Privacy URL | Draft public page describes hosted backend, teen privacy, location, disabled providers, and deletion | DEPLOYMENT/LEGAL PENDING | Publish attorney-reviewed version over HTTPS with named privacy contact |
| Support contact | In-app Support exists; public page currently says contact pending | BLOCKED | Name, staff, publish, and monitor a truthful support route |
| Ads/IAP | Disabled for current boundary | PASS FOR DISABLED RELEASE ONLY | Re-audit Families, SDKs, Data Safety, consent, and declarations before activation |
| Location | Approximate/manual area and temporary foreground active-job location are documented; no background location | OWNER/LEGAL PENDING | Confirm exact artifact permissions and 2026 Data Safety precise/approximate answers |
| Third-party AI | External AI is disabled; deterministic Support remains | PASS FOR DISABLED RELEASE ONLY | New privacy, disclosure, consent, vendor, and Data Safety review before activation |

## Current Official Policy Findings

Google Play guidance reviewed on 2026-08-01:

- Families policy: accurate target audience, Data Safety, content rating, child
  data/SDK handling, age screening, social-feature safety reminders, and adult
  action where personal-information exchange requires it.
  https://support.google.com/googleplay/android-developer/answer/9893335
- Target audience: ages 13-15 and 16-17 may be children under local law; mixed
  audiences must be selected only when the app is designed for each group.
  https://support.google.com/googleplay/android-developer/answer/9867159
- UGC: terms must define prohibited content; reporting and blocking must be
  available; moderation must be ongoing and appropriate to the UGC surface.
  https://support.google.com/googleplay/android-developer/answer/9876937
- Child Safety Standards: in-scope apps need globally accessible standards,
  in-app feedback, lawful CSAM/CSAE handling, and a designated point of contact.
  MORT's final category and scope require owner/legal confirmation.
  https://support.google.com/googleplay/android-developer/answer/14747720
- Account deletion: an app that permits account creation needs an in-app
  deletion path and a functional public web request path, with transparent
  retention exceptions.
  https://support.google.com/googleplay/android-developer/answer/13327111
- July 15, 2026 update: Google clarified third-party AI User Data obligations,
  precise/approximate location Data Safety guidance, content rating, developer
  registration, and new anonymous/random-chat child-safety restrictions. MORT
  does not claim to be anonymous or random chat, but must still recheck these
  declarations before submission.
  https://support.google.com/googleplay/android-developer/answer/17134731

## Blocking Decisions

- Do not publish while public contacts contain placeholders.
- Do not open the public marketplace without attorney-approved documents,
  verified owner approval, trained moderation/support coverage, incident
  on-call ownership, production identity readiness, and approved Play answers.
- Do not infer Play Console completion from repository workbooks.
- Do not enable any provider or SDK without repeating the exact AAB, Data
  Safety, target-audience, consent, and privacy review.
- Do not classify the Supabase Free-plan leaked-password check as a code defect.
  It remains `DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT`; enable it
  immediately after a future Pro upgrade and rerun Auth security advisors.
