-- Transactional legal clickwrap, immutable job-contract, completion, and
-- nonpayment RPCs. Clients receive no direct write grants to these tables.

create or replace function private.current_age_band(p_dob date)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_dob is null then 'adult_18_plus'
    when extract(year from age(current_date, p_dob)) between 13 and 15 then 'teen_13_15'
    when extract(year from age(current_date, p_dob)) between 16 and 17 then 'teen_16_17'
    else 'adult_18_plus'
  end;
$$;

create or replace function public.get_my_legal_requirements()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with actor as (
    select profile.id, profile.role, private.current_age_band(profile.dob) as age_band
    from public.profiles profile
    where profile.id = auth.uid()
  ), current_versions as (
    select distinct on (version.document_id)
      version.document_id,
      version.id as version_id,
      version.version_label,
      version.content_hash,
      version.effective_at,
      version.language_code,
      version.jurisdiction_policy,
      version.acceptance_ui_version,
      version.requires_electronic_signature
    from public.legal_document_versions version
    where version.publication_status = 'published'
      and version.effective_at <= now()
    order by version.document_id, version.effective_at desc, version.created_at desc
  ), requirements as (
    select
      document.document_key,
      document.title,
      role_requirement.required,
      current_version.*,
      acceptance.id as acceptance_id,
      acceptance.accepted_at,
      reacceptance.id as reacceptance_requirement_id
    from actor
    join public.legal_role_requirements role_requirement
      on role_requirement.role = actor.role
     and role_requirement.age_band in ('all', actor.age_band)
    join public.legal_documents document
      on document.id = role_requirement.document_id
     and document.publication_status = 'published'
    join current_versions current_version
      on current_version.document_id = document.id
    left join public.legal_acceptances acceptance
      on acceptance.user_id = actor.id
     and acceptance.document_version_id = current_version.version_id
     and acceptance.active
    left join public.legal_reacceptance_requirements reacceptance
      on reacceptance.user_id = actor.id
     and reacceptance.required_version_id = current_version.version_id
     and reacceptance.satisfied_at is null
     and reacceptance.waived_at is null
    order by role_requirement.priority, document.document_key
  )
  select jsonb_build_object(
    'ok', auth.uid() is not null,
    'guardian_mode_optional', true,
    'acceptance_inferred_from_browsing', false,
    'requirements', coalesce(jsonb_agg(to_jsonb(requirements)), '[]'::jsonb)
  )
  from requirements;
$$;

create or replace function public.submit_legal_acceptance(
  p_document_version_id uuid,
  p_affirmative_checkbox boolean,
  p_teen_summary_viewed boolean,
  p_electronic_signature_text text,
  p_platform text,
  p_app_version text,
  p_language_code text default 'en-US'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor public.profiles%rowtype;
  v_version public.legal_document_versions%rowtype;
  v_document public.legal_documents%rowtype;
  v_acceptance public.legal_acceptances%rowtype;
  v_age_band text;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not coalesce(p_affirmative_checkbox, false) then
    return jsonb_build_object('ok', false, 'code', 'affirmative_checkbox_required');
  end if;
  if char_length(btrim(coalesce(p_platform, ''))) not between 2 and 40
     or char_length(btrim(coalesce(p_app_version, ''))) not between 1 and 40 then
    return jsonb_build_object('ok', false, 'code', 'platform_and_app_version_required');
  end if;

  select * into v_actor from public.profiles where id = auth.uid() for share;
  if v_actor.id is null or v_actor.role is null then
    return jsonb_build_object('ok', false, 'code', 'completed_profile_required');
  end if;

  select * into v_version
  from public.legal_document_versions
  where id = p_document_version_id
  for share;
  if v_version.id is null
     or v_version.publication_status <> 'published'
     or v_version.effective_at is null
     or v_version.effective_at > now() then
    return jsonb_build_object('ok', false, 'code', 'published_effective_version_required');
  end if;
  select * into v_document from public.legal_documents where id = v_version.document_id;
  if v_document.publication_status <> 'published' then
    return jsonb_build_object('ok', false, 'code', 'published_document_required');
  end if;
  if v_actor.role = 'teen' and not coalesce(p_teen_summary_viewed, false) then
    return jsonb_build_object('ok', false, 'code', 'teen_summary_must_be_viewed_first');
  end if;
  if v_version.requires_electronic_signature
     and char_length(btrim(coalesce(p_electronic_signature_text, ''))) < 3 then
    return jsonb_build_object('ok', false, 'code', 'electronic_signature_text_required');
  end if;

  v_age_band := private.current_age_band(v_actor.dob);
  insert into public.legal_acceptances (
    user_id, role, age_band, document_id, document_version_id,
    content_hash, effective_date, platform, app_version, language_code,
    jurisdiction_policy, acceptance_ui_version, affirmative_checkbox,
    electronic_signature_text
  ) values (
    v_actor.id, v_actor.role, v_age_band, v_document.id, v_version.id,
    v_version.content_hash, v_version.effective_at, left(btrim(p_platform), 40),
    left(btrim(p_app_version), 40), left(btrim(coalesce(p_language_code, 'en-US')), 20),
    v_version.jurisdiction_policy, v_version.acceptance_ui_version, true,
    nullif(left(btrim(coalesce(p_electronic_signature_text, '')), 200), '')
  )
  on conflict (user_id, document_version_id) where active
  do update set server_request_id = public.legal_acceptances.server_request_id
  returning * into v_acceptance;

  insert into public.legal_acceptance_audit_events (
    user_id, document_id, document_version_id, acceptance_id,
    event_type, event_metadata
  ) values (
    v_actor.id, v_document.id, v_version.id, v_acceptance.id,
    'accepted', jsonb_build_object(
      'role', v_actor.role,
      'age_band', v_age_band,
      'platform', left(btrim(p_platform), 40),
      'app_version', left(btrim(p_app_version), 40),
      'affirmative_checkbox', true,
      'teen_summary_viewed', case when v_actor.role = 'teen' then true else null end
    )
  );

  update public.legal_reacceptance_requirements
  set satisfied_by_acceptance_id = v_acceptance.id,
      satisfied_at = now()
  where user_id = v_actor.id
    and required_version_id = v_version.id
    and satisfied_at is null
    and waived_at is null;

  return jsonb_build_object(
    'ok', true,
    'acceptance_id', v_acceptance.id,
    'document_version_id', v_version.id,
    'content_hash', v_version.content_hash,
    'accepted_at', v_acceptance.accepted_at
  );
end;
$$;

create or replace function public.decline_legal_document(
  p_document_version_id uuid,
  p_reason_code text,
  p_platform text,
  p_app_version text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor public.profiles%rowtype;
  v_version public.legal_document_versions%rowtype;
  v_decline public.legal_declines%rowtype;
  v_optional boolean;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_actor from public.profiles where id = auth.uid();
  select * into v_version from public.legal_document_versions where id = p_document_version_id;
  if v_version.id is null or v_version.publication_status <> 'published' then
    return jsonb_build_object('ok', false, 'code', 'published_version_required');
  end if;
  select not coalesce(bool_or(requirement.required), false) into v_optional
  from public.legal_role_requirements requirement
  where requirement.document_id = v_version.document_id
    and requirement.role = v_actor.role
    and requirement.age_band in ('all', private.current_age_band(v_actor.dob));

  insert into public.legal_declines (
    user_id, document_id, document_version_id, role, reason_code,
    optional_document, platform, app_version
  ) values (
    v_actor.id, v_version.document_id, v_version.id, v_actor.role,
    case when lower(p_reason_code) in ('declined', 'needs_help', 'not_now', 'withdrawn') then lower(p_reason_code) else 'declined' end,
    coalesce(v_optional, true), left(btrim(p_platform), 40), left(btrim(p_app_version), 40)
  ) returning * into v_decline;

  insert into public.legal_acceptance_audit_events (
    user_id, document_id, document_version_id, decline_id, event_type, event_metadata
  ) values (
    v_actor.id, v_version.document_id, v_version.id, v_decline.id, 'declined',
    jsonb_build_object('optional_document', v_decline.optional_document, 'reason_code', v_decline.reason_code)
  );
  return jsonb_build_object('ok', true, 'decline_id', v_decline.id, 'optional_document', v_decline.optional_document);
end;
$$;

create or replace function private.queue_legal_reacceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.publication_status = 'published'
     and new.material_revision
     and (tg_op = 'INSERT' or old.publication_status is distinct from new.publication_status) then
    insert into public.legal_reacceptance_requirements (
      user_id, document_id, required_version_id, prior_acceptance_id, reason
    )
    select distinct on (acceptance.user_id)
      acceptance.user_id,
      new.document_id,
      new.id,
      acceptance.id,
      'Material legal document revision requires affirmative reacceptance.'
    from public.legal_acceptances acceptance
    where acceptance.document_id = new.document_id
      and acceptance.document_version_id <> new.id
      and acceptance.active
    order by acceptance.user_id, acceptance.accepted_at desc
    on conflict (user_id, required_version_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists legal_versions_queue_reacceptance on public.legal_document_versions;
create trigger legal_versions_queue_reacceptance
after insert or update of publication_status on public.legal_document_versions
for each row execute function private.queue_legal_reacceptance();

create or replace function private.initial_job_contract_terms(p_application_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'job_id', job.id,
    'application_id', application.id,
    'teen_public_identifier', coalesce(teen.username, 'account-' || left(encode(extensions.digest(teen.id::text, 'sha256'), 'hex'), 12)),
    'adult_public_identifier', coalesce(adult.username, 'account-' || left(encode(extensions.digest(adult.id::text, 'sha256'), 'hex'), 12)),
    'agreed_scope', job.description,
    'excluded_work', to_jsonb(job.excluded_work),
    'location_type', job.location_type,
    'exact_location_release_state', 'accepted_not_released',
    'service_date', coalesce(job.starts_at::date, current_date)::text,
    'start_window', job.starts_at,
    'expected_end_window', job.ends_at,
    'amount_type', case when job.payment_type = 'hourly' then 'hourly' else 'fixed' end,
    'hourly_rate_cents', case when job.payment_type = 'hourly' then coalesce(job.pay_amount_cents, 0) else null end,
    'maximum_approved_hours', case when job.payment_type = 'hourly' then coalesce(job.maximum_approved_hours, greatest(coalesce(job.estimated_duration_minutes, 60)::numeric / 60, 0.25)) else null end,
    'fixed_total_cents', case when job.payment_type = 'hourly' then null else coalesce(job.pay_amount_cents, 0) end,
    'currency_code', 'USD',
    'payment_preference', job.payment_method,
    'payment_due_rule', job.payment_due_rule,
    'authorized_expenses', to_jsonb(job.authorized_expenses),
    'equipment', concat_ws('; ', nullif(job.equipment_provided, ''), nullif(job.equipment_worker_brings, '')),
    'hazards', concat_ws('; ', nullif(job.safety_notes, ''), nullif(job.animal_risk_notes, ''), nullif(job.equipment_risk_notes, '')),
    'expected_people_present', coalesce(job.who_will_be_present, 'Not specified; participant confirmation required before arrival.'),
    'supervision', case when job.adult_supervision_present then 'Adult supervision disclosed as present.' else 'No adult supervision commitment recorded.' end,
    'proof_requirements', case when job.proof_expected then coalesce(job.special_instructions, 'Reasonable, noninvasive completion proof requested.') else 'No media proof required; completion assertion remains available.' end,
    'completion_requirements', coalesce(job.completion_requirements, 'Complete only the accepted scope and submit a truthful completion assertion.'),
    'cancellation_terms', job.cancellation_terms,
    'material_change_process', 'Amount, scope, hours, location, hazards, expenses, or payment timing changes require a versioned request and both parties'' affirmative acceptance.',
    'dispute_process', 'Private evidence review with notice, assigned reviewer, appeal, no public accusation, no automatic legal filing, and no guaranteed recovery.',
    'safety_agreement_version', 'job-safety-v1',
    'guardian_mode_optional', true,
    'classification_status', 'classification_unknown',
    'payment_processed_by_mort', false,
    'escrow_provided_by_mort', false
  )
  from public.applications application
  join public.jobs job on job.id = application.job_id
  join public.profiles teen on teen.id = application.teen_id
  join public.profiles adult on adult.id = job.poster_id
  where application.id = p_application_id;
$$;

create or replace function private.create_job_contract_after_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
  v_contract public.job_contracts%rowtype;
  v_terms jsonb;
  v_hash text;
begin
  if new.status = 'accepted' and old.status is distinct from new.status then
    select * into v_job from public.jobs where id = new.job_id;
    insert into public.job_contracts (job_id, application_id, teen_id, adult_id)
    values (new.job_id, new.id, new.teen_id, v_job.poster_id)
    on conflict (application_id) do update set application_id = excluded.application_id
    returning * into v_contract;

    if not exists (select 1 from public.job_contract_versions where contract_id = v_contract.id) then
      v_terms := private.initial_job_contract_terms(new.id);
      v_hash := encode(extensions.digest(v_terms::text, 'sha256'), 'hex');
      insert into public.job_contract_versions (
        contract_id, version_number, source, teen_public_identifier,
        adult_public_identifier, agreed_scope, excluded_work, location_type,
        exact_location_release_state, service_date, start_window,
        expected_end_window, amount_type, hourly_rate_cents,
        maximum_approved_hours, fixed_total_cents, currency_code,
        payment_preference, payment_due_rule, authorized_expenses,
        equipment, hazards, expected_people_present, supervision,
        proof_requirements, completion_requirements, cancellation_terms,
        material_change_process, dispute_process, safety_agreement_version,
        terms_snapshot, content_hash, created_by
      ) values (
        v_contract.id, 1, 'application_acceptance',
        v_terms->>'teen_public_identifier', v_terms->>'adult_public_identifier',
        v_terms->>'agreed_scope', array(select jsonb_array_elements_text(v_terms->'excluded_work')),
        v_terms->>'location_type', v_terms->>'exact_location_release_state',
        (v_terms->>'service_date')::date, (v_terms->>'start_window')::timestamptz,
        (v_terms->>'expected_end_window')::timestamptz, v_terms->>'amount_type',
        (v_terms->>'hourly_rate_cents')::integer, (v_terms->>'maximum_approved_hours')::numeric,
        (v_terms->>'fixed_total_cents')::integer, v_terms->>'currency_code',
        v_terms->>'payment_preference', v_terms->>'payment_due_rule',
        array(select jsonb_array_elements_text(v_terms->'authorized_expenses')),
        v_terms->>'equipment', v_terms->>'hazards', v_terms->>'expected_people_present',
        v_terms->>'supervision', v_terms->>'proof_requirements',
        v_terms->>'completion_requirements', v_terms->>'cancellation_terms',
        v_terms->>'material_change_process', v_terms->>'dispute_process',
        v_terms->>'safety_agreement_version', v_terms, v_hash, v_job.poster_id
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists applications_create_job_contract on public.applications;
create trigger applications_create_job_contract
after update of status on public.applications
for each row execute function private.create_job_contract_after_acceptance();

create or replace function public.confirm_job_contract_version(
  p_contract_version_id uuid,
  p_affirmative_checkbox boolean,
  p_confirmation_text text,
  p_platform text,
  p_app_version text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contract public.job_contracts%rowtype;
  v_version public.job_contract_versions%rowtype;
  v_role text;
  v_acceptance public.job_contract_acceptances%rowtype;
  v_count integer;
  v_amount integer;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if not coalesce(p_affirmative_checkbox, false) then return jsonb_build_object('ok', false, 'code', 'affirmative_checkbox_required'); end if;
  if char_length(btrim(coalesce(p_confirmation_text, ''))) < 8 then return jsonb_build_object('ok', false, 'code', 'confirmation_text_required'); end if;

  select * into v_version from public.job_contract_versions where id = p_contract_version_id for update;
  select * into v_contract from public.job_contracts where id = v_version.contract_id for update;
  if v_version.id is null or v_version.status <> 'pending_confirmation' then
    return jsonb_build_object('ok', false, 'code', 'pending_contract_version_required');
  end if;
  if auth.uid() = v_contract.teen_id then v_role := 'teen';
  elsif auth.uid() = v_contract.adult_id then v_role := 'adult';
  else return jsonb_build_object('ok', false, 'code', 'contract_party_required');
  end if;

  insert into public.job_contract_acceptances (
    contract_id, contract_version_id, user_id, party_role, content_hash,
    affirmative_checkbox, confirmation_text, platform, app_version
  ) values (
    v_contract.id, v_version.id, auth.uid(), v_role, v_version.content_hash,
    true, left(btrim(p_confirmation_text), 300), left(btrim(p_platform), 40), left(btrim(p_app_version), 40)
  )
  on conflict (contract_version_id, user_id) do nothing
  returning * into v_acceptance;

  if v_acceptance.id is null then
    select * into v_acceptance
    from public.job_contract_acceptances
    where contract_version_id = v_version.id and user_id = auth.uid();
  end if;

  select count(distinct acceptance.party_role) into v_count
  from public.job_contract_acceptances acceptance
  where acceptance.contract_version_id = v_version.id
    and acceptance.content_hash = v_version.content_hash
    and acceptance.affirmative_checkbox;

  if v_count = 2 then
    update public.job_contract_versions
    set status = 'active', activated_at = coalesce(activated_at, now())
    where id = v_version.id;
    update public.job_contracts
    set status = 'active', active_version_id = v_version.id,
        activated_at = coalesce(activated_at, now())
    where id = v_contract.id;

    v_amount := case when v_version.amount_type = 'hourly'
      then round(v_version.hourly_rate_cents * v_version.maximum_approved_hours)::integer
      else v_version.fixed_total_cents end;
    insert into public.job_payment_obligations (
      contract_id, contract_version_id, obligated_poster_id, worker_id,
      amount_cents, currency_code, payment_preference, due_rule
    ) values (
      v_contract.id, v_version.id, v_contract.adult_id, v_contract.teen_id,
      coalesce(v_amount, 0), v_version.currency_code, v_version.payment_preference,
      v_version.payment_due_rule
    ) on conflict (contract_version_id) do nothing;
  end if;

  return jsonb_build_object(
    'ok', true,
    'acceptance_id', v_acceptance.id,
    'party_role', v_role,
    'contract_active', v_count = 2,
    'content_hash', v_version.content_hash
  );
end;
$$;

create or replace function public.request_job_contract_change(
  p_contract_id uuid,
  p_patch jsonb,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contract public.job_contracts%rowtype;
  v_base public.job_contract_versions%rowtype;
  v_proposed jsonb;
  v_categories text[];
  v_request public.job_contract_change_requests%rowtype;
  v_allowed constant text[] := array[
    'agreed_scope', 'excluded_work', 'location_type', 'exact_location_release_state',
    'service_date', 'start_window', 'expected_end_window', 'amount_type',
    'hourly_rate_cents', 'maximum_approved_hours', 'fixed_total_cents',
    'payment_preference', 'payment_due_rule', 'authorized_expenses', 'equipment',
    'hazards', 'expected_people_present', 'supervision', 'proof_requirements',
    'completion_requirements', 'cancellation_terms'
  ];
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if jsonb_typeof(p_patch) <> 'object' or p_patch = '{}'::jsonb then
    return jsonb_build_object('ok', false, 'code', 'nonempty_change_patch_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 8 then
    return jsonb_build_object('ok', false, 'code', 'change_reason_required');
  end if;
  select * into v_contract from public.job_contracts where id = p_contract_id for update;
  if v_contract.id is null or auth.uid() not in (v_contract.teen_id, v_contract.adult_id) then
    return jsonb_build_object('ok', false, 'code', 'contract_party_required');
  end if;
  if v_contract.status not in ('active', 'change_pending') or v_contract.active_version_id is null then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  if exists (
    select 1 from public.job_contract_change_requests request
    where request.contract_id = v_contract.id and request.status = 'pending_both_parties'
  ) then
    return jsonb_build_object('ok', false, 'code', 'pending_change_already_exists');
  end if;
  select array_agg(key order by key) into v_categories from jsonb_object_keys(p_patch) key;
  if exists (select 1 from unnest(v_categories) key where key <> all(v_allowed)) then
    return jsonb_build_object('ok', false, 'code', 'unsupported_or_identity_changing_field');
  end if;
  select * into v_base from public.job_contract_versions where id = v_contract.active_version_id for share;
  v_proposed := v_base.terms_snapshot || p_patch;

  insert into public.job_contract_change_requests (
    contract_id, base_version_id, requested_by, change_categories,
    proposed_terms, proposed_content_hash, reason
  ) values (
    v_contract.id, v_base.id, auth.uid(), v_categories, v_proposed,
    encode(extensions.digest(v_proposed::text, 'sha256'), 'hex'), left(btrim(p_reason), 1000)
  ) returning * into v_request;
  update public.job_contracts set status = 'change_pending' where id = v_contract.id;
  return jsonb_build_object('ok', true, 'change_request_id', v_request.id, 'change_categories', v_categories, 'both_parties_must_accept', true);
end;
$$;

create or replace function private.finalize_job_contract_change(p_change_request_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.job_contract_change_requests%rowtype;
  v_contract public.job_contracts%rowtype;
  v_base public.job_contract_versions%rowtype;
  v_new public.job_contract_versions%rowtype;
  v_terms jsonb;
  v_next integer;
  v_amount integer;
  v_old_obligation public.job_payment_obligations%rowtype;
begin
  select * into v_request from public.job_contract_change_requests where id = p_change_request_id for update;
  select * into v_contract from public.job_contracts where id = v_request.contract_id for update;
  select * into v_base from public.job_contract_versions where id = v_request.base_version_id for update;
  if v_request.status <> 'pending_both_parties' or v_contract.active_version_id <> v_base.id then
    raise exception 'Change request is not finalizable';
  end if;
  if (select count(distinct acceptance.party_role) from public.job_contract_change_acceptances acceptance where acceptance.change_request_id = v_request.id and acceptance.accepted and acceptance.affirmative_checkbox and acceptance.proposed_content_hash = v_request.proposed_content_hash) <> 2 then
    raise exception 'Both contract parties must accept the exact proposed hash';
  end if;
  v_terms := v_request.proposed_terms;
  select coalesce(max(version_number), 0) + 1 into v_next from public.job_contract_versions where contract_id = v_contract.id;

  insert into public.job_contract_versions (
    contract_id, version_number, source, source_change_request_id,
    teen_public_identifier, adult_public_identifier, agreed_scope, excluded_work,
    location_type, exact_location_release_state, service_date, start_window,
    expected_end_window, amount_type, hourly_rate_cents, maximum_approved_hours,
    fixed_total_cents, currency_code, payment_preference, payment_due_rule,
    authorized_expenses, equipment, hazards, expected_people_present,
    supervision, proof_requirements, completion_requirements, cancellation_terms,
    material_change_process, dispute_process, safety_agreement_version,
    terms_snapshot, content_hash, created_by, status, activated_at
  ) values (
    v_contract.id, v_next, 'mutual_change_request', v_request.id,
    v_terms->>'teen_public_identifier', v_terms->>'adult_public_identifier',
    v_terms->>'agreed_scope', array(select jsonb_array_elements_text(v_terms->'excluded_work')),
    v_terms->>'location_type', v_terms->>'exact_location_release_state',
    nullif(v_terms->>'service_date', '')::date,
    nullif(v_terms->>'start_window', '')::timestamptz,
    nullif(v_terms->>'expected_end_window', '')::timestamptz,
    v_terms->>'amount_type', nullif(v_terms->>'hourly_rate_cents', '')::integer,
    nullif(v_terms->>'maximum_approved_hours', '')::numeric,
    nullif(v_terms->>'fixed_total_cents', '')::integer,
    coalesce(v_terms->>'currency_code', 'USD'), v_terms->>'payment_preference',
    v_terms->>'payment_due_rule',
    array(select jsonb_array_elements_text(coalesce(v_terms->'authorized_expenses', '[]'::jsonb))),
    v_terms->>'equipment', v_terms->>'hazards', v_terms->>'expected_people_present',
    v_terms->>'supervision', v_terms->>'proof_requirements',
    v_terms->>'completion_requirements', v_terms->>'cancellation_terms',
    v_terms->>'material_change_process', v_terms->>'dispute_process',
    v_terms->>'safety_agreement_version', v_terms, v_request.proposed_content_hash,
    v_request.requested_by, 'active', now()
  ) returning * into v_new;

  update public.job_contract_versions set status = 'superseded', superseded_at = now() where id = v_base.id;
  update public.job_contracts set active_version_id = v_new.id, status = 'active' where id = v_contract.id;
  update public.job_contract_change_requests set status = 'accepted', resolved_at = now(), created_version_id = v_new.id where id = v_request.id;

  select * into v_old_obligation from public.job_payment_obligations where contract_version_id = v_base.id for update;
  if v_old_obligation.id is not null and v_old_obligation.status not in ('due', 'poster_marked_sent', 'worker_confirmed_received', 'disputed') then
    update public.job_payment_obligations set status = 'superseded' where id = v_old_obligation.id;
    v_amount := case when v_new.amount_type = 'hourly' then round(v_new.hourly_rate_cents * v_new.maximum_approved_hours)::integer else v_new.fixed_total_cents end;
    insert into public.job_payment_obligations (
      contract_id, contract_version_id, obligated_poster_id, worker_id,
      amount_cents, currency_code, payment_preference, due_rule
    ) values (
      v_contract.id, v_new.id, v_contract.adult_id, v_contract.teen_id,
      coalesce(v_amount, 0), v_new.currency_code, v_new.payment_preference, v_new.payment_due_rule
    ) returning id into v_old_obligation.superseded_by_obligation_id;
    update public.job_payment_obligations
    set superseded_by_obligation_id = v_old_obligation.superseded_by_obligation_id
    where id = v_old_obligation.id;
  end if;
  return v_new.id;
end;
$$;

create or replace function public.respond_job_contract_change(
  p_change_request_id uuid,
  p_accept boolean,
  p_affirmative_checkbox boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.job_contract_change_requests%rowtype;
  v_contract public.job_contracts%rowtype;
  v_role text;
  v_new_version uuid;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  select * into v_request from public.job_contract_change_requests where id = p_change_request_id for update;
  select * into v_contract from public.job_contracts where id = v_request.contract_id for update;
  if v_request.id is null or v_request.status <> 'pending_both_parties' then return jsonb_build_object('ok', false, 'code', 'pending_change_required'); end if;
  if auth.uid() = v_contract.teen_id then v_role := 'teen';
  elsif auth.uid() = v_contract.adult_id then v_role := 'adult';
  else return jsonb_build_object('ok', false, 'code', 'contract_party_required'); end if;
  if coalesce(p_accept, false) and not coalesce(p_affirmative_checkbox, false) then return jsonb_build_object('ok', false, 'code', 'affirmative_checkbox_required'); end if;

  insert into public.job_contract_change_acceptances (
    change_request_id, user_id, party_role, accepted,
    proposed_content_hash, affirmative_checkbox
  ) values (
    v_request.id, auth.uid(), v_role, coalesce(p_accept, false),
    v_request.proposed_content_hash, coalesce(p_affirmative_checkbox, false)
  ) on conflict (change_request_id, user_id) do nothing;

  if not coalesce(p_accept, false) then
    update public.job_contract_change_requests set status = 'declined', resolved_at = now() where id = v_request.id;
    update public.job_contracts set status = 'active' where id = v_contract.id;
    return jsonb_build_object('ok', true, 'status', 'declined');
  end if;

  if (select count(distinct party_role) from public.job_contract_change_acceptances where change_request_id = v_request.id and accepted and affirmative_checkbox and proposed_content_hash = v_request.proposed_content_hash) = 2 then
    v_new_version := private.finalize_job_contract_change(v_request.id);
    return jsonb_build_object('ok', true, 'status', 'accepted', 'new_contract_version_id', v_new_version);
  end if;
  return jsonb_build_object('ok', true, 'status', 'awaiting_other_party', 'party_role', v_role);
end;
$$;

create or replace function public.submit_job_completion_assertion(
  p_contract_id uuid,
  p_task_checklist jsonb,
  p_start_timestamp timestamptz,
  p_completion_timestamp timestamptz,
  p_location_type_confirmation text,
  p_approved_scope_confirmation boolean,
  p_witness_notes text default null,
  p_statement text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contract public.job_contracts%rowtype;
  v_assertion public.job_completion_assertions%rowtype;
begin
  select * into v_contract from public.job_contracts where id = p_contract_id for share;
  if v_contract.id is null or auth.uid() <> v_contract.teen_id then return jsonb_build_object('ok', false, 'code', 'worker_contract_party_required'); end if;
  if v_contract.status not in ('active', 'change_pending') or v_contract.active_version_id is null then return jsonb_build_object('ok', false, 'code', 'active_contract_required'); end if;
  if not coalesce(p_approved_scope_confirmation, false) then return jsonb_build_object('ok', false, 'code', 'approved_scope_confirmation_required'); end if;
  if p_completion_timestamp is null or p_completion_timestamp > now() + interval '5 minutes' then return jsonb_build_object('ok', false, 'code', 'valid_completion_timestamp_required'); end if;
  if jsonb_typeof(coalesce(p_task_checklist, '[]'::jsonb)) <> 'array' then return jsonb_build_object('ok', false, 'code', 'task_checklist_array_required'); end if;

  insert into public.job_completion_assertions (
    contract_id, contract_version_id, asserted_by, assertion_role,
    assertion_type, task_checklist, start_timestamp, completion_timestamp,
    location_type_confirmation, approved_scope_confirmation, witness_notes, statement
  ) values (
    v_contract.id, v_contract.active_version_id, auth.uid(), 'teen',
    'worker_completed', coalesce(p_task_checklist, '[]'::jsonb), p_start_timestamp,
    p_completion_timestamp, left(btrim(coalesce(p_location_type_confirmation, '')), 100),
    true, nullif(left(btrim(coalesce(p_witness_notes, '')), 1000), ''),
    nullif(left(btrim(coalesce(p_statement, '')), 2000), '')
  ) returning * into v_assertion;
  return jsonb_build_object('ok', true, 'assertion_id', v_assertion.id, 'adult_acknowledgment_still_required', true);
end;
$$;

create or replace function public.respond_job_completion(
  p_contract_id uuid,
  p_acknowledged boolean,
  p_statement text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contract public.job_contracts%rowtype;
  v_assertion public.job_completion_assertions%rowtype;
  v_obligation public.job_payment_obligations%rowtype;
  v_due_at timestamptz;
begin
  select * into v_contract from public.job_contracts where id = p_contract_id for update;
  if v_contract.id is null or auth.uid() <> v_contract.adult_id then return jsonb_build_object('ok', false, 'code', 'adult_contract_party_required'); end if;
  if not exists (select 1 from public.job_completion_assertions assertion where assertion.contract_id = v_contract.id and assertion.assertion_type = 'worker_completed') then
    return jsonb_build_object('ok', false, 'code', 'worker_completion_assertion_required');
  end if;
  insert into public.job_completion_assertions (
    contract_id, contract_version_id, asserted_by, assertion_role,
    assertion_type, completion_timestamp, approved_scope_confirmation, statement
  ) values (
    v_contract.id, v_contract.active_version_id, auth.uid(), 'adult',
    case when coalesce(p_acknowledged, false) then 'adult_acknowledged' else 'adult_disagreed' end,
    now(), coalesce(p_acknowledged, false), nullif(left(btrim(coalesce(p_statement, '')), 2000), '')
  ) returning * into v_assertion;

  if coalesce(p_acknowledged, false) then
    select * into v_obligation from public.job_payment_obligations where contract_version_id = v_contract.active_version_id for update;
    v_due_at := case v_obligation.due_rule
      when 'at_completion' then now()
      when 'within_24_hours_of_completion' then now() + interval '24 hours'
      else coalesce(v_obligation.due_at, now() + interval '24 hours')
    end;
    update public.job_payment_obligations
    set status = 'due', became_due_at = now(), due_at = v_due_at
    where id = v_obligation.id and status = 'pending_completion';
  end if;
  return jsonb_build_object('ok', true, 'assertion_id', v_assertion.id, 'payment_due', coalesce(p_acknowledged, false), 'mort_processed_payment', false);
end;
$$;

create or replace function public.record_payment_confirmation(
  p_obligation_id uuid,
  p_confirmation_type text,
  p_amount_cents integer,
  p_occurred_at timestamptz,
  p_payment_reference text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_obligation public.job_payment_obligations%rowtype;
  v_contract public.job_contracts%rowtype;
  v_role text;
  v_record public.payment_confirmation_records%rowtype;
begin
  select * into v_obligation from public.job_payment_obligations where id = p_obligation_id for update;
  select * into v_contract from public.job_contracts where id = v_obligation.contract_id for share;
  if auth.uid() = v_contract.adult_id and p_confirmation_type = 'poster_marked_sent' then v_role := 'adult';
  elsif auth.uid() = v_contract.teen_id and p_confirmation_type in ('worker_confirmed_received', 'worker_reports_not_received') then v_role := 'teen';
  else return jsonb_build_object('ok', false, 'code', 'party_confirmation_type_mismatch'); end if;
  if p_amount_cents < 0 or p_amount_cents > v_obligation.amount_cents then return jsonb_build_object('ok', false, 'code', 'invalid_confirmation_amount'); end if;
  if p_occurred_at is null or p_occurred_at > now() + interval '5 minutes' then return jsonb_build_object('ok', false, 'code', 'valid_occurred_at_required'); end if;

  insert into public.payment_confirmation_records (
    obligation_id, confirmed_by, confirmer_role, confirmation_type,
    amount_cents, payment_reference, occurred_at
  ) values (
    v_obligation.id, auth.uid(), v_role, p_confirmation_type, p_amount_cents,
    nullif(left(btrim(coalesce(p_payment_reference, '')), 200), ''), p_occurred_at
  ) on conflict (obligation_id, confirmed_by, confirmation_type) do nothing
  returning * into v_record;

  if p_confirmation_type = 'poster_marked_sent' and v_obligation.status = 'due' then
    update public.job_payment_obligations set status = 'poster_marked_sent' where id = v_obligation.id;
  elsif p_confirmation_type = 'worker_confirmed_received' then
    update public.job_payment_obligations set status = 'worker_confirmed_received', satisfied_at = now() where id = v_obligation.id;
  end if;
  return jsonb_build_object('ok', true, 'confirmation_id', v_record.id, 'payment_received', p_confirmation_type = 'worker_confirmed_received', 'mort_processed_payment', false);
end;
$$;

create or replace function public.report_nonpayment(
  p_obligation_id uuid,
  p_worker_statement text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_obligation public.job_payment_obligations%rowtype;
  v_contract public.job_contracts%rowtype;
  v_dispute public.payment_disputes%rowtype;
begin
  select * into v_obligation from public.job_payment_obligations where id = p_obligation_id for update;
  select * into v_contract from public.job_contracts where id = v_obligation.contract_id for update;
  if auth.uid() is null or auth.uid() <> v_contract.teen_id then return jsonb_build_object('ok', false, 'code', 'worker_contract_party_required'); end if;
  if v_obligation.status = 'worker_confirmed_received' then return jsonb_build_object('ok', false, 'code', 'payment_already_confirmed_received'); end if;
  if v_obligation.status not in ('due', 'poster_marked_sent', 'disputed') or (v_obligation.due_at is not null and v_obligation.due_at > now()) then
    return jsonb_build_object('ok', false, 'code', 'payment_not_yet_reportable');
  end if;
  if char_length(btrim(coalesce(p_worker_statement, ''))) < 10 then return jsonb_build_object('ok', false, 'code', 'worker_statement_required'); end if;

  insert into public.payment_disputes (
    obligation_id, contract_id, opened_by, worker_id, poster_id, worker_statement
  ) values (
    v_obligation.id, v_contract.id, auth.uid(), v_contract.teen_id,
    v_contract.adult_id, left(btrim(p_worker_statement), 4000)
  ) on conflict (obligation_id) do update set obligation_id = excluded.obligation_id
  returning * into v_dispute;

  update public.job_payment_obligations set status = 'disputed', disputed_at = coalesce(disputed_at, now()) where id = v_obligation.id;
  update public.job_contracts set status = 'disputed' where id = v_contract.id;
  insert into public.payment_dispute_timeline (dispute_id, actor_id, event_type, event_summary)
  values (v_dispute.id, auth.uid(), 'reported_nonpayment', 'Worker reported that the off-platform payment has not been received. This is an allegation, not a guilt finding.');
  return jsonb_build_object('ok', true, 'dispute_id', v_dispute.id, 'private', true, 'guilt_determined', false, 'automatic_lawsuit', false, 'recovery_guaranteed', false);
end;
$$;

create or replace function public.submit_payment_dispute_statement(
  p_dispute_id uuid,
  p_statement text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dispute public.payment_disputes%rowtype;
begin
  select * into v_dispute from public.payment_disputes where id = p_dispute_id for update;
  if auth.uid() not in (v_dispute.worker_id, v_dispute.poster_id) then return jsonb_build_object('ok', false, 'code', 'dispute_party_required'); end if;
  if char_length(btrim(coalesce(p_statement, ''))) < 10 then return jsonb_build_object('ok', false, 'code', 'statement_required'); end if;
  if auth.uid() = v_dispute.worker_id then
    update public.payment_disputes set worker_statement = left(btrim(p_statement), 4000), status = 'awaiting_poster' where id = v_dispute.id;
  else
    update public.payment_disputes set poster_statement = left(btrim(p_statement), 4000), status = 'mediation_review' where id = v_dispute.id;
  end if;
  insert into public.payment_dispute_timeline (dispute_id, actor_id, event_type, event_summary)
  values (v_dispute.id, auth.uid(), 'party_statement_submitted', 'A contract party submitted a private statement for review.');
  return jsonb_build_object('ok', true, 'dispute_id', v_dispute.id);
end;
$$;

create or replace function public.admin_assign_payment_dispute_reviewer(
  p_dispute_id uuid,
  p_reviewer_id uuid,
  p_purpose text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.payment_dispute_assignments%rowtype;
begin
  if auth.uid() is null or not public.is_admin() then return jsonb_build_object('ok', false, 'code', 'admin_required'); end if;
  if not private.has_ready_team_role(p_reviewer_id, array['safety_moderator', 'incident_manager', 'super_admin']::text[]) then
    return jsonb_build_object('ok', false, 'code', 'ready_trained_reviewer_required');
  end if;
  if p_reviewer_id in ((select worker_id from public.payment_disputes where id = p_dispute_id), (select poster_id from public.payment_disputes where id = p_dispute_id)) then
    return jsonb_build_object('ok', false, 'code', 'dispute_party_cannot_review');
  end if;
  if p_expires_at <= now() or p_expires_at > now() + interval '30 days' then return jsonb_build_object('ok', false, 'code', 'bounded_assignment_expiry_required'); end if;
  insert into public.payment_dispute_assignments (dispute_id, reviewer_id, assigned_by, purpose, expires_at)
  values (p_dispute_id, p_reviewer_id, auth.uid(), left(btrim(p_purpose), 500), p_expires_at)
  returning * into v_assignment;
  insert into public.team_access_audit_events (user_id, action, target_category, target_id, purpose, access_allowed)
  values (p_reviewer_id, 'assignment_created', 'payment_dispute', p_dispute_id, left(btrim(p_purpose), 500), true);
  return jsonb_build_object('ok', true, 'assignment_id', v_assignment.id);
end;
$$;

create or replace function public.review_payment_dispute(
  p_dispute_id uuid,
  p_decision_type text,
  p_rationale text,
  p_recommended_amount_cents integer default null,
  p_restrict_poster boolean default false,
  p_restriction_type text default 'block_new_job_publication',
  p_restriction_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dispute public.payment_disputes%rowtype;
  v_obligation public.job_payment_obligations%rowtype;
  v_decision public.payment_dispute_decisions%rowtype;
  v_status text;
begin
  select * into v_dispute from public.payment_disputes where id = p_dispute_id for update;
  if not private.is_assigned_payment_dispute_reviewer(v_dispute.id, auth.uid()) then return jsonb_build_object('ok', false, 'code', 'assigned_ready_reviewer_required'); end if;
  select * into v_obligation from public.job_payment_obligations where id = v_dispute.obligation_id;
  if p_decision_type not in ('recommend_payment', 'recommend_partial_payment', 'request_more_evidence', 'no_platform_determination', 'confirm_payment_received') then return jsonb_build_object('ok', false, 'code', 'unsupported_platform_decision'); end if;
  if char_length(btrim(coalesce(p_rationale, ''))) < 20 then return jsonb_build_object('ok', false, 'code', 'substantive_rationale_required'); end if;
  if p_recommended_amount_cents is not null and (p_recommended_amount_cents < 0 or p_recommended_amount_cents > v_obligation.amount_cents) then return jsonb_build_object('ok', false, 'code', 'invalid_recommended_amount'); end if;
  if coalesce(p_restrict_poster, false) and p_decision_type = 'no_platform_determination' then return jsonb_build_object('ok', false, 'code', 'restriction_requires_preliminary_evidence_basis'); end if;

  insert into public.payment_dispute_decisions (
    dispute_id, reviewer_id, decision_type, rationale, recommended_amount_cents
  ) values (
    v_dispute.id, auth.uid(), p_decision_type, left(btrim(p_rationale), 4000), p_recommended_amount_cents
  ) returning * into v_decision;
  v_status := case p_decision_type
    when 'recommend_payment' then 'resolved_payment_recommended'
    when 'recommend_partial_payment' then 'resolved_partial_payment_recommended'
    when 'request_more_evidence' then 'resolved_more_evidence'
    when 'confirm_payment_received' then 'closed_confirmed_paid'
    else 'resolved_no_platform_determination'
  end;
  update public.payment_disputes set status = v_status, closed_at = case when p_decision_type = 'request_more_evidence' then null else now() end where id = v_dispute.id;
  if p_decision_type = 'confirm_payment_received' then
    update public.job_payment_obligations set status = 'worker_confirmed_received', satisfied_at = now() where id = v_obligation.id;
  end if;
  if coalesce(p_restrict_poster, false) then
    if p_restriction_expires_at is null or p_restriction_expires_at <= now() or p_restriction_expires_at > now() + interval '30 days' then return jsonb_build_object('ok', false, 'code', 'bounded_restriction_expiry_required'); end if;
    insert into public.poster_payment_restrictions (
      poster_id, dispute_id, restriction_type, private_reason, imposed_by, expires_at
    ) values (
      v_dispute.poster_id, v_dispute.id, p_restriction_type,
      'Temporary private restriction based on assigned reviewer preliminary evidence assessment; appeal available.',
      auth.uid(), p_restriction_expires_at
    );
  end if;
  insert into public.payment_dispute_timeline (dispute_id, actor_id, event_type, event_summary)
  values (v_dispute.id, auth.uid(), 'platform_review_decision', 'Assigned reviewer recorded a private platform recommendation. This is not a court judgment or criminal finding.');
  return jsonb_build_object('ok', true, 'decision_id', v_decision.id, 'status', v_status, 'court_judgment', false, 'criminal_finding', false, 'appeal_available', true);
end;
$$;

create or replace function public.request_payment_evidence_export(p_dispute_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dispute public.payment_disputes%rowtype;
  v_manifest jsonb;
  v_hash text;
  v_event public.payment_evidence_export_events%rowtype;
begin
  select * into v_dispute from public.payment_disputes where id = p_dispute_id;
  if auth.uid() not in (v_dispute.worker_id, v_dispute.poster_id) then return jsonb_build_object('ok', false, 'code', 'authorized_dispute_party_required'); end if;
  select jsonb_build_object(
    'schema_version', 'payment-evidence-export-v1',
    'generated_at', now(),
    'legal_information_only', true,
    'automatic_lawsuit', false,
    'recovery_guaranteed', false,
    'dispute', jsonb_build_object('id', dispute.id, 'status', dispute.status, 'classification_status', dispute.classification_status, 'guilt_determined', false, 'opened_at', dispute.opened_at),
    'obligation', jsonb_build_object('id', obligation.id, 'amount_cents', obligation.amount_cents, 'currency_code', obligation.currency_code, 'due_rule', obligation.due_rule, 'due_at', obligation.due_at, 'status', obligation.status),
    'contract', jsonb_build_object('id', contract.id, 'job_id', contract.job_id, 'status', contract.status, 'classification_status', contract.classification_status),
    'versions', coalesce((select jsonb_agg(jsonb_build_object('id', version.id, 'version_number', version.version_number, 'content_hash', version.content_hash, 'agreed_scope', version.agreed_scope, 'excluded_work', version.excluded_work, 'amount_type', version.amount_type, 'hourly_rate_cents', version.hourly_rate_cents, 'maximum_approved_hours', version.maximum_approved_hours, 'fixed_total_cents', version.fixed_total_cents, 'payment_due_rule', version.payment_due_rule, 'created_at', version.created_at) order by version.version_number) from public.job_contract_versions version where version.contract_id = contract.id), '[]'::jsonb),
    'party_confirmations', coalesce((select jsonb_agg(jsonb_build_object('party_role', acceptance.party_role, 'content_hash', acceptance.content_hash, 'accepted_at', acceptance.accepted_at) order by acceptance.accepted_at) from public.job_contract_acceptances acceptance where acceptance.contract_id = contract.id), '[]'::jsonb),
    'completion_assertions', coalesce((select jsonb_agg(jsonb_build_object('assertion_role', assertion.assertion_role, 'assertion_type', assertion.assertion_type, 'completion_timestamp', assertion.completion_timestamp, 'approved_scope_confirmation', assertion.approved_scope_confirmation, 'created_at', assertion.created_at) order by assertion.created_at) from public.job_completion_assertions assertion where assertion.contract_id = contract.id), '[]'::jsonb),
    'payment_confirmations', coalesce((select jsonb_agg(jsonb_build_object('confirmer_role', confirmation.confirmer_role, 'confirmation_type', confirmation.confirmation_type, 'amount_cents', confirmation.amount_cents, 'occurred_at', confirmation.occurred_at) order by confirmation.created_at) from public.payment_confirmation_records confirmation where confirmation.obligation_id = obligation.id), '[]'::jsonb),
    'timeline', coalesce((select jsonb_agg(jsonb_build_object('event_type', timeline.event_type, 'event_summary', timeline.event_summary, 'created_at', timeline.created_at) order by timeline.created_at) from public.payment_dispute_timeline timeline where timeline.dispute_id = dispute.id), '[]'::jsonb),
    'decisions', coalesce((select jsonb_agg(jsonb_build_object('decision_type', decision.decision_type, 'rationale', decision.rationale, 'recommended_amount_cents', decision.recommended_amount_cents, 'is_court_judgment', false, 'is_criminal_finding', false, 'appeal_available', decision.appeal_available, 'decided_at', decision.decided_at) order by decision.decided_at) from public.payment_dispute_decisions decision where decision.dispute_id = dispute.id), '[]'::jsonb),
    'excluded_categories', jsonb_build_array('raw_identity_documents', 'document_numbers', 'face_data', 'residential_addresses', 'precise_coordinates', 'unrelated_incidents', 'other_users_private_data', 'secrets')
  ) into v_manifest
  from public.payment_disputes dispute
  join public.job_payment_obligations obligation on obligation.id = dispute.obligation_id
  join public.job_contracts contract on contract.id = dispute.contract_id
  where dispute.id = p_dispute_id;
  v_hash := encode(extensions.digest(v_manifest::text, 'sha256'), 'hex');
  insert into public.payment_evidence_export_events (
    dispute_id, requested_by, authorization_basis, included_record_manifest,
    excluded_categories, manifest_hash
  ) values (
    v_dispute.id, auth.uid(), 'authenticated_contract_party', v_manifest,
    array['raw_identity_documents', 'document_numbers', 'face_data', 'residential_addresses', 'precise_coordinates', 'unrelated_incidents', 'other_users_private_data', 'secrets'],
    v_hash
  ) returning * into v_event;
  return jsonb_build_object('ok', true, 'export_event_id', v_event.id, 'manifest_hash', v_hash, 'export', v_manifest);
end;
$$;

create or replace function private.prevent_restricted_application_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_poster_id uuid;
begin
  if new.status = 'accepted' and old.status is distinct from new.status then
    select job.poster_id into v_poster_id from public.jobs job where job.id = new.job_id;
    if exists (
      select 1 from public.poster_payment_restrictions restriction
      where restriction.poster_id = v_poster_id
        and restriction.restriction_type = 'block_new_application_acceptance'
        and restriction.status = 'active'
        and (restriction.expires_at is null or restriction.expires_at > now())
    ) then
      raise exception using errcode = '42501', message = 'Poster is temporarily restricted from accepting new workers during private payment review.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists applications_enforce_payment_restriction on public.applications;
create trigger applications_enforce_payment_restriction
before update of status on public.applications
for each row execute function private.prevent_restricted_application_acceptance();

revoke all on function private.current_age_band(date) from public, anon;
revoke all on function private.queue_legal_reacceptance() from public, anon, authenticated;
revoke all on function private.initial_job_contract_terms(uuid) from public, anon, authenticated;
revoke all on function private.create_job_contract_after_acceptance() from public, anon, authenticated;
revoke all on function private.finalize_job_contract_change(uuid) from public, anon, authenticated;
revoke all on function private.prevent_restricted_application_acceptance() from public, anon, authenticated;

revoke all on function public.get_my_legal_requirements() from public, anon;
revoke all on function public.submit_legal_acceptance(uuid, boolean, boolean, text, text, text, text) from public, anon;
revoke all on function public.decline_legal_document(uuid, text, text, text) from public, anon;
revoke all on function public.confirm_job_contract_version(uuid, boolean, text, text, text) from public, anon;
revoke all on function public.request_job_contract_change(uuid, jsonb, text) from public, anon;
revoke all on function public.respond_job_contract_change(uuid, boolean, boolean) from public, anon;
revoke all on function public.submit_job_completion_assertion(uuid, jsonb, timestamptz, timestamptz, text, boolean, text, text) from public, anon;
revoke all on function public.respond_job_completion(uuid, boolean, text) from public, anon;
revoke all on function public.record_payment_confirmation(uuid, text, integer, timestamptz, text) from public, anon;
revoke all on function public.report_nonpayment(uuid, text) from public, anon;
revoke all on function public.submit_payment_dispute_statement(uuid, text) from public, anon;
revoke all on function public.admin_assign_payment_dispute_reviewer(uuid, uuid, text, timestamptz) from public, anon;
revoke all on function public.review_payment_dispute(uuid, text, text, integer, boolean, text, timestamptz) from public, anon;
revoke all on function public.request_payment_evidence_export(uuid) from public, anon;

grant execute on function private.current_age_band(date) to authenticated, service_role;
grant execute on function public.get_my_legal_requirements() to authenticated, service_role;
grant execute on function public.submit_legal_acceptance(uuid, boolean, boolean, text, text, text, text) to authenticated, service_role;
grant execute on function public.decline_legal_document(uuid, text, text, text) to authenticated, service_role;
grant execute on function public.confirm_job_contract_version(uuid, boolean, text, text, text) to authenticated, service_role;
grant execute on function public.request_job_contract_change(uuid, jsonb, text) to authenticated, service_role;
grant execute on function public.respond_job_contract_change(uuid, boolean, boolean) to authenticated, service_role;
grant execute on function public.submit_job_completion_assertion(uuid, jsonb, timestamptz, timestamptz, text, boolean, text, text) to authenticated, service_role;
grant execute on function public.respond_job_completion(uuid, boolean, text) to authenticated, service_role;
grant execute on function public.record_payment_confirmation(uuid, text, integer, timestamptz, text) to authenticated, service_role;
grant execute on function public.report_nonpayment(uuid, text) to authenticated, service_role;
grant execute on function public.submit_payment_dispute_statement(uuid, text) to authenticated, service_role;
grant execute on function public.admin_assign_payment_dispute_reviewer(uuid, uuid, text, timestamptz) to authenticated, service_role;
grant execute on function public.review_payment_dispute(uuid, text, text, integer, boolean, text, timestamptz) to authenticated, service_role;
grant execute on function public.request_payment_evidence_export(uuid) to authenticated, service_role;
