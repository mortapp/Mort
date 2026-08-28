# MORT Partner Organization System

## Scope

The hosted schema supports schools, online schools, vocational programs, nonprofits, youth programs, community centers, and workforce programs through `partner_organizations`, `partner_domains`, `partner_programs`, `partner_invite_codes`, `partner_memberships`, `partner_verification_requests`, and `partner_audit_events`.

Organization creation and approval are restricted to the `affiliation_reviewer` role. Review access requires a reason and case ID and creates an audit record. Partner roles do not provide access to unrelated teens, messages, private addresses, identity evidence, or unrestricted activity.

## Invite-code controls

- only a SHA-256 code hash and a short non-secret prefix are stored
- expiry and usage limit are required
- revocation is supported
- redemption is atomic and idempotent
- the user and organization must share the same sandbox/production environment
- a code grants affiliation only and never grants production identity or marketplace access by itself
- membership and trust signals can expire or be revoked
- users may hide the public affiliation indicator without deleting the private audit record

No production partner is approved by the migration. Organization verification, staff onboarding, data-processing terms, support boundaries, and participant communications require an operational and legal review before use with real programs.
