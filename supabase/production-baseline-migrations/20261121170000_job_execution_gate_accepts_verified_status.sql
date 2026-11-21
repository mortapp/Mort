-- Restore the canonical production job execution gate to migration history.
-- The function was present in production/QA but absent from tracked migrations,
-- so clean installs could not apply the verification-state correction.
-- Preserve all production gate checks; only accept the actual reviewer states
-- ("verified" and legacy "approved") for both participants. Null remains denied.
CREATE OR REPLACE FUNCTION private.job_execution_gate(p_application_id uuid, p_operation text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_application public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_teen public.profiles%rowtype;
  v_adult public.profiles%rowtype;
  v_contract public.job_contracts%rowtype;
  v_version public.job_contract_versions%rowtype;
  v_safety public.job_safety_agreements%rowtype;
  v_safety_terms jsonb;
  v_acceptances integer;
  v_funded boolean := false;
  v_runtime jsonb;
  v_start_at timestamptz;
begin
  if p_operation is null or p_operation not in ('start', 'finish') then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_execution_operation');
  end if;
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;

  select assignment.* into v_assignment
    from public.job_assignments assignment
   where assignment.application_id = p_application_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if v_user_id not in (v_assignment.teen_user_id, v_assignment.adult_user_id) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if p_operation = 'start' and v_assignment.status <> 'accepted' then
    return jsonb_build_object('ok', false, 'code', 'job_not_awaiting_start');
  end if;
  if p_operation = 'finish' and v_assignment.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'job_not_in_progress');
  end if;

  select application.* into v_application
    from public.job_applications application
   where application.id = v_assignment.application_id
     and application.job_id = v_assignment.job_id;
  if not found or v_application.status <> 'accepted'::public.mort_application_status then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;
  select job.* into v_job
    from public.jobs job
   where job.id = v_assignment.job_id
     and job.poster_id = v_assignment.adult_user_id;
  if not found or (p_operation = 'start' and v_job.status <> 'filled')
     or (p_operation = 'finish' and v_job.status <> 'in_progress') then
    return jsonb_build_object('ok', false, 'code', 'assigned_job_required');
  end if;

  select profile.* into v_teen from public.profiles profile
   where profile.id = v_assignment.teen_user_id;
  select profile.* into v_adult from public.profiles profile
   where profile.id = v_assignment.adult_user_id;
  if v_teen.role <> 'teen' or v_adult.role <> 'adult'
     or v_teen.account_status <> 'active'
     or v_adult.account_status <> 'active'
     or coalesce(v_teen.verification_status::text, '') not in ('verified', 'approved')
     or coalesce(v_adult.verification_status::text, '') not in ('verified', 'approved') then
    return jsonb_build_object('ok', false, 'code', 'participant_not_eligible');
  end if;

  select contract.* into v_contract from public.job_contracts contract
   where contract.application_id = p_application_id
     and contract.job_id = v_job.id
     and contract.teen_id = v_assignment.teen_user_id
     and contract.adult_id = v_assignment.adult_user_id;
  if not found or v_contract.status <> 'active'
     or v_contract.active_version_id is null then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  select version.* into v_version from public.job_contract_versions version
   where version.id = v_contract.active_version_id
     and version.contract_id = v_contract.id
     and version.status = 'active';
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  select count(distinct acceptance.user_id)::integer into v_acceptances
    from public.job_contract_acceptances acceptance
   where acceptance.contract_id = v_contract.id
     and acceptance.contract_version_id = v_version.id
     and acceptance.content_hash = v_version.content_hash
     and acceptance.affirmative_checkbox
     and ((acceptance.user_id = v_assignment.teen_user_id and acceptance.party_role = 'teen')
       or (acceptance.user_id = v_assignment.adult_user_id and acceptance.party_role = 'adult'));
  if v_acceptances <> 2 then
    return jsonb_build_object('ok', false, 'code', 'current_contract_acceptance_required');
  end if;

  select agreement.* into v_safety from public.job_safety_agreements agreement
   where agreement.application_id = p_application_id
     and agreement.teen_id = v_assignment.teen_user_id
     and agreement.adult_id = v_assignment.adult_user_id;
  if not found or v_safety.status <> 'confirmed'
     or v_safety.teen_confirmed_version <> v_safety.agreement_version
     or v_safety.adult_confirmed_version <> v_safety.agreement_version then
    return jsonb_build_object('ok', false, 'code', 'mutual_safety_agreement_required');
  end if;
  v_safety_terms := private.job_safety_terms(p_application_id);
  if v_safety_terms is null
     or v_safety.material_terms_hash <> encode(extensions.digest(v_safety.terms_snapshot::text, 'sha256'), 'hex')
     or v_safety.material_terms_hash <> encode(extensions.digest(v_safety_terms::text, 'sha256'), 'hex') then
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_version_changed');
  end if;
  if not exists (
    select 1 from public.job_safety_plans plan
     where plan.application_id = p_application_id
       and plan.checkin_cadence_minutes between 15 and 240
       and (plan.expected_people is not null or v_job.remote_allowed)
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_plan_required');
  end if;
  if exists (
    select 1 from public.safety_reports report
     where (report.application_id = p_application_id or report.job_id = v_job.id)
       and report.status not in ('resolved', 'dismissed', 'closed')
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_safety_incident_blocks_start');
  end if;
  if exists (
    select 1 from public.disputes dispute
     where dispute.assignment_id = v_assignment.id
       and dispute.status in ('open', 'investigating', 'awaiting_evidence')
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_dispute_blocks_execution');
  end if;

  if p_operation = 'start' then
    v_start_at := coalesce(v_version.start_window, v_job.starts_at);
    if v_start_at is null then
      return jsonb_build_object('ok', false, 'code', 'start_window_required');
    end if;
    if now() < v_start_at - interval '2 hours'
       or now() > v_start_at + interval '4 hours' then
      return jsonb_build_object('ok', false, 'code', 'outside_start_window');
    end if;
    v_runtime := public.get_runtime_feature_status();
    if coalesce((v_runtime->>'payments_disabled')::boolean, true) then
      return jsonb_build_object('ok', false, 'code', 'confirmed_job_funding_required');
    end if;
    select exists (
      select 1 from private.stripe_payment_intents payment
       where payment.assignment_id = v_assignment.id
         and payment.environment = 'live'
         and payment.status in ('succeeded', 'authorized')
    ) into v_funded;
    if not v_funded then
      return jsonb_build_object('ok', false, 'code', 'confirmed_job_funding_required');
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'application_id', p_application_id,
    'assignment_id', v_assignment.id,
    'job_id', v_job.id,
    'teen_id', v_assignment.teen_user_id,
    'adult_id', v_assignment.adult_user_id,
    'contract_id', v_contract.id,
    'contract_version_id', v_version.id,
    'contract_content_hash', v_version.content_hash,
    'safety_agreement_version', v_safety.agreement_version,
    'start_window', coalesce(v_version.start_window, v_job.starts_at)
  );
end;
$function$
;

-- The private SECURITY DEFINER helper is intentionally callable only by its owner.
revoke all on function private.job_execution_gate(uuid, text)
  from public, anon, authenticated, service_role;

do $assert$
declare
  v_definition text;
begin
  v_definition := pg_catalog.pg_get_functiondef(
    'private.job_execution_gate(uuid,text)'::regprocedure
  );

  if pg_catalog.strpos(v_definition,
       'coalesce(v_teen.verification_status::text, '''') not in (''verified'', ''approved'')') = 0
     or pg_catalog.strpos(v_definition,
       'coalesce(v_adult.verification_status::text, '''') not in (''verified'', ''approved'')') = 0 then
    raise exception 'Job execution gate verification predicate assertion failed';
  end if;

  if pg_catalog.has_function_privilege('anon', 'private.job_execution_gate(uuid,text)', 'EXECUTE')
     or pg_catalog.has_function_privilege('authenticated', 'private.job_execution_gate(uuid,text)', 'EXECUTE')
     or pg_catalog.has_function_privilege('service_role', 'private.job_execution_gate(uuid,text)', 'EXECUTE') then
    raise exception 'Job execution gate must remain inaccessible to API roles';
  end if;
end
$assert$;
