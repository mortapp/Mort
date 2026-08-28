-- Cascading profile deletion can schedule a message thread for deletion while
-- another FK action updates its job/application columns. Avoid recreating a
-- conversation for a thread that is no longer visible in the same statement.
create or replace function public.sync_conversation_for_thread()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation_id uuid;
begin
  if not exists (
    select 1
    from public.message_threads thread
    where thread.id = new.id
  ) then
    return new;
  end if;

  insert into public.conversations (legacy_thread_id, job_id, application_id)
  values (new.id, new.job_id, new.application_id)
  on conflict (legacy_thread_id) do update
    set job_id = excluded.job_id,
        application_id = excluded.application_id
  returning id into v_conversation_id;

  if new.teen_id is not null then
    insert into public.conversation_participants (conversation_id, user_id, role)
    values (v_conversation_id, new.teen_id, 'teen')
    on conflict (conversation_id, user_id) do nothing;
  end if;

  if new.adult_id is not null then
    insert into public.conversation_participants (conversation_id, user_id, role)
    values (v_conversation_id, new.adult_id, 'adult')
    on conflict (conversation_id, user_id) do nothing;
  end if;

  if new.guardian_id is not null then
    insert into public.conversation_participants (conversation_id, user_id, role)
    values (v_conversation_id, new.guardian_id, 'guardian')
    on conflict (conversation_id, user_id) do nothing;
  end if;

  return new;
end;
$$;

revoke all on function public.sync_conversation_for_thread() from public, anon, authenticated;
grant execute on function public.sync_conversation_for_thread() to service_role;
