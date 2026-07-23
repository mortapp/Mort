# MORT Support System

Status: implemented for closed testing with deterministic fallback and human escalation.

- Searchable approved help articles and guided categories.
- Private support conversations, messages, links, assignments, status events, audit records, feedback, and attachments.
- Case references use the `MORT-CASE-...` format.
- Requesters cannot assign themselves, impersonate staff, or mutate staff-owned state.
- Support evidence uses a private bucket, ownership checks, manifests, short-lived signed URLs, and server rate limits.
- Email fallback opens a draft to `mortapp.help@gmail.com`, includes the case reference and account context, warns against sending secrets, and never claims receipt or automatic attachment import.
- Safety-critical language diverts to the Safety Center/emergency guidance and a human-support route.
- Admin support access is assignment- and role-authorized.

External AI is disabled. Support remains functional through deterministic FAQ search, guided help, case creation, evidence upload, and human escalation.
