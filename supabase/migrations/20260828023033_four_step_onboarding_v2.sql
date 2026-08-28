-- Compatibility-safe four-step onboarding. Legacy progress/RPCs remain intact
-- for deployed clients; v2 projects resume state from canonical persisted data.

create table private.onboarding_v2_requests (
  user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null check (operation in (
    'save_account', 'save_work_preferences', 'save_safety_support', 'complete'
  )),
  client_request_id uuid not null,
  step text not null check (step in (
    'account', 'work_preferences', 'safety_support', 'review'
  )),
  payload_version integer not null check (payload_version = 1),
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  response jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (user_id, operation, client_request_id)
);

create table private.onboarding_v2_safety (
  user_id uuid primary key references auth.users(id) on delete cascade,
  notification_intent text not null check (
    notification_intent in ('ask_later', 'preferred', 'not_preferred')
  ),
  saved_at timestamptz not null default now()
);

-- A completed legacy onboarding is canonical evidence that the user already
-- passed the prior safety presentation. Preserve that truth without claiming
-- an OS permission or inventing an enabled notification preference.
insert into private.onboarding_v2_safety (user_id, notification_intent, saved_at)
select profile.id, 'ask_later', coalesce(profile.updated_at, now())
from public.profiles profile
where profile.onboarding_completed
on conflict (user_id) do nothing;

alter table private.onboarding_v2_requests enable row level security;
alter table private.onboarding_v2_requests force row level security;
alter table private.onboarding_v2_safety enable row level security;
alter table private.onboarding_v2_safety force row level security;

revoke all on private.onboarding_v2_requests from public, anon, authenticated;
revoke all on private.onboarding_v2_safety from public, anon, authenticated;
grant select, insert, update, delete on private.onboarding_v2_requests to service_role;
grant select, insert, update, delete on private.onboarding_v2_safety to service_role;

create or replace function private.valid_mort_display_name(p_value text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_value is null or (
    char_length(btrim(p_value)) between 2 and 80
    and btrim(p_value) !~ '[[:cntrl:]]'
    and btrim(p_value) ~ '[[:alpha:]]'
    and lower(regexp_replace(btrim(p_value), '[[:space:]]+', ' ', 'g'))
      not in ('test', 'testing', 'user', 'unknown', 'none', 'n/a', 'asdf')
    and btrim(p_value) !~ '^(.)\1{3,}$'
  );
$$;

create or replace function private.enforce_valid_mort_display_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.valid_mort_display_name(new.display_name) then
    raise exception 'display_name_invalid';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_validate_display_name on public.profiles;
create trigger profiles_validate_display_name
before insert or update of display_name on public.profiles
for each row execute function private.enforce_valid_mort_display_name();

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_trigger guard_trigger
    join pg_catalog.pg_class relation on relation.oid = guard_trigger.tgrelid
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    join pg_catalog.pg_proc procedure on procedure.oid = guard_trigger.tgfoid
    where namespace.nspname = 'public'
      and relation.relname = 'profiles'
      and guard_trigger.tgname = 'profiles_enforce_authoritative_onboarding_completion'
      and procedure.proname = 'enforce_server_authoritative_onboarding_completion'
      and not guard_trigger.tgisinternal
  ) then
    raise exception 'server_authoritative_onboarding_completion_guard_required';
  end if;
end;
$$;

create or replace function private.evaluate_onboarding_v2(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_progress public.onboarding_progress%rowtype;
  v_missing text[] := array[]::text[];
  v_completed text[] := array[]::text[];
  v_active text := 'account';
  v_age integer;
  v_legal_missing boolean := false;
begin
  select * into v_profile from public.profiles where id = p_user_id;
  select * into v_progress from public.onboarding_progress where user_id = p_user_id;

  if v_profile.id is null then
    v_missing := array['profile'];
  else
    if v_profile.role is null then v_missing := v_missing || array['role']; end if;
    if v_profile.dob is null then v_missing := v_missing || array['dob']; end if;
    if not private.valid_mort_display_name(v_profile.display_name)
       or v_profile.display_name is null then
      v_missing := v_missing || array['display_name'];
    end if;
    if public.validate_username(v_profile.username) is not null then
      v_missing := v_missing || array['username'];
    end if;
    if v_profile.dob is not null then
      v_age := extract(year from age(current_date, v_profile.dob))::integer;
      if v_age < 13
         or (v_profile.role = 'teen' and v_age not between 13 and 17)
         or (v_profile.role in ('adult', 'guardian') and v_age < 18) then
        v_missing := v_missing || array['age_role_eligibility'];
      end if;
    end if;
    if v_profile.location_setup_mode = 'city_state'
       and (nullif(btrim(v_profile.city), '') is null
            or v_profile.state !~ '^[A-Z]{2}$') then
      v_missing := v_missing || array['general_location'];
    end if;
    if v_profile.role = 'adult' and (
      v_progress.adult_account_type not in ('individual', 'business')
      or (v_progress.adult_account_type = 'business'
          and nullif(btrim(v_progress.business_name), '') is null)
    ) then
      v_missing := v_missing || array['adult_account_type'];
    end if;
  end if;

  if cardinality(v_missing) = 0 then
    v_completed := v_completed || array['account'];
    v_active := 'work_preferences';
    if v_profile.role = 'teen' then
      if cardinality(v_profile.preferred_job_categories) = 0 then
        v_missing := v_missing || array['preferred_job_categories'];
      end if;
      if nullif(btrim(v_profile.availability), '') is null then
        v_missing := v_missing || array['availability'];
      end if;
      if cardinality(v_profile.transportation_methods) = 0 then
        v_missing := v_missing || array['transportation_methods'];
      end if;
    end if;
  end if;

  if cardinality(v_missing) = 0 then
    v_completed := v_completed || array['work_preferences'];
    v_active := 'safety_support';
    if not exists (
      select 1 from private.onboarding_v2_safety safety
      where safety.user_id = p_user_id
    ) then
      v_missing := v_missing || array['safety_support_intent'];
    end if;
    if v_profile.role = 'teen'
       and v_profile.guardian_setup_status not in ('skipped', 'invite_pending', 'linked') then
      v_missing := v_missing || array['guardian_setup_choice'];
    end if;
  end if;

  if cardinality(v_missing) = 0 then
    v_completed := v_completed || array['safety_support'];
    v_active := 'review';
    with current_versions as (
      select distinct on (version.document_id)
        version.document_id,
        version.id as version_id
      from public.legal_document_versions version
      join public.legal_documents document on document.id = version.document_id
      where document.publication_status = 'published'
        and version.publication_status = 'published'
        and version.effective_at <= now()
      order by version.document_id, version.effective_at desc, version.created_at desc
    ), required_versions as (
      select current_version.version_id
      from public.legal_role_requirements requirement
      left join current_versions current_version
        on current_version.document_id = requirement.document_id
      where requirement.role = v_profile.role
        and requirement.age_band in ('all', private.current_age_band(v_profile.dob))
        and requirement.required
    )
    select exists (
      select 1
      from required_versions required_version
      where not exists (
        select 1
        from public.legal_acceptances acceptance
        where acceptance.user_id = p_user_id
          and acceptance.document_version_id = required_version.version_id
          and acceptance.active
      ) or exists (
        select 1
        from public.legal_reacceptance_requirements reacceptance
        where reacceptance.user_id = p_user_id
          and reacceptance.required_version_id = required_version.version_id
          and reacceptance.satisfied_at is null
          and reacceptance.waived_at is null
      )
    ) into v_legal_missing;
    if v_legal_missing then v_missing := v_missing || array['legal_acceptances']; end if;
  end if;

  if cardinality(v_missing) = 0 and v_profile.onboarding_completed then
    v_completed := v_completed || array['review'];
    v_active := 'complete';
  elsif cardinality(v_missing) = 0 then
    v_missing := array['onboarding_completion'];
  end if;

  return jsonb_build_object(
    'ok', true,
    'completed', v_active = 'complete',
    'active_step', v_active,
    'primary_steps', array['account','work_preferences','safety_support','review'],
    'completed_steps', v_completed,
    'missing_requirements', v_missing,
    'role', v_profile.role,
    'revision', v_profile.updated_at
  );
end;
$$;

create or replace function public.get_my_onboarding_progress_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  return private.evaluate_onboarding_v2(auth.uid());
end;
$$;

create or replace function public.save_my_onboarding_account_v2(
  p_payload jsonb,
  p_client_request_id uuid,
  p_payload_version integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_hash text;
  v_prior private.onboarding_v2_requests%rowtype;
  v_profile public.profiles%rowtype;
  v_result jsonb;
  v_role text := lower(btrim(coalesce(p_payload->>'role', '')));
  v_dob date;
  v_unknown text[];
  v_merged jsonb;
begin
  if v_user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into v_unknown
  from jsonb_object_keys(p_payload) key where key not in (
    'role','display_name','username','dob','city','state','location_setup_mode',
    'adult_account_type','business_name','approximate_area'
  );
  if cardinality(v_unknown) > 0 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_payload_unknown_fields');
  end if;
  v_hash := encode(extensions.digest(convert_to(p_payload::text, 'utf8'), 'sha256'), 'hex');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_user_id::text || ':save_account:' || p_client_request_id::text, 0
  ));
  select * into v_prior from private.onboarding_v2_requests
  where user_id = v_user_id and operation = 'save_account'
    and client_request_id = p_client_request_id for update;
  if v_prior.user_id is not null then
    if v_prior.payload_hash <> v_hash or v_prior.payload_version <> p_payload_version then
      return jsonb_build_object('ok', false, 'code', 'onboarding_request_payload_mismatch');
    end if;
    if v_prior.response is not null then
      return v_prior.response || jsonb_build_object('replayed', true);
    end if;
    delete from private.onboarding_v2_requests
    where user_id = v_user_id and operation = 'save_account'
      and client_request_id = p_client_request_id;
  end if;
  insert into private.onboarding_v2_requests(
    user_id, operation, client_request_id, step, payload_version, payload_hash
  ) values (v_user_id, 'save_account', p_client_request_id, 'account', p_payload_version, v_hash);

  begin v_dob := (p_payload->>'dob')::date;
  exception when others then return jsonb_build_object('ok', false, 'code', 'dob_invalid', 'field', 'dob'); end;

  select * into v_profile from public.profiles where id = v_user_id for update;
  if v_profile.dob is null then
    v_result := public.save_my_onboarding_age(v_dob, gen_random_uuid());
    if not coalesce((v_result->>'ok')::boolean, false) then return v_result; end if;
  elsif v_profile.dob <> v_dob then
    return jsonb_build_object('ok', false, 'code', 'dob_immutable', 'field', 'dob');
  end if;
  select * into v_profile from public.profiles where id = v_user_id;
  if v_profile.role is null then
    v_result := public.save_my_onboarding_role(v_role, gen_random_uuid());
    if not coalesce((v_result->>'ok')::boolean, false) then return v_result; end if;
  elsif v_profile.role::text <> v_role then
    return jsonb_build_object('ok', false, 'code', 'role_immutable', 'field', 'role');
  end if;
  select * into v_profile from public.profiles where id = v_user_id;
  v_merged := p_payload || jsonb_build_object(
    'bio', v_profile.bio,
    'availability', v_profile.availability,
    'preferred_job_categories', to_jsonb(v_profile.preferred_job_categories),
    'approximate_area', coalesce(nullif(btrim(p_payload->>'approximate_area'),''), v_profile.approximate_area),
    'goals', v_profile.goals
  );
  v_result := public.save_my_profile_setup_v2(v_merged, gen_random_uuid(), false);
  if not coalesce((v_result->>'ok')::boolean, false) then return v_result; end if;
  v_result := private.evaluate_onboarding_v2(v_user_id) || jsonb_build_object('replayed', false);
  update private.onboarding_v2_requests set response = v_result, completed_at = now()
  where user_id = v_user_id and operation = 'save_account' and client_request_id = p_client_request_id;
  return v_result;
end;
$$;

create or replace function public.save_my_onboarding_work_v2(
  p_payload jsonb,
  p_client_request_id uuid,
  p_payload_version integer default 1,
  p_expected_revision text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid(); v_hash text; v_prior private.onboarding_v2_requests%rowtype;
  v_profile public.profiles%rowtype; v_result jsonb; v_unknown text[];
begin
  if v_user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid'); end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into v_unknown
  from jsonb_object_keys(p_payload) key where key not in (
    'availability','preferred_job_categories','transportation_methods',
    'max_travel_distance_miles','max_travel_minutes','walking_distance_only',
    'guardian_transportation_possible'
  );
  if cardinality(v_unknown) > 0 then return jsonb_build_object('ok', false, 'code', 'onboarding_payload_unknown_fields'); end if;
  v_hash := encode(extensions.digest(convert_to(p_payload::text, 'utf8'), 'sha256'), 'hex');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_user_id::text || ':save_work_preferences:' || p_client_request_id::text, 0
  ));
  select * into v_prior from private.onboarding_v2_requests where user_id=v_user_id and operation='save_work_preferences' and client_request_id=p_client_request_id for update;
  if v_prior.user_id is not null then
    if v_prior.payload_hash <> v_hash then return jsonb_build_object('ok', false, 'code', 'onboarding_request_payload_mismatch'); end if;
    if v_prior.response is not null then return v_prior.response || jsonb_build_object('replayed', true); end if;
    delete from private.onboarding_v2_requests where user_id=v_user_id and operation='save_work_preferences' and client_request_id=p_client_request_id;
  end if;
  insert into private.onboarding_v2_requests values (v_user_id,'save_work_preferences',p_client_request_id,'work_preferences',p_payload_version,v_hash,null,now(),null);
  select * into v_profile from public.profiles where id=v_user_id for update;
  if p_expected_revision is not null and v_profile.updated_at is distinct from p_expected_revision::timestamptz then
    return jsonb_build_object('ok', false, 'code', 'onboarding_revision_conflict', 'revision', v_profile.updated_at);
  end if;
  if v_profile.role = 'teen' then
    v_result := public.update_my_profile(jsonb_build_object(
      'availability', p_payload->>'availability',
      'preferred_job_categories', coalesce(p_payload->'preferred_job_categories','[]'::jsonb)
    ), null, gen_random_uuid());
    if not coalesce((v_result->>'ok')::boolean,false) then return v_result; end if;
    v_result := public.save_my_transportation_preferences(
      array(select jsonb_array_elements_text(coalesce(p_payload->'transportation_methods','[]'::jsonb))),
      (p_payload->>'max_travel_distance_miles')::integer,
      (p_payload->>'max_travel_minutes')::integer,
      coalesce((p_payload->>'walking_distance_only')::boolean,false),
      coalesce((p_payload->>'guardian_transportation_possible')::boolean,false),
      gen_random_uuid()
    );
    if not coalesce((v_result->>'ok')::boolean,false) then return v_result; end if;
  end if;
  v_result := private.evaluate_onboarding_v2(v_user_id) || jsonb_build_object('replayed', false);
  update private.onboarding_v2_requests set response=v_result,completed_at=now() where user_id=v_user_id and operation='save_work_preferences' and client_request_id=p_client_request_id;
  return v_result;
exception when invalid_text_representation then
  return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_invalid');
end;
$$;

create or replace function public.save_my_onboarding_safety_v2(
  p_payload jsonb, p_client_request_id uuid, p_payload_version integer default 1,
  p_expected_revision text default null
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid:=auth.uid(); v_hash text; v_prior private.onboarding_v2_requests%rowtype;
  v_profile public.profiles%rowtype; v_intent text; v_result jsonb; v_unknown text[];
begin
  if v_user_id is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload)<>'object' or p_client_request_id is null or p_payload_version<>1 then return jsonb_build_object('ok',false,'code','onboarding_request_invalid'); end if;
  select coalesce(array_agg(key order by key),array[]::text[]) into v_unknown from jsonb_object_keys(p_payload) key where key not in ('notification_intent','guardian_choice');
  if cardinality(v_unknown)>0 then return jsonb_build_object('ok',false,'code','onboarding_payload_unknown_fields'); end if;
  v_intent:=coalesce(p_payload->>'notification_intent','ask_later');
  if v_intent not in ('ask_later','preferred','not_preferred') then return jsonb_build_object('ok',false,'code','notification_intent_invalid'); end if;
  v_hash:=encode(extensions.digest(convert_to(p_payload::text,'utf8'),'sha256'),'hex');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_user_id::text || ':save_safety_support:' || p_client_request_id::text, 0
  ));
  select * into v_prior from private.onboarding_v2_requests where user_id=v_user_id and operation='save_safety_support' and client_request_id=p_client_request_id for update;
  if v_prior.user_id is not null then
    if v_prior.payload_hash<>v_hash then return jsonb_build_object('ok',false,'code','onboarding_request_payload_mismatch'); end if;
    if v_prior.response is not null then return v_prior.response||jsonb_build_object('replayed',true); end if;
    delete from private.onboarding_v2_requests where user_id=v_user_id and operation='save_safety_support' and client_request_id=p_client_request_id;
  end if;
  insert into private.onboarding_v2_requests values(v_user_id,'save_safety_support',p_client_request_id,'safety_support',p_payload_version,v_hash,null,now(),null);
  select * into v_profile from public.profiles where id=v_user_id for update;
  if p_expected_revision is not null and v_profile.updated_at is distinct from p_expected_revision::timestamptz then return jsonb_build_object('ok',false,'code','onboarding_revision_conflict','revision',v_profile.updated_at); end if;
  if v_profile.role='teen' and coalesce(p_payload->>'guardian_choice','')='skip' then perform public.set_guardian_setup_skipped(); end if;
  insert into private.onboarding_v2_safety(user_id,notification_intent) values(v_user_id,v_intent)
  on conflict(user_id) do update set notification_intent=excluded.notification_intent,saved_at=now();
  v_result:=private.evaluate_onboarding_v2(v_user_id)||jsonb_build_object('replayed',false);
  update private.onboarding_v2_requests set response=v_result,completed_at=now() where user_id=v_user_id and operation='save_safety_support' and client_request_id=p_client_request_id;
  return v_result;
end;
$$;

create or replace function public.complete_my_onboarding_v2(
  p_payload jsonb, p_client_request_id uuid, p_payload_version integer default 1,
  p_expected_revision text default null
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid:=auth.uid(); v_hash text; v_prior private.onboarding_v2_requests%rowtype;
  v_profile public.profiles%rowtype; v_progress jsonb; v_accept jsonb; v_version text;
  v_unknown text[];
begin
  if v_user_id is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload)<>'object' or p_client_request_id is null or p_payload_version<>1 then return jsonb_build_object('ok',false,'code','onboarding_request_invalid'); end if;
  select coalesce(array_agg(key order by key),array[]::text[]) into v_unknown
  from jsonb_object_keys(p_payload) key
  where key not in ('legal_version_ids','teen_summary_viewed','signature','platform','app_version');
  if cardinality(v_unknown)>0 or jsonb_typeof(coalesce(p_payload->'legal_version_ids','[]'::jsonb))<>'array' then
    return jsonb_build_object('ok',false,'code','onboarding_payload_unknown_fields');
  end if;
  v_hash:=encode(extensions.digest(convert_to(p_payload::text,'utf8'),'sha256'),'hex');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_user_id::text || ':complete:' || p_client_request_id::text, 0
  ));
  select * into v_prior from private.onboarding_v2_requests where user_id=v_user_id and operation='complete' and client_request_id=p_client_request_id for update;
  if v_prior.user_id is not null then
    if v_prior.payload_hash<>v_hash then return jsonb_build_object('ok',false,'code','onboarding_request_payload_mismatch'); end if;
    if v_prior.response is not null then return v_prior.response||jsonb_build_object('replayed',true); end if;
    delete from private.onboarding_v2_requests where user_id=v_user_id and operation='complete' and client_request_id=p_client_request_id;
  end if;
  insert into private.onboarding_v2_requests values(v_user_id,'complete',p_client_request_id,'review',p_payload_version,v_hash,null,now(),null);
  select * into v_profile from public.profiles where id=v_user_id for update;
  if v_profile.onboarding_completed then
    v_progress:=private.evaluate_onboarding_v2(v_user_id)||jsonb_build_object('replayed',true);
    update private.onboarding_v2_requests set response=v_progress,completed_at=now() where user_id=v_user_id and operation='complete' and client_request_id=p_client_request_id;
    return v_progress;
  end if;
  if p_expected_revision is not null and v_profile.updated_at is distinct from p_expected_revision::timestamptz then return jsonb_build_object('ok',false,'code','onboarding_revision_conflict','revision',v_profile.updated_at); end if;
  v_progress:=private.evaluate_onboarding_v2(v_user_id);
  if v_progress->>'active_step'<>'review' then
    return jsonb_build_object('ok',false,'code',case v_progress->>'active_step'
      when 'account' then 'onboarding_account_required'
      when 'work_preferences' then 'onboarding_work_preferences_required'
      else 'onboarding_safety_support_required' end,
      'missing_requirements',v_progress->'missing_requirements');
  end if;
  for v_version in select jsonb_array_elements_text(coalesce(p_payload->'legal_version_ids','[]'::jsonb)) loop
    v_accept:=public.submit_legal_acceptance(
      v_version::uuid,true,coalesce((p_payload->>'teen_summary_viewed')::boolean,false),
      p_payload->>'signature',coalesce(p_payload->>'platform','flutter_native'),
      coalesce(p_payload->>'app_version','unknown'),'en-US'
    );
    if not coalesce((v_accept->>'ok')::boolean,false) then return v_accept; end if;
  end loop;
  v_progress:=private.evaluate_onboarding_v2(v_user_id);
  if 'legal_acceptances'=any(array(select jsonb_array_elements_text(v_progress->'missing_requirements'))) then
    return jsonb_build_object('ok',false,'code','published_legal_acceptance_required');
  end if;
  perform set_config('mort.onboarding_completion','true',true);
  update public.profiles set onboarding_completed=true,updated_at=now() where id=v_user_id;
  perform set_config('mort.onboarding_completion','',true);
  v_progress:=private.evaluate_onboarding_v2(v_user_id)||jsonb_build_object('replayed',false);
  update private.onboarding_v2_requests set response=v_progress,completed_at=now() where user_id=v_user_id and operation='complete' and client_request_id=p_client_request_id;
  return v_progress;
end;
$$;

revoke all on function private.valid_mort_display_name(text) from public, anon, authenticated;
revoke all on function private.enforce_valid_mort_display_name() from public, anon, authenticated;
revoke all on function private.evaluate_onboarding_v2(uuid) from public, anon, authenticated;
revoke all on function public.get_my_onboarding_progress_v2() from public, anon;
revoke all on function public.save_my_onboarding_account_v2(jsonb,uuid,integer) from public, anon;
revoke all on function public.save_my_onboarding_work_v2(jsonb,uuid,integer,text) from public, anon;
revoke all on function public.save_my_onboarding_safety_v2(jsonb,uuid,integer,text) from public, anon;
revoke all on function public.complete_my_onboarding_v2(jsonb,uuid,integer,text) from public, anon;
grant execute on function public.get_my_onboarding_progress_v2() to authenticated, service_role;
grant execute on function public.save_my_onboarding_account_v2(jsonb,uuid,integer) to authenticated, service_role;
grant execute on function public.save_my_onboarding_work_v2(jsonb,uuid,integer,text) to authenticated, service_role;
grant execute on function public.save_my_onboarding_safety_v2(jsonb,uuid,integer,text) to authenticated, service_role;
grant execute on function public.complete_my_onboarding_v2(jsonb,uuid,integer,text) to authenticated, service_role;
