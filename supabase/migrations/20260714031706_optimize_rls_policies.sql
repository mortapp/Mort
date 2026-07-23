-- Preserve MORT's authorization model while avoiding per-row auth function
-- evaluation and overlapping permissive SELECT policies.

alter policy profiles_insert_self on public.profiles
to authenticated
with check (id = (select auth.uid()));

alter policy profiles_select_visible on public.profiles
to authenticated
using (
  id = (select auth.uid())
  or public.is_admin()
  or exists (
    select 1
    from public.guardian_connections connection
    where connection.status = 'active'
      and (
        (connection.teen_id = profiles.id and connection.guardian_id = (select auth.uid()))
        or (connection.guardian_id = profiles.id and connection.teen_id = (select auth.uid()))
      )
  )
  or exists (
    select 1
    from public.applications application
    join public.jobs job on job.id = application.job_id
    where application.teen_id = profiles.id
      and job.poster_id = (select auth.uid())
  )
);

alter policy profiles_update_self_or_admin on public.profiles
to authenticated
using (id = (select auth.uid()) or public.is_admin())
with check (id = (select auth.uid()) or public.is_admin());

-- Identical SELECT + ALL policies are consolidated into the ALL policy.
drop policy if exists adult_profiles_select on public.adult_profiles;
alter policy adult_profiles_upsert_self on public.adult_profiles
to authenticated
using (user_id = (select auth.uid()) or public.is_admin())
with check (user_id = (select auth.uid()) or public.is_admin());

drop policy if exists guardian_profiles_select on public.guardian_profiles;
alter policy guardian_profiles_upsert_self on public.guardian_profiles
to authenticated
using (user_id = (select auth.uid()) or public.is_admin())
with check (user_id = (select auth.uid()) or public.is_admin());

drop policy if exists payment_preferences_select_owner_or_admin on public.payment_preferences;
alter policy payment_preferences_upsert_owner on public.payment_preferences
to authenticated
using (user_id = (select auth.uid()) or public.is_admin())
with check (user_id = (select auth.uid()) or public.is_admin());

drop policy if exists push_tokens_select_owner_or_admin on public.push_tokens;
alter policy push_tokens_upsert_owner on public.push_tokens
to authenticated
using (user_id = (select auth.uid()) or public.is_admin())
with check (user_id = (select auth.uid()) or public.is_admin());

drop policy if exists user_profile_theme_settings_select_own_or_admin
  on public.user_profile_theme_settings;
alter policy user_profile_theme_settings_upsert_own on public.user_profile_theme_settings
to authenticated
using (user_id = (select auth.uid()) or public.is_admin())
with check (user_id = (select auth.uid()) or public.is_admin());

drop policy if exists user_saved_job_folders_select_own_or_admin
  on public.user_saved_job_folders;
alter policy user_saved_job_folders_write_own on public.user_saved_job_folders
to authenticated
using (user_id = (select auth.uid()) or public.is_admin())
with check (user_id = (select auth.uid()) or public.is_admin());

-- Teen profile reads include linked guardians, so writes remain separate.
drop policy if exists teen_profiles_upsert_self on public.teen_profiles;
create policy teen_profiles_insert_self_or_admin
on public.teen_profiles
for insert
to authenticated
with check (user_id = (select auth.uid()) or public.is_admin());
create policy teen_profiles_update_self_or_admin
on public.teen_profiles
for update
to authenticated
using (user_id = (select auth.uid()) or public.is_admin())
with check (user_id = (select auth.uid()) or public.is_admin());
create policy teen_profiles_delete_self_or_admin
on public.teen_profiles
for delete
to authenticated
using (user_id = (select auth.uid()) or public.is_admin());
alter policy teen_profiles_select on public.teen_profiles
to authenticated
using (
  user_id = (select auth.uid())
  or public.is_admin()
  or public.guardian_is_connected_to_teen(user_id, (select auth.uid()))
);

-- Split write-capable ALL policies where SELECT has intentionally broader
-- visibility. This removes duplicate permissive SELECT evaluation.
drop policy if exists ai_moderation_events_admin_all on public.ai_moderation_events;
create policy ai_moderation_events_admin_insert on public.ai_moderation_events
for insert to authenticated with check (public.is_admin());
create policy ai_moderation_events_admin_update on public.ai_moderation_events
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy ai_moderation_events_admin_delete on public.ai_moderation_events
for delete to authenticated using (public.is_admin());

drop policy if exists job_boost_credits_admin_write on public.job_boost_credits;
create policy job_boost_credits_admin_insert on public.job_boost_credits
for insert to authenticated with check (public.is_admin());
create policy job_boost_credits_admin_update on public.job_boost_credits
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy job_boost_credits_admin_delete on public.job_boost_credits
for delete to authenticated using (public.is_admin());

drop policy if exists jurisdiction_guardian_policies_admin_write
  on public.jurisdiction_guardian_policies;
create policy jurisdiction_guardian_policies_admin_insert
on public.jurisdiction_guardian_policies
for insert to authenticated with check (public.is_admin());
create policy jurisdiction_guardian_policies_admin_update
on public.jurisdiction_guardian_policies
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy jurisdiction_guardian_policies_admin_delete
on public.jurisdiction_guardian_policies
for delete to authenticated using (public.is_admin());

drop policy if exists monetization_experiments_write_admin on public.monetization_experiments;
create policy monetization_experiments_admin_insert on public.monetization_experiments
for insert to authenticated with check (public.is_admin());
create policy monetization_experiments_admin_update on public.monetization_experiments
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy monetization_experiments_admin_delete on public.monetization_experiments
for delete to authenticated using (public.is_admin());

drop policy if exists profile_theme_unlocks_admin_write on public.profile_theme_unlocks;
create policy profile_theme_unlocks_admin_insert on public.profile_theme_unlocks
for insert to authenticated with check (public.is_admin());
create policy profile_theme_unlocks_admin_update on public.profile_theme_unlocks
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy profile_theme_unlocks_admin_delete on public.profile_theme_unlocks
for delete to authenticated using (public.is_admin());

drop policy if exists saved_job_folder_items_write_own on public.saved_job_folder_items;
create policy saved_job_folder_items_insert_own on public.saved_job_folder_items
for insert
to authenticated
with check (
  public.is_admin()
  or (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.user_saved_job_folders folder
      where folder.id = saved_job_folder_items.folder_id
        and folder.user_id = (select auth.uid())
    )
  )
);
create policy saved_job_folder_items_update_own on public.saved_job_folder_items
for update
to authenticated
using (
  public.is_admin()
  or (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.user_saved_job_folders folder
      where folder.id = saved_job_folder_items.folder_id
        and folder.user_id = (select auth.uid())
    )
  )
)
with check (
  public.is_admin()
  or (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.user_saved_job_folders folder
      where folder.id = saved_job_folder_items.folder_id
        and folder.user_id = (select auth.uid())
    )
  )
);
create policy saved_job_folder_items_delete_own on public.saved_job_folder_items
for delete
to authenticated
using (
  public.is_admin()
  or (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.user_saved_job_folders folder
      where folder.id = saved_job_folder_items.folder_id
        and folder.user_id = (select auth.uid())
    )
  )
);

drop policy if exists username_change_credits_admin_write on public.username_change_credits;
create policy username_change_credits_admin_insert on public.username_change_credits
for insert to authenticated with check (public.is_admin());
create policy username_change_credits_admin_update on public.username_change_credits
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy username_change_credits_admin_delete on public.username_change_credits
for delete to authenticated using (public.is_admin());

drop policy if exists username_reservations_admin_write on public.username_reservations;
create policy username_reservations_admin_insert on public.username_reservations
for insert to authenticated with check (public.is_admin());
create policy username_reservations_admin_update on public.username_reservations
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy username_reservations_admin_delete on public.username_reservations
for delete to authenticated using (public.is_admin());

-- Remaining advisor-flagged policies keep the same predicates with auth values
-- evaluated once per statement through scalar subqueries.
alter policy message_threads_insert_application_participant on public.message_threads
to authenticated
with check (
  public.is_admin()
  or (
    teen_id = (select auth.uid())
    and application_id is not null
    and public.is_application_participant(application_id)
  )
);

alter policy conversations_select_participant on public.conversations
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.conversation_participants participant
    where participant.conversation_id = conversations.id
      and participant.user_id = (select auth.uid())
  )
);

alter policy conversation_participants_select_self_or_admin
on public.conversation_participants
to authenticated
using (
  user_id = (select auth.uid())
  or public.is_admin()
  or exists (
    select 1
    from public.conversation_participants participant
    where participant.conversation_id = conversation_participants.conversation_id
      and participant.user_id = (select auth.uid())
  )
);

alter policy reports_insert_reporter on public.reports
to authenticated
with check (reporter_id = (select auth.uid()));
alter policy reports_select_reporter_or_admin on public.reports
to authenticated
using (reporter_id = (select auth.uid()) or public.is_admin());

alter policy blocks_insert_self on public.blocks
to authenticated
with check (blocker_id = (select auth.uid()));
alter policy blocks_select_self_or_admin on public.blocks
to authenticated
using (
  blocker_id = (select auth.uid())
  or blocked_id = (select auth.uid())
  or public.is_admin()
);

alter policy business_verifications_select_owner_or_admin
on public.business_verifications
to authenticated
using (adult_id = (select auth.uid()) or public.is_admin());

alter policy notifications_select_recipient_or_admin on public.notifications
to authenticated
using (recipient_id = (select auth.uid()) or public.is_admin());
alter policy notifications_update_recipient_or_admin on public.notifications
to authenticated
using (recipient_id = (select auth.uid()) or public.is_admin())
with check (recipient_id = (select auth.uid()) or public.is_admin());
alter policy notification_events_select_recipient_or_admin on public.notification_events
to authenticated
using (recipient_id = (select auth.uid()) or public.is_admin());

alter policy support_tickets_insert_self on public.support_tickets
to authenticated
with check (requester_id = (select auth.uid()));
alter policy support_tickets_select_owner_or_admin on public.support_tickets
to authenticated
using (requester_id = (select auth.uid()) or public.is_admin());
alter policy support_ticket_messages_insert_participant on public.support_ticket_messages
to authenticated
with check (
  sender_id = (select auth.uid())
  and (
    public.is_admin()
    or exists (
      select 1
      from public.support_tickets ticket
      where ticket.id = support_ticket_messages.ticket_id
        and ticket.requester_id = (select auth.uid())
    )
  )
);
alter policy support_ticket_messages_select_participant on public.support_ticket_messages
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.support_tickets ticket
    where ticket.id = support_ticket_messages.ticket_id
      and ticket.requester_id = (select auth.uid())
  )
);

alter policy admin_action_logs_insert_admin on public.admin_action_logs
to authenticated
with check (public.is_admin() and admin_id = (select auth.uid()));

alter policy guardian_connections_select on public.guardian_connections
to authenticated
using (
  teen_id = (select auth.uid())
  or guardian_id = (select auth.uid())
  or (
    status = 'invited'
    and invited_email is not null
    and lower(invited_email) = lower(coalesce((select auth.jwt())->>'email', ''))
  )
  or public.is_admin()
);

alter policy guardian_preferences_select_participants on public.guardian_preferences
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.guardian_connections connection
    where connection.id = guardian_preferences.link_id
      and connection.status = 'active'
      and (
        connection.teen_id = (select auth.uid())
        or connection.guardian_id = (select auth.uid())
      )
  )
);
alter policy guardian_preferences_update_teen on public.guardian_preferences
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.guardian_connections connection
    where connection.id = guardian_preferences.link_id
      and connection.teen_id = (select auth.uid())
      and connection.status = 'active'
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.guardian_connections connection
    where connection.id = guardian_preferences.link_id
      and connection.teen_id = (select auth.uid())
      and connection.status = 'active'
  )
);

alter policy saved_jobs_select_own on public.saved_jobs
to authenticated
using (user_id = (select auth.uid()) or public.is_admin());
alter policy saved_jobs_delete_own on public.saved_jobs
to authenticated
using (user_id = (select auth.uid()) or public.is_admin());
alter policy saved_jobs_insert_own on public.saved_jobs
to authenticated
with check (
  user_id = (select auth.uid())
  and public.current_profile_role() = 'teen'
  and exists (
    select 1
    from public.jobs job
    where job.id = saved_jobs.job_id
      and job.status = 'open'
      and (not job.is_test or public.current_profile_is_test())
  )
);
alter policy saved_jobs_update_own on public.saved_jobs
to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid())
  and public.current_profile_role() = 'teen'
  and exists (
    select 1
    from public.jobs job
    where job.id = saved_jobs.job_id
      and job.status = 'open'
      and (not job.is_test or public.current_profile_is_test())
  )
);

alter policy job_templates_owner on public.job_templates
to authenticated
using (owner_id = (select auth.uid()) or public.is_admin())
with check (owner_id = (select auth.uid()) or public.is_admin());

alter policy job_status_events_participant_select on public.job_status_events
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.jobs job
    where job.id = job_status_events.job_id
      and (
        job.poster_id = (select auth.uid())
        or exists (
          select 1
          from public.applications application
          where application.job_id = job.id
            and application.teen_id = (select auth.uid())
        )
      )
  )
);

alter policy reviews_select_visible on public.reviews
to authenticated
using (
  moderation_status = 'approved'
  or reviewer_id = (select auth.uid())
  or subject_id = (select auth.uid())
  or public.is_admin()
);
alter policy reviews_insert_participant on public.reviews
to authenticated
with check (
  reviewer_id = (select auth.uid())
  and exists (
    select 1
    from public.jobs job
    join public.applications application
      on application.job_id = job.id
     and application.status = 'completed'
    where job.id = reviews.job_id
      and job.status = 'completed'
      and (
        (reviews.reviewer_id = job.poster_id and reviews.subject_id = application.teen_id)
        or (reviews.reviewer_id = application.teen_id and reviews.subject_id = job.poster_id)
      )
  )
);

alter policy jobs_select_visible on public.jobs
to authenticated
using (
  (
    status = 'open'
    and (
      not is_test
      or poster_id = (select auth.uid())
      or public.is_admin()
      or public.current_profile_is_test()
    )
  )
  or poster_id = (select auth.uid())
  or public.is_admin()
  or exists (
    select 1
    from public.applications application
    where application.job_id = jobs.id
      and public.is_application_participant(application.id)
  )
  or exists (
    select 1
    from public.saved_jobs saved
    where saved.job_id = jobs.id
      and saved.user_id = (select auth.uid())
  )
);

alter policy safety_pings_insert_teen on public.safety_pings
to authenticated
with check (
  teen_id = (select auth.uid())
  and public.current_profile_role() = 'teen'
  and (
    guardian_id is null
    or public.guardian_is_connected_to_teen(teen_id, guardian_id)
  )
);
alter policy safety_pings_select_participant on public.safety_pings
to authenticated
using (
  teen_id = (select auth.uid())
  or public.guardian_receives_safety_pings(teen_id, (select auth.uid()))
  or public.is_admin()
);
