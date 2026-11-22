-- Review/replica only until separately approved for a hosted target.
-- Preserve pending onboarding, existing evidence review, and abandoned-upload
-- cleanup. Guard both intake paths; a UI flag is not an authorization decision.
begin;

create function private.can_collect_my_verification_evidence()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    join auth.users u on u.id = p.id
    join public.mort_release_control c on c.is_primary
    where p.id = (select auth.uid())
      and u.email_confirmed_at is not null
      and p.account_status in ('pending', 'active')
      and p.date_of_birth is not null
      and private.mort_age_years(p.date_of_birth) >= 13
      and c.real_document_collection
      and not c.maintenance_mode
  )
$$;
revoke all on function private.can_collect_my_verification_evidence() from public, anon;
grant execute on function private.can_collect_my_verification_evidence() to authenticated;

-- Restrictive: any other permissive Storage policy is still subject to this
-- restriction for authenticated verification-evidence writes.
create policy mort_verification_evidence_intake_gate on storage.objects
as restrictive for insert to authenticated
with check (
  bucket_id <> 'verification-evidence'
  or (
    (select private.can_collect_my_verification_evidence())
    and name ~ ('^' || (select auth.uid())::text
      || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|heic|webp|pdf)$')
  )
);

-- Keep the legacy no-evidence start operation but never let a client attach
-- an object directly. The RPC below is the registration boundary.
create policy mort_verification_case_direct_insert_no_evidence on public.verification_cases
as restrictive for insert to authenticated
with check (evidence_path is null);

-- Preserve the recorded definition including patched age-track behavior and
-- the existing grants. Abort rather than rewriting a changed hosted function.
do $patch$
declare
  v_source text := pg_get_functiondef('public.submit_my_verification_evidence_v1(text,text)'::regprocedure);
  v_profile_line constant text := 'select p.date_of_birth into v_dob from public.profiles p where p.id = v_user;';
  v_insert_line constant text := 'insert into public.verification_cases (';
begin
  if position('not (p_verification_type = ''age'' and vc.provider = ''self_reported'')' in v_source) = 0
      or (length(v_source) - length(replace(v_source, v_profile_line, ''))) <> length(v_profile_line)
      or (length(v_source) - length(replace(v_source, v_insert_line, ''))) <> length(v_insert_line) then
    raise exception 'source_drift: submit_my_verification_evidence_v1';
  end if;
  v_source := replace(v_source, v_profile_line, $body$
  -- Serialize duplicate registration and authorization against a committed
  -- account-status update. Storage uses its own per-request policy snapshot.
  select p.date_of_birth into v_dob from public.profiles p where p.id = v_user for update;
  if not private.can_collect_my_verification_evidence() then
    return jsonb_build_object('ok', false, 'code', 'document_collection_unavailable');
  end if;
  $body$);
  v_source := replace(v_source, v_insert_line, $body$
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'verification-evidence' and o.name = p_evidence_path
      and o.owner_id = v_user::text
  ) then
    return jsonb_build_object('ok', false, 'code', 'evidence_document_missing');
  end if;

  insert into public.verification_cases ($body$);
  execute v_source;
end;
$patch$;

commit;
