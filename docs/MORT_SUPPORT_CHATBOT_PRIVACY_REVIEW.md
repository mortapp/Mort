# MORT Support Chatbot Privacy Review

Date: 2026-07-29

## Data Processed

The support system can process authenticated user ID, role, support message
text, issue category, safety level, related MORT entity IDs, citations, feedback,
case state, audit events, and optional support attachments. It does not require
government ID, payment-card data, passwords, job PINs, verification codes, exact
home addresses, or private keys. The UI warns users not to upload those items.

## Storage And Visibility

- Conversations and messages are owner-only under forced RLS.
- Guardian Mode does not grant support-chat access.
- Human support staff use audited RPCs rather than direct table reads.
- Attachments are private, owner-bound, opaque-path objects with expiring signed
  access.
- Knowledge documents are approved MORT help content, not user conversations.
- Raw message text and attachment content are not written to Edge logs.
- The mobile app contains only public Supabase configuration.

## Retention

- Conversation retention defaults to 30 days and is constrained to 1 through
  90 days by the user preference model.
- Attachment deletion is scheduled for 90 days unless an authorized support or
  safety retention requirement applies.
- Upload authorization expires after 15 minutes.
- Soft deletion removes chat content while preserving required ticket/evidence
  audit relationships.
- The service-only retention function ran successfully against the hosted
  project.

## Provider Privacy

External AI is currently disabled, so no support conversation is sent to
Anthropic. If enabled later, only messages that pass deterministic levels 0 or
1 and approved knowledge excerpts may be sent. Level 2/3 safety content, human
handoff requests, restricted accounts, and deletion-pending accounts are
provider-ineligible. Provider configuration and credentials stay server-side.

## Attachment Test

Remote QA uploaded a generated JPEG through the private manifest flow, submitted
it, downloaded the same bytes through a signed URL, confirmed path opacity and
cross-user isolation, confirmed URL expiry, and removed the QA object. No real
identity document or user photo was used.

## Remaining Privacy Work

- Obtain legal review of retention periods, deletion exceptions, safety-case
  preservation, guardian expectations, and teen consent language.
- Update App Store and Play data-safety disclosures for support messages,
  attachments, diagnostics, and any later external AI processing.
- Document processor/subprocessor terms before enabling Anthropic.
- Add production operations for data-subject access, deletion exceptions,
  incident response, and staff least-privilege review.
- Test VoiceOver/TalkBack privacy announcements and physical-device screenshot,
  notification-preview, camera, and photo-picker behavior.

