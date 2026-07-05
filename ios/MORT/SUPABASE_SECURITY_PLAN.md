# MORT Supabase Security Plan

## Core rules
- Public client keys only. Never use service_role in the client app.
- All sensitive write paths must be enforced by Row Level Security and, where needed, Edge Functions.

## RLS and access policies
- Conversation participants only: only users who are participants in a conversation may read or write its messages.
- Job applications visible only to the poster, the applicant teen, the linked active guardian for that applicant, and admin.
- Unique application per teen per job: enforce `unique(job_id, applicant_id)` on `job_applications`.
- `startJob` and `completeJob` must be implemented as Edge Functions, not client-side direct writes.
- Blocked users cannot message each other.
- `moderation_events` must be admin-only.
- `rate_limit_events` must be written only by Edge Functions.

## Notes
- Keep the mock/demo layer isolated from live Supabase services.
- The client should never bypass these rules by calling privileged tables directly.
