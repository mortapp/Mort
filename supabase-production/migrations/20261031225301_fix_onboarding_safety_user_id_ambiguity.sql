create or replace function public.save_my_onboarding_safety_v2(
  p_payload jsonb,
  p_client_request_id uuid,
  p_payload_version integer default 1,
  p_expected_revision text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  profile public.profiles%rowtype;
  intent text := coalesce(p_payload->>'notification_intent', 'ask_later');
  guardian_choice text := coalesce(p_payload->>'guardian_choice', 'not_applicable');
  unknown_keys text[];
begin
  if v_user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into unknown_keys
  from jsonb_object_keys(p_payload) key where key not in ('notification_intent','guardian_choice');
  if cardinality(unknown_keys) > 0 or intent not in ('ask_later','preferred','not_preferred') then
    return jsonb_build_object('ok', false, 'code', 'onboarding_safety_support_invalid');
  end if;
  select * into profile from public.profiles where id = v_user_id for update;
  if profile.id is null then return jsonb_build_object('ok', false, 'code', 'onboarding_account_required'); end if;
  if p_expected_revision is not null and profile.updated_at is distinct from p_expected_revision::timestamptz then
    return jsonb_build_object('ok', false, 'code', 'onboarding_revision_conflict', 'revision', profile.updated_at);
  end if;
  if profile.role = 'teen'::public.mort_role then
    if guardian_choice = 'skip' then
      perform public.set_guardian_setup_skipped();
    elsif guardian_choice = 'existing' and profile.guardian_setup_status not in ('invite_pending','linked') then
      return jsonb_build_object('ok', false, 'code', 'guardian_invite_required_or_skip');
    elsif guardian_choice not in ('existing','skip') then
      return jsonb_build_object('ok', false, 'code', 'guardian_invite_required_or_skip');
    end if;
  end if;
  insert into private.mort_onboarding_safety(user_id, notification_intent)
  values (v_user_id, intent)
  on conflict (user_id) do update set notification_intent = excluded.notification_intent, saved_at = now();
  return private.evaluate_mort_onboarding(v_user_id) || jsonb_build_object('replayed', false);
end;
$function$;
revoke all on function public.save_my_onboarding_safety_v2(jsonb,uuid,integer,text) from public, anon;
grant execute on function public.save_my_onboarding_safety_v2(jsonb,uuid,integer,text) to authenticated, service_role;