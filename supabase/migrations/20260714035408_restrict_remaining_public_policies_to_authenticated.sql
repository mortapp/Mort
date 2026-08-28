-- Table grants already excluded anon, but these legacy policies still targeted
-- PUBLIC. Narrow the policy role as defense in depth so a future grant cannot
-- accidentally activate private reads or moderation writes for anonymous users.
alter policy admin_action_logs_select_admin
on public.admin_action_logs to authenticated;

alter policy applications_select_participant
on public.applications to authenticated;

alter policy business_verifications_update_admin
on public.business_verifications to authenticated;

alter policy message_threads_select_participant
on public.message_threads to authenticated;

alter policy message_threads_update_participant
on public.message_threads to authenticated;

alter policy messages_select_thread_participant
on public.messages to authenticated;

alter policy notification_events_update_admin
on public.notification_events to authenticated;

alter policy proof_uploads_select_participant
on public.proof_uploads to authenticated;

alter policy reports_update_admin
on public.reports to authenticated;
