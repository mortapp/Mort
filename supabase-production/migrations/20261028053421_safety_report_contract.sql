-- Extend the existing reporter-owned safety case record to match the Flutter
-- report form, with request-id idempotency for safe client retries.
alter table public.safety_reports
  add column if not exists application_id uuid references public.job_applications(id) on delete set null,
  add column if not exists target_review_id uuid,
  add column if not exists immediate_danger boolean not null default false,
  add column if not exists occurred_at timestamptz,
  add column if not exists location_type text,
  add column if not exists desired_outcome text,
  add column if not exists confidential_safety_feedback boolean not null default false,
  add column if not exists client_request_id uuid;

create unique index if not exists safety_reports_reporter_request_id_uidx
  on public.safety_reports (reporter_id, client_request_id)
  where client_request_id is not null;

create or replace function public.submit_safety_report_v2(
  p_target_user_id uuid,
  p_target_job_id uuid,
  p_target_message_id uuid,
  p_target_review_id uuid,
  p_application_id uuid,
  p_category text,
  p_severity text,
  p_immediate_danger boolean,
  p_details text,
  p_occurred_at timestamptz,
  p_location_type text,
  p_desired_outcome text,
  p_confidential_safety_feedback boolean,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  reporter uuid := auth.uid();
  report_id uuid;
  clean_details text := btrim(coalesce(p_details, ''));
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

  insert into public.safety_reports (
    reporter_id,
    reported_user_id,
    job_id,
    message_id,
    target_review_id,
    application_id,
    category,
    description,
    status,
    severity,
    immediate_danger,
    occurred_at,
    location_type,
    desired_outcome,
    confidential_safety_feedback,
    client_request_id
  ) values (
    reporter,
    p_target_user_id,
    p_target_job_id,
    p_target_message_id,
    p_target_review_id,
    p_application_id,
    p_category,
    clean_details,
    'open',
    p_severity,
    coalesce(p_immediate_danger, false),
    p_occurred_at,
    nullif(btrim(coalesce(p_location_type, '')), ''),
    nullif(btrim(coalesce(p_desired_outcome, '')), ''),
    coalesce(p_confidential_safety_feedback, false),
    p_client_request_id
  )
  on conflict (reporter_id, client_request_id)
    where client_request_id is not null do nothing
  returning id into report_id;

  if report_id is null then
    select id into report_id
    from public.safety_reports
    where reporter_id = reporter and client_request_id = p_client_request_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'report_id', report_id,
    'immediate_danger', coalesce(p_immediate_danger, false)
  );
end;
$function$;

revoke all on function public.submit_safety_report_v2(
  uuid, uuid, uuid, uuid, uuid, text, text, boolean, text, timestamptz,
  text, text, boolean, uuid
) from public, anon, authenticated;
grant execute on function public.submit_safety_report_v2(
  uuid, uuid, uuid, uuid, uuid, text, text, boolean, text, timestamptz,
  text, text, boolean, uuid
) to authenticated;

