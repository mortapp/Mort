-- Restrict authenticated user RPCs to authenticated callers. These functions
-- already fail closed on auth.uid(), but removing anonymous EXECUTE narrows the
-- SECURITY DEFINER surface at the PostgREST boundary.
revoke execute on function public.accept_guardian_invite(text) from public, anon;
revoke execute on function public.create_my_expense(integer, date, text, text, text, uuid, text) from public, anon;
revoke execute on function public.delete_my_expense(uuid) from public, anon;
revoke execute on function public.delete_my_financial_target(integer) from public, anon;
revoke execute on function public.evaluate_my_financial_alerts(integer) from public, anon;
revoke execute on function public.get_linked_teen_financial_summary(uuid, integer) from public, anon;
revoke execute on function public.get_my_financial_preferences() from public, anon;
revoke execute on function public.get_my_financial_summary(integer) from public, anon;
revoke execute on function public.get_my_financial_year_report(integer) from public, anon;
revoke execute on function public.list_financial_rules(text) from public, anon;
revoke execute on function public.list_my_expenses(integer) from public, anon;
revoke execute on function public.set_my_expense_receipt(uuid, text) from public, anon;
revoke execute on function public.set_my_financial_preferences(boolean, text[], boolean) from public, anon;
revoke execute on function public.support_classify_intent(text) from public, anon;
revoke execute on function public.update_my_expense(uuid, integer, date, text, text, text, uuid, boolean, text) from public, anon;
revoke execute on function public.upsert_my_financial_target(integer, integer, text) from public, anon;

grant execute on function public.accept_guardian_invite(text) to authenticated;
grant execute on function public.create_my_expense(integer, date, text, text, text, uuid, text) to authenticated;
grant execute on function public.delete_my_expense(uuid) to authenticated;
grant execute on function public.delete_my_financial_target(integer) to authenticated;
grant execute on function public.evaluate_my_financial_alerts(integer) to authenticated;
grant execute on function public.get_linked_teen_financial_summary(uuid, integer) to authenticated;
grant execute on function public.get_my_financial_preferences() to authenticated;
grant execute on function public.get_my_financial_summary(integer) to authenticated;
grant execute on function public.get_my_financial_year_report(integer) to authenticated;
grant execute on function public.list_financial_rules(text) to authenticated;
grant execute on function public.list_my_expenses(integer) to authenticated;
grant execute on function public.set_my_expense_receipt(uuid, text) to authenticated;
grant execute on function public.set_my_financial_preferences(boolean, text[], boolean) to authenticated;
grant execute on function public.support_classify_intent(text) to authenticated;
grant execute on function public.update_my_expense(uuid, integer, date, text, text, text, uuid, boolean, text) to authenticated;
grant execute on function public.upsert_my_financial_target(integer, integer, text) to authenticated;

drop policy if exists financial_preferences_select_own on public.financial_preferences;
create policy financial_preferences_select_own
on public.financial_preferences
for select
to public
using (user_id = (select auth.uid()));

drop policy if exists financial_preferences_insert_own on public.financial_preferences;
create policy financial_preferences_insert_own
on public.financial_preferences
for insert
to public
with check (user_id = (select auth.uid()));

drop policy if exists financial_preferences_update_own on public.financial_preferences;
create policy financial_preferences_update_own
on public.financial_preferences
for update
to public
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists expense_records_select_own on public.expense_records;
create policy expense_records_select_own
on public.expense_records
for select
to public
using (user_id = (select auth.uid()));

drop policy if exists expense_records_insert_own on public.expense_records;
create policy expense_records_insert_own
on public.expense_records
for insert
to public
with check (user_id = (select auth.uid()));

drop policy if exists expense_records_update_own on public.expense_records;
create policy expense_records_update_own
on public.expense_records
for update
to public
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists expense_records_delete_own on public.expense_records;
create policy expense_records_delete_own
on public.expense_records
for delete
to public
using (user_id = (select auth.uid()));

drop policy if exists financial_personal_targets_all_own on public.financial_personal_targets;
create policy financial_personal_targets_all_own
on public.financial_personal_targets
for all
to public
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists financial_alert_events_select_own on public.financial_alert_events;
create policy financial_alert_events_select_own
on public.financial_alert_events
for select
to public
using (user_id = (select auth.uid()));

drop policy if exists job_management_requests_participant_select on public.job_management_requests;
create policy job_management_requests_participant_select
on public.job_management_requests
for select
to authenticated
using (
  actor_id = (select auth.uid())
  or is_admin()
  or (
    exists (
      select 1
      from public.jobs job
      where job.id = job_management_requests.job_id
        and job.poster_id = (select auth.uid())
    )
  )
  or (
    exists (
      select 1
      from public.applications application
      where application.job_id = application.job_id
        and (
          (select auth.uid()) = application.teen_id
          or (select auth.uid()) = coalesce(application.guardian_id, application.teen_id)
        )
    )
  )
);

drop policy if exists application_transition_requests_participant_select on public.application_transition_requests;
create policy application_transition_requests_participant_select
on public.application_transition_requests
for select
to authenticated
using (
  actor_id = (select auth.uid())
  or is_admin()
  or is_application_participant(application_id)
);

drop policy if exists payment_dispute_statements_participant_or_assigned_select on public.payment_dispute_statements;
create policy payment_dispute_statements_participant_or_assigned_select
on public.payment_dispute_statements
for select
to authenticated
using (
  exists (
    select 1
    from public.payment_disputes dispute
    where dispute.id = payment_dispute_statements.dispute_id
      and (
        (select auth.uid()) = dispute.worker_id
        or (select auth.uid()) = dispute.poster_id
        or private.is_assigned_payment_dispute_reviewer(dispute.id, (select auth.uid()))
      )
  )
);

drop policy if exists payment_dispute_appeals_participant_or_assigned_select on public.payment_dispute_appeals;
create policy payment_dispute_appeals_participant_or_assigned_select
on public.payment_dispute_appeals
for select
to authenticated
using (
  exists (
    select 1
    from public.payment_disputes dispute
    where dispute.id = payment_dispute_appeals.dispute_id
      and (
        (select auth.uid()) = dispute.worker_id
        or (select auth.uid()) = dispute.poster_id
        or private.is_assigned_payment_dispute_reviewer(dispute.id, (select auth.uid()))
      )
  )
);
