alter table public.notification_preferences
  add column if not exists categories jsonb not null default
    '{"application_updates":true,"job_updates":true,"schedule_changes":true,"new_messages":true,"work_reminders":true,"support_updates":true,"guardian_updates":true,"verification_updates":true,"dispute_updates":true}'::jsonb,
  add column if not exists quiet_hours_enabled boolean not null default false,
  add column if not exists quiet_start time not null default time '21:00',
  add column if not exists quiet_end time not null default time '07:00',
  add column if not exists timezone_name text not null default 'UTC';

create or replace function public.get_my_notification_preferences()
returns jsonb language plpgsql security definer set search_path to ''
as $fn$
declare
  v_user uuid := auth.uid();
  v_pref public.notification_preferences%rowtype;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  insert into public.notification_preferences(user_id) values (v_user)
  on conflict (user_id) do nothing;
  select * into v_pref from public.notification_preferences where user_id = v_user;
  return jsonb_build_object('ok', true, 'preferences', jsonb_build_object(
    'push_enabled', v_pref.push_enabled,
    'categories', v_pref.categories,
    'quiet_hours_enabled', v_pref.quiet_hours_enabled,
    'quiet_start', v_pref.quiet_start,
    'quiet_end', v_pref.quiet_end,
    'timezone_name', v_pref.timezone_name
  ));
end;
$fn$;

create or replace function public.update_my_notification_preferences(
  p_push_enabled boolean, p_categories jsonb, p_quiet_hours_enabled boolean,
  p_quiet_start time, p_quiet_end time, p_timezone_name text
)
returns jsonb language plpgsql security definer set search_path to ''
as $fn$
declare
  v_user uuid := auth.uid();
  v_categories jsonb;
  v_timezone text := btrim(coalesce(p_timezone_name, 'UTC'));
  v_pref public.notification_preferences%rowtype;
  v_allowed constant text[] := array[
    'application_updates','job_updates','schedule_changes','new_messages',
    'work_reminders','support_updates','guardian_updates',
    'verification_updates','dispute_updates'
  ];
  v_key text;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_categories is null or jsonb_typeof(p_categories) <> 'object' then
    return jsonb_build_object('ok', false, 'code', 'notification_categories_invalid');
  end if;
  for v_key in select jsonb_object_keys(p_categories) loop
    if not (v_key = any(v_allowed)) or jsonb_typeof(p_categories -> v_key) <> 'boolean' then
      return jsonb_build_object('ok', false, 'code', 'notification_categories_invalid');
    end if;
  end loop;
  if char_length(v_timezone) < 1 or char_length(v_timezone) > 100
     or not exists (select 1 from pg_catalog.pg_timezone_names where name = v_timezone) then
    return jsonb_build_object('ok', false, 'code', 'notification_timezone_invalid');
  end if;
  if p_quiet_start is null or p_quiet_end is null then
    return jsonb_build_object('ok', false, 'code', 'notification_quiet_hours_invalid');
  end if;
  v_categories := jsonb_build_object(
    'application_updates',true,'job_updates',true,'schedule_changes',true,
    'new_messages',true,'work_reminders',true,'support_updates',true,
    'guardian_updates',true,'verification_updates',true,'dispute_updates',true
  ) || p_categories;
  insert into public.notification_preferences(
    user_id,push_enabled,categories,quiet_hours_enabled,quiet_start,quiet_end,
    timezone_name,message_updates,job_updates,safety_alerts,updated_at
  ) values (
    v_user,coalesce(p_push_enabled,false),v_categories,
    coalesce(p_quiet_hours_enabled,false),p_quiet_start,p_quiet_end,v_timezone,
    coalesce((v_categories->>'new_messages')::boolean,true),
    coalesce((v_categories->>'job_updates')::boolean,true),
    (coalesce((v_categories->>'support_updates')::boolean,true)
      or coalesce((v_categories->>'guardian_updates')::boolean,true)
      or coalesce((v_categories->>'verification_updates')::boolean,true)
      or coalesce((v_categories->>'dispute_updates')::boolean,true)),
    now()
  )
  on conflict (user_id) do update set
    push_enabled=excluded.push_enabled,categories=excluded.categories,
    quiet_hours_enabled=excluded.quiet_hours_enabled,quiet_start=excluded.quiet_start,
    quiet_end=excluded.quiet_end,timezone_name=excluded.timezone_name,
    message_updates=excluded.message_updates,job_updates=excluded.job_updates,
    safety_alerts=excluded.safety_alerts,updated_at=now();
  select * into v_pref from public.notification_preferences where user_id=v_user;
  return jsonb_build_object('ok',true,'preferences',jsonb_build_object(
    'push_enabled',v_pref.push_enabled,'categories',v_pref.categories,
    'quiet_hours_enabled',v_pref.quiet_hours_enabled,'quiet_start',v_pref.quiet_start,
    'quiet_end',v_pref.quiet_end,'timezone_name',v_pref.timezone_name
  ));
end;
$fn$;

create or replace function public.get_my_push_status()
returns jsonb language plpgsql security definer set search_path to ''
as $fn$
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('ok',false,'code','active_account_required');
  end if;
  return jsonb_build_object(
    'ok',true,'remote_push_enabled',false,'active_device_count',0,
    'provider','fcm','provider_delivery_verified',false
  );
end;
$fn$;

create or replace function private.notify_approved_message_recipients()
returns trigger language plpgsql security definer set search_path to ''
as $fn$
declare v_recipient uuid;
begin
  if new.moderation_status <> 'approved' then return new; end if;
  if tg_op='UPDATE' and old.moderation_status='approved' then return new; end if;
  for v_recipient in
    select member.user_id
    from public.conversation_members member
    join public.profiles recipient on recipient.id=member.user_id
    where member.conversation_id=new.conversation_id
      and member.user_id<>new.sender_id
      and recipient.account_status='active'
      and coalesce((select preferences.message_updates
        from public.notification_preferences preferences
        where preferences.user_id=member.user_id),true)
  loop
    insert into public.notifications(user_id,notification_type,title,body,data)
    select v_recipient,'new_message','New message','You have a new message in MORT.',
      jsonb_build_object('type','new_message','threadId',new.conversation_id::text,'messageId',new.id::text)
    where not exists (
      select 1 from public.notifications existing
      where existing.user_id=v_recipient
        and existing.notification_type='new_message'
        and existing.data->>'messageId'=new.id::text
    );
  end loop;
  return new;
end;
$fn$;

drop trigger if exists messages_notify_approved_recipients on public.messages;
create trigger messages_notify_approved_recipients
after insert or update on public.messages
for each row execute function private.notify_approved_message_recipients();

create index if not exists notifications_user_created_idx
on public.notifications(user_id,created_at desc);

revoke all on function public.get_my_notification_preferences() from public,anon;
revoke all on function public.update_my_notification_preferences(boolean,jsonb,boolean,time,time,text) from public,anon;
revoke all on function public.get_my_push_status() from public,anon;
revoke all on function private.notify_approved_message_recipients() from public,anon,authenticated;
grant execute on function public.get_my_notification_preferences() to authenticated,service_role;
grant execute on function public.update_my_notification_preferences(boolean,jsonb,boolean,time,time,text) to authenticated,service_role;
grant execute on function public.get_my_push_status() to authenticated,service_role;
