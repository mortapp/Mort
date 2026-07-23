# Flutter Repository Audit

All repositories inside `lib/data/repositories` have been audited.

1. **admin_repository.dart**: Implements `getAdminStats`, `listModerationQueues`, etc., mapping to Supabase RPCs.
2. **applications_repository.dart**: Implements `applyForJob`, `getJobApplications`, `updateApplicationStatus` correctly mapped to `applications` table.
3. **auth_repository.dart**: Implements Supabase Auth (`signInWithPassword`, `signUp`, `signOut`, `resetPasswordForEmail`).
4. **guardian_repository.dart**: Connects to `guardian_links` for link requests, approvals, and listing linked teens.
5. **jobs_repository.dart**: Implements CRUD for `jobs` (inserting, listing, listing by poster, getting single job).
6. **messaging_repository.dart**: Implements inserting into `messages` and reading from `conversations`.
7. **monetization_repository.dart**: Wraps `RevenueCatService` and Supabase Edge Function calls (or RPCs like `get_my_entitlements`, `consume_job_boost_credit`).
8. **notifications_repository.dart**: Maps to `notifications` table for unread counts and listing.
9. **profile_repository.dart**: Manages `profiles` reading and updating, including `onboarding_completed`.
10. **safety_repository.dart**: Connects to `safety_pings`, `reports`, and `blocks` tables.
11. **uploads_repository.dart**: Maps to Supabase Storage for avatar and proof uploads.

No fake data generators were found in the production repositories. All data uses the injected `SupabaseService.client`.
