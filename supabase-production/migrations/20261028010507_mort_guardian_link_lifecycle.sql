-- Add self-service lifecycle RPCs for guardian links in the current schema.
-- Only the teen who initiated a pending invite can cancel it. Either linked
-- party can end an active link; historical rows remain for auditability.

create or replace function public.cancel_guardian_invite(p_link_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  user_id uuid := auth.uid();
  affected integer;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_link_id is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_link_id_required');
  end if;

  update public.guardian_links
  set status = 'revoked', updated_at = now()
  where id = p_link_id and teen_user_id = user_id and status = 'pending';
  get diagnostics affected = row_count;
  if affected <> 1 then
    return jsonb_build_object('ok', false, 'code', 'pending_guardian_invite_not_found');
  end if;

  update private.guardian_invite_codes
  set consumed_at = coalesce(consumed_at, now())
  where guardian_link_id = p_link_id and consumed_at is null;
  update public.profiles
  set guardian_setup_status = 'not_started', updated_at = now()
  where id = user_id and role = 'teen'::public.mort_role;

  return jsonb_build_object('ok', true, 'link_id', p_link_id, 'status', 'revoked');
end;
$$;
revoke all on function public.cancel_guardian_invite(uuid) from public, anon;
grant execute on function public.cancel_guardian_invite(uuid) to authenticated;

create or replace function public.unlink_guardian(p_link_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  user_id uuid := auth.uid();
  affected integer;
  teen_id uuid;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_link_id is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_link_id_required');
  end if;

  update public.guardian_links
  set status = 'revoked', updated_at = now()
  where id = p_link_id
    and status = 'active'
    and (teen_user_id = user_id or guardian_user_id = user_id)
  returning teen_user_id into teen_id;
  get diagnostics affected = row_count;
  if affected <> 1 then
    return jsonb_build_object('ok', false, 'code', 'active_guardian_link_not_found');
  end if;

  update public.profiles
  set guardian_setup_status = 'not_started', updated_at = now()
  where id = teen_id and role = 'teen'::public.mort_role;

  return jsonb_build_object('ok', true, 'link_id', p_link_id, 'status', 'revoked');
end;
$$;
revoke all on function public.unlink_guardian(uuid) from public, anon;
grant execute on function public.unlink_guardian(uuid) to authenticated;

comment on function public.cancel_guardian_invite(uuid) is
  'Allows only the teen who created a pending guardian invitation to revoke it; consumes its code.';
comment on function public.unlink_guardian(uuid) is
  'Allows either participant to revoke their own active guardian link while preserving the historical row.';

