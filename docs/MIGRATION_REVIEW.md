# Migration Review

Reviewed file: `supabase/migrations/202607070001_initial_mort.sql`.

## Tables Summary

The migration creates core profile, role, marketplace, messaging, safety, payment-preference, notification, support, admin-log, proof-upload, and business-verification tables. It also creates private Storage buckets for proof, verification, and report uploads.

Core app tables:

- `profiles`, `teen_profiles`, `adult_profiles`, `guardian_profiles`
- `guardian_connections`, `jobs`, `applications`
- `message_threads`, `conversations`, `conversation_participants`, `messages`
- `reports`, `blocks`, `safety_pings`
- `business_verifications`, `proof_uploads`
- `payment_preferences`, `push_tokens`
- `notifications`, `notification_events`
- `support_tickets`, `support_ticket_messages`, `admin_action_logs`

## Index Summary

The migration includes indexes for feed lookups, user-owned rows, participant lookups, moderation queues, push queues, proof uploads, support tickets, and common foreign-key paths. Extra FK/status indexes were added so fresh projects start closer to Supabase advisor expectations.

## RLS Summary

RLS is enabled on every public table. Policies keep profiles self/admin/linked-participant scoped, guardian teen access invite-linked, jobs visible when open or owned/participating/admin, applications participant-scoped, messages thread-participant-scoped, reports reporter/admin-scoped, push tokens and notifications recipient-scoped, and admin queues admin-only.

The migration grants authenticated table access so Supabase Data API requests can reach tables, then RLS policies decide row access. This matches Supabase's newer explicit-grant guidance for fresh projects.

## Triggers And Functions Summary

- `handle_new_auth_user` creates a profile row for new Supabase Auth users.
- `enforce_profile_completion` requires display name, DOB, role, city, and two-letter state before onboarding completes.
- Age rules block under-13 onboarding, restrict teens to 13-17, and require adult/guardian/admin roles to be 18+.
- `protect_profile_sensitive_fields` blocks admin self-selection, role changes after initial selection, user-edited verification/account status, and user-edited restrictions.
- `send_safe_message` scans messages before insert and blocks contact, payment, social, secrecy, and unsafe language.
- Notification triggers enqueue in-app and push-queue notifications for applications, proof uploads, safety pings, reports, and verification decisions.
- Admin status changes are logged in `admin_action_logs`.

## Storage Summary

The migration creates private buckets and Storage policies. Users upload under their own user-id folder. Proof records can only be created by the teen on an accepted application. Proof files can be selected for signed preview by application participants and admins. Verification and report files remain owner/admin visible unless additional reviewed policies are added.

## Known Assumptions

- This initial migration is intended for a fresh Supabase project, branch, or reviewed staging database.
- It assumes Supabase Auth is the only identity provider for the MVP.
- It assumes first admin promotion happens manually in trusted SQL/dashboard with `mort.internal_update` set for that transaction, not from the app.
- It assumes private Storage object paths use the first folder segment as `auth.uid()`.
- It was not applied to the existing live project in this pass because that project has an older mismatched schema.

## Fresh Project Apply

```powershell
supabase login
supabase link --project-ref <fresh-project-ref>
supabase db push
```

Then deploy the Edge Function:

```powershell
supabase functions deploy send-push
```

## Warning

Do not run this migration blindly against the existing mismatched live project. Use `docs/SUPABASE_SCHEMA_RECONCILIATION.md` first.
