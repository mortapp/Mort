-- Priority FK and ownership indexes selected from the live advisor output.
-- Low-volume administrative attribution FKs are documented and deferred to
-- avoid adding write cost without a demonstrated lookup path.

create index if not exists abuse_flags_user_idx
  on public.abuse_flags (user_id);
create index if not exists ai_moderation_events_user_idx
  on public.ai_moderation_events (user_id, created_at desc);
create index if not exists ai_recommendation_events_user_idx
  on public.ai_recommendation_events (user_id, generated_at desc);
create index if not exists ai_risk_scores_job_idx
  on public.ai_risk_scores (job_id);
create index if not exists ai_rule_matches_event_idx
  on public.ai_rule_matches (event_id);
create index if not exists ai_support_sessions_user_idx
  on public.ai_support_sessions (user_id, created_at desc);

create index if not exists application_status_events_actor_idx
  on public.application_status_events (actor_id);
create index if not exists business_verifications_reviewed_by_idx
  on public.business_verifications (reviewed_by)
  where reviewed_by is not null;
create index if not exists conversations_job_idx
  on public.conversations (job_id);
create index if not exists job_status_events_actor_idx
  on public.job_status_events (actor_id);
create index if not exists job_templates_owner_idx
  on public.job_templates (owner_id);
create index if not exists job_templates_source_job_idx
  on public.job_templates (source_job_id)
  where source_job_id is not null;
create index if not exists message_threads_job_idx
  on public.message_threads (job_id);
create index if not exists messages_sender_idx
  on public.messages (sender_id);
create index if not exists moderation_events_moderator_idx
  on public.moderation_events (moderator_id);
create index if not exists moderation_events_target_user_idx
  on public.moderation_events (target_user_id);
create index if not exists notification_events_recipient_idx
  on public.notification_events (recipient_id, created_at desc);
create index if not exists reviews_reviewer_idx
  on public.reviews (reviewer_id, created_at desc);
create index if not exists reviews_subject_idx
  on public.reviews (subject_id, created_at desc);
create index if not exists saved_jobs_job_idx
  on public.saved_jobs (job_id);
create index if not exists support_ticket_messages_sender_idx
  on public.support_ticket_messages (sender_id);
create index if not exists username_reservations_user_idx
  on public.username_reservations (user_id);

create index if not exists boosted_jobs_purchaser_idx
  on public.boosted_jobs (purchaser_id, created_at desc);
create index if not exists boost_impressions_viewer_idx
  on public.boost_impressions (viewer_id, created_at desc);
