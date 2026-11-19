-- Exact statements from production ledger version 20261115005137
-- Permit cleanup of a user's just-uploaded verification object only when no
-- verification case has registered that exact path. Registered evidence stays immutable.
BEGIN;

create or replace function public.can_delete_my_unregistered_verification_evidence_v1(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null or p_name is null then
    return false;
  end if;
  if p_name !~ ('^' || v_user::text || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|heic|webp|pdf)$') then
    return false;
  end if;
  return not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_user and vc.evidence_path = p_name
  );
end;
$function$;

revoke all on function public.can_delete_my_unregistered_verification_evidence_v1(text) from public, anon;
grant execute on function public.can_delete_my_unregistered_verification_evidence_v1(text) to authenticated, service_role;

drop policy if exists mort_verification_evidence_delete_unregistered_own on storage.objects;
create policy mort_verification_evidence_delete_unregistered_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'verification-evidence'
  and public.can_delete_my_unregistered_verification_evidence_v1(name)
);

COMMIT;
