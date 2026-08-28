# Supabase Performance Hardening

- Project: `rakjydmgwwgtdislanbt`
- Snapshot: 2026-07-14 UTC
- Method: live advisor baseline, pre-change catalog backup, explicit additive migrations, CLI dry runs, remote apply, full backend QA, then final advisor rerun.

## Before and after

| Finding | Before | Final | Outcome |
|---|---:|---:|---|
| Performance WARN | 83 | 0 | All warning-level findings resolved |
| Performance INFO | 43 | 28 | 15 fewer after QA exercised indexes |
| `auth_rls_initplan` | 43 | 0 | Fixed with scalar `(select auth.uid())` evaluation |
| `multiple_permissive_policies` | 40 | 0 | Consolidated or split by command without weakening RLS |
| Unindexed foreign keys | 31 | 7 | 24 priority FK/ownership paths indexed; 7 low-volume paths deferred |
| Unused indexes | 12 | 21 | No blind removals; 24 indexes were added and 15 candidates recorded scans during QA |

The INFO count is not a failure count. `unused_index` is based on current statistics, and this project does not yet have representative real-user traffic. Removing indexes now would substitute guesswork for evidence.

## Applied migrations

- `20260714031706_optimize_rls_policies.sql`: removes all 43 repeated-auth init-plan warnings and all 40 multiple-permissive-policy warnings.
- `20260714031709_add_priority_foreign_key_indexes.sql`: adds 24 selected FK, ownership, relationship, timeline, and moderation indexes.
- `20260714034330_fix_conversation_participant_rls_recursion.sql`: removes recursive self-reference from conversation membership RLS.
- `20260714034602_fix_saved_jobs_rls_recursion.sql`: breaks the `saved_jobs`/`jobs` circular policy graph with a caller-bound private helper.
- `20260714035408_restrict_remaining_public_policies_to_authenticated.sql`: narrows nine legacy policy roles and preserves one permissive policy per role/action.
- `20260714044100_fix_job_safety_word_boundaries.sql`: post-audit business-logic fix that preserves the roof-work block without rejecting legitimate proof wording; it does not change RLS or index behavior.

## Added indexes

- `abuse_flags_user_idx`
- `ai_moderation_events_user_idx`
- `ai_recommendation_events_user_idx`
- `ai_risk_scores_job_idx`
- `ai_rule_matches_event_idx`
- `ai_support_sessions_user_idx`
- `application_status_events_actor_idx`
- `business_verifications_reviewed_by_idx`
- `conversations_job_idx`
- `job_status_events_actor_idx`
- `job_templates_owner_idx`
- `job_templates_source_job_idx`
- `message_threads_job_idx`
- `messages_sender_idx`
- `moderation_events_moderator_idx`
- `moderation_events_target_user_idx`
- `notification_events_recipient_idx`
- `reviews_reviewer_idx`
- `reviews_subject_idx`
- `saved_jobs_job_idx`
- `support_ticket_messages_sender_idx`
- `username_reservations_user_idx`
- `boosted_jobs_purchaser_idx`
- `boost_impressions_viewer_idx`

Selection rationale:
- Prioritized owner, participant, recipient, reviewer, moderation, and timeline lookups used by RLS or user-facing queries.
- Preserved unique constraints and existing composite indexes.
- Used partial indexes only where null/non-active rows would otherwise add avoidable write/storage cost.
- Did not add seven attribution/reviewer indexes without a demonstrated read/delete path.

## Final unindexed FK findings

1. Table `public.ad_click_events` has a foreign key `ad_click_events_impression_id_fkey` without a covering index. This can lead to suboptimal query performance. Status: deferred until a real query/delete path or `EXPLAIN` plan demonstrates value.
2. Table `public.boosted_jobs` has a foreign key `boosted_jobs_reviewed_by_fkey` without a covering index. This can lead to suboptimal query performance. Status: deferred until a real query/delete path or `EXPLAIN` plan demonstrates value.
3. Table `public.jurisdiction_guardian_policies` has a foreign key `jurisdiction_guardian_policies_created_by_fkey` without a covering index. This can lead to suboptimal query performance. Status: deferred until a real query/delete path or `EXPLAIN` plan demonstrates value.
4. Table `public.monetization_experiments` has a foreign key `monetization_experiments_created_by_fkey` without a covering index. This can lead to suboptimal query performance. Status: deferred until a real query/delete path or `EXPLAIN` plan demonstrates value.
5. Table `public.username_change_events` has a foreign key `username_change_events_reviewed_by_fkey` without a covering index. This can lead to suboptimal query performance. Status: deferred until a real query/delete path or `EXPLAIN` plan demonstrates value.
6. Table `public.username_moderation_flags` has a foreign key `username_moderation_flags_event_id_fkey` without a covering index. This can lead to suboptimal query performance. Status: deferred until a real query/delete path or `EXPLAIN` plan demonstrates value.
7. Table `public.username_moderation_flags` has a foreign key `username_moderation_flags_resolved_by_fkey` without a covering index. This can lead to suboptimal query performance. Status: deferred until a real query/delete path or `EXPLAIN` plan demonstrates value.

These seven relationships are low-frequency attribution, review, experiment-author, or moderation links. An index is cheap to add later but has permanent write and storage cost. Recheck before launch and after representative staging traffic.

## Final unused-index findings

1. Index `jobs_status_city_idx` on table `public.jobs` has not been used. Status: observe; do not remove before representative traffic.
2. Index `profiles_verification_status_idx` on table `public.profiles` has not been used. Status: observe; do not remove before representative traffic.
3. Index `message_threads_participants_idx` on table `public.message_threads` has not been used. Status: observe; do not remove before representative traffic.
4. Index `reports_status_created_idx` on table `public.reports` has not been used. Status: observe; do not remove before representative traffic.
5. Index `reports_target_user_idx` on table `public.reports` has not been used. Status: observe; do not remove before representative traffic.
6. Index `reports_target_job_idx` on table `public.reports` has not been used. Status: observe; do not remove before representative traffic.
7. Index `reports_target_message_idx` on table `public.reports` has not been used. Status: observe; do not remove before representative traffic.
8. Index `monetization_entitlements_cache_refreshed_idx` on table `public.monetization_entitlements_cache` has not been used. Status: observe; do not remove before representative traffic.
9. Index `boosted_jobs_active_idx` on table `public.boosted_jobs` has not been used. Status: observe; do not remove before representative traffic.
10. Index `boost_impressions_boost_idx` on table `public.boost_impressions` has not been used. Status: observe; do not remove before representative traffic.
11. Index `username_moderation_flags_open_idx` on table `public.username_moderation_flags` has not been used. Status: observe; do not remove before representative traffic.
12. Index `ai_rule_matches_event_idx` on table `public.ai_rule_matches` has not been used. Status: observe; do not remove before representative traffic.
13. Index `application_status_events_actor_idx` on table `public.application_status_events` has not been used. Status: observe; do not remove before representative traffic.
14. Index `business_verifications_reviewed_by_idx` on table `public.business_verifications` has not been used. Status: observe; do not remove before representative traffic.
15. Index `conversations_job_idx` on table `public.conversations` has not been used. Status: observe; do not remove before representative traffic.
16. Index `job_status_events_actor_idx` on table `public.job_status_events` has not been used. Status: observe; do not remove before representative traffic.
17. Index `message_threads_job_idx` on table `public.message_threads` has not been used. Status: observe; do not remove before representative traffic.
18. Index `messages_sender_idx` on table `public.messages` has not been used. Status: observe; do not remove before representative traffic.
19. Index `reports_target_review_idx` on table `public.reports` has not been used. Status: observe; do not remove before representative traffic.
20. Index `username_reservations_user_idx` on table `public.username_reservations` has not been used. Status: observe; do not remove before representative traffic.
21. Index `boosted_jobs_purchaser_idx` on table `public.boosted_jobs` has not been used. Status: observe; do not remove before representative traffic.

## RLS performance changes

- Replaced per-row `auth.uid()` evaluation with stable scalar subqueries in all advisor-flagged policies.
- Consolidated overlapping permissive policies or separated INSERT/UPDATE/DELETE admin paths.
- Retained relationship checks for application participants, active guardians, thread participants, recipients, and test-account isolation.
- Repaired two circular policy graphs found by real PostgREST QA, not by the advisor.
- Final advisor has no `auth_rls_initplan` or `multiple_permissive_policies` rows.

## Change controls

- Pre-change backup: `backups/remote-feature-schema-rakjydmgwwgtdislanbt-2026-07-14T03-07-16-645Z.json`.
- Every migration was inspected locally and run with `supabase db push --linked --dry-run` before apply.
- No reset, drop, truncate, destructive migration repair, or real-user cleanup was used.
- The first index push failed safely before applying because `ai_recommendation_events` uses `generated_at`, not `created_at`; the migration was corrected and dry-run/apply then passed.
- Full remote feature, smoke, RLS, monetization, credit, rate-limit, and 30-case multi-user suites passed after the RLS/performance migrations. Focused application QA passed again after the later scanner word-boundary migration.

## Future measurement

1. Capture representative staging traffic before removing any index.
2. Inspect `pg_stat_user_indexes`, slow query logs, and `EXPLAIN (ANALYZE, BUFFERS)` for feed, application, messaging, notification, moderation, and admin queries.
3. Add one of the seven deferred FK indexes only when a query/delete plan demonstrates it.
4. Re-run both Supabase advisors after each schema or policy migration.
5. Do not treat an INFO-only advisor result as proof of launch readiness.
