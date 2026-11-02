-- PROPOSAL ONLY — do not place in supabase-production/migrations or apply to production.
-- Fail-closed provider evidence gate for staff verification decisions.
-- No provider is seeded/enabled; verified decisions remain unavailable until an
-- approved provider and signed webhook integration are reviewed and deployed.
begin;
do $guard$
begin
  if md5(pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamp with time zone)'::regprocedure))
     <> '9de9e53ea3e300b78819932eabc14594' then
    raise exception 'proposal_source_mismatch:mort_review_verification_case';
  end if;
end;
$guard$;

create table if not exists private.verification_provider_allowlist (
  provider_key text not null,
  verification_type text not null
    check (verification_type in ('age','identity','guardian_consent','school_email','school_id','business')),
  is_enabled boolean not null default false,
  created_at timestamptz not null default clock_timestamp(),
  primary key (provider_key, verification_type),
  check (provider_key = btrim(provider_key) and char_length(provider_key) between 1 and 100)
);
alter table private.verification_provider_allowlist enable row level security;
revoke all on private.verification_provider_allowlist from public, anon, authenticated, service_role;
grant select on private.verification_provider_allowlist to service_role;
comment on table private.verification_provider_allowlist is
  'Proposal: explicitly approved verification providers by case type; intentionally empty until provider/legal/security approval.';

create table if not exists private.verification_provider_results (
  id uuid primary key default extensions.gen_random_uuid(),
  verification_case_id uuid not null references public.verification_cases(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  verification_type text not null
    check (verification_type in ('age','identity','guardian_consent','school_email','school_id','business')),
  provider_key text not null,
  provider_reference text not null,
  provider_event_id text not null,
  result text not null check (result in ('verified','rejected','needs_review')),
  evidence_sha256 text not null check (evidence_sha256 ~ '^[0-9a-f]{64}$'),
  verified_at timestamptz,
  expires_at timestamptz,
  received_at timestamptz not null default clock_timestamp(),
  unique (provider_key, provider_event_id),
  unique (verification_case_id, provider_key, provider_reference, provider_event_id),
  check (provider_event_id = btrim(provider_event_id) and char_length(provider_event_id) between 1 and 200),
  check ((result = 'verified' and verified_at is not null) or result <> 'verified'),
  check (expires_at is null or verified_at is null or expires_at > verified_at)
);
create index if not exists verification_provider_results_case_current_idx
  on private.verification_provider_results
    (verification_case_id, provider_key, verification_type, received_at desc);
alter table private.verification_provider_results enable row level security;
revoke all on private.verification_provider_results from public, anon, authenticated, service_role;
grant select, insert on private.verification_provider_results to service_role;
comment on table private.verification_provider_results is
  'Proposal: immutable provider result metadata only; store no document or raw provider payload. Insert only after provider signature/event verification in a trusted server function.';

CREATE OR REPLACE FUNCTION public.mort_review_verification_case(p_case_id uuid, p_status mort_verification_status, p_note text DEFAULT NULL::text, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user uuid := auth.uid();
  v_case public.verification_cases%rowtype;
  v_date_of_birth date;
  v_now timestamptz;
  v_evidence_expires_at timestamptz;
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    raise exception 'Authorized verification reviewer required';
  end if;
  if p_status not in ('verified'::public.mort_verification_status,
                      'rejected'::public.mort_verification_status,
                      'needs_review'::public.mort_verification_status,
                      'expired'::public.mort_verification_status) then
    raise exception 'Invalid review outcome';
  end if;

  select * into v_case
  from public.verification_cases verification
  where verification.id = p_case_id
  for update;
  if not found then raise exception 'Verification case not found'; end if;

  select profile.date_of_birth into v_date_of_birth
  from public.profiles profile
  where profile.id = v_case.user_id
  for share;
  if not found then raise exception 'Verification subject not found'; end if;
  v_now := clock_timestamp();

  if p_status = 'verified'::public.mort_verification_status then
    if v_date_of_birth is null
       or extract(year from age(v_now::date, v_date_of_birth)) < 13 then
      raise exception 'minimum_age_verification_required';
    end if;

    perform provider.provider_key
    from private.verification_provider_allowlist provider
    where provider.provider_key = v_case.provider
      and provider.verification_type = v_case.verification_type
      and provider.is_enabled
    for share;
    if not found then
      raise exception 'trusted_verification_provider_unavailable';
    end if;

    select result.expires_at into v_evidence_expires_at
    from private.verification_provider_results result
    where result.verification_case_id = v_case.id
      and result.user_id = v_case.user_id
      and result.verification_type = v_case.verification_type
      and result.provider_key = v_case.provider
      and result.provider_reference = v_case.provider_reference
      and result.result = 'verified'
      and result.verified_at <= v_now
      and result.received_at <= v_now
      and (result.expires_at is null or result.expires_at > v_now)
    order by result.received_at desc
    limit 1
    for share;
    if not found then
      raise exception 'case_appropriate_provider_evidence_required';
    end if;
    if v_evidence_expires_at is not null
       and (p_expires_at is null or p_expires_at > v_evidence_expires_at) then
      raise exception 'review_expiry_exceeds_provider_evidence';
    end if;
  end if;

  update public.verification_cases
  set status=p_status, reviewer_id=v_user,
      reviewer_note=nullif(btrim(p_note),''),
      reviewed_at=v_now, expires_at=p_expires_at, updated_at=v_now
  where id=v_case.id;
  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values (v_user,'verification_reviewed','verification_case',p_case_id::text,
          nullif(btrim(p_note),''),jsonb_build_object('status',p_status));
  return p_case_id;
end;
$function$;

commit;

