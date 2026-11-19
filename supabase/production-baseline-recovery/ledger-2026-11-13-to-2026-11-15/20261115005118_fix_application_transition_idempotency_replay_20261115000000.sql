-- Exact statements from production ledger version 20261115005118
BEGIN;
create or replace function public.update_my_job_application_status_v3(
  p_application_id uuid,
  p_action text,
  p_client_request_id uuid,
  p_expected_updated_at timestamptz default null
)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_role public.mort_role := private.current_role();
  v_app public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_assignment uuid;
  v_recipient uuid;
  v_title text;
  v_body text;
  v_updated jsonb;
  v_response jsonb;
  v_hash text;
  v_existing_hash text;
  v_request_exists boolean := false;
  v_inserted integer;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_application_id is null or p_client_request_id is null or p_action is null
     or p_action not in ('accepted','shortlisted','rejected','viewed','withdrawn') then
    return jsonb_build_object('ok', false, 'code', 'application_action_invalid');
  end if;
  v_hash := md5(p_application_id::text || '|' || p_action || '|' || coalesce(p_expected_updated_at::text, ''));
  select response, request_hash into v_response, v_existing_hash from private.mort_job_mutation_requests
  where user_id = v_user and client_request_id = p_client_request_id;
  v_request_exists := found;
  if v_request_exists and v_response is not null then
    if v_existing_hash is distinct from v_hash then
      return jsonb_build_object('ok',false,'code','idempotency_key_reused');
    end if;
    return v_response || jsonb_build_object('replayed', true);
  end if;
  select ja.* into v_app from public.job_applications ja
  where ja.id = p_application_id
    and (ja.applicant_id = v_user or exists (select 1 from public.jobs j where j.id = ja.job_id and j.poster_id = v_user))
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'application_not_available');
  end if;
  select response, request_hash into v_response, v_existing_hash from private.mort_job_mutation_requests
  where user_id = v_user and client_request_id = p_client_request_id;
  if found and v_response is not null then
    if v_existing_hash is distinct from v_hash then
      return jsonb_build_object('ok',false,'code','idempotency_key_reused');
    end if;
    return v_response || jsonb_build_object('replayed', true);
  end if;
  if p_expected_updated_at is not null and v_app.updated_at <> p_expected_updated_at then
    return jsonb_build_object('ok', false, 'code', 'application_changed_refresh');
  end if;
  select * into v_job from public.jobs where id = v_app.job_id;
  if not v_request_exists then
    insert into private.mort_job_mutation_requests(user_id,client_request_id,operation,request_hash)
    values (v_user,p_client_request_id,'application_transition',v_hash) on conflict do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted = 0 then
      select response, request_hash into v_response, v_existing_hash from private.mort_job_mutation_requests
      where user_id = v_user and client_request_id = p_client_request_id for update;
      if v_response is not null then
        if v_existing_hash is distinct from v_hash then
          return jsonb_build_object('ok',false,'code','idempotency_key_reused');
        end if;
        return v_response || jsonb_build_object('replayed',true);
      end if;
      return jsonb_build_object('ok',false,'code','application_action_in_progress');
    end if;
  else
    select request_hash into v_existing_hash from private.mort_job_mutation_requests
    where user_id = v_user and client_request_id = p_client_request_id;
    if v_existing_hash is distinct from v_hash then
      return jsonb_build_object('ok',false,'code','idempotency_key_reused');
    end if;
  end if;
  begin
    if p_action = 'accepted' and v_role = 'adult'::public.mort_role and v_job.poster_id = v_user then
      if v_app.status not in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status) then
        v_response := jsonb_build_object('ok',false,'code','application_not_eligible_for_acceptance');
      else
        v_assignment := public.mort_accept_job_application(v_app.id);
        v_response := null;
      end if;
    elsif p_action in ('shortlisted','rejected','viewed') and v_role = 'adult'::public.mort_role and v_job.poster_id = v_user
          and v_app.status in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status) then
      if p_action = 'viewed' then
        update public.job_applications set viewed_at = coalesce(viewed_at,now()) where id = v_app.id;
      else
        update public.job_applications set status = p_action::public.mort_application_status where id = v_app.id;
        v_recipient := v_app.applicant_id;
        v_title := case when p_action = 'shortlisted' then 'Application shortlisted' else 'Application update' end;
        v_body := case when p_action = 'shortlisted' then 'Your application was shortlisted.' else 'Your application was declined.' end;
      end if;
    elsif p_action = 'withdrawn' and v_role = 'teen'::public.mort_role and v_app.applicant_id = v_user
          and v_app.status in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status) then
      update public.job_applications set status='withdrawn'::public.mort_application_status,withdrawn_at=now() where id = v_app.id;
      v_recipient := v_job.poster_id;
      v_title := 'Application withdrawn';
      v_body := 'A teen withdrew their application.';
    else
      v_response := jsonb_build_object('ok',false,'code','application_action_not_allowed');
    end if;
  exception when others then
    v_response := jsonb_build_object('ok',false,'code','application_action_failed','detail',sqlerrm);
  end;
  if v_response is null then
    if v_recipient is not null then
      insert into public.notifications(user_id,notification_type,title,body,data)
      values (v_recipient,'application_status',v_title,v_body,jsonb_build_object('application_id',v_app.id,'job_id',v_app.job_id));
    end if;
    v_updated := public.get_my_job_applications(v_app.id)->'items'->0;
    v_response := jsonb_build_object('ok',true,'application',v_updated,'assignment_id',v_assignment,'replayed',false);
  else
    v_response := v_response || jsonb_build_object('replayed',false);
  end if;
  update private.mort_job_mutation_requests set response=v_response where user_id=v_user and client_request_id=p_client_request_id;
  return v_response;
end;
$function$;
revoke all on function public.update_my_job_application_status_v3(uuid,text,uuid,timestamptz) from public, anon;
grant execute on function public.update_my_job_application_status_v3(uuid,text,uuid,timestamptz) to authenticated, service_role;
COMMIT;
