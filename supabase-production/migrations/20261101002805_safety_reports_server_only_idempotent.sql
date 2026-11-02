-- Force safety reports through the idempotent, rate-limited server RPC.
-- The previous INSERT policy let authenticated users bypass request IDs and
-- per-account report throttles by writing directly to safety_reports.

CREATE OR REPLACE FUNCTION public.submit_safety_report_v2(
  p_target_user_id uuid,
  p_target_job_id uuid,
  p_target_message_id uuid,
  p_target_review_id uuid,
  p_application_id uuid,
  p_category text,
  p_severity text,
  p_immediate_danger boolean,
  p_details text,
  p_occurred_at timestamp with time zone,
  p_location_type text,
  p_desired_outcome text,
  p_confidential_safety_feedback boolean,
  p_client_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  reporter uuid := auth.uid();
  report_id uuid;
  clean_details text := btrim(coalesce(p_details, ''));
  clean_location_type text := nullif(btrim(coalesce(p_location_type, '')), '');
  clean_desired_outcome text := nullif(btrim(coalesce(p_desired_outcome, '')), '');
  v_existing public.safety_reports%rowtype;
  v_count integer;
begin
  if reporter is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;
  if p_target_user_id = reporter then
    return jsonb_build_object('ok', false, 'code', 'cannot_report_self');
  end if;
  if char_length(clean_details) < 10 or char_length(clean_details) > 4000 then
    return jsonb_build_object('ok', false, 'code', 'safety_report_details_invalid');
  end if;
  if p_category is null or p_category not in (
    'harassment', 'unsafe_meeting', 'scam', 'inappropriate_content',
    'privacy', 'underage_concern', 'payment', 'other'
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_report_category_invalid');
  end if;
  if p_severity is null or p_severity not in ('low', 'normal', 'high', 'critical') then
    return jsonb_build_object('ok', false, 'code', 'safety_report_severity_invalid');
  end if;

  -- Private artifacts can only be reported by someone who participated in them.
  if p_target_message_id is not null and not exists (
    select 1
    from public.messages message
    join public.conversation_members member
      on member.conversation_id = message.conversation_id
    where message.id = p_target_message_id
      and member.user_id = reporter
      and (
        p_target_user_id is null
        or exists (
          select 1 from public.conversation_members target_member
          where target_member.conversation_id = message.conversation_id
            and target_member.user_id = p_target_user_id
        )
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'report_target_not_authorized');
  end if;
  if p_application_id is not null and not exists (
    select 1
    from public.job_applications application
    join public.jobs job on job.id = application.job_id
    where application.id = p_application_id
      and (
        application.applicant_id = reporter
        or job.poster_id = reporter
      )
      and (
        p_target_user_id is null
        or (application.applicant_id = reporter and job.poster_id = p_target_user_id)
        or (job.poster_id = reporter and application.applicant_id = p_target_user_id)
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'report_target_not_authorized');
  end if;
  if p_target_review_id is not null and not exists (
    select 1
    from public.reviews review
    where review.id = p_target_review_id
      and (review.reviewer_id = reporter or review.subject_id = reporter)
      and (
        p_target_user_id is null
        or (review.reviewer_id = reporter and review.subject_id = p_target_user_id)
        or (review.subject_id = reporter and review.reviewer_id = p_target_user_id)
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'report_target_not_authorized');
  end if;
  if p_target_job_id is not null and not exists (
    select 1
    from public.jobs job
    where job.id = p_target_job_id
      and (
        job.poster_id = reporter
        or exists (
          select 1 from public.job_applications application
          where application.job_id = job.id and application.applicant_id = reporter
        )
        or exists (
          select 1 from public.saved_jobs saved
          where saved.job_id = job.id and saved.user_id = reporter
        )
        or exists (
          select 1 from public.conversations conversation
          join public.conversation_members member on member.conversation_id = conversation.id
          where conversation.job_id = job.id and member.user_id = reporter
        )
        or (
          job.status = 'open'::public.mort_job_status
          and job.safety_review_status = 'approved'
          and exists (
            select 1 from public.profiles poster
            where poster.id = job.poster_id and poster.account_status = 'active'
          )
        )
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'report_target_not_authorized');
  end if;

  -- Serialize retries for the same request ID before applying rate limits.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(reporter::text || ':safety-report-request:' || p_client_request_id::text, 0)
  );
  select * into v_existing
  from public.safety_reports report
  where report.reporter_id = reporter
    and report.client_request_id = p_client_request_id
  for update;
  if found then
    if v_existing.reported_user_id is distinct from p_target_user_id
      or v_existing.job_id is distinct from p_target_job_id
      or v_existing.message_id is distinct from p_target_message_id
      or v_existing.target_review_id is distinct from p_target_review_id
      or v_existing.application_id is distinct from p_application_id
      or v_existing.category is distinct from p_category
      or v_existing.severity is distinct from p_severity
      or v_existing.immediate_danger is distinct from coalesce(p_immediate_danger, false)
      or v_existing.description is distinct from clean_details
      or v_existing.occurred_at is distinct from p_occurred_at
      or v_existing.location_type is distinct from clean_location_type
      or v_existing.desired_outcome is distinct from clean_desired_outcome
      or v_existing.confidential_safety_feedback is distinct from coalesce(p_confidential_safety_feedback, false) then
      return jsonb_build_object('ok', false, 'code', 'safety_request_payload_mismatch');
    end if;
    return jsonb_build_object(
      'ok', true,
      'report_id', v_existing.id,
      'immediate_danger', v_existing.immediate_danger,
      'replayed', true
    );
  end if;

  -- Urgent reports have a separate, more generous throttle so the ordinary
  -- daily limit cannot suppress a time-sensitive safety report.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(reporter::text || ':safety-report-limit:' || coalesce(p_immediate_danger, false)::text, 0)
  );
  if coalesce(p_immediate_danger, false) then
    select count(*) into v_count
    from public.safety_reports report
    where report.reporter_id = reporter
      and report.immediate_danger
      and report.created_at >= now() - interval '1 hour';
    if v_count >= 20 then
      return jsonb_build_object(
        'ok', false, 'code', 'urgent_safety_rate_limited',
        'emergency_guidance_required', true
      );
    end if;
  else
    select count(*) into v_count
    from public.safety_reports report
    where report.reporter_id = reporter
      and not report.immediate_danger
      and report.created_at >= now() - interval '1 day';
    if v_count >= 15 then
      return jsonb_build_object('ok', false, 'code', 'safety_report_rate_limited');
    end if;
  end if;

  insert into public.safety_reports (
    reporter_id, reported_user_id, job_id, message_id, target_review_id,
    application_id, category, description, status, severity, immediate_danger,
    occurred_at, location_type, desired_outcome, confidential_safety_feedback,
    client_request_id
  ) values (
    reporter, p_target_user_id, p_target_job_id, p_target_message_id,
    p_target_review_id, p_application_id, p_category, clean_details, 'open',
    p_severity, coalesce(p_immediate_danger, false), p_occurred_at,
    clean_location_type, clean_desired_outcome,
    coalesce(p_confidential_safety_feedback, false), p_client_request_id
  ) returning id into report_id;

  return jsonb_build_object(
    'ok', true,
    'report_id', report_id,
    'immediate_danger', coalesce(p_immediate_danger, false),
    'replayed', false
  );
end;
$function$;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.safety_reports FROM anon, authenticated;
DROP POLICY IF EXISTS reports_insert_self ON public.safety_reports;
REVOKE EXECUTE ON FUNCTION public.submit_safety_report_v2(uuid,uuid,uuid,uuid,uuid,text,text,boolean,text,timestamp with time zone,text,text,boolean,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_safety_report_v2(uuid,uuid,uuid,uuid,uuid,text,text,boolean,text,timestamp with time zone,text,text,boolean,uuid) TO authenticated, service_role;
CREATE INDEX IF NOT EXISTS safety_reports_reporter_danger_created_at_idx
  ON public.safety_reports (reporter_id, immediate_danger, created_at DESC);
