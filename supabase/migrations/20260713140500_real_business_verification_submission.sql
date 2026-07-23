drop policy if exists business_verifications_insert_adult
on public.business_verifications;
create policy business_verifications_insert_admin_only
on public.business_verifications for insert to authenticated
with check (public.is_admin());

create policy storage_verification_delete_unattached_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'verification-uploads'
  and (storage.foldername(name))[1] = auth.uid()::text
  and not exists (
    select 1
    from public.business_verifications verification
    where verification.document_storage_path = storage.objects.name
  )
);

create or replace function public.submit_business_verification(
  p_verification_id uuid,
  p_storage_path text,
  p_business_name text,
  p_business_type text,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile public.profiles%rowtype;
  v_verification public.business_verifications%rowtype;
  v_path text := btrim(coalesce(p_storage_path, ''));
  v_name text := btrim(coalesce(p_business_name, ''));
  v_type text := lower(btrim(coalesce(p_business_type, '')));
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_verification_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_verification_submission');
  end if;
  if v_path <> (auth.uid()::text || '/' || p_verification_id::text || '.jpg')
     or position('..' in v_path) > 0 then
    return jsonb_build_object('ok', false, 'code', 'invalid_verification_path');
  end if;

  select * into v_verification
  from public.business_verifications
  where id = p_verification_id;
  if v_verification.id is not null then
    if v_verification.adult_id <> auth.uid()
       or v_verification.document_storage_path <> v_path then
      return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
    end if;
    return jsonb_build_object(
      'ok', true,
      'idempotent', true,
      'verification', to_jsonb(v_verification)
    );
  end if;

  select * into v_profile
  from public.profiles
  where id = auth.uid()
  for update;
  if v_profile.role <> 'adult' or v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;
  if char_length(v_name) not between 2 and 120
     or v_type not in (
       'individual',
       'sole_proprietor',
       'business',
       'nonprofit',
       'community_organization'
     )
     or char_length(coalesce(p_notes, '')) > 1000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_verification_details');
  end if;
  if exists (
    select 1
    from public.business_verifications
    where adult_id = auth.uid()
      and status = 'pending'
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_already_pending');
  end if;
  if not exists (
    select 1
    from storage.objects object
    where object.bucket_id = 'verification-uploads'
      and object.name = v_path
      and object.owner_id = auth.uid()::text
  ) then
    return jsonb_build_object('ok', false, 'code', 'verification_object_not_found');
  end if;

  insert into public.business_verifications (
    id,
    adult_id,
    business_name,
    business_type,
    document_storage_path,
    notes,
    status
  ) values (
    p_verification_id,
    auth.uid(),
    v_name,
    v_type,
    v_path,
    nullif(btrim(coalesce(p_notes, '')), ''),
    'pending'
  ) returning * into v_verification;

  return jsonb_build_object(
    'ok', true,
    'idempotent', false,
    'verification', to_jsonb(v_verification)
  );
end;
$$;

revoke execute on function public.submit_business_verification(uuid, text, text, text, text)
from public, anon;
grant execute on function public.submit_business_verification(uuid, text, text, text, text)
to authenticated, service_role;
