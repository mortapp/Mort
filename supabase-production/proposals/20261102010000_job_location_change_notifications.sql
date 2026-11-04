-- Adds in-app notifications when private job terms invalidate an accepted
-- assignment's safety agreement. Does not alter job rows or user data.
begin;

create or replace function private.refresh_job_safety_agreement(p_application_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_terms jsonb;
  v_agreement public.job_safety_agreements%rowtype;
begin
  v_terms := private.job_safety_terms(p_application_id);
  if v_terms is null then
    return;
  end if;

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

  if not found then
    return;
  end if;

  insert into public.notifications (user_id, notification_type, title, body, data)
  values
    (
      v_agreement.teen_id,
      'safety_reconfirmation_required',
      'Job details changed — please reconfirm',
      'The job location or terms were updated. Review and reconfirm the safety agreement before this job can continue.',
      jsonb_build_object('application_id', p_application_id, 'job_id', v_agreement.job_id,
                         'agreement_version', v_agreement.agreement_version)
    ),
    (
      v_agreement.adult_id,
      'safety_reconfirmation_required',
      'Reconfirmation needed after your update',
      'You updated this job’s location or terms. Both you and the teen need to reconfirm the safety agreement before work can continue.',
      jsonb_build_object('application_id', p_application_id, 'job_id', v_agreement.job_id,
                         'agreement_version', v_agreement.agreement_version)
    );
end;
$function$;

commit;
