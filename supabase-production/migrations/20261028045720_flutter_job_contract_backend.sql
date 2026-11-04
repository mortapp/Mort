-- Build the agreement contract on the live job_applications model. The older
-- legal-contract migrations target public.applications and are not compatible
-- with the current production schema.

create table public.job_contracts (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete restrict,
  application_id uuid not null references public.job_applications(id) on delete restrict,
  teen_id uuid not null references public.profiles(id) on delete restrict,
  adult_id uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'pending_confirmation',
  active_version_id uuid,
  classification_status text not null default 'classification_unknown',
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  closed_at timestamptz,
  constraint job_contracts_application_key unique (application_id),
  constraint job_contracts_party_check check (teen_id <> adult_id),
  constraint job_contracts_status_check check (
    status in ('pending_confirmation', 'active', 'change_pending', 'completed', 'disputed', 'cancelled')
  ),
  constraint job_contracts_classification_check check (
    classification_status in ('classification_unknown', 'possible_employee_relationship', 'possible_independent_service_relationship', 'organization_program_role', 'requires_review')
  )
);

create table public.job_contract_versions (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  version_number integer not null,
  source text not null,
  source_change_request_id uuid,
  status text not null default 'pending_confirmation',
  teen_public_identifier text not null,
  adult_public_identifier text not null,
  agreed_scope text not null,
  excluded_work text[] not null default '{}'::text[],
  location_type text not null,
  exact_location_release_state text not null,
  service_date date,
  start_window timestamptz,
  expected_end_window timestamptz,
  amount_type text not null,
  hourly_rate_cents integer,
  maximum_approved_hours numeric(6,2),
  fixed_total_cents integer,
  currency_code text not null default 'USD',
  payment_preference text not null,
  payment_due_rule text not null,
  authorized_expenses text[] not null default '{}'::text[],
  equipment text,
  hazards text,
  expected_people_present text,
  supervision text,
  proof_requirements text,
  completion_requirements text,
  cancellation_terms text not null,
  material_change_process text not null,
  dispute_process text not null,
  safety_agreement_version text not null,
  terms_snapshot jsonb not null,
  content_hash text not null,
  created_by uuid references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  superseded_at timestamptz,
  constraint job_contract_versions_number_key unique (contract_id, version_number),
  constraint job_contract_versions_number_check check (version_number > 0),
  constraint job_contract_versions_source_check check (source in ('application_acceptance', 'mutual_change_request')),
  constraint job_contract_versions_status_check check (status in ('pending_confirmation', 'active', 'superseded', 'cancelled')),
  constraint job_contract_versions_amount_type_check check (amount_type in ('hourly', 'fixed')),
  constraint job_contract_versions_amount_check check (
    (amount_type = 'hourly' and hourly_rate_cents is not null and hourly_rate_cents >= 0 and maximum_approved_hours is not null and maximum_approved_hours > 0 and fixed_total_cents is null)
    or (amount_type = 'fixed' and fixed_total_cents is not null and fixed_total_cents >= 0 and hourly_rate_cents is null and maximum_approved_hours is null)
  ),
  constraint job_contract_versions_hash_check check (content_hash ~ '^[a-f0-9]{64}$')
);

alter table public.job_contracts
  add constraint job_contracts_active_version_fkey
  foreign key (active_version_id) references public.job_contract_versions(id) on delete restrict;

create table public.job_contract_acceptances (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  contract_version_id uuid not null references public.job_contract_versions(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  party_role text not null,
  content_hash text not null,
  affirmative_checkbox boolean not null,
  confirmation_text text not null,
  platform text not null,
  app_version text not null,
  accepted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint job_contract_acceptances_version_user_key unique (contract_version_id, user_id),
  constraint job_contract_acceptances_role_check check (party_role in ('teen', 'adult')),
  constraint job_contract_acceptances_checkbox_check check (affirmative_checkbox),
  constraint job_contract_acceptances_hash_check check (content_hash ~ '^[a-f0-9]{64}$')
);

create table public.job_contract_change_requests (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  base_version_id uuid not null references public.job_contract_versions(id) on delete restrict,
  requested_by uuid not null references public.profiles(id) on delete restrict,
  change_categories text[] not null,
  proposed_terms jsonb not null,
  proposed_content_hash text not null,
  reason text not null,
  status text not null default 'pending_both_parties',
  requested_at timestamptz not null default now(),
  resolved_at timestamptz,
  created_version_id uuid references public.job_contract_versions(id) on delete restrict,
  constraint job_contract_change_requests_categories_check check (cardinality(change_categories) > 0),
  constraint job_contract_change_requests_hash_check check (proposed_content_hash ~ '^[a-f0-9]{64}$'),
  constraint job_contract_change_requests_status_check check (status in ('pending_both_parties', 'accepted', 'declined', 'cancelled'))
);

create table public.job_contract_change_acceptances (
  id uuid primary key default gen_random_uuid(),
  change_request_id uuid not null references public.job_contract_change_requests(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  party_role text not null,
  accepted boolean not null,
  proposed_content_hash text not null,
  affirmative_checkbox boolean not null,
  responded_at timestamptz not null default now(),
  constraint job_contract_change_acceptances_request_user_key unique (change_request_id, user_id),
  constraint job_contract_change_acceptances_role_check check (party_role in ('teen', 'adult')),
  constraint job_contract_change_acceptances_checkbox_check check ((accepted and affirmative_checkbox) or (not accepted and not affirmative_checkbox)),
  constraint job_contract_change_acceptances_hash_check check (proposed_content_hash ~ '^[a-f0-9]{64}$')
);

create index job_contract_versions_contract_order_idx
  on public.job_contract_versions(contract_id, version_number desc);
create index job_contract_acceptances_contract_idx
  on public.job_contract_acceptances(contract_id, accepted_at);
create index job_contract_change_requests_contract_idx
  on public.job_contract_change_requests(contract_id, requested_at desc);
create unique index job_contract_one_pending_change_idx
  on public.job_contract_change_requests(contract_id)
  where status = 'pending_both_parties';

alter table public.job_contracts enable row level security;
alter table public.job_contract_versions enable row level security;
alter table public.job_contract_acceptances enable row level security;
alter table public.job_contract_change_requests enable row level security;
alter table public.job_contract_change_acceptances enable row level security;

grant select on public.job_contracts, public.job_contract_versions,
  public.job_contract_acceptances, public.job_contract_change_requests,
  public.job_contract_change_acceptances to authenticated;
revoke all on public.job_contracts, public.job_contract_versions,
  public.job_contract_acceptances, public.job_contract_change_requests,
  public.job_contract_change_acceptances from public, anon;

create policy job_contract_parties_read
  on public.job_contracts for select to authenticated
  using (auth.uid() = teen_id or auth.uid() = adult_id);

create policy job_contract_versions_parties_read
  on public.job_contract_versions for select to authenticated
  using (exists (
    select 1 from public.job_contracts contract
    where contract.id = contract_id
      and (auth.uid() = contract.teen_id or auth.uid() = contract.adult_id)
  ));

create policy job_contract_acceptances_parties_read
  on public.job_contract_acceptances for select to authenticated
  using (exists (
    select 1 from public.job_contracts contract
    where contract.id = contract_id
      and (auth.uid() = contract.teen_id or auth.uid() = contract.adult_id)
  ));

create policy job_contract_changes_parties_read
  on public.job_contract_change_requests for select to authenticated
  using (exists (
    select 1 from public.job_contracts contract
    where contract.id = contract_id
      and (auth.uid() = contract.teen_id or auth.uid() = contract.adult_id)
  ));

create policy job_contract_change_responses_parties_read
  on public.job_contract_change_acceptances for select to authenticated
  using (exists (
    select 1
    from public.job_contract_change_requests request
    join public.job_contracts contract on contract.id = request.contract_id
    where request.id = change_request_id
      and (auth.uid() = contract.teen_id or auth.uid() = contract.adult_id)
  ));

create or replace function private.create_job_contract_after_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_job public.jobs%rowtype;
  v_teen public.profiles%rowtype;
  v_adult public.profiles%rowtype;
  v_contract_id uuid;
  v_terms jsonb;
  v_amount_cents integer;
  v_amount_type text;
  v_hours numeric(6,2);
  v_excluded_work text[] := array[
    'Work outside the accepted scope',
    'Work prohibited by MORT safety rules'
  ]::text[];
begin
  if new.status <> 'accepted'::public.mort_application_status
     or old.status = 'accepted'::public.mort_application_status then
    return new;
  end if;

  select * into v_job from public.jobs where id = new.job_id;
  select * into v_teen from public.profiles where id = new.applicant_id;
  select * into v_adult from public.profiles where id = v_job.poster_id;
  if v_job.id is null or v_teen.id is null or v_adult.id is null then
    raise exception 'Contract participants are unavailable';
  end if;

  insert into public.job_contracts (job_id, application_id, teen_id, adult_id)
  values (v_job.id, new.id, v_teen.id, v_adult.id)
  on conflict (application_id) do nothing
  returning id into v_contract_id;
  if v_contract_id is null then
    select id into v_contract_id from public.job_contracts where application_id = new.id;
  end if;
  if exists (select 1 from public.job_contract_versions where contract_id = v_contract_id) then
    return new;
  end if;

  v_amount_cents := greatest(0, coalesce(
    v_job.pay_amount_cents,
    round(v_job.pay_amount * 100)::integer,
    0
  ));
  v_amount_type := case when v_job.payment_type = 'hourly' then 'hourly' else 'fixed' end;
  v_hours := greatest(
    0.25,
    coalesce(v_job.estimated_duration_minutes, v_job.estimated_minutes, 60)::numeric / 60
  );
  v_terms := jsonb_build_object(
    'teen_public_identifier', coalesce(nullif(v_teen.username, ''), nullif(v_teen.display_name, ''), 'Teen participant'),
    'adult_public_identifier', coalesce(nullif(v_adult.username, ''), nullif(v_adult.display_name, ''), 'Adult participant'),
    'agreed_scope', v_job.description,
    'excluded_work', to_jsonb(v_excluded_work),
    'location_type', coalesce(nullif(v_job.location_type, ''), 'unspecified'),
    'exact_location_release_state', 'accepted_not_released',
    'service_date', coalesce(v_job.starts_at::date, current_date)::text,
    'start_window', v_job.starts_at,
    'expected_end_window', v_job.ends_at,
    'amount_type', v_amount_type,
    'hourly_rate_cents', case when v_amount_type = 'hourly' then v_amount_cents else null end,
    'maximum_approved_hours', case when v_amount_type = 'hourly' then v_hours else null end,
    'fixed_total_cents', case when v_amount_type = 'fixed' then v_amount_cents else null end,
    'currency_code', 'USD',
    'payment_preference', coalesce(v_job.payment_method, 'flexible'),
    'payment_due_rule', coalesce(v_job.payment_timing, 'after_completion'),
    'authorized_expenses', '[]'::jsonb,
    'equipment', nullif(concat_ws('; ', nullif(v_job.equipment_provided, ''), nullif(v_job.equipment_worker_brings, '')), ''),
    'hazards', nullif(v_job.safety_notes, ''),
    'expected_people_present', 'Not specified; confirm before work begins.',
    'supervision', case when v_job.adult_supervision_present then 'Adult supervision disclosed as present.' else 'No adult supervision commitment recorded.' end,
    'proof_requirements', case when v_job.proof_expected then coalesce(nullif(v_job.special_instructions, ''), 'Reasonable, noninvasive completion proof requested.') else 'No media proof required.' end,
    'completion_requirements', coalesce(nullif(v_job.summary, ''), v_job.description),
    'cancellation_terms', 'Contact the other party in MORT before cancelling or changing the agreed schedule.',
    'material_change_process', 'Changes to scope, pay, hours, location, hazards, expenses, or timing require a new version and both parties’ confirmation.',
    'dispute_process', 'Raise concerns privately through MORT. MORT does not determine legal liability or guarantee recovery.',
    'safety_agreement_version', 'job-safety-v1',
    'payment_processed_by_mort', false,
    'escrow_provided_by_mort', false
  );

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
    v_contract_id, 1, 'application_acceptance',
    v_terms->>'teen_public_identifier', v_terms->>'adult_public_identifier',
    v_terms->>'agreed_scope', v_excluded_work, v_terms->>'location_type',
    v_terms->>'exact_location_release_state', (v_terms->>'service_date')::date,
    (v_terms->>'start_window')::timestamptz, (v_terms->>'expected_end_window')::timestamptz,
    v_amount_type,
    case when v_amount_type = 'hourly' then v_amount_cents else null end,
    case when v_amount_type = 'hourly' then v_hours else null end,
    case when v_amount_type = 'fixed' then v_amount_cents else null end,
    'USD', coalesce(v_job.payment_method, 'flexible'), coalesce(v_job.payment_timing, 'after_completion'),
    '{}'::text[], v_terms->>'equipment', v_terms->>'hazards', v_terms->>'expected_people_present',
    v_terms->>'supervision', v_terms->>'proof_requirements', v_terms->>'completion_requirements',
    v_terms->>'cancellation_terms', v_terms->>'material_change_process',
    v_terms->>'dispute_process', v_terms->>'safety_agreement_version', v_terms,
    encode(extensions.digest(v_terms::text, 'sha256'), 'hex'), v_job.poster_id
  );
  return new;
end;
$function$;

create trigger job_applications_create_contract
after update of status on public.job_applications
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
as $function$
declare
  v_user uuid := auth.uid();
  v_version public.job_contract_versions%rowtype;
  v_contract public.job_contracts%rowtype;
  v_party_role text;
  v_confirmations integer;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not coalesce(p_affirmative_checkbox, false) then
    return jsonb_build_object('ok', false, 'code', 'affirmative_checkbox_required');
  end if;
  if char_length(btrim(coalesce(p_confirmation_text, ''))) < 8 then
    return jsonb_build_object('ok', false, 'code', 'confirmation_text_required');
  end if;
  if char_length(coalesce(p_platform, '')) not between 1 and 40
     or char_length(coalesce(p_app_version, '')) not between 1 and 40 then
    return jsonb_build_object('ok', false, 'code', 'client_context_required');
  end if;

  select * into v_version
  from public.job_contract_versions
  where id = p_contract_version_id
  for update;
  if not found or v_version.status <> 'pending_confirmation'
     or v_version.content_hash <> encode(extensions.digest(v_version.terms_snapshot::text, 'sha256'), 'hex') then
    return jsonb_build_object('ok', false, 'code', 'pending_contract_version_required');
  end if;

  select * into v_contract
  from public.job_contracts
  where id = v_version.contract_id
  for update;
  if v_user = v_contract.teen_id then
    v_party_role := 'teen';
  elsif v_user = v_contract.adult_id then
    v_party_role := 'adult';
  else
    return jsonb_build_object('ok', false, 'code', 'contract_party_required');
  end if;

  insert into public.job_contract_acceptances (
    contract_id, contract_version_id, user_id, party_role, content_hash,
    affirmative_checkbox, confirmation_text, platform, app_version
  ) values (
    v_contract.id, v_version.id, v_user, v_party_role, v_version.content_hash,
    true, left(btrim(p_confirmation_text), 300), left(btrim(p_platform), 40), left(btrim(p_app_version), 40)
  ) on conflict (contract_version_id, user_id) do nothing;

  select count(distinct user_id)::integer into v_confirmations
  from public.job_contract_acceptances
  where contract_version_id = v_version.id
    and content_hash = v_version.content_hash
    and user_id in (v_contract.teen_id, v_contract.adult_id);

  if v_confirmations = 2 then
    update public.job_contract_versions
    set status = 'superseded', superseded_at = now()
    where id = v_contract.active_version_id
      and id <> v_version.id
      and status = 'active';
    update public.job_contract_versions
    set status = 'active', activated_at = coalesce(activated_at, now())
    where id = v_version.id;
    update public.job_contracts
    set status = 'active', active_version_id = v_version.id,
        activated_at = coalesce(activated_at, now())
    where id = v_contract.id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'code', case when v_confirmations = 2 then 'contract_active' else 'confirmation_recorded' end,
    'confirmations', v_confirmations,
    'required_confirmations', 2
  );
end;
$function$;

create or replace function public.request_job_contract_change(
  p_contract_id uuid,
  p_patch jsonb,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_contract public.job_contracts%rowtype;
  v_base public.job_contract_versions%rowtype;
  v_terms jsonb;
  v_categories text[] := '{}'::text[];
  v_change_id uuid;
  v_role text;
begin
  if v_user is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if jsonb_typeof(p_patch) <> 'object' or p_patch = '{}'::jsonb then
    return jsonb_build_object('ok', false, 'code', 'change_terms_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 8 and 1000 then
    return jsonb_build_object('ok', false, 'code', 'change_reason_required');
  end if;
  if exists (
    select 1 from jsonb_object_keys(p_patch) as key_name
    where key_name not in ('agreed_scope', 'amount_type', 'fixed_total_cents', 'hourly_rate_cents', 'maximum_approved_hours')
  ) then
    return jsonb_build_object('ok', false, 'code', 'unsupported_material_change');
  end if;

  select * into v_contract from public.job_contracts where id = p_contract_id for update;
  if not found or v_contract.status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  if v_user = v_contract.teen_id then v_role := 'teen';
  elsif v_user = v_contract.adult_id then v_role := 'adult';
  else return jsonb_build_object('ok', false, 'code', 'contract_party_required'); end if;
  select * into v_base from public.job_contract_versions where id = v_contract.active_version_id;
  if not found then return jsonb_build_object('ok', false, 'code', 'active_contract_version_missing'); end if;

  v_terms := v_base.terms_snapshot || p_patch;
  if p_patch ? 'agreed_scope' then
    if jsonb_typeof(p_patch->'agreed_scope') <> 'string'
       or char_length(btrim(v_terms->>'agreed_scope')) not between 1 and 4000 then
      return jsonb_build_object('ok', false, 'code', 'invalid_agreed_scope');
    end if;
    v_categories := array_append(v_categories, 'scope');
  end if;
  if p_patch ?| array['amount_type', 'fixed_total_cents', 'hourly_rate_cents', 'maximum_approved_hours'] then
    if v_terms->>'amount_type' = 'fixed' then
      if coalesce(v_terms->>'fixed_total_cents', '') !~ '^[0-9]{1,9}$'
         or (v_terms->>'fixed_total_cents')::bigint > 50000000 then
        return jsonb_build_object('ok', false, 'code', 'invalid_fixed_total');
      end if;
      v_terms := jsonb_set(v_terms - 'hourly_rate_cents' - 'maximum_approved_hours', '{fixed_total_cents}', to_jsonb((v_terms->>'fixed_total_cents')::integer), true);
    elsif v_terms->>'amount_type' = 'hourly' then
      if coalesce(v_terms->>'hourly_rate_cents', '') !~ '^[0-9]{1,9}$'
         or coalesce(v_terms->>'maximum_approved_hours', '') !~ '^[0-9]{1,3}(\.[0-9]{1,2})?$'
         or (v_terms->>'hourly_rate_cents')::bigint > 50000000
         or (v_terms->>'maximum_approved_hours')::numeric <= 0
         or (v_terms->>'maximum_approved_hours')::numeric > 1000 then
        return jsonb_build_object('ok', false, 'code', 'invalid_hourly_terms');
      end if;
      v_terms := jsonb_set(v_terms - 'fixed_total_cents', '{hourly_rate_cents}', to_jsonb((v_terms->>'hourly_rate_cents')::integer), true);
      v_terms := jsonb_set(v_terms, '{maximum_approved_hours}', to_jsonb((v_terms->>'maximum_approved_hours')::numeric), true);
    else
      return jsonb_build_object('ok', false, 'code', 'invalid_amount_type');
    end if;
    v_categories := array_append(v_categories, 'compensation');
  end if;
  if cardinality(v_categories) = 0 then
    return jsonb_build_object('ok', false, 'code', 'supported_change_required');
  end if;

  insert into public.job_contract_change_requests (
    contract_id, base_version_id, requested_by, change_categories,
    proposed_terms, proposed_content_hash, reason
  ) values (
    v_contract.id, v_base.id, v_user, v_categories, v_terms,
    encode(extensions.digest(v_terms::text, 'sha256'), 'hex'), left(btrim(p_reason), 1000)
  ) returning id into v_change_id;
  insert into public.job_contract_change_acceptances (
    change_request_id, user_id, party_role, accepted,
    proposed_content_hash, affirmative_checkbox
  ) values (
    v_change_id, v_user, v_role, true,
    encode(extensions.digest(v_terms::text, 'sha256'), 'hex'), true
  );
  update public.job_contracts set status = 'change_pending' where id = v_contract.id;
  return jsonb_build_object('ok', true, 'change_request_id', v_change_id, 'status', 'pending_both_parties');
exception when unique_violation then
  return jsonb_build_object('ok', false, 'code', 'change_already_pending');
end;
$function$;

create or replace function public.respond_job_contract_change(
  p_change_request_id uuid,
  p_accept boolean,
  p_affirmative_checkbox boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_change public.job_contract_change_requests%rowtype;
  v_contract public.job_contracts%rowtype;
  v_base public.job_contract_versions%rowtype;
  v_role text;
  v_acceptances integer;
  v_new_version_id uuid;
  v_terms jsonb;
begin
  if v_user is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if coalesce(p_accept, false) and not coalesce(p_affirmative_checkbox, false) then
    return jsonb_build_object('ok', false, 'code', 'affirmative_checkbox_required');
  end if;
  select * into v_change from public.job_contract_change_requests where id = p_change_request_id for update;
  if not found or v_change.status <> 'pending_both_parties' then
    return jsonb_build_object('ok', false, 'code', 'pending_change_required');
  end if;
  select * into v_contract from public.job_contracts where id = v_change.contract_id for update;
  if v_user = v_contract.teen_id then v_role := 'teen';
  elsif v_user = v_contract.adult_id then v_role := 'adult';
  else return jsonb_build_object('ok', false, 'code', 'contract_party_required'); end if;
  if v_user = v_change.requested_by then
    return jsonb_build_object('ok', false, 'code', 'other_party_response_required');
  end if;
  if exists (select 1 from public.job_contract_change_acceptances where change_request_id = v_change.id and user_id = v_user) then
    return jsonb_build_object('ok', false, 'code', 'change_already_answered');
  end if;
  insert into public.job_contract_change_acceptances (
    change_request_id, user_id, party_role, accepted,
    proposed_content_hash, affirmative_checkbox
  ) values (
    v_change.id, v_user, v_role, coalesce(p_accept, false),
    v_change.proposed_content_hash, coalesce(p_affirmative_checkbox, false)
  );
  if not coalesce(p_accept, false) then
    update public.job_contract_change_requests set status = 'declined', resolved_at = now() where id = v_change.id;
    update public.job_contracts set status = 'active' where id = v_contract.id;
    return jsonb_build_object('ok', true, 'status', 'declined');
  end if;

  select count(*)::integer into v_acceptances
  from public.job_contract_change_acceptances
  where change_request_id = v_change.id
    and accepted and affirmative_checkbox
    and proposed_content_hash = v_change.proposed_content_hash;
  if v_acceptances < 2 then
    return jsonb_build_object('ok', true, 'status', 'pending_both_parties');
  end if;

  select * into v_base from public.job_contract_versions where id = v_change.base_version_id for update;
  v_terms := v_change.proposed_terms;
  insert into public.job_contract_versions (
    contract_id, version_number, source, source_change_request_id, status,
    teen_public_identifier, adult_public_identifier, agreed_scope, excluded_work,
    location_type, exact_location_release_state, service_date, start_window,
    expected_end_window, amount_type, hourly_rate_cents, maximum_approved_hours,
    fixed_total_cents, currency_code, payment_preference, payment_due_rule,
    authorized_expenses, equipment, hazards, expected_people_present, supervision,
    proof_requirements, completion_requirements, cancellation_terms,
    material_change_process, dispute_process, safety_agreement_version,
    terms_snapshot, content_hash, created_by
  ) values (
    v_contract.id, v_base.version_number + 1, 'mutual_change_request', v_change.id,
    'pending_confirmation', v_terms->>'teen_public_identifier', v_terms->>'adult_public_identifier',
    v_terms->>'agreed_scope', array(select jsonb_array_elements_text(v_terms->'excluded_work')),
    v_terms->>'location_type', v_terms->>'exact_location_release_state',
    nullif(v_terms->>'service_date', '')::date, nullif(v_terms->>'start_window', '')::timestamptz,
    nullif(v_terms->>'expected_end_window', '')::timestamptz, v_terms->>'amount_type',
    nullif(v_terms->>'hourly_rate_cents', '')::integer,
    nullif(v_terms->>'maximum_approved_hours', '')::numeric,
    nullif(v_terms->>'fixed_total_cents', '')::integer, coalesce(v_terms->>'currency_code', 'USD'),
    v_terms->>'payment_preference', v_terms->>'payment_due_rule',
    array(select jsonb_array_elements_text(v_terms->'authorized_expenses')),
    v_terms->>'equipment', v_terms->>'hazards', v_terms->>'expected_people_present',
    v_terms->>'supervision', v_terms->>'proof_requirements', v_terms->>'completion_requirements',
    v_terms->>'cancellation_terms', v_terms->>'material_change_process',
    v_terms->>'dispute_process', v_terms->>'safety_agreement_version', v_terms,
    v_change.proposed_content_hash, v_user
  ) returning id into v_new_version_id;
  update public.job_contract_change_requests
  set status = 'accepted', resolved_at = now(), created_version_id = v_new_version_id
  where id = v_change.id;
  return jsonb_build_object('ok', true, 'status', 'accepted', 'contract_version_id', v_new_version_id);
exception when unique_violation then
  return jsonb_build_object('ok', false, 'code', 'contract_change_conflict');
end;
$function$;

revoke all on function public.confirm_job_contract_version(uuid, boolean, text, text, text) from public, anon;
grant execute on function public.confirm_job_contract_version(uuid, boolean, text, text, text) to authenticated;
revoke all on function public.request_job_contract_change(uuid, jsonb, text) from public, anon;
grant execute on function public.request_job_contract_change(uuid, jsonb, text) to authenticated;
revoke all on function public.respond_job_contract_change(uuid, boolean, boolean) from public, anon;
grant execute on function public.respond_job_contract_change(uuid, boolean, boolean) to authenticated;
revoke all on function private.create_job_contract_after_acceptance() from public, anon, authenticated;

comment on table public.job_contracts is 'Private-to-participants agreement envelope for a MORT job application.';
comment on table public.job_contract_versions is 'Immutable terms snapshots. A version becomes active only after both contract parties confirm its matching content hash.';
comment on function public.confirm_job_contract_version(uuid, boolean, text, text, text) is 'Records a party confirmation of the exact immutable contract version; activates only after both parties confirm.';

