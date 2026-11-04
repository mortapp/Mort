-- Align Guardian row visibility with the full eligibility predicate used for guardian_id disclosure.
-- This is a forward-only correction. It does not expand consent or change direct table grants.

CREATE OR REPLACE FUNCTION public.get_my_job_applications(p_application_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare v_user uuid:=auth.uid(); v_items jsonb; begin if v_user is null or not private.is_active_user() then return jsonb_build_object('ok',false,'code','active_account_required'); end if; select coalesce(jsonb_agg(jsonb_build_object('id',ja.id,'job_id',ja.job_id,'teen_id',ja.applicant_id,'status',ja.status::text,'note',ja.cover_note,'guardian_id',case
  when ja.applicant_id=v_user or exists(
    select 1
    from public.guardian_links gl
    join public.profiles guardian_profile on guardian_profile.id=gl.guardian_user_id
    join auth.users guardian_auth on guardian_auth.id=gl.guardian_user_id
    where gl.teen_user_id=ja.applicant_id
      and gl.guardian_user_id=v_user
      and gl.status='active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
      and guardian_profile.role='guardian'::public.mort_role
      and guardian_profile.account_status='active'
      and guardian_profile.date_of_birth is not null
      and extract(year from age(current_date,guardian_profile.date_of_birth))>=18
      and guardian_auth.email_confirmed_at is not null
  ) then ja.guardian_id
  else null
end,'availability_confirmed',ja.availability_confirmed,'created_at',ja.created_at,'updated_at',ja.updated_at,'viewed_at',ja.viewed_at,'withdrawn_at',ja.withdrawn_at,'teen',jsonb_build_object('display_name',teen.display_name,'avatar_path',teen.avatar_path),'jobs',jsonb_build_object('id',j.id,'poster_id',j.poster_id,'title',j.title,'summary',j.summary,'description',j.description,'category',j.category,'location_text',case when j.remote_allowed then 'Remote' else concat_ws(', ',j.city,j.region) end,'city',j.city,'state',j.region,'status',j.status::text,'requires_guardian_approval',j.requires_guardian_approval,'adult_job_amount_cents',round(j.pay_amount*100)::integer,'mort_service_fee_cents',j.mort_service_fee_cents,'pay_amount_cents',round(j.pay_amount*100)::integer,'starts_at',j.starts_at,'ends_at',j.ends_at,'deadline_at',j.deadline_at,'expires_at',j.expires_at,'published_at',j.published_at,'updated_at',j.updated_at,'profiles',jsonb_build_object('display_name',poster.display_name,'verification_status',poster.verification_status,'avatar_path',poster.avatar_path),'schedule_type',j.schedule_type,'payment_type',j.pay_type,'payment_method',j.payment_method,'payment_timing',j.payment_timing,'verification_requirement',j.verification_requirement,'work_environment',j.work_environment,'location_type',j.location_type,'experience_level',j.experience_level,'estimated_duration_minutes',j.estimated_duration_minutes,'workers_needed',j.workers_needed,'skills_needed',to_jsonb(j.skills_needed),'physical_requirements',to_jsonb(j.physical_requirements),'equipment_provided',j.equipment_provided,'equipment_worker_brings',j.equipment_worker_brings,'special_instructions',j.special_instructions,'safety_notes',j.safety_notes,'proof_expected',j.proof_expected,'adult_supervision_present',j.adult_supervision_present,'tip_allowed',j.tip_allowed,'applications_open',j.applications_open,'is_test',false,'recurring',j.recurring,'recurrence_rule',j.recurrence_rule,'timezone',j.timezone,'urgency',j.urgency,'acceptable_transportation_methods',to_jsonb(j.acceptable_transportation_methods),'teen_min_age',j.age_min,'teen_max_age',j.age_max,'quick_accept_eligible',false)) order by ja.created_at desc,ja.id desc),'[]'::jsonb) into v_items from public.job_applications ja join public.jobs j on j.id=ja.job_id join public.profiles teen on teen.id=ja.applicant_id join public.profiles poster on poster.id=j.poster_id where (p_application_id is null or ja.id=p_application_id) and (ja.applicant_id=v_user or j.poster_id=v_user or exists(
  select 1
  from public.guardian_links gl
  join public.profiles guardian_profile on guardian_profile.id = gl.guardian_user_id
  join auth.users guardian_auth on guardian_auth.id = gl.guardian_user_id
  where gl.teen_user_id = ja.applicant_id
    and gl.guardian_user_id = v_user
    and gl.status = 'active'
    and gl.teen_consent_at is not null
    and gl.guardian_consent_at is not null
    and guardian_profile.role = 'guardian'::public.mort_role
    and guardian_profile.account_status = 'active'
    and guardian_profile.date_of_birth is not null
    and extract(year from age(current_date, guardian_profile.date_of_birth)) >= 18
    and guardian_auth.email_confirmed_at is not null
)); return jsonb_build_object('ok',true,'items',v_items); end; $function$
;

