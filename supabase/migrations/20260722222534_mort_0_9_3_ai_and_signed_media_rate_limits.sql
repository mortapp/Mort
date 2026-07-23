-- External AI remains disabled by default. These controls make enabling it a
-- server-governed operation instead of trusting Edge/client configuration.
alter table public.ai_runtime_controls
  add column if not exists global_daily_requests integer not null default 1000
    check (global_daily_requests between 1 and 100000),
  add column if not exists global_monthly_requests integer not null default 10000
    check (global_monthly_requests between 1 and 1000000),
  add column if not exists global_monthly_budget_usd numeric(10, 4) not null default 0
    check (global_monthly_budget_usd >= 0),
  add column if not exists provider_request_reserve_usd numeric(10, 6) not null default 0.020000
    check (provider_request_reserve_usd > 0),
  add column if not exists provider_concurrency_limit integer not null default 5
    check (provider_concurrency_limit between 1 and 100),
  add column if not exists provider_timeout_seconds integer not null default 20
    check (provider_timeout_seconds between 5 and 60),
  add column if not exists provider_max_input_tokens integer not null default 400
    check (provider_max_input_tokens between 64 and 4000),
  add column if not exists provider_max_output_tokens integer not null default 300
    check (provider_max_output_tokens between 64 and 2000),
  add column if not exists approved_provider_models text[] not null default array['gpt-5-mini']::text[]
    check (
      cardinality(approved_provider_models) between 1 and 10
      and approved_provider_models <@ array['gpt-5-mini', 'gpt-5-nano']::text[]
    );

create or replace function public.reserve_mort_guide_provider_request(
  p_client_request_id uuid,
  p_input_characters integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_control public.ai_runtime_controls%rowtype;
  v_role public.user_role;
  v_consent text;
  v_reservation_id uuid;
  v_daily_cost numeric(10, 6);
  v_monthly_cost numeric(10, 6);
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_client_request_id is null or p_input_characters not between 3 and 16000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_provider_request');
  end if;

  select * into v_control
  from public.ai_runtime_controls
  where id
  for update;

  if v_control.mode not in ('sandbox', 'production')
     or not v_control.external_provider_enabled
     or v_control.provider_circuit_open then
    return jsonb_build_object('ok', false, 'code', 'external_provider_disabled');
  end if;
  if p_input_characters > v_control.provider_max_input_tokens * 4 then
    return jsonb_build_object('ok', false, 'code', 'question_too_long');
  end if;
  if v_control.global_daily_budget_usd <= 0 or v_control.global_monthly_budget_usd <= 0 then
    return jsonb_build_object('ok', false, 'code', 'provider_budget_not_configured');
  end if;
  if exists (
    select 1 from public.ai_usage_events
    where user_id = auth.uid() and client_request_id = p_client_request_id
  ) then
    return jsonb_build_object('ok', false, 'code', 'duplicate_provider_request');
  end if;

  select role into v_role from public.profiles where id = auth.uid();
  if v_role = 'teen' then
    select status into v_consent from public.ai_processing_consents where user_id = auth.uid();
    if coalesce(v_consent, 'not_requested') <> 'approved' then
      return jsonb_build_object('ok', false, 'code', 'minor_ai_consent_required');
    end if;
  end if;

  if not public.check_rate_limit('mort_guide_provider_request', v_control.daily_user_requests, 86400) then
    return jsonb_build_object('ok', false, 'code', 'daily_limit_reached');
  end if;
  if (select count(*) from public.ai_usage_events
      where user_id = auth.uid() and created_at >= date_trunc('month', now())) >= v_control.monthly_user_requests then
    return jsonb_build_object('ok', false, 'code', 'monthly_limit_reached');
  end if;
  if (select count(*) from public.ai_usage_events
      where provider_called and created_at >= date_trunc('day', now())) >= v_control.global_daily_requests then
    return jsonb_build_object('ok', false, 'code', 'global_daily_limit_reached');
  end if;
  if (select count(*) from public.ai_usage_events
      where provider_called and created_at >= date_trunc('month', now())) >= v_control.global_monthly_requests then
    return jsonb_build_object('ok', false, 'code', 'global_monthly_limit_reached');
  end if;
  if (select count(*) from public.ai_usage_events
      where provider_called and outcome = 'provider_reserved'
        and created_at >= now() - make_interval(secs => v_control.provider_timeout_seconds + 10)) >= v_control.provider_concurrency_limit then
    return jsonb_build_object('ok', false, 'code', 'provider_concurrency_limited');
  end if;

  select coalesce(sum(estimated_cost_usd), 0) into v_daily_cost
  from public.ai_usage_events where provider_called and created_at >= date_trunc('day', now());
  select coalesce(sum(estimated_cost_usd), 0) into v_monthly_cost
  from public.ai_usage_events where provider_called and created_at >= date_trunc('month', now());
  if v_daily_cost + v_control.provider_request_reserve_usd > v_control.global_daily_budget_usd then
    return jsonb_build_object('ok', false, 'code', 'global_daily_budget_reached');
  end if;
  if v_monthly_cost + v_control.provider_request_reserve_usd > v_control.global_monthly_budget_usd then
    return jsonb_build_object('ok', false, 'code', 'global_monthly_budget_reached');
  end if;

  insert into public.ai_usage_events (
    user_id, client_request_id, mode, input_characters, estimated_cost_usd,
    provider_called, outcome
  ) values (
    auth.uid(), p_client_request_id, v_control.mode, p_input_characters,
    v_control.provider_request_reserve_usd, true, 'provider_reserved'
  ) returning id into v_reservation_id;
  perform public.record_rate_limit_event('mort_guide_provider_request');

  return jsonb_build_object(
    'ok', true,
    'reservation_id', v_reservation_id,
    'mode', v_control.mode,
    'approved_model', v_control.approved_provider_models[1],
    'max_input_tokens', v_control.provider_max_input_tokens,
    'max_output_tokens', v_control.provider_max_output_tokens,
    'timeout_seconds', v_control.provider_timeout_seconds
  );
end;
$$;

create or replace function public.mort_guide_server_finalize_provider_request(
  p_reservation_id uuid,
  p_outcome text,
  p_conversation_id uuid default null,
  p_input_tokens integer default null,
  p_output_tokens integer default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_outcome not in ('answered', 'provider_error', 'input_blocked', 'output_blocked', 'timeout', 'fallback') then
    raise exception 'invalid_provider_outcome';
  end if;
  update public.ai_usage_events
  set outcome = p_outcome,
      conversation_id = p_conversation_id,
      input_tokens = p_input_tokens,
      output_tokens = p_output_tokens
  where id = p_reservation_id and provider_called and outcome = 'provider_reserved';
  return found;
end;
$$;

create or replace function public.authorize_profile_avatar_url(
  p_profile_id uuid,
  p_requested_path text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_allowed boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not public.check_rate_limit('avatar_signed_url', 240, 3600) then
    return jsonb_build_object('ok', false, 'code', 'signed_url_rate_limited');
  end if;
  perform public.record_rate_limit_event('avatar_signed_url');

  select * into v_profile from public.profiles where id = p_profile_id;
  if v_profile.id is null or v_profile.account_status <> 'active'
     or v_profile.avatar_moderation_status <> 'active' or v_profile.avatar_path is null then
    return jsonb_build_object('ok', true, 'object_path', null);
  end if;
  if p_requested_path is not null and p_requested_path <> v_profile.avatar_path then
    return jsonb_build_object('ok', false, 'code', 'avatar_version_changed');
  end if;
  if v_profile.avatar_path !~ ('^' || p_profile_id::text || '/[0-9a-f-]{36}[.]jpg$') then
    return jsonb_build_object('ok', false, 'code', 'avatar_path_invalid');
  end if;
  if exists (
    select 1 from public.blocks
    where (blocker_id = auth.uid() and blocked_id = p_profile_id)
       or (blocker_id = p_profile_id and blocked_id = auth.uid())
  ) then
    return jsonb_build_object('ok', true, 'object_path', null);
  end if;

  v_allowed := p_profile_id = auth.uid()
    or exists (
      select 1 from public.guardian_connections connection
      where connection.status = 'active'
        and ((connection.teen_id = p_profile_id and connection.guardian_id = auth.uid())
          or (connection.guardian_id = p_profile_id and connection.teen_id = auth.uid()))
    )
    or exists (
      select 1 from public.applications application
      join public.jobs job on job.id = application.job_id
      where (application.teen_id = p_profile_id and job.poster_id = auth.uid())
         or (application.teen_id = auth.uid() and job.poster_id = p_profile_id)
    );
  if not v_allowed then return jsonb_build_object('ok', true, 'object_path', null); end if;
  return jsonb_build_object('ok', true, 'object_path', v_profile.avatar_path);
end;
$$;

create or replace function public.authorize_support_evidence_url(p_evidence_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_evidence public.support_evidence_attachments%rowtype;
  v_basis text;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'evidence_not_authorized');
  end if;
  if not public.check_rate_limit('support_evidence_signed_url', 60, 3600) then
    return jsonb_build_object('ok', false, 'code', 'signed_url_rate_limited');
  end if;
  perform public.record_rate_limit_event('support_evidence_signed_url');
  if not private.can_access_support_evidence(p_evidence_id, auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'evidence_not_authorized');
  end if;
  select * into v_evidence from public.support_evidence_attachments where id = p_evidence_id;
  v_basis := case when v_evidence.owner_id = auth.uid() then 'owner'
    when private.has_support_role(auth.uid(), array['support_manager', 'safety_reviewer']) then 'assigned_review'
    else 'authorized_case_participant' end;
  insert into public.support_evidence_access_events (evidence_id, actor_id, access_type, authorization_basis)
  values (v_evidence.id, auth.uid(), 'signed_url_created', v_basis);
  return jsonb_build_object('ok', true, 'bucket_id', v_evidence.bucket_id, 'object_path', v_evidence.object_path, 'authorization_basis', v_basis);
end;
$$;

revoke all on function public.reserve_mort_guide_provider_request(uuid, integer) from public, anon;
grant execute on function public.reserve_mort_guide_provider_request(uuid, integer) to authenticated, service_role;
revoke all on function public.mort_guide_server_finalize_provider_request(uuid, text, uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.mort_guide_server_finalize_provider_request(uuid, text, uuid, integer, integer) to service_role;
revoke all on function public.authorize_profile_avatar_url(uuid, text) from public, anon;
grant execute on function public.authorize_profile_avatar_url(uuid, text) to authenticated, service_role;
revoke all on function public.authorize_support_evidence_url(uuid) from public, anon;
grant execute on function public.authorize_support_evidence_url(uuid) to authenticated, service_role;
