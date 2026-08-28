# MORT Sensitive Document Vault

Status: technical foundation only. Real document collection and vault delivery are disabled. The `document-vault-access` Edge Function is prepared in source but must not be deployed for real evidence until all gates pass.

## Storage boundary

The `mort-document-vault` bucket is private, limited to JPEG, PNG, and PDF, and capped at 10 MiB. There is no authenticated user policy on `storage.objects` for this bucket. Mobile and web clients receive no service-role key, direct listing, public URL, raw path, or client-controlled approval.

Object metadata uses a random identifier, environment-separated path, evidence hash, MIME type, size, retention-delete date, preservation-lock status, case ID, and review metadata. Original filenames and raw evidence do not belong in profiles, public tables, analytics, logs, support tickets, or archives.

## Access exchange

1. A specialized reviewer authenticates and supplies case, object, action, and a specific reason.
2. The server verifies active assignment and conflict clearance, then records authorization and issues a one-time grant.
3. The Edge Function validates the user JWT, checks readiness, exchanges the grant with a server-only service role, verifies reviewer and case binding, and creates a private signed URL for at most 60 seconds.
4. The grant is consumed once and delivery is audited as view, download, or denied.

Signed URLs can remain valid until expiry, so the configured duration must remain short and evidence should be rendered without persistent caching where possible. A signed URL is not a public URL, but it is still a bearer capability during its lifetime.

## Least privilege

Only assigned `document_reviewer`, `senior_verification_reviewer`, `child_safety_specialist`, or `incident_manager` roles can request evidence access. Ordinary admins, partners, guardians, posters, teens, and founder/developer status have no automatic raw access. Super-admin business logic does not silently bypass the specialized access RPC.

## Retention and incidents

Deletion needs a tested queue, legal/preservation review, object deletion verification, metadata tombstone, and audit entry. Breach response must identify affected objects and access events without copying evidence into incident logs. No claim of encryption, legal compliance, or safe operation should exceed Supabase platform configuration and the organization controls actually verified.
