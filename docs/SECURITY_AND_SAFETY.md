# Security and Safety

- Supabase Auth only. No Clerk, fake auth helpers, mock current-user IDs, or hardcoded admin IDs.
- No service-role key is used in Expo/mobile code.
- RLS is enabled on user-data tables.
- Admin route access is guarded in UI and enforced by RLS.
- DOB and completed onboarding are enforced in the database.
- Under-13 users are blocked. Teen role is 13-17. Adult/guardian/admin require 18+.
- Guardian Mode can pause linked teen apply/message activity.
- Messaging is sent through `send_safe_message`, checks participants, blocks paused teens, blocks blocked-user pairs, and scans unsafe content.
- Reports, blocks, safety pings, support, notification events, and admin action logs are first-class records.
- Proof, verification, and report buckets are private. Proof previews use signed URLs.

Old project rebuild note: `rakjydmgwwgtdislanbt` was rebuilt and remote smoke/RLS verified on 2026-07-08. That confirms backend behavior for the current baseline only; it does not approve real-user launch.

Required production work remains: legal review for teen labor, parental consent/privacy, App Store UGC moderation review, incident response, support operations, and jurisdiction-specific safety policy.
