-- Additive Safety Center runtime. No hosted deployment or public activation.
-- Job lifecycle, evidence, payments, progression and digital entitlements keep
-- their existing authorities. Device telemetry is private, never a penalty.
create table private.safety_device_state (
  teen_id uuid primary key references public.profiles(id) on delete cascade,
  application_id uuid references public.applications(id) on delete set null,
  safety_state text not null default 'normal',
  travel_state text not null default 'off' check (travel_state in ('off','traveling','arrived','reconfirm')),
  eta_minutes integer check (eta_minutes between 0 and 1440),
  travel_mode text not null default 'WALK' check (travel_mode in ('WALK','DRIVE','BICYCLE','TRANSIT')),
  eta_observed_at timestamptz,
  eta_requested_at timestamptz,
  eta_request_id uuid,
  last_seen_at timestamptz not null default now(),
  last_checkin_at timestamptz,
  next_checkin_at timestamptz,
  missed_online_checks integer not null default 0,
  offline_notified_at timestamptz,
  battery_percent integer check (battery_percent between 0 and 100),
  saver_enabled boolean not null default false,
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  location_at timestamptz,
  review_hold boolean not null default false,
  final_safety_pending boolean not null default false,
  check ((latitude is null) = (longitude is null))
);
create table private.safety_runtime_requests (
  actor_id uuid not null references public.profiles(id) on delete cascade,
  request_id uuid not null,
  payload_hash text not null,
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key(actor_id, request_id)
);
create table private.safety_event_recipients (
  event_id uuid not null references public.safety_pings(id) on delete cascade,
  teen_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  relationship text not null check (relationship in ('guardian','trusted')),
  event_snapshot jsonb not null default '{}'::jsonb,
  access_expires_at timestamptz not null default now()+interval '24 hours',
  primary key(event_id,recipient_id)
);
alter table public.job_location_share_sessions alter column application_id drop not null;
alter table public.job_location_share_sessions add column safety_event_id uuid
  references public.safety_pings(id) on delete cascade;
create index safety_event_shares_idx on public.job_location_share_sessions(safety_event_id,owner_id);
alter table public.message_threads add column safety_event_id uuid references public.safety_pings(id) on delete cascade;
alter table public.message_threads add column safety_contact_kind text check (safety_contact_kind in ('teen','poster'));
create unique index safety_contact_thread_unique on public.message_threads(safety_event_id,guardian_id,safety_contact_kind)
where safety_event_id is not null;
alter table public.reports add column selected_safety_categories text[] not null default '{}';
alter table public.job_safety_plans drop constraint safety_plan_cadence_check;
alter table public.job_safety_plans add constraint safety_plan_cadence_check
check(checkin_cadence_minutes is null or checkin_cadence_minutes=6 or checkin_cadence_minutes between 15 and 240);

do $$ declare t text; begin
  foreach t in array array['safety_device_state','safety_runtime_requests','safety_event_recipients'] loop
    execute format('alter table private.%I enable row level security',t);
    execute format('alter table private.%I force row level security',t);
    execute format('revoke all on private.%I from public,anon,authenticated',t);
    execute format('grant all on private.%I to service_role',t);
  end loop;
end $$;

create function private.safety_account_active(p_user_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles where id=p_user_id and account_status='active'
   and (blocked_until is null or blocked_until<now()))
$$;
create function private.current_safety_contacts(p_teen_id uuid)
returns table(recipient_id uuid,relationship text)
language sql stable security definer set search_path='' as $$
  select c.guardian_id,'guardian'::text from public.guardian_connections c
  join public.guardian_preferences p on p.link_id=c.id
  where c.teen_id=p_teen_id and c.status='active' and p.safety_ping_alerts
    and private.is_minor_teen(p_teen_id) and private.safety_account_active(p_teen_id) and private.safety_account_active(c.guardian_id)
  union
  select c.contact_id,'trusted'::text from public.safety_circle_members c
  where c.teen_id=p_teen_id and c.status='active' and c.receive_safety_ping
    and private.is_minor_teen(p_teen_id) and private.safety_account_active(p_teen_id) and private.safety_account_active(c.contact_id)
$$;
create function private.can_read_safety_event(p_event_id uuid,p_actor uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select private.safety_account_active(p_actor) and exists(
   select 1 from private.safety_event_recipients r
   join private.current_safety_contacts(r.teen_id) c
     on c.recipient_id=r.recipient_id and c.relationship=r.relationship
   where r.event_id=p_event_id and r.recipient_id=p_actor and r.access_expires_at>now())
 and not exists(select 1 from public.safety_pings p join public.safety_incidents i on i.id=p.incident_id
   where p.id=p_event_id and i.status in ('resolved','closed'))
$$;
create function private.register_safety_event_recipients(p_event_id uuid,p_teen_id uuid)
returns void language sql security definer set search_path='' as $$
 insert into private.safety_event_recipients(event_id,teen_id,recipient_id,relationship,event_snapshot)
 select p_event_id,p_teen_id,recipient_id,relationship,
   coalesce((select jsonb_build_object('latitude',d.latitude,'longitude',d.longitude,'location_at',d.location_at)
     from private.safety_device_state d where d.teen_id=p_teen_id),'{}'::jsonb)
 from private.current_safety_contacts(p_teen_id)
 where recipient_id is distinct from (select j.poster_id from public.safety_pings p
   join public.jobs j on j.id=p.job_id where p.id=p_event_id)
 on conflict(event_id,recipient_id) do nothing
$$;
create function private.audit_safety_runtime(p_actor uuid,p_resource uuid,p_action text)
returns void language sql security definer set search_path='' as $$
 insert into public.private_data_access_events(actor_id,resource_type,resource_id,action,reason)
 values(p_actor,'safety_runtime',p_resource,p_action,'Authorized Safety Center action or access')
$$;

create function public.get_my_safety_runtime()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v private.safety_device_state%rowtype; a public.applications%rowtype; j public.jobs%rowtype;
begin
 if auth.uid() is null or not private.safety_account_active(auth.uid()) then
   return jsonb_build_object('ok',false,'code','active_account_required'); end if;
 select * into v from private.safety_device_state where teen_id=auth.uid();
 select * into a from public.applications where teen_id=auth.uid()
   and status in ('accepted','in_progress','proof_submitted','completion_pending_release','disputed')
   order by case when status in ('in_progress','proof_submitted','completion_pending_release') then 0
     when id=v.application_id then 1 else 2 end,created_at desc limit 1;
 select * into j from public.jobs where id=a.job_id;
 return jsonb_build_object('ok',true,'safety_state',coalesce(v.safety_state,'normal'),
  'application_id',a.id,'job_id',j.id,'job_title',j.title,'job_status',a.status,
  'remaining_job_minutes',greatest(0,coalesce(j.estimated_duration_minutes,0)-coalesce(
    (select floor(extract(epoch from (now()-checkin_at))/60)::integer from public.job_arrival_handshakes
      where application_id=a.id and checkin_at is not null),0)),
  'travel_state',coalesce(v.travel_state,'off'),'travel_mode',v.travel_mode,
  'eta_minutes',case when v.travel_state='traveling' and v.eta_observed_at>now()-interval '5 minutes' then v.eta_minutes end,
  'next_checkin_at',v.next_checkin_at,'last_checkin_at',v.last_checkin_at,
  'battery_percent',v.battery_percent,'saver_enabled',coalesce(v.saver_enabled,false),
  'review_hold',coalesce(v.review_hold,false) or private.safety_job_review_held(a.id),'final_safety_pending',coalesce(v.final_safety_pending,false),
  'guardian_count',(select count(*) from private.current_safety_contacts(auth.uid()) where relationship='guardian'),
  'trusted_count',(select count(*) from private.current_safety_contacts(auth.uid()) where relationship='trusted'),
  'sharing_expires_at',(select max(expires_at) from public.job_location_share_sessions
     where owner_id=auth.uid() and safety_event_id is not null and status='active' and expires_at>now()));
end $$;

create function public.perform_safety_action(
 p_action text,p_application_id uuid,p_payload jsonb,p_client_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
<<runtime_action>>
declare v private.safety_device_state%rowtype; a public.applications%rowtype; j public.jobs%rowtype;
 r private.safety_runtime_requests%rowtype; h text; response jsonb; ping jsonb; event_id uuid;
 contact record; expiry timestamptz; cancellation jsonb; requested_at timestamptz;
begin
 if auth.uid() is null or not private.safety_account_active(auth.uid()) or not private.is_minor_teen(auth.uid()) then
   return jsonb_build_object('ok',false,'code','active_teen_required'); end if;
 if p_client_request_id is null or p_payload is null or jsonb_typeof(p_payload)<>'object'
   or octet_length(p_payload::text)>2048 then return jsonb_build_object('ok',false,'code','invalid_safety_request'); end if;
 if p_payload ? 'actor_id' and p_payload->>'actor_id' is distinct from auth.uid()::text then
   return jsonb_build_object('ok',false,'code','safety_actor_changed'); end if;
 begin requested_at:=coalesce((p_payload->>'requested_at')::timestamptz,now());
 exception when invalid_datetime_format or datetime_field_overflow then
   return jsonb_build_object('ok',false,'code','invalid_safety_request_time'); end;
 if requested_at>now()+interval '10 seconds' then
   return jsonb_build_object('ok',false,'code','invalid_safety_request_time'); end if;
 if p_action is null or p_action not in ('alert','share','stop_sharing','extend_sharing','safe','exit','travel','stop_trip','arrived','continue_trip','final_safe') then
   return jsonb_build_object('ok',false,'code','invalid_safety_action'); end if;
 h:=encode(extensions.digest(jsonb_build_object('action',p_action,'application',p_application_id,'payload',p_payload)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':safety-runtime',0));
 select * into r from private.safety_runtime_requests where actor_id=auth.uid() and request_id=p_client_request_id;
 if found then
   if r.payload_hash<>h then return jsonb_build_object('ok',false,'code','safety_request_payload_mismatch'); end if;
   return r.response||jsonb_build_object('replayed',true);
 end if;
 -- Opening the Emergency panel performs no action. An explicit alert may
 -- resolve the caller's current job on the server, including from a locked UI.
 if p_application_id is null and p_action in ('alert','share') and requested_at>now()-interval '2 minutes' then
   select * into a from public.applications where teen_id=auth.uid()
     and status in ('accepted','in_progress','proof_submitted','completion_pending_release','disputed')
     order by case when status in ('in_progress','proof_submitted','completion_pending_release') then 0
       when id=(select application_id from private.safety_device_state where teen_id=auth.uid()) then 1 else 2 end,
       created_at desc limit 1 for update;
   select * into j from public.jobs where id=a.job_id;
 elsif p_application_id is not null then
   select * into a from public.applications where id=p_application_id and teen_id=auth.uid() for update;
   if a.id is null or a.status not in ('accepted','in_progress','proof_submitted','completion_pending_release','disputed') then
     return jsonb_build_object('ok',false,'code','assigned_active_job_required'); end if;
   select * into j from public.jobs where id=a.job_id;
 end if;
 if p_action in ('exit','travel','arrived','continue_trip','final_safe') and a.id is null then
   return jsonb_build_object('ok',false,'code','assigned_active_job_required'); end if;
 insert into private.safety_device_state(teen_id,application_id) values(auth.uid(),a.id) on conflict(teen_id) do nothing;
 select * into v from private.safety_device_state where teen_id=auth.uid() for update;
 if p_action in ('alert','share','exit') then
   ping:=public.create_safety_ping_v2('needs_help',
     case when p_action='share' then 'The teen explicitly started temporary safety sharing.'
          when p_action='exit' then 'The worker used Safety Exit.' else null end,
     case when a.status='disputed' then null else j.id end,p_action='alert',p_client_request_id);
   if ping->>'ok'<>'true' then return ping; end if;
   if p_action='exit' then
     cancellation:=public.submit_safety_cancellation(a.id,'unsafe_condition','The worker used Safety Exit. Private details may be added later.');
     if cancellation->>'ok'<>'true' then raise exception 'Safety Exit was not recorded'; end if;
     update private.safety_device_state set application_id=a.id,safety_state='safety_exit',review_hold=true,travel_state='off',next_checkin_at=null where teen_id=auth.uid();
     update public.job_checkins set status='canceled' where application_id=a.id and status in ('pending','missed');
     perform public.enqueue_notification(j.poster_id,'MORT Safety','Job ended through MORT Safety. Open MORT for job status.',jsonb_build_object('applicationId',a.id));
   end if;
   event_id:=(ping->>'safety_ping_id')::uuid;
   update public.safety_pings set job_id=j.id where id=event_id;
   if p_action='alert' and a.id is not null then
     update public.safety_incidents set application_id=a.id where id=(ping->>'incident_id')::uuid and reporter_id=auth.uid();
     update private.safety_device_state set application_id=a.id,review_hold=true where teen_id=auth.uid();
   end if;
   delete from private.safety_event_recipients where safety_event_recipients.event_id=runtime_action.event_id and recipient_id=j.poster_id;
   perform private.register_safety_event_recipients(event_id,auth.uid());
   if p_action in ('alert','share') then
     expiry:=least(now()+interval '60 minutes',requested_at+interval '60 minutes');
     update public.job_location_share_sessions set status='stopped',stopped_at=now()
       where owner_id=auth.uid() and safety_event_id is not null and status='active';
     for contact in select * from private.current_safety_contacts(auth.uid())
       where recipient_id is distinct from j.poster_id and expiry>now() loop
       insert into public.job_location_share_sessions(application_id,owner_id,recipient_user_id,mode,
         safety_event_id,expires_at,latitude,longitude,last_location_at)
       values(a.id,auth.uid(),contact.recipient_id,'safety_ping_emergency',event_id,expiry,
         case when v.location_at>now()-interval '2 minutes' then v.latitude end,
         case when v.location_at>now()-interval '2 minutes' then v.longitude end,v.location_at);
     end loop;
     update private.safety_device_state set safety_state=case when p_action='alert' then 'safety_alert' else 'live_sharing' end where teen_id=auth.uid();
   end if;
 elsif p_action in ('stop_sharing','extend_sharing') then
   update public.job_location_share_sessions s set status='stopped',stopped_at=now()
     where owner_id=auth.uid() and safety_event_id is not null and status='active'
       and not private.can_read_safety_event(s.safety_event_id,s.recipient_user_id);
   if not exists(select 1 from public.job_location_share_sessions where owner_id=auth.uid()
     and safety_event_id is not null and status='active' and expires_at>now()) then
     return jsonb_build_object('ok',false,'code','location_share_not_active'); end if;
   if p_action='extend_sharing' then expiry:=now()+interval '60 minutes'; end if;
   update public.job_location_share_sessions s set
     status=case when p_action='stop_sharing' then 'stopped' else 'active' end,
     stopped_at=case when p_action='stop_sharing' then now() else null end,
     starts_at=case when p_action='extend_sharing' then now() else s.starts_at end,
     expires_at=coalesce(expiry,s.expires_at)
   where owner_id=auth.uid() and safety_event_id is not null and status='active' and expires_at>now();
   for contact in select * from private.current_safety_contacts(auth.uid()) loop
     perform public.enqueue_notification(contact.recipient_id,'MORT Safety','Open MORT for a safety sharing update.',jsonb_build_object('teenId',auth.uid(),'action',p_action));
   end loop;
 elsif p_action in ('safe','final_safe') then
   if p_action='final_safe' and (v.application_id is distinct from a.id or not v.final_safety_pending) then
     return jsonb_build_object('ok',false,'code','final_safety_check_not_pending'); end if;
   if v.safety_state in ('attention','connection_lost','safety_alert','safety_exit') then
     for contact in select * from private.current_safety_contacts(auth.uid()) loop
       perform public.enqueue_notification(contact.recipient_id,'MORT Safety','The teen marked themselves safe. Open MORT for details.',jsonb_build_object('teenId',auth.uid()));
     end loop;
   end if;
   update private.safety_device_state set safety_state='normal',last_checkin_at=now(),missed_online_checks=0,
     next_checkin_at=case when a.status='in_progress' then now()+interval '6 minutes' end,
     final_safety_pending=case when p_action='final_safe' then false else final_safety_pending end where teen_id=auth.uid();
   update public.job_checkins set status='completed',completed_at=now()
     where application_id=a.id and user_id=auth.uid() and status in ('pending','missed');
   if a.status='in_progress' then
     insert into public.job_checkins(application_id,user_id,checkin_type,expected_at,status)
       values(a.id,auth.uid(),'cadence',now()+interval '6 minutes','pending');
   end if;
 elsif p_action in ('travel','continue_trip') then
   if a.status<>'accepted' or (p_action='continue_trip' and v.travel_state<>'reconfirm') then
     return jsonb_build_object('ok',false,'code','travel_transition_not_allowed'); end if;
   if p_payload ? 'travel_mode' and p_payload->>'travel_mode' not in ('WALK','DRIVE','BICYCLE','TRANSIT') then
     return jsonb_build_object('ok',false,'code','invalid_travel_mode'); end if;
   update private.safety_device_state set application_id=a.id,travel_state='traveling',
     travel_mode=coalesce(p_payload->>'travel_mode',travel_mode),eta_minutes=null,eta_observed_at=null where teen_id=auth.uid();
   for contact in select * from private.current_safety_contacts(auth.uid()) where relationship='guardian' loop
     perform public.enqueue_notification(contact.recipient_id,'MORT job update','A linked teen started their trip. Exact location sharing is off unless separately enabled.',jsonb_build_object('applicationId',a.id));
   end loop;
 elsif p_action='arrived' then
   if a.status<>'accepted' then return jsonb_build_object('ok',false,'code','arrival_transition_not_allowed'); end if;
   update private.safety_device_state set application_id=a.id,travel_state='arrived' where teen_id=auth.uid();
 elsif p_action='stop_trip' then
   update private.safety_device_state set travel_state='off',eta_minutes=null where teen_id=auth.uid();
 end if;
 perform private.audit_safety_runtime(auth.uid(),coalesce(event_id,a.id,auth.uid()),p_action);
 response:=jsonb_build_object('ok',true,'event_id',event_id,'acknowledged_at',now(),
   'sharing_expires_at',expiry,'delivery_confirmed',false,
   'guardian_queued',case when event_id is not null then (select count(*) from private.safety_event_recipients where safety_event_recipients.event_id=runtime_action.event_id and relationship='guardian') else 0 end,
   'trusted_queued',case when event_id is not null then (select count(*) from private.safety_event_recipients where safety_event_recipients.event_id=runtime_action.event_id and relationship='trusted') else 0 end);
 insert into private.safety_runtime_requests(actor_id,request_id,payload_hash,response) values(auth.uid(),p_client_request_id,h,response);
 return response||jsonb_build_object('replayed',false);
end $$;

create function public.record_safety_device_snapshot(p_application_id uuid,p_battery_percent integer,
 p_saver_enabled boolean,p_latitude double precision,p_longitude double precision,p_location_at timestamptz,p_expected_actor_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
 declare v private.safety_device_state%rowtype; c record;
begin
 if auth.uid() is null or p_expected_actor_id is distinct from auth.uid() then
   return jsonb_build_object('ok',false,'code','safety_actor_changed'); end if;
 if auth.uid() is null or not private.safety_account_active(auth.uid()) or not private.is_minor_teen(auth.uid()) then
   return jsonb_build_object('ok',false,'code','active_teen_required'); end if;
 if p_application_id is not null and not exists(select 1 from public.applications where id=p_application_id
   and teen_id=auth.uid() and status in ('accepted','in_progress','proof_submitted','completion_pending_release','disputed')) then
   return jsonb_build_object('ok',false,'code','assigned_active_job_required'); end if;
 if p_battery_percent is not null and p_battery_percent not between 0 and 100 then
   return jsonb_build_object('ok',false,'code','invalid_battery'); end if;
 if (p_latitude is null)<>(p_longitude is null) or p_latitude not between -90 and 90 or p_longitude not between -180 and 180
   or (p_latitude is not null and (p_location_at is null or p_location_at>now()+interval '10 seconds' or p_location_at<now()-interval '2 minutes')) then
   return jsonb_build_object('ok',false,'code','invalid_location_snapshot'); end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':safety-runtime',0));
 select * into v from private.safety_device_state where teen_id=auth.uid() for update;
 if v.offline_notified_at is not null then
   for c in select * from private.current_safety_contacts(auth.uid()) loop
     perform public.enqueue_notification(c.recipient_id,'MORT Safety','Device reconnected. Open MORT for details.',jsonb_build_object('teenId',auth.uid()));
   end loop;
   perform private.audit_safety_runtime(auth.uid(),auth.uid(),'device_reconnected');
 end if;
 insert into private.safety_device_state(teen_id,application_id,last_seen_at,battery_percent,saver_enabled,latitude,longitude,location_at)
 values(auth.uid(),p_application_id,now(),p_battery_percent,coalesce(p_saver_enabled,false),p_latitude,p_longitude,p_location_at)
 on conflict(teen_id) do update set application_id=coalesce(excluded.application_id,safety_device_state.application_id),
   last_seen_at=now(),battery_percent=coalesce(excluded.battery_percent,safety_device_state.battery_percent),saver_enabled=excluded.saver_enabled,
   latitude=coalesce(excluded.latitude,safety_device_state.latitude),longitude=coalesce(excluded.longitude,safety_device_state.longitude),
   location_at=coalesce(excluded.location_at,safety_device_state.location_at),offline_notified_at=null,
   next_checkin_at=case when safety_device_state.next_checkin_at is null and exists(select 1 from public.applications
     where id=p_application_id and status='in_progress') then now()+interval '6 minutes' else safety_device_state.next_checkin_at end,
   travel_state=case when safety_device_state.last_seen_at<=now()-interval '2 minutes' and safety_device_state.travel_state='traveling' then 'reconfirm' else safety_device_state.travel_state end;
 update public.job_location_share_sessions s set latitude=p_latitude,longitude=p_longitude,last_location_at=p_location_at
 where s.owner_id=auth.uid() and s.safety_event_id is not null and s.status='active' and s.expires_at>now()
   and p_latitude is not null and private.can_read_safety_event(s.safety_event_id,s.recipient_user_id);
 return jsonb_build_object('ok',true,'acknowledged_at',now());
end $$;

create function public.get_safety_event_status(p_event_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.safety_pings%rowtype; v private.safety_device_state%rowtype; s public.job_location_share_sessions%rowtype; snapshot jsonb;
begin
 select * into p from public.safety_pings where id=p_event_id;
 if p.id is null or auth.uid() is null or not private.safety_account_active(auth.uid()) or
   (p.teen_id<>auth.uid() and not private.can_read_safety_event(p.id,auth.uid())) then
   return jsonb_build_object('ok',false,'code','safety_event_not_authorized'); end if;
 select * into v from private.safety_device_state where teen_id=p.teen_id;
 select * into s from public.job_location_share_sessions where safety_event_id=p.id
   and (recipient_user_id=auth.uid() or owner_id=auth.uid()) order by created_at desc limit 1;
 perform private.audit_safety_runtime(auth.uid(),p.id,'view_event');
 select event_snapshot into snapshot from private.safety_event_recipients
   where event_id=p.id and recipient_id=auth.uid();
 return jsonb_build_object('ok',true,'event_id',p.id,'teen_id',p.teen_id,
   'teen_name',(select display_name from public.profiles where id=p.teen_id),
   'job_id',p.job_id,'safety_state',v.safety_state,'battery_percent',v.battery_percent,
   'last_checkin_at',v.last_checkin_at,'last_seen_at',v.last_seen_at,
   'live_sharing',coalesce(s.status='active' and s.expires_at>now(),false),
   'sharing_expires_at',s.expires_at,'latitude',coalesce(s.latitude,(snapshot->>'latitude')::double precision),
   'longitude',coalesce(s.longitude,(snapshot->>'longitude')::double precision),
   'last_location_at',coalesce(s.last_location_at,(snapshot->>'location_at')::timestamptz));
end $$;

-- New runtime shares may not bypass event scoping through the legacy reader.
create or replace function public.get_authorized_location_shares()
returns table(id uuid,application_id uuid,owner_id uuid,recipient_user_id uuid,mode public.location_share_mode,
 coarse_location text,latitude double precision,longitude double precision,status text,expires_at timestamptz,last_location_at timestamptz)
language sql stable security definer set search_path='' as $$
 select s.id,s.application_id,s.owner_id,s.recipient_user_id,s.mode,s.coarse_location,s.latitude,s.longitude,
 s.status,s.expires_at,s.last_location_at from public.job_location_share_sessions s
 where auth.uid() is not null and private.safety_account_active(auth.uid()) and s.status='active' and s.expires_at>now()
 and (s.owner_id=auth.uid() or (s.recipient_user_id=auth.uid()
   and ((s.safety_event_id is null and not (private.is_minor_teen(s.owner_id) and s.latitude is not null))
     or private.can_read_safety_event(s.safety_event_id,auth.uid()))))
 order by s.created_at desc
$$;

-- Successful routine check-ins do not notify guardians or trusted contacts.
create or replace function public.queue_safety_ping_notifications()
returns trigger language plpgsql security definer set search_path='' as $$
declare c record;
begin
 if new.status not in ('needs_help','missed') or not private.is_minor_teen(new.teen_id) then return new; end if;
 perform private.register_safety_event_recipients(new.id,new.teen_id);
 for c in select * from private.current_safety_contacts(new.teen_id) where relationship='guardian'
   and recipient_id is distinct from (select poster_id from public.jobs where id=new.job_id) loop
   perform public.enqueue_notification(c.recipient_id,'MORT Safety Alert','Open MORT for details.',jsonb_build_object('safetyPingId',new.id,'safetyEventId',new.id));
 end loop;
 -- Preserve trained staff fallback, never a physical-response promise.
 if not exists(select 1 from private.current_safety_contacts(new.teen_id) where relationship='guardian') then
   for c in select distinct r.user_id recipient_id from public.admin_role_assignments r
     join public.profiles p on p.id=r.user_id where r.revoked_at is null and p.account_status='active'
       and r.role in ('senior_safety_moderator','child_safety_specialist','incident_manager','super_admin') loop
     perform public.enqueue_notification(c.recipient_id,'MORT Safety Alert','Open MORT for restricted review.',jsonb_build_object('safetyPingId',new.id));
   end loop;
 end if;
 return new;
end $$;
create or replace function private.notify_safety_circle_ping()
returns trigger language plpgsql security definer set search_path='' as $$
declare c record;
begin
 if new.status not in ('needs_help','missed') then return new; end if;
 for c in select * from private.current_safety_contacts(new.teen_id)
   where relationship='trusted' and recipient_id is distinct from (select poster_id from public.jobs where id=new.job_id) loop
   perform public.enqueue_notification(c.recipient_id,'MORT Safety Alert','Open MORT for details.',jsonb_build_object('safetyPingId',new.id,'safetyEventId',new.id));
 end loop;
 return new;
end $$;

-- A single next check-in is rolled forward by the worker; never GPS polling.
create or replace function private.schedule_job_cadence_checkins()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.start_pin_used_at is null and new.start_pin_used_at is not null then
   insert into private.safety_device_state(teen_id,application_id,last_checkin_at,last_seen_at,next_checkin_at)
   values(new.teen_id,new.application_id,now(),now(),now()+interval '6 minutes')
   on conflict(teen_id) do update set application_id=excluded.application_id,last_checkin_at=now(),
     last_seen_at=now(),next_checkin_at=now()+interval '6 minutes',missed_online_checks=0,safety_state='normal',
     final_safety_pending=false,travel_state='off',eta_minutes=null,eta_observed_at=null;
   insert into public.job_checkins(application_id,user_id,checkin_type,expected_at,status)
   values(new.application_id,new.teen_id,'cadence',now()+interval '6 minutes','pending');
 end if;
 if old.finish_pin_used_at is null and new.finish_pin_used_at is not null then
   update private.safety_device_state set next_checkin_at=null,final_safety_pending=true
     where teen_id=new.teen_id and application_id=new.application_id;
   update public.job_checkins set status='canceled' where application_id=new.application_id and status='pending';
 end if;
 return new;
end $$;

create or replace function private.escalate_missed_job_checkins_worker()
returns integer language plpgsql security definer set search_path='' as $$
declare v private.safety_device_state%rowtype; event uuid; job uuid; count_processed integer:=0;
begin
 for v in select d.* from private.safety_device_state d
   join public.applications a on a.id=d.application_id
   where a.status in ('accepted','in_progress','proof_submitted')
     and private.is_minor_teen(d.teen_id) and private.safety_account_active(d.teen_id)
     and (d.final_safety_pending or not exists(select 1 from public.job_arrival_handshakes h
       where h.application_id=a.id and h.finish_pin_used_at is not null))
   for update of d skip locked loop
   perform pg_advisory_xact_lock(hashtextextended(v.teen_id::text||':safety-runtime',0));
   select job_id into job from public.applications where id=v.application_id;
   if v.safety_state='safety_exit' then continue; end if;
   if v.last_seen_at<=now()-interval '2 minutes' then
     update private.safety_device_state set safety_state=case when v.safety_state='safety_alert' then v.safety_state
       when v.last_seen_at<=now()-interval '15 minutes' then 'attention' else 'connection_lost' end where teen_id=v.teen_id;
     if v.last_seen_at<=now()-interval '5 minutes' and v.offline_notified_at is null then
       insert into public.safety_pings(teen_id,status,note,job_id,immediate_danger)
       values(v.teen_id,'missed','MORT cannot reach this device. This does not necessarily mean the teen is in danger.',job,false) returning id into event;
       perform private.register_safety_event_recipients(event,v.teen_id);
       update private.safety_device_state set offline_notified_at=now() where teen_id=v.teen_id;
       perform private.audit_safety_runtime(null,event,'device_disconnected');
     end if;
   elsif v.next_checkin_at is not null and v.next_checkin_at<=now()
     and exists(select 1 from public.applications where id=v.application_id and status='in_progress') then
     update public.job_checkins set status='missed' where application_id=v.application_id
       and user_id=v.teen_id and status='pending' and expected_at<=now();
     update private.safety_device_state set missed_online_checks=missed_online_checks+1,
       next_checkin_at=now()+interval '6 minutes',safety_state=case when v.safety_state='safety_alert' then v.safety_state
         when v.missed_online_checks=0 then 'checkin_missed' else 'attention' end where teen_id=v.teen_id;
     if v.missed_online_checks=0 then
       perform public.enqueue_notification(v.teen_id,'Quick safety check','Everything okay? Open MORT to check in.',jsonb_build_object('applicationId',v.application_id));
     elsif v.missed_online_checks=1 then
       insert into public.safety_pings(teen_id,status,note,job_id,immediate_danger)
       values(v.teen_id,'missed','Two online safety check-ins were missed. This is Safety Attention, not automatic emergency dispatch.',job,false) returning id into event;
       perform private.register_safety_event_recipients(event,v.teen_id);
       update public.job_checkins set escalation_sent_at=now() where application_id=v.application_id
         and user_id=v.teen_id and status='missed' and escalation_sent_at is null;
     end if;
     insert into public.job_checkins(application_id,user_id,checkin_type,expected_at,status)
       values(v.application_id,v.teen_id,'cadence',now()+interval '6 minutes','pending');
     perform private.audit_safety_runtime(null,v.application_id,'checkin_missed');
   end if;
   count_processed:=count_processed+1;
 end loop;
 update public.job_location_share_sessions set status='expired' where safety_event_id is not null and status='active' and expires_at<=now();
 return count_processed;
end $$;

-- Protect all entry points, including legacy RPCs and service-backed mutations.
create function public.list_my_safety_events()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(row_to_json(events)),'[]'::jsonb) from (
   select p.id event_id,p.teen_id,p.status,p.created_at,
     (select display_name from public.profiles where id=p.teen_id) teen_name
   from public.safety_pings p where auth.uid() is not null and private.safety_account_active(auth.uid())
     and p.status in ('needs_help','missed') and p.created_at>now()-interval '24 hours'
     and (p.teen_id=auth.uid() or private.can_read_safety_event(p.id,auth.uid()))
   order by p.created_at desc limit 50
 ) events
$$;
create function public.list_guardian_safety_status()
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; teen uuid;
begin
 if auth.uid() is null or not private.safety_account_active(auth.uid()) then
   return jsonb_build_object('ok',false,'code','active_account_required'); end if;
 select coalesce(jsonb_agg(jsonb_build_object('teen_id',c.teen_id,'teen_name',p.display_name,
   'job_title',case when preferences.accepted_job_summary then j.title end,
   'job_status',case when preferences.accepted_job_summary then a.status::text end,
   'travel_state',case when preferences.accepted_job_summary then coalesce(d.travel_state,'off') end,
   'eta_range_min',case when preferences.accepted_job_summary and d.travel_state='traveling'
     and d.application_id=a.id and d.last_seen_at>now()-interval '2 minutes' and d.eta_observed_at>now()-interval '5 minutes' then (d.eta_minutes/5)*5 end,
   'eta_range_max',case when preferences.accepted_job_summary and d.travel_state='traveling'
     and d.application_id=a.id and d.last_seen_at>now()-interval '2 minutes' and d.eta_observed_at>now()-interval '5 minutes' then (d.eta_minutes/5)*5+5 end,
   'last_checkin_at',case when preferences.job_checkin_alerts then d.last_checkin_at end,
   'connection_lost',case when preferences.job_checkin_alerts then coalesce(d.last_seen_at<now()-interval '2 minutes',false) end,
   'saver_enabled',case when preferences.job_checkin_alerts then d.saver_enabled end,
   'safety_state',case when preferences.safety_ping_alerts then coalesce(d.safety_state,'normal') end)),'[]'::jsonb)
 into result from public.guardian_connections c join public.profiles p on p.id=c.teen_id
 join public.guardian_preferences preferences on preferences.link_id=c.id
 left join lateral(select * from public.applications where teen_id=c.teen_id
   and status in ('accepted','in_progress','proof_submitted','completion_pending_release','disputed')
   order by case when status in ('in_progress','proof_submitted','completion_pending_release') then 0
     when id=(select application_id from private.safety_device_state where teen_id=c.teen_id) then 1 else 2 end,
     created_at desc limit 1) a on true
 left join public.jobs j on j.id=a.job_id
 left join private.safety_device_state d on d.teen_id=c.teen_id
 where c.guardian_id=auth.uid() and c.status='active' and private.is_minor_teen(c.teen_id)
   and private.safety_account_active(c.teen_id);
 for teen in select c.teen_id from public.guardian_connections c where c.guardian_id=auth.uid()
   and c.status='active' and private.is_minor_teen(c.teen_id) loop
   perform private.audit_safety_runtime(auth.uid(),teen,'guardian_view_status');
 end loop;
 return jsonb_build_object('ok',true,'teens',result);
end $$;
create function public.record_safety_contact_reached(p_event_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not private.can_read_safety_event(p_event_id,auth.uid()) then
   return jsonb_build_object('ok',false,'code','safety_event_not_authorized'); end if;
 perform private.audit_safety_runtime(auth.uid(),p_event_id,'contact_reached_teen');
 return jsonb_build_object('ok',true,'acknowledged_at',now(),'teen_status_unchanged',true);
end $$;
create function public.get_job_safety_runtime(p_application_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.applications%rowtype; j public.jobs%rowtype; d private.safety_device_state%rowtype;
begin
 select * into a from public.applications where id=p_application_id;
 select * into j from public.jobs where id=a.job_id;
 if auth.uid() is null or not private.safety_account_active(auth.uid()) or a.id is null or
   (auth.uid() not in (a.teen_id,j.poster_id) and not exists(select 1 from private.current_safety_contacts(a.teen_id)
     where recipient_id=auth.uid() and relationship='guardian' and exists(select 1 from public.guardian_connections gc
       join public.guardian_preferences gp on gp.link_id=gc.id where gc.teen_id=a.teen_id and gc.guardian_id=auth.uid()
       and gc.status='active' and gp.accepted_job_summary))) then
   return jsonb_build_object('ok',false,'code','job_safety_not_authorized'); end if;
 select * into d from private.safety_device_state where teen_id=a.teen_id and application_id=a.id;
 return jsonb_build_object('ok',true,'application_id',a.id,'job_id',j.id,'job_status',a.status,
   'travel_state',coalesce(d.travel_state,'off'),'travel_mode',d.travel_mode,
   'eta_minutes',case when auth.uid()=a.teen_id and d.travel_state='traveling' and d.last_seen_at>now()-interval '2 minutes'
     and d.eta_observed_at>now()-interval '5 minutes' then d.eta_minutes end,
   'eta_range_min',case when d.travel_state='traveling' and d.last_seen_at>now()-interval '2 minutes'
     and d.eta_observed_at>now()-interval '5 minutes' then greatest(0,(d.eta_minutes/5)*5) end,
   'eta_range_max',case when d.travel_state='traveling' and d.last_seen_at>now()-interval '2 minutes'
     and d.eta_observed_at>now()-interval '5 minutes' then (d.eta_minutes/5)*5+5 end,
   'nearby',coalesce(d.travel_state='traveling' and d.last_seen_at>now()-interval '2 minutes'
     and d.eta_observed_at>now()-interval '5 minutes' and d.eta_minutes<=10,false),
   'connection_lost',coalesce(d.last_seen_at<now()-interval '2 minutes',false),
   'last_seen_at',d.last_seen_at,'final_safety_pending',coalesce(d.final_safety_pending,false),
   'review_hold',private.safety_job_review_held(a.id),'last_checkin_at',case when auth.uid()=a.teen_id or
     (auth.uid()<>j.poster_id and exists(select 1 from public.guardian_connections gc join public.guardian_preferences gp on gp.link_id=gc.id
       where gc.teen_id=a.teen_id and gc.guardian_id=auth.uid() and gc.status='active' and gp.job_checkin_alerts)) then d.last_checkin_at end);
end $$;

-- Temporary safety conversations extend canonical threads, never the private
create function public.record_worker_connection_response(p_application_id uuid,p_response text,p_client_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.applications%rowtype; j public.jobs%rowtype;
 r private.safety_runtime_requests%rowtype; h text; result jsonb;
begin
 select * into a from public.applications where id=p_application_id;
 select * into j from public.jobs where id=a.job_id;
 if auth.uid() is null or not private.safety_account_active(auth.uid()) or auth.uid() is distinct from j.poster_id then
   return jsonb_build_object('ok',false,'code','job_poster_required'); end if;
 if p_client_request_id is null or p_response is null or p_response not in ('wait_for_worker','worker_arrived_device_unavailable','wait_for_device','cancel_connection') then
   return jsonb_build_object('ok',false,'code','invalid_connection_response'); end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':safety-runtime',0));
 h:=encode(extensions.digest(jsonb_build_object('application',a.id,'response',p_response)::text,'sha256'),'hex');
 select * into r from private.safety_runtime_requests where actor_id=auth.uid() and request_id=p_client_request_id;
 if found then
   if r.payload_hash<>h then return jsonb_build_object('ok',false,'code','safety_request_payload_mismatch'); end if;
   return r.response||jsonb_build_object('replayed',true);
 end if;
 if a.status<>'accepted' then return jsonb_build_object('ok',false,'code','connection_response_not_allowed'); end if;
 if p_response='cancel_connection' then
   result:=public.request_adult_job_cancellation(a.id,'Connection / safety issue. This is not a no-show finding.',p_client_request_id);
   if result->>'ok'<>'true' then return result; end if;
 else result:=jsonb_build_object('ok',true,'statement_only',true,'job_status_unchanged',true); end if;
 perform private.audit_safety_runtime(auth.uid(),a.id,'poster_statement_'||p_response);
 insert into private.safety_runtime_requests(actor_id,request_id,payload_hash,response) values(auth.uid(),p_client_request_id,h,result);
 return result||jsonb_build_object('replayed',false);
end $$;
revoke all on function public.record_worker_connection_response(uuid,text,uuid) from public,anon;
grant execute on function public.record_worker_connection_response(uuid,text,uuid) to authenticated,service_role;

-- teen/poster job thread. Link/age/ban/event checks run on every access.
create function private.is_safety_contact_participant(p_thread_id uuid,p_actor_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select private.safety_account_active(p_actor_id) and exists(
   select 1 from public.message_threads t join public.safety_pings p on p.id=t.safety_event_id
   where t.id=p_thread_id and p_actor_id in (t.teen_id,t.adult_id,t.guardian_id)
     and private.can_read_safety_event(p.id,t.guardian_id))
$$;
create or replace function public.is_thread_participant(p_thread_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and private.safety_account_active(auth.uid()) and exists(
   select 1 from public.message_threads t where t.id=p_thread_id and
    ((t.safety_event_id is not null and private.is_safety_contact_participant(t.id,auth.uid()))
     or (t.safety_event_id is null and auth.uid() in (t.teen_id,t.adult_id)
       and private.has_marketplace_identity(auth.uid()))))
$$;
create function public.open_safety_contact(p_event_id uuid,p_target text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.safety_pings%rowtype; j public.jobs%rowtype; thread uuid;
begin
 if auth.uid() is null or not private.can_read_safety_event(p_event_id,auth.uid()) then
   return jsonb_build_object('ok',false,'code','safety_event_not_authorized'); end if;
 if p_target is null or p_target not in ('teen','poster') then return jsonb_build_object('ok',false,'code','invalid_safety_contact_target'); end if;
 select * into p from public.safety_pings where id=p_event_id;
 select * into j from public.jobs where id=p.job_id;
 if p_target='poster' and j.id is null then return jsonb_build_object('ok',false,'code','safety_job_not_available'); end if;
 if not private.safety_account_active(case when p_target='teen' then p.teen_id else j.poster_id end) then
   return jsonb_build_object('ok',false,'code','safety_contact_not_available'); end if;
 perform pg_advisory_xact_lock(hashtextextended(p_event_id::text||auth.uid()::text||p_target,0));
 select id into thread from public.message_threads where safety_event_id=p_event_id and guardian_id=auth.uid() and safety_contact_kind=p_target;
 if thread is null then
   insert into public.message_threads(job_id,teen_id,adult_id,guardian_id,safety_event_id,safety_contact_kind)
     values(j.id,case when p_target='teen' then p.teen_id end,
       case when p_target='poster' then j.poster_id end,auth.uid(),p_event_id,p_target) returning id into thread;
   perform public.enqueue_notification(case when p_target='teen' then p.teen_id else j.poster_id end,
     'MORT Safety Contact','A temporary Safety Contact is available for this event. Open MORT for details.',
     jsonb_build_object('safetyContactThreadId',thread));
 end if;
 perform private.audit_safety_runtime(auth.uid(),p_event_id,'open_safety_contact_'||p_target);
 return jsonb_build_object('ok',true,'thread_id',thread);
end $$;
create function public.get_safety_contact_thread(p_thread_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare messages jsonb; t public.message_threads%rowtype;
begin
 if auth.uid() is null or not private.is_safety_contact_participant(p_thread_id,auth.uid()) then
   return jsonb_build_object('ok',false,'code','safety_contact_not_authorized'); end if;
 select * into t from public.message_threads where id=p_thread_id;
 select coalesce(jsonb_agg(row_to_json(m)),'[]'::jsonb) into messages from (
   select id,sender_id,case when scanner_status='blocked' then '[Blocked by MORT safety controls]' else body end body,created_at
   from public.messages where thread_id=p_thread_id order by created_at desc limit 100) m;
 perform private.audit_safety_runtime(auth.uid(),t.safety_event_id,'read_safety_contact');
 return jsonb_build_object('ok',true,'event_id',t.safety_event_id,'kind',t.safety_contact_kind,
   'is_poster',auth.uid()=t.adult_id,'messages',messages);
end $$;

create function public.submit_safety_report_categories(p_categories text[],p_details text,p_target_user_id uuid,
 p_target_job_id uuid,p_target_message_id uuid,p_target_review_id uuid,p_immediate_danger boolean,p_client_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare categories text[]; primary_category text; severity text; result jsonb; narrative text;
begin
 select array_agg(distinct item order by item) into categories from unnest(p_categories) item;
 if categories is null or cardinality(categories) not between 1 and 12 or exists(select 1 from unnest(categories) c
   where c not in ('harassment','threats','stalking','scam','child_safety_concern','personal_information_request','discrimination',
     'unsafe_job_conditions','off_platform_pressure','sexual_conduct','inappropriate_images','weapons','other_urgent_concern'))
   or array_position(p_categories,null) is not null then return jsonb_build_object('ok',false,'code','invalid_safety_categories'); end if;
 if char_length(coalesce(p_details,''))>5000 then return jsonb_build_object('ok',false,'code','report_details_too_long'); end if;
 select c into primary_category from unnest(categories) c order by case
   when c in ('child_safety_concern','sexual_conduct','inappropriate_images','threats','weapons') then 0
   when c='stalking' then 1 else 2 end,c limit 1;
 severity:=case when coalesce(p_immediate_danger,false) then 'critical'
   when primary_category in ('child_safety_concern','sexual_conduct','inappropriate_images','threats','weapons','stalking') then 'high' else 'moderate' end;
 narrative:='Selected concerns: '||array_to_string(categories,', ')||'. '||
   case when btrim(coalesce(p_details,''))='' then 'No additional narrative provided.' else btrim(p_details) end;
 result:=public.submit_safety_report_v2(p_target_user_id,p_target_job_id,p_target_message_id,p_target_review_id,null,
   primary_category,severity,coalesce(p_immediate_danger,false),narrative,null,null,
   'Review the selected safety concerns.',true,p_client_request_id);
 if result->>'ok'='true' then
   update public.reports set selected_safety_categories=categories
     where id=(result->>'report_id')::uuid and reporter_id=auth.uid();
   update public.safety_incidents i set application_id=a.id from public.applications a join public.jobs j on j.id=a.job_id
     where i.id=(result->>'incident_id')::uuid and i.reporter_id=auth.uid() and a.job_id=p_target_job_id
       and auth.uid() in (a.teen_id,j.poster_id) and a.status in ('accepted','in_progress','proof_submitted','completion_pending_release','disputed');
   update private.safety_device_state d set review_hold=true where exists(select 1 from public.safety_incidents i
     where i.id=(result->>'incident_id')::uuid and i.application_id=d.application_id);
 end if;
 return result;
end $$;

-- Private cancellation narrative is limited to its author and safety reviewers.
drop policy if exists safety_cancellations_participant_select on public.safety_cancellations;
create policy safety_cancellations_participant_select on public.safety_cancellations for select to authenticated
using(actor_id=(select auth.uid()));

-- Location tables are read only through caller-scoped RPCs.
revoke truncate,references,trigger on public.job_location_share_sessions from authenticated;

create function private.guard_safety_location_write()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if private.is_minor_teen(new.owner_id) and new.status='active' and new.expires_at>now() then
   if new.latitude is not null and (new.safety_event_id is null or
     not private.can_read_safety_event(new.safety_event_id,new.recipient_user_id)) then
     raise exception 'teen_precise_location_requires_authorized_safety_event'; end if;
   if new.safety_event_id is not null and new.expires_at>new.starts_at+interval '60 minutes' then
     raise exception 'safety_share_limit_60_minutes'; end if;
 end if;
 return new;
end $$;
create trigger safety_location_write_guard before insert or update on public.job_location_share_sessions
for each row execute function private.guard_safety_location_write();

create function private.sync_safety_completed_checkin()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='completed' and old.status is distinct from 'completed' then
   update private.safety_device_state set last_checkin_at=now(),missed_online_checks=0,
     next_checkin_at=case when exists(select 1 from public.applications where id=new.application_id and status='in_progress')
       then now()+interval '6 minutes' end,
     safety_state=case when safety_state in ('checkin_missed','attention') then 'normal' else safety_state end
   where teen_id=new.user_id and application_id=new.application_id;
 end if;
 return new;
end $$;
create trigger safety_completed_checkin_sync after update on public.job_checkins
for each row execute function private.sync_safety_completed_checkin();

create function private.safety_job_review_held(p_application_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.safety_cancellations c
   left join public.safety_incidents i on i.id=c.incident_id
   where c.application_id=p_application_id and c.is_safety_related
     and (i.id is null or i.status not in ('resolved','closed')))
 or exists(select 1 from public.safety_incidents i where i.application_id=p_application_id
   and i.status not in ('resolved','closed'))
$$;
create function private.guard_safety_job_transition()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status is distinct from old.status and new.status in ('completed','completion_pending_release','proof_submitted') then
   if private.safety_job_review_held(new.id) then raise exception 'safety_review_hold'; end if;
   if new.status='completed' and exists(select 1 from private.safety_device_state where application_id=new.id and final_safety_pending) then
     raise exception 'final_safety_check_required'; end if;
 end if;
 return new;
end $$;
create trigger safety_job_transition_guard before update on public.applications
for each row execute function private.guard_safety_job_transition();
create function private.guard_safety_review()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.applications a where a.job_id=new.job_id
   and (private.safety_job_review_held(a.id) or exists(select 1 from public.jobs j join public.trusted_relationships r
     on r.owner_id in (a.teen_id,j.poster_id) and r.target_id in (a.teen_id,j.poster_id)
     where j.id=a.job_id and r.relationship_type='no_contact'))) then
   new.moderation_status:='pending_review';
 end if;
 return new;
end $$;
create trigger safety_review_hold_guard before insert or update on public.reviews
for each row execute function private.guard_safety_review();
create function private.guard_safety_abandonment()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if private.safety_job_review_held(new.application_id) then raise exception 'safety_review_hold'; end if;
 return new;
end $$;
create trigger safety_abandonment_guard before insert on public.teen_abandonment_reports
for each row execute function private.guard_safety_abandonment();
create function private.sync_safety_case_resolution()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status in ('resolved','closed') and old.status is distinct from new.status then
   update private.safety_device_state set review_hold=private.safety_job_review_held(application_id)
     where application_id=new.application_id;
   update public.job_location_share_sessions s set status='stopped',stopped_at=now()
     where s.status='active' and exists(select 1 from public.safety_pings p where p.id=s.safety_event_id and p.incident_id=new.id);
 end if;
 return new;
end $$;
create trigger safety_case_resolution_sync after update of status on public.safety_incidents
for each row execute function private.sync_safety_case_resolution();

create function private.safety_case_reviewer(p_incident_id uuid,p_actor_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select p_actor_id=auth.uid() and private.safety_account_active(p_actor_id) and exists(
   select 1 from public.safety_incidents i where i.id=p_incident_id and
     private.has_admin_safety_role(p_actor_id,case when i.category in (
       'sexual_harassment','sexual_conduct','inappropriate_touching','inappropriate_images',
       'child_safety_concern','kidnapping_abduction_concern') then
       array['senior_safety_moderator','child_safety_specialist','incident_manager']::public.admin_safety_role[]
       else array['moderator','senior_safety_moderator','child_safety_specialist','incident_manager']::public.admin_safety_role[] end))
$$;
create policy safety_case_staff_scope on public.safety_incidents as restrictive for select to authenticated
using(private.is_incident_participant(id,(select auth.uid())) or private.safety_case_reviewer(id,(select auth.uid())));
alter policy safety_cancellations_participant_select on public.safety_cancellations
using(actor_id=(select auth.uid()) or private.safety_case_reviewer(incident_id,(select auth.uid())));
create policy safety_evidence_staff_scope on public.incident_evidence as restrictive for select to authenticated
using(submitted_by=(select auth.uid()) or private.safety_case_reviewer(incident_id,(select auth.uid())));
create policy safety_timeline_staff_scope on public.incident_timeline_events as restrictive for select to authenticated
using(private.is_incident_participant(incident_id,(select auth.uid())) or private.safety_case_reviewer(incident_id,(select auth.uid())));
create function public.get_staff_safety_context(p_incident_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.safety_incidents%rowtype; a public.applications%rowtype; d private.safety_device_state%rowtype;
begin
 if auth.uid() is null or not private.safety_case_reviewer(p_incident_id,auth.uid()) then
   return jsonb_build_object('ok',false,'code','incident_reviewer_required'); end if;
 if char_length(btrim(coalesce(p_reason,'')))<10 then return jsonb_build_object('ok',false,'code','safety_access_reason_required'); end if;
 select * into i from public.safety_incidents where id=p_incident_id;
 select * into a from public.applications where id=i.application_id;
 select * into d from private.safety_device_state where teen_id=a.teen_id and application_id=a.id;
 insert into public.private_data_access_events(actor_id,resource_type,resource_id,action,reason)
   values(auth.uid(),'safety_runtime',i.id,'staff_view_context',left(btrim(p_reason),500));
 return jsonb_build_object('ok',true,'incident_id',i.id,'application_id',a.id,
   'safety_state',d.safety_state,'battery_percent',d.battery_percent,'last_seen_at',d.last_seen_at,
   'last_checkin_at',d.last_checkin_at,'review_hold',private.safety_job_review_held(a.id),
   'safety_exit',exists(select 1 from public.safety_cancellations where application_id=a.id and is_safety_related),
   'evidence_count',(select count(*) from public.incident_evidence where incident_id=i.id));
end $$;

-- Preserve existing scanner, evidence and identity guards; add event-scoped contact exceptions.
create or replace function public.send_safe_message(p_thread_id uuid, p_body text)
returns public.messages
language plpgsql
security definer
set search_path = 'public', 'extensions', 'pg_temp'
as $$
declare
  v_scan jsonb;
  v_message public.messages%rowtype;
  v_thread public.message_threads%rowtype;
  v_target uuid;
  v_repeated boolean := false;
  v_incident public.safety_incidents%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if not private.safety_account_active(auth.uid()) then
    raise exception 'user_account_restricted';
  end if;
  if not private.has_marketplace_identity(auth.uid()) and not private.is_safety_contact_participant(p_thread_id,auth.uid()) then
    raise exception 'identity_verification_required';
  end if;
  if not public.is_thread_participant(p_thread_id) then
    raise exception 'thread_participant_required';
  end if;

  select * into v_thread from public.message_threads where id = p_thread_id;
  if v_thread.teen_id = auth.uid() and public.teen_is_paused(v_thread.teen_id) then
    raise exception 'guardian_mode_paused';
  end if;
  if (v_thread.teen_id is not null and v_thread.teen_id <> auth.uid() and public.users_are_blocked(auth.uid(), v_thread.teen_id))
    or (v_thread.adult_id is not null and v_thread.adult_id <> auth.uid() and public.users_are_blocked(auth.uid(), v_thread.adult_id))
    or (v_thread.guardian_id is not null and v_thread.guardian_id <> auth.uid() and public.users_are_blocked(auth.uid(), v_thread.guardian_id)) then
    raise exception 'participant_blocked';
  end if;

  select count(*) >= 4 into v_repeated
  from public.messages message
  where message.thread_id = p_thread_id
    and message.sender_id = auth.uid()
    and message.created_at > now() - interval '15 minutes'
    and not exists (
      select 1
      from public.messages reply
      where reply.thread_id = p_thread_id
        and reply.sender_id <> auth.uid()
        and reply.created_at > message.created_at
    );

  v_scan := private.classify_message_safety(p_body);
  if v_repeated then
    v_scan := jsonb_build_object(
      'blocked', true,
      'category', 'repeated_unwanted_contact',
      'severity', 'moderate',
      'reason', 'Pause and wait for the other participant to respond.',
      'safer_rewrite', false
    );
  end if;

  if coalesce((v_scan->>'blocked')::boolean, false) then
    insert into public.messages (
      thread_id, sender_id, body, scanner_status, scanner_reason,
      safety_category, safety_severity, preserved_for_safety,
      safer_rewrite_available
    ) values (
      p_thread_id,
      auth.uid(),
      '[Blocked by MORT safety controls]',
      'blocked',
      v_scan->>'reason',
      (v_scan->>'category')::public.safety_report_category,
      (v_scan->>'severity')::public.safety_incident_severity,
      (v_scan->>'severity') in ('high', 'critical'),
      coalesce((v_scan->>'safer_rewrite')::boolean, false)
    ) returning * into v_message;

    insert into public.message_safety_evidence (
      message_id, sender_id, thread_id, raw_body, body_sha256,
      category, severity, preserved_until
    ) values (
      v_message.id,
      auth.uid(),
      p_thread_id,
      left(p_body, 2000),
      encode(extensions.digest(left(p_body, 2000), 'sha256'), 'hex'),
      (v_scan->>'category')::public.safety_report_category,
      (v_scan->>'severity')::public.safety_incident_severity,
      case when (v_scan->>'severity') in ('high', 'critical') then now() + interval '1 year' else null end
    );

    if (v_scan->>'severity') in ('high', 'critical') then
      v_target := case
        when v_thread.teen_id is distinct from auth.uid() then v_thread.teen_id
        when v_thread.adult_id is distinct from auth.uid() then v_thread.adult_id
        else v_thread.guardian_id
      end;

      insert into public.safety_incidents (
        reporter_id, subject_user_id, job_id, application_id,
        category, severity, immediate_danger, priority, sla_due_at,
        preservation_status
      ) values (
        null,
        auth.uid(),
        v_thread.job_id,
        v_thread.application_id,
        (v_scan->>'category')::public.safety_report_category,
        (v_scan->>'severity')::public.safety_incident_severity,
        (v_scan->>'severity') = 'critical',
        case when (v_scan->>'severity') = 'critical' then 1 else 2 end,
        now() + case when (v_scan->>'severity') = 'critical' then interval '15 minutes' else interval '2 hours' end,
        'preserve_relevant_records'
      ) returning * into v_incident;

      insert into public.incident_participants (
        incident_id, user_id, participant_role
      ) values (
        v_incident.id, auth.uid(), 'accused_person'
      ) on conflict do nothing;
      if v_target is not null then
        insert into public.incident_participants (
          incident_id, user_id, participant_role
        ) values (
          v_incident.id, v_target, 'affected_person'
        ) on conflict do nothing;
        perform public.enqueue_notification(
          v_target,
          'MORT blocked a safety-sensitive message',
          'A message was blocked. You can report, block, leave the job, or use Safety Ping. Contact emergency services for immediate danger.',
          jsonb_build_object('threadId', p_thread_id, 'incidentId', v_incident.id)
        );
      end if;
      insert into public.incident_timeline_events (
        incident_id, actor_id, event_type, public_status_note,
        restricted_note, event_data
      ) values (
        v_incident.id,
        null,
        'automated_message_signal',
        'A message safety signal was queued for human review.',
        'Raw content is stored separately with restricted access.',
        jsonb_build_object('message_id', v_message.id, 'category', v_scan->>'category', 'severity', v_scan->>'severity')
      );
    end if;
    return v_message;
  end if;

  insert into public.messages (
    thread_id, sender_id, body, scanner_status, scanner_reason,
    safety_category, safety_severity, safer_rewrite_available
  ) values (
    p_thread_id,
    auth.uid(),
    btrim(p_body),
    case when v_scan->>'category' is null then 'clean'::public.scanner_status else 'flagged'::public.scanner_status end,
    v_scan->>'reason',
    nullif(v_scan->>'category', '')::public.safety_report_category,
    nullif(v_scan->>'severity', '')::public.safety_incident_severity,
    coalesce((v_scan->>'safer_rewrite')::boolean, false)
  ) returning * into v_message;

  return v_message;
end;
$$;

create or replace function private.enforce_marketplace_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
  v_deleting_user_id uuid;
begin
  begin
    v_deleting_user_id := nullif(
      current_setting('mort.account_deletion_user_id', true),
      ''
    )::uuid;
  exception
    when invalid_text_representation then
      v_deleting_user_id := null;
  end;

  if tg_table_name = 'jobs' then
    if session_user = 'supabase_auth_admin'
       and new.poster_id is null
       and old.poster_id = v_deleting_user_id then
      return new;
    end if;
    if new.status <> 'draft'
       and not private.has_marketplace_identity(new.poster_id) then
      raise exception 'poster_verification_required';
    end if;
  elsif tg_table_name = 'applications' then
    if session_user = 'supabase_auth_admin'
       and new.teen_id is null
       and old.teen_id = v_deleting_user_id then
      return new;
    end if;
    if not private.has_marketplace_identity(new.teen_id) then
      raise exception 'applicant_verification_required';
    end if;
    if new.status in ('accepted', 'in_progress', 'proof_submitted', 'completed') then
      select * into v_job from public.jobs where id = new.job_id;
      if not private.has_marketplace_identity(v_job.poster_id) then
        raise exception 'poster_verification_required';
      end if;
    end if;
  elsif tg_table_name = 'messages' then
    if not private.has_marketplace_identity(new.sender_id) and not (new.sender_id=auth.uid() and private.is_safety_contact_participant(new.thread_id,new.sender_id)) then
      raise exception 'identity_verification_required';
    end if;
  elsif tg_table_name = 'proof_uploads' then
    if not private.has_marketplace_identity(new.uploaded_by) then
      raise exception 'identity_verification_required';
    end if;
  elsif tg_table_name = 'reviews' then
    if not private.has_marketplace_identity(new.reviewer_id) then
      raise exception 'identity_verification_required';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.save_job_safety_plan(
  p_application_id uuid,
  p_expected_people text,
  p_public_or_visible_meeting boolean,
  p_daylight_preferred boolean,
  p_transportation_plan text,
  p_checkin_cadence_minutes integer
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'extensions', 'pg_temp'
as $$
declare
  v_plan public.job_safety_plans%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_terms jsonb;
begin
  if auth.uid() is null or not private.is_job_safety_participant(p_application_id, auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if p_checkin_cadence_minutes is not null and p_checkin_cadence_minutes<>6 and p_checkin_cadence_minutes not between 15 and 240 then
    return jsonb_build_object('ok', false, 'code', 'invalid_checkin_cadence');
  end if;

  update public.job_safety_plans
  set expected_people = nullif(left(btrim(coalesce(p_expected_people, '')), 500), ''),
      public_or_visible_meeting = p_public_or_visible_meeting,
      daylight_preferred = p_daylight_preferred,
      transportation_plan = nullif(left(btrim(coalesce(p_transportation_plan, '')), 1000), ''),
      checkin_cadence_minutes = p_checkin_cadence_minutes,
      teen_updated_at = case when teen_id = auth.uid() then now() else teen_updated_at end,
      adult_updated_at = case when adult_id = auth.uid() then now() else adult_updated_at end,
      updated_at = now()
  where application_id = p_application_id
  returning * into v_plan;

  if v_plan.id is null then
    return jsonb_build_object('ok', false, 'code', 'safety_plan_not_found');
  end if;

  v_terms := private.job_safety_terms(p_application_id);
  update public.job_safety_agreements
  set agreement_version = agreement_version + 1,
      terms_snapshot = v_terms,
      material_terms_hash = encode(extensions.digest(v_terms::text, 'sha256'), 'hex'),
      status = 'reconfirmation_required',
      teen_confirmed_at = null,
      adult_confirmed_at = null,
      teen_confirmed_version = null,
      adult_confirmed_version = null,
      updated_at = now()
  where application_id = p_application_id
  returning * into v_agreement;

  return jsonb_build_object(
    'ok', true,
    'plan', to_jsonb(v_plan),
    'agreement_version', v_agreement.agreement_version,
    'agreement_status', v_agreement.status
  );
end;
$$;

create or replace function public.authorize_incident_evidence_access(
  p_evidence_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_evidence public.incident_evidence%rowtype;
  v_grant public.incident_evidence_access_grants%rowtype;
begin
  if auth.uid() is null or not private.safety_case_reviewer((select incident_id from public.incident_evidence where id=p_evidence_id),auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'incident_reviewer_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 10 then
    return jsonb_build_object('ok', false, 'code', 'evidence_access_reason_required');
  end if;

  select * into v_evidence from public.incident_evidence where id = p_evidence_id;
  if v_evidence.id is null then
    return jsonb_build_object('ok', false, 'code', 'evidence_not_found');
  end if;

  insert into public.incident_evidence_access_grants (
    evidence_id, reviewer_id, access_reason, expires_at
  ) values (
    p_evidence_id, auth.uid(), left(btrim(p_reason), 500), now() + interval '5 minutes'
  ) returning * into v_grant;

  insert into public.incident_timeline_events (
    incident_id, actor_id, event_type, restricted_note,
    event_data
  ) values (
    v_evidence.incident_id,
    auth.uid(),
    'evidence_access_authorized',
    left(btrim(p_reason), 500),
    jsonb_build_object('evidence_id', p_evidence_id, 'expires_at', v_grant.expires_at)
  );

  return jsonb_build_object(
    'ok', true,
    'evidence_id', v_evidence.id,
    'bucket_id', v_evidence.bucket_id,
    'storage_path', v_evidence.storage_path,
    'content_type', v_evidence.content_type,
    'expires_at', v_grant.expires_at
  );
end;
$$;

create or replace function public.admin_update_incident_case(
  p_incident_id uuid,
  p_status text,
  p_public_status_note text,
  p_restricted_note text default null,
  p_severity text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_status public.safety_incident_status;
  v_severity public.safety_incident_severity;
  v_incident public.safety_incidents%rowtype;
begin
  if auth.uid() is null or not private.safety_case_reviewer(p_incident_id,auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'incident_reviewer_required');
  end if;
  if char_length(btrim(coalesce(p_public_status_note, ''))) < 5 then
    return jsonb_build_object('ok', false, 'code', 'public_status_note_required');
  end if;
  if lower(btrim(p_status)) in ('resolved','closed') and char_length(btrim(coalesce(p_restricted_note,'')))<10 then
    return jsonb_build_object('ok',false,'code','safety_resolution_reason_required'); end if;
  begin
    v_status := lower(btrim(p_status))::public.safety_incident_status;
    v_severity := coalesce(lower(btrim(p_severity))::public.safety_incident_severity, null);
  exception when invalid_text_representation then
    return jsonb_build_object('ok', false, 'code', 'invalid_incident_update');
  end;

  update public.safety_incidents
  set status = v_status,
      severity = coalesce(v_severity, severity),
      updated_at = now(),
      closed_at = case when v_status in ('closed', 'resolved') then now() else closed_at end
  where id = p_incident_id
  returning * into v_incident;

  if v_incident.id is null then
    return jsonb_build_object('ok', false, 'code', 'incident_not_found');
  end if;

  insert into public.incident_timeline_events (
    incident_id, actor_id, event_type, public_status_note,
    restricted_note, event_data
  ) values (
    p_incident_id,
    auth.uid(),
    'case_status_updated',
    left(btrim(p_public_status_note), 1000),
    nullif(left(btrim(coalesce(p_restricted_note, '')), 5000), ''),
    jsonb_build_object('status', v_status, 'severity', v_incident.severity)
  );

  return jsonb_build_object('ok', true, 'incident_id', v_incident.id, 'case_number', v_incident.case_number, 'status', v_incident.status);
end;
$$;

create or replace function public.get_incident_evidence_manifest(
  p_incident_id uuid
)
returns table (
  evidence_id uuid,
  evidence_type text,
  evidence_status text,
  content_type text,
  byte_size bigint,
  submitted_at timestamptz,
  retention_delete_at timestamptz,
  preserved boolean
)
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
begin
  if auth.uid() is null or not private.safety_case_reviewer(p_incident_id,auth.uid()) then
    raise exception 'incident_reviewer_required';
  end if;
  if not exists (
    select 1 from public.safety_incidents incident
    where incident.id = p_incident_id
  ) then
    raise exception 'incident_not_found';
  end if;

  insert into public.incident_timeline_events (
    incident_id, actor_id, event_type, restricted_note
  ) values (
    p_incident_id, auth.uid(), 'evidence_manifest_viewed',
    'Reviewer opened metadata-only evidence manifest; no document path or content was returned.'
  );

  return query
  select
    evidence.id,
    evidence.evidence_type,
    evidence.evidence_status,
    evidence.content_type,
    evidence.byte_size,
    evidence.created_at,
    evidence.retention_delete_at,
    evidence.preserved_until is not null and evidence.preserved_until > now()
  from public.incident_evidence evidence
  where evidence.incident_id = p_incident_id
  order by evidence.created_at;
end;
$$;

do $$ declare f record; begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where (n.nspname='private' and p.proname in ('safety_account_active','current_safety_contacts','can_read_safety_event','register_safety_event_recipients','audit_safety_runtime',
   'guard_safety_location_write','sync_safety_completed_checkin','safety_job_review_held','guard_safety_job_transition','guard_safety_review','guard_safety_abandonment',
   'is_safety_contact_participant','safety_case_reviewer','sync_safety_case_resolution'))
 or (n.nspname='public' and p.proname in ('get_my_safety_runtime','perform_safety_action','record_safety_device_snapshot','get_safety_event_status',
   'list_my_safety_events','list_guardian_safety_status','record_safety_contact_reached','get_job_safety_runtime','open_safety_contact','get_safety_contact_thread','submit_safety_report_categories','get_staff_safety_context')) loop
   execute format('revoke all on function %s from public,anon,authenticated',f.signature);
   execute format('grant execute on function %s to service_role',f.signature);
 end loop;
end $$;
grant execute on function public.get_my_safety_runtime(),public.perform_safety_action(text,uuid,jsonb,uuid),
 public.record_safety_device_snapshot(uuid,integer,boolean,double precision,double precision,timestamptz,uuid),
 public.get_safety_event_status(uuid),public.list_my_safety_events(),public.record_safety_contact_reached(uuid),public.get_job_safety_runtime(uuid) to authenticated;
grant execute on function public.open_safety_contact(uuid,text),public.get_safety_contact_thread(uuid),
 public.submit_safety_report_categories(text[],text,uuid,uuid,uuid,uuid,boolean,uuid),public.list_guardian_safety_status() to authenticated;
grant execute on function private.safety_case_reviewer(uuid,uuid),public.get_staff_safety_context(uuid,text) to authenticated;
select cron.alter_job(jobid,schedule:='* * * * *') from cron.job where jobname='mort-missed-job-checkins';
notify pgrst,'reload schema';

-- Preserve service-owned payment acknowledgments separately from Safety state.
-- Routing context is service-only: no participant RPC returns coordinates.
create function public.perform_adult_safety_exit(p_application_id uuid,p_client_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.applications%rowtype; j public.jobs%rowtype; r private.safety_runtime_requests%rowtype;
 result jsonb; h text;
begin
 select * into a from public.applications where id=p_application_id;
 select * into j from public.jobs where id=a.job_id;
 if auth.uid() is null or not private.safety_account_active(auth.uid()) or auth.uid() is distinct from j.poster_id then
   return jsonb_build_object('ok',false,'code','job_poster_required'); end if;
 if p_client_request_id is null then return jsonb_build_object('ok',false,'code','invalid_safety_request'); end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':safety-runtime',0));
 h:=encode(extensions.digest(jsonb_build_object('action','adult_safety_exit','application',a.id)::text,'sha256'),'hex');
 select * into r from private.safety_runtime_requests where actor_id=auth.uid() and request_id=p_client_request_id;
 if found then
   if r.payload_hash<>h then return jsonb_build_object('ok',false,'code','safety_request_payload_mismatch'); end if;
   return r.response||jsonb_build_object('replayed',true);
 end if;
 if a.status not in ('accepted','in_progress','proof_submitted','completion_pending_release','disputed') then
   return jsonb_build_object('ok',false,'code','safety_exit_not_allowed'); end if;
 result:=public.submit_safety_cancellation(a.id,'unsafe_condition','The poster ended this job for Safety. This is an allegation for review; private details may be added later.');
 if result->>'ok'<>'true' then return result; end if;
 update private.safety_device_state set review_hold=true,next_checkin_at=null where application_id=a.id;
 update public.job_checkins set status='canceled' where application_id=a.id and status in ('pending','missed');
 perform public.enqueue_notification(a.teen_id,'MORT Safety','The poster ended this job for Safety review. This does not establish fault or decide payment. Open MORT for support.',jsonb_build_object('applicationId',a.id));
 perform private.audit_safety_runtime(auth.uid(),a.id,'adult_safety_exit_allegation');
 result:=result||jsonb_build_object('money_moved',false,'fault_determined',false);
 insert into private.safety_runtime_requests(actor_id,request_id,payload_hash,response) values(auth.uid(),p_client_request_id,h,result);
 return result||jsonb_build_object('replayed',false);
end $$;
revoke all on function public.perform_adult_safety_exit(uuid,uuid) from public,anon;
grant execute on function public.perform_adult_safety_exit(uuid,uuid) to authenticated,service_role;

create function public.safety_server_claim_route(p_actor_id uuid,p_application_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d private.safety_device_state%rowtype; a public.applications%rowtype;
 loc public.job_private_locations%rowtype; request_id uuid:=gen_random_uuid();
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'safety_service_role_required'; end if;
 select * into a from public.applications where id=p_application_id;
 select * into d from private.safety_device_state where teen_id=p_actor_id for update;
 if a.teen_id is distinct from p_actor_id or not private.safety_account_active(p_actor_id)
   or not private.is_minor_teen(p_actor_id) or a.status<>'accepted' or d.application_id is distinct from a.id
   or d.travel_state<>'traveling' then return jsonb_build_object('ok',false,'code','active_manual_trip_required'); end if;
 if d.location_at is null or d.location_at<now()-interval '2 minutes' or d.latitude is null then
   return jsonb_build_object('ok',false,'code','fresh_location_required'); end if;
 if d.eta_requested_at>now()-(case when d.saver_enabled then interval '5 minutes' else interval '3 minutes' end) then
   return jsonb_build_object('ok',false,'code','route_update_deferred'); end if;
 select * into loc from public.job_private_locations where job_id=a.job_id;
 if loc.latitude is null or loc.longitude is null then return jsonb_build_object('ok',false,'code','job_route_unavailable'); end if;
 update private.safety_device_state set eta_requested_at=now(),eta_request_id=request_id where teen_id=p_actor_id;
 return jsonb_build_object('ok',true,'request_id',request_id,'travel_mode',d.travel_mode,
   'origin_latitude',d.latitude,'origin_longitude',d.longitude,'destination_latitude',loc.latitude,'destination_longitude',loc.longitude);
end $$;
create function public.safety_server_record_route(p_actor_id uuid,p_application_id uuid,p_request_id uuid,p_duration_seconds integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d private.safety_device_state%rowtype;
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'safety_service_role_required'; end if;
 if p_duration_seconds is null or p_duration_seconds not between 0 and 86400 then
   return jsonb_build_object('ok',false,'code','invalid_route_duration'); end if;
 select * into d from private.safety_device_state where teen_id=p_actor_id for update;
 if not private.safety_account_active(p_actor_id) or not private.is_minor_teen(p_actor_id)
   or d.application_id is distinct from p_application_id or d.travel_state<>'traveling'
   or p_request_id is null or d.eta_request_id is null or d.eta_requested_at is null
   or d.eta_request_id is distinct from p_request_id or d.eta_requested_at<now()-interval '20 seconds'
   or not exists(select 1 from public.applications where id=p_application_id and teen_id=p_actor_id and status='accepted') then
   return jsonb_build_object('ok',false,'code','trip_changed_during_route'); end if;
 update private.safety_device_state set eta_minutes=ceil(p_duration_seconds::numeric/60)::integer,
   eta_observed_at=now(),eta_request_id=null where teen_id=p_actor_id;
 return jsonb_build_object('ok',true);
end $$;
revoke all on function public.safety_server_claim_route(uuid,uuid),public.safety_server_record_route(uuid,uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.safety_server_claim_route(uuid,uuid),public.safety_server_record_route(uuid,uuid,uuid,integer) to service_role;

create or replace function public.stripe_server_record_resolution_result(
  p_resolution_id uuid,
  p_environment text,
  p_provider_transfer_id text,
  p_provider_refund_id text,
  p_provider_status text,
  p_safe_failure_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_resolution private.stripe_payment_resolutions%rowtype;
  v_payment private.stripe_job_payment_intents%rowtype;
  v_account private.stripe_connected_accounts%rowtype;
  v_status text;
begin
  perform private.require_stripe_service_role();
  select * into v_resolution from private.stripe_payment_resolutions where id = p_resolution_id and environment = p_environment for update;
  if v_resolution.id is null then raise exception 'payment_resolution_not_found'; end if;
  if v_resolution.status = 'completed' then return jsonb_build_object('ok', true, 'replayed', true, 'status', v_resolution.status); end if;
  if v_resolution.status not in ('financial_execution_started', 'provider_processing') then raise exception 'resolution_execution_not_claimed'; end if;
  select * into v_payment from private.stripe_job_payment_intents where id = v_resolution.payment_intent_id for update;
  select * into v_account from private.stripe_connected_accounts where user_id = v_payment.teen_id and environment = p_environment;
  if v_resolution.transfer_amount_cents > 0 and p_provider_transfer_id !~ '^tr_[A-Za-z0-9]+$' then raise exception 'provider_transfer_reference_required'; end if;
  if v_resolution.refund_amount_cents > 0 and p_provider_refund_id !~ '^re_[A-Za-z0-9]+$' then raise exception 'provider_refund_reference_required'; end if;
  v_status := case p_provider_status when 'succeeded' then 'completed' when 'processing' then 'provider_processing' else 'failed' end;
  if p_provider_status = 'succeeded' and v_resolution.transfer_amount_cents > 0 then
    insert into private.stripe_job_transfers(
      payment_intent_id, connected_account_id, environment, amount_cents, currency_code,
      provider_transfer_id, provider_source_charge_id, idempotency_key, eligibility_path, status, transferred_at
    ) values (
      v_payment.id, v_account.id, p_environment, v_resolution.transfer_amount_cents, v_resolution.currency_code,
      p_provider_transfer_id, v_payment.provider_charge_id, v_resolution.transfer_idempotency_key,
      v_resolution.eligibility_path, 'paid', now()
    ) on conflict (payment_intent_id) do update set
      provider_transfer_id = coalesce(private.stripe_job_transfers.provider_transfer_id, excluded.provider_transfer_id),
      status = 'paid', transferred_at = coalesce(private.stripe_job_transfers.transferred_at, now()), updated_at = now();
  end if;
  if p_provider_status = 'succeeded' and v_resolution.refund_amount_cents > 0 then
    insert into private.stripe_job_refunds(payment_intent_id, requested_by, environment, amount_cents, provider_refund_id, idempotency_key, reason_code, status)
    values (v_payment.id, v_resolution.financial_operator_id, p_environment, v_resolution.refund_amount_cents, p_provider_refund_id, v_resolution.refund_idempotency_key, 'reviewed_partial_resolution', 'succeeded')
    on conflict (environment, idempotency_key) do update set provider_refund_id = excluded.provider_refund_id, status = 'succeeded', updated_at = now();
  end if;
  update private.stripe_payment_resolutions set
    status = v_status, provider_transfer_id = p_provider_transfer_id,
    provider_refund_id = p_provider_refund_id, safe_failure_code = left(p_safe_failure_code, 120),
    executed_at = case when v_status = 'completed' then now() else executed_at end, updated_at = now()
  where id = v_resolution.id returning * into v_resolution;
  if v_status = 'completed' then
    update private.stripe_job_payment_intents set status = case when v_resolution.refund_amount_cents > 0 then 'partially_refunded' else 'transferred' end, updated_at = now() where id = v_payment.id;
    -- Record a real provider result even while the separate Safety workflow is
    -- held. Do not fabricate job completion, departure or progression.
    if not private.safety_job_review_held((select application_id from public.job_contracts where id=v_resolution.contract_id))
       and not exists(select 1 from private.safety_device_state where application_id=(select application_id from public.job_contracts where id=v_resolution.contract_id) and final_safety_pending) then
    update public.job_contracts set status = 'completed', closed_at = now() where id = v_resolution.contract_id;
    update public.applications set status = 'completed', updated_at = now() where id = (select application_id from public.job_contracts where id = v_resolution.contract_id);
    update public.jobs set status = 'closed', updated_at = now() where id = (select job_id from public.job_contracts where id = v_resolution.contract_id);
    update public.job_arrival_handshakes set execution_state = 'completed', updated_at = now() where application_id = (select application_id from public.job_contracts where id = v_resolution.contract_id);
    end if;
    update public.job_payment_obligations set status = 'due', became_due_at = coalesce(became_due_at, now()) where id = v_payment.obligation_id and status in ('pending_release', 'disputed');
    if v_resolution.dispute_id is not null then
      insert into public.payment_dispute_timeline(dispute_id, actor_id, event_type, event_summary)
      values (v_resolution.dispute_id, v_resolution.financial_operator_id, 'provider_resolution_completed', 'The approved server resolution completed through the payment provider.');
    end if;
  end if;
  insert into private.stripe_financial_audit_events(actor_id, environment, event_type, subject_type, subject_id, safe_reason_code, field_names)
  values (v_resolution.financial_operator_id, p_environment, 'resolution_provider_result', 'stripe_payment_resolution', v_resolution.id, v_status, array['status', 'provider_transfer_id', 'provider_refund_id']);
  return jsonb_build_object('ok', true, 'replayed', false, 'resolution_id', v_resolution.id, 'status', v_resolution.status);
end;
$$;



-- Safety cancellation preserves another person's explicit emergency sharing.
create or replace function public.submit_safety_cancellation(
  p_application_id uuid,
  p_reason text,
  p_details text default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_reason text := lower(btrim(coalesce(p_reason, '')));
  v_safety_related boolean;
  v_target uuid;
  v_report jsonb;
  v_cancellation public.safety_cancellations%rowtype;
begin
  if auth.uid() is null or not private.safety_account_active(auth.uid()) then
    return jsonb_build_object('ok',false,'code','active_account_required'); end if;
  select * into v_application
  from public.applications application
  where application.id = p_application_id
  for update;
  select * into v_job
  from public.jobs job
  where job.id = v_application.job_id
  for update;
  if v_application.id is null or auth.uid() not in (v_application.teen_id, v_job.poster_id) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if v_reason not in (
    'schedule_conflict', 'illness', 'transportation_problem', 'scope_changed',
    'location_changed', 'person_mismatch', 'unsafe_condition', 'harassment',
    'emergency', 'payment_disagreement', 'equipment_issue'
  ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_cancellation_reason');
  end if;

  v_safety_related := v_reason in (
    'scope_changed', 'location_changed', 'person_mismatch', 'unsafe_condition',
    'harassment', 'emergency', 'payment_disagreement', 'equipment_issue'
  );
  if v_safety_related and char_length(btrim(coalesce(p_details, ''))) < 10 then
    return jsonb_build_object('ok', false, 'code', 'safety_cancellation_details_required');
  end if;

  v_target := case when auth.uid() = v_application.teen_id then v_job.poster_id else v_application.teen_id end;
  if v_safety_related then
    v_report := public.submit_safety_report(
      v_target,
      v_job.id,
      null,
      null,
      p_application_id,
      case v_reason
        when 'person_mismatch' then 'identity_mismatch'
        when 'harassment' then 'harassment'
        when 'payment_disagreement' then 'payment_threat'
        else 'unsafe_job_conditions'
      end,
      case when v_reason in ('person_mismatch', 'harassment', 'emergency') then 'high' else 'moderate' end,
      v_reason = 'emergency',
      p_details,
      now(),
      v_job.location_type,
      'End the job safely and prevent retaliation.',
      true
    );
  end if;

  insert into public.safety_cancellations (
    application_id, job_id, actor_id, reason, details,
    is_safety_related, reputation_penalty_applied, incident_id
  ) values (
    p_application_id, v_job.id, auth.uid(), v_reason,
    nullif(left(btrim(coalesce(p_details, '')), 3000), ''),
    v_safety_related, false,
    case when v_safety_related then (v_report->>'incident_id')::uuid else null end
  ) returning * into v_cancellation;

  if v_safety_related then
    update public.applications set status = 'disputed' where id = p_application_id;
    update public.jobs set status = 'paused', applications_open = false where id = v_job.id;
    insert into public.trusted_relationships (
      owner_id, target_id, relationship_type, source_job_id
    ) values (
      auth.uid(), v_target, 'no_contact', v_job.id
    ) on conflict (owner_id, target_id, relationship_type) do nothing;
  elsif auth.uid() = v_application.teen_id
    and v_application.status in ('submitted', 'guardian_pending', 'adult_review', 'viewed', 'accepted') then
    update public.applications set status = 'withdrawn', withdrawn_at = now() where id = p_application_id;
  elsif auth.uid() = v_job.poster_id then
    update public.jobs set status = 'canceled', applications_open = false where id = v_job.id;
  end if;

  update public.job_location_share_sessions
  set status = 'stopped', stopped_at = now()
  where application_id = p_application_id and status = 'active'
    and (safety_event_id is null or owner_id=auth.uid());

  return jsonb_build_object(
    'ok', true,
    'cancellation_id', v_cancellation.id,
    'safety_related', v_safety_related,
    'reputation_penalty_applied', false,
    'incident_id', v_cancellation.incident_id
  );
end;
$$;
