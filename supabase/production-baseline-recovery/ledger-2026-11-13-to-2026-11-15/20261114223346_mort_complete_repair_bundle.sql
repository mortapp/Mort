-- Exact statements from production ledger version 20261114223346
-- Consolidated repair bundle. Guarded edits match the exact inspected production function bodies.
begin;
do $repair$
declare
  v_def text;
  v_old text := $old$
  insert into public.verification_cases(
    user_id, verification_type, status, provider, submitted_at
  )
  select v_user_id, 'age', 'pending'::public.mort_verification_status,
         'self_reported', now()
  where not exists (
    select 1
    from public.verification_cases vc
    where vc.user_id = v_user_id
      and vc.verification_type = 'age'
      and vc.status in (
        'pending'::public.mort_verification_status,
        'verified'::public.mort_verification_status
      )
  );
$old$;
begin
 select pg_get_functiondef('public.save_my_onboarding_account_v2(jsonb,uuid,integer)'::regprocedure) into v_def;
 if position(v_old in v_def)>0 then v_def:=replace(v_def,v_old,E'  -- Real age evidence is submitted through the private staff-review workflow.\n'); execute v_def;
 elsif position('insert into public.verification_cases(' in v_def)>0 then raise exception 'repair_source_mismatch:save_my_onboarding_account_v2'; end if;
end;
$repair$;
do $repair$
declare v_def text; v_old_type text := $old$if p_verification_type is null or p_verification_type <> v_expected then$old$; v_old_pending text := $old$where vc.user_id = v_user and vc.status in ('pending','needs_review')$old$;
begin
 select pg_get_functiondef('public.submit_my_verification_evidence_v1(text,text)'::regprocedure) into v_def;
 if position(v_old_type in v_def)>0 then v_def:=replace(v_def,v_old_type,$new$if p_verification_type is null or p_verification_type not in (v_expected, 'age') then$new$);
 elsif position('p_verification_type not in (v_expected, ''age'')' in v_def)=0 then raise exception 'repair_source_mismatch:submit_my_verification_evidence_v1_type'; end if;
 if position(v_old_pending in v_def)>0 then v_def:=replace(v_def,v_old_pending,$new$where vc.user_id = v_user and vc.verification_type = p_verification_type and vc.status in ('pending','needs_review')$new$);
 elsif position('vc.verification_type = p_verification_type' in v_def)=0 then raise exception 'repair_source_mismatch:submit_my_verification_evidence_v1_pending_guard'; end if;
 execute v_def;
end;
$repair$;
insert into private.verification_provider_allowlist(provider_key,verification_type,is_enabled) values ('mort_staff_review','age',true),('mort_staff_review','school_id',true),('mort_staff_review','identity',true) on conflict(provider_key,verification_type) do update set is_enabled=excluded.is_enabled;
create or replace function private.mort_is_eligible_for_role_activation(p_user_id uuid,p_role public.mort_role) returns boolean language sql stable security definer set search_path = '' as $function$
 select case p_role
 when 'teen'::public.mort_role then (
  exists(select 1 from public.verification_cases vc where vc.user_id=p_user_id and vc.verification_type='age' and vc.status='verified'::public.mort_verification_status and (vc.expires_at is null or vc.expires_at>now()))
  and exists(select 1 from public.verification_cases vc where vc.user_id=p_user_id and vc.verification_type='school_id' and vc.status='verified'::public.mort_verification_status and (vc.expires_at is null or vc.expires_at>now()))
  and exists(select 1 from auth.users u where u.id=p_user_id and u.email_confirmed_at is not null and private.is_approved_school_email(u.email)))
 when 'adult'::public.mort_role then exists(select 1 from public.verification_cases vc where vc.user_id=p_user_id and vc.verification_type='identity' and vc.status='verified'::public.mort_verification_status and (vc.expires_at is null or vc.expires_at>now()))
 else false end;
$function$;
revoke all on function private.mort_is_eligible_for_role_activation(uuid,public.mort_role) from public,anon,authenticated;
grant execute on function private.mort_is_eligible_for_role_activation(uuid,public.mort_role) to service_role;
create or replace function public.mort_review_role_request(p_request_id uuid,p_approve boolean,p_reason text default null) returns uuid language plpgsql security definer set search_path = '' as $function$
declare v_user uuid:=auth.uid(); v_req public.role_requests%rowtype;
begin
 if v_user is null or not private.has_staff_role(array['admin']::public.mort_role[]) then raise exception 'Administrator role required for role approval'; end if;
 if p_approve is null then raise exception 'Approval decision is required'; end if;
 select * into v_req from public.role_requests where id=p_request_id for update;
 if not found or v_req.status<>'pending' then raise exception 'Pending role request not found'; end if;
 if p_approve then
  if not private.mort_is_eligible_for_role_activation(v_req.user_id,v_req.requested_role) then raise exception 'Role request does not meet the required verification tracks'; end if;
  update public.profiles set role=v_req.requested_role,account_status='active',updated_at=now() where id=v_req.user_id;
  if not found then raise exception 'Profile not found'; end if;
  update public.role_requests set status='approved',reviewed_at=now(),reviewed_by=v_user,review_note=nullif(btrim(p_reason),'') where id=p_request_id;
 else update public.role_requests set status='rejected',reviewed_at=now(),reviewed_by=v_user,review_note=nullif(btrim(p_reason),'') where id=p_request_id; end if;
 insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata) values(v_user,case when p_approve then 'role_request_approved' else 'role_request_rejected' end,'role_request',p_request_id::text,nullif(btrim(p_reason),''),jsonb_build_object('user_id',v_req.user_id,'requested_role',v_req.requested_role));
 return p_request_id;
end;
$function$;
revoke all on function public.mort_review_role_request(uuid,boolean,text) from public,anon;
grant execute on function public.mort_review_role_request(uuid,boolean,text) to authenticated,service_role;
create or replace function private.mort_queue_role_activation(p_user_id uuid) returns void language plpgsql security definer set search_path = '' as $function$
declare v_role public.mort_role; v_status text;
begin
 select role,account_status into v_role,v_status from public.profiles where id=p_user_id for update;
 if not found or v_status<>'pending' or v_role not in ('teen','adult') then return; end if;
 if not private.mort_is_eligible_for_role_activation(p_user_id,v_role) then return; end if;
 if exists(select 1 from public.role_requests where user_id=p_user_id and status='pending') then return; end if;
 insert into public.role_requests(user_id,requested_role,status) values(p_user_id,v_role,'pending');
end;
$function$;
revoke all on function private.mort_queue_role_activation(uuid) from public,anon,authenticated;
grant execute on function private.mort_queue_role_activation(uuid) to service_role;
do $repair$
declare v_def text; v_old text := $old$  return p_case_id;$old$; v_new text := $new$
  if p_status = 'verified'::public.mort_verification_status then
    begin perform private.mort_queue_role_activation(v_owner);
    exception when others then insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata) values(v_user,'role_activation_autoqueue_failed','profile',v_owner::text,SQLERRM,'{}'::jsonb); end;
  end if;
  return p_case_id;$new$;
begin
 select pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamptz)'::regprocedure) into v_def;
 if position('mort_queue_role_activation' in v_def)=0 then
  if position(v_old in v_def)=0 then raise exception 'repair_source_mismatch:mort_review_verification_case'; end if;
  v_def:=replace(v_def,v_old,v_new); execute v_def;
 end if;
end;
$repair$;
create or replace function public.update_my_job_application_status_v3(p_application_id uuid,p_action text,p_client_request_id uuid,p_expected_updated_at timestamptz default null) returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
 v_user uuid:=auth.uid(); v_role public.mort_role:=private.current_role(); v_app public.job_applications%rowtype; v_job public.jobs%rowtype;
 v_assignment uuid; v_recipient uuid; v_title text; v_body text; v_updated jsonb; v_response jsonb; v_hash text; v_request_exists boolean:=false; v_inserted integer;
begin
 if v_user is null or not private.is_active_user() then return jsonb_build_object('ok',false,'code','active_account_required'); end if;
 if p_application_id is null or p_client_request_id is null or p_action not in ('accepted','shortlisted','rejected','viewed','withdrawn') then return jsonb_build_object('ok',false,'code','application_action_invalid'); end if;
 v_hash:=md5(p_application_id::text||'|'||p_action||'|'||coalesce(p_expected_updated_at::text,''));
 select response into v_response from private.mort_job_mutation_requests where user_id=v_user and client_request_id=p_client_request_id;
 v_request_exists:=found; if v_request_exists and v_response is not null then return v_response||jsonb_build_object('replayed',true); end if;
 select ja.* into v_app from public.job_applications ja where ja.id=p_application_id and (ja.applicant_id=v_user or exists(select 1 from public.jobs j where j.id=ja.job_id and j.poster_id=v_user)) for update;
 if not found then return jsonb_build_object('ok',false,'code','application_not_available'); end if;
 select response into v_response from private.mort_job_mutation_requests where user_id=v_user and client_request_id=p_client_request_id;
 if found and v_response is not null then return v_response||jsonb_build_object('replayed',true); end if;
 if p_expected_updated_at is not null and v_app.updated_at<>p_expected_updated_at then return jsonb_build_object('ok',false,'code','application_changed_refresh'); end if;
 select * into v_job from public.jobs where id=v_app.job_id;
 if not v_request_exists then
  insert into private.mort_job_mutation_requests(user_id,client_request_id,operation,request_hash) values(v_user,p_client_request_id,'application_transition',v_hash) on conflict do nothing;
  get diagnostics v_inserted=row_count;
  if v_inserted=0 then select response into v_response from private.mort_job_mutation_requests where user_id=v_user and client_request_id=p_client_request_id for update; if v_response is not null then return v_response||jsonb_build_object('replayed',true); end if; return jsonb_build_object('ok',false,'code','application_action_in_progress'); end if;
 else
  select request_hash into v_hash from private.mort_job_mutation_requests where user_id=v_user and client_request_id=p_client_request_id;
  if v_hash<>md5(p_application_id::text||'|'||p_action||'|'||coalesce(p_expected_updated_at::text,'')) then return jsonb_build_object('ok',false,'code','idempotency_key_reused'); end if;
 end if;
 begin
  if p_action='accepted' and v_role='adult'::public.mort_role and v_job.poster_id=v_user then
   if v_app.status not in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status) then v_response:=jsonb_build_object('ok',false,'code','application_not_eligible_for_acceptance'); else v_assignment:=public.mort_accept_job_application(v_app.id); v_response:=null; end if;
  elsif p_action in ('shortlisted','rejected','viewed') and v_role='adult'::public.mort_role and v_job.poster_id=v_user and v_app.status in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status) then
   if p_action='viewed' then update public.job_applications set viewed_at=coalesce(viewed_at,now()) where id=v_app.id; else update public.job_applications set status=p_action::public.mort_application_status where id=v_app.id; v_recipient:=v_app.applicant_id; v_title:=case when p_action='shortlisted' then 'Application shortlisted' else 'Application update' end; v_body:=case when p_action='shortlisted' then 'Your application was shortlisted.' else 'Your application was declined.' end; end if;
  elsif p_action='withdrawn' and v_role='teen'::public.mort_role and v_app.applicant_id=v_user and v_app.status in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status) then update public.job_applications set status='withdrawn'::public.mort_application_status,withdrawn_at=now() where id=v_app.id; v_recipient:=v_job.poster_id; v_title:='Application withdrawn'; v_body:='A teen withdrew their application.';
  else v_response:=jsonb_build_object('ok',false,'code','application_action_not_allowed'); end if;
 exception when others then v_response:=jsonb_build_object('ok',false,'code','application_action_failed','detail',sqlerrm); end;
 if v_response is null then
  if v_recipient is not null then insert into public.notifications(user_id,notification_type,title,body,data) values(v_recipient,'application_status',v_title,v_body,jsonb_build_object('application_id',v_app.id,'job_id',v_app.job_id)); end if;
  v_updated:=public.get_my_job_applications(v_app.id)->'items'->0; v_response:=jsonb_build_object('ok',true,'application',v_updated,'assignment_id',v_assignment,'replayed',false);
 else v_response:=v_response||jsonb_build_object('replayed',false); end if;
 update private.mort_job_mutation_requests set response=v_response where user_id=v_user and client_request_id=p_client_request_id; return v_response;
end;
$function$;
revoke all on function public.update_my_job_application_status_v3(uuid,text,uuid,timestamptz) from public,anon;
grant execute on function public.update_my_job_application_status_v3(uuid,text,uuid,timestamptz) to authenticated,service_role;
create or replace function public.admin_set_account_status_v2(p_user_id uuid,p_status text,p_reason_code text,p_reason text,p_expires_at timestamptz default null) returns jsonb language plpgsql security definer set search_path = '' as $function$
declare v_actor uuid:=auth.uid(); v_profile public.profiles%rowtype; v_request public.role_requests%rowtype;
begin
 if v_actor is null or not private.has_staff_role(array['admin']::public.mort_role[]) then return jsonb_build_object('ok',false,'code','administrator_required'); end if;
 if p_user_id is null or p_status is null or p_status<>'active' or nullif(btrim(coalesce(p_reason,'')),'') is null or nullif(btrim(coalesce(p_reason_code,'')),'') is null or p_expires_at is not null then return jsonb_build_object('ok',false,'code','account_status_request_invalid'); end if;
 select * into v_profile from public.profiles where id=p_user_id for update; if not found then return jsonb_build_object('ok',false,'code','profile_not_found'); end if;
 if v_profile.account_status='active' then return jsonb_build_object('ok',true,'code','already_active'); end if;
 select * into v_request from public.role_requests where user_id=p_user_id and requested_role=v_profile.role and status='pending' order by submitted_at desc limit 1 for update;
 if not found then return jsonb_build_object('ok',false,'code','activation_request_required'); end if;
 begin perform public.mort_review_role_request(v_request.id,true,p_reason); exception when others then return jsonb_build_object('ok',false,'code','activation_review_failed'); end;
 return jsonb_build_object('ok',true,'code','activation_approved','request_id',v_request.id);
end;
$function$;
revoke all on function public.admin_set_account_status_v2(uuid,text,text,text,timestamptz) from public,anon;
grant execute on function public.admin_set_account_status_v2(uuid,text,text,text,timestamptz) to authenticated,service_role;
commit;
