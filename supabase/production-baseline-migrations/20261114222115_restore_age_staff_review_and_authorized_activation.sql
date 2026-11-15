-- Repair the production-baseline staff-review/activation contract.
-- Age evidence is reviewed by the same internal staff provider as identity and
-- school-ID evidence. Activation remains gated by a pending role request and
-- mort_review_role_request's verification checks.
begin;

insert into private.verification_provider_allowlist
  (provider_key, verification_type, is_enabled)
values
  ('mort_staff_review', 'age', true),
  ('mort_staff_review', 'school_id', true),
  ('mort_staff_review', 'identity', true)
on conflict (provider_key, verification_type)
do update set is_enabled = excluded.is_enabled;

create or replace function public.admin_set_account_status_v2(
  p_user_id uuid,
  p_status text,
  p_reason_code text,
  p_reason text,
  p_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_request public.role_requests%rowtype;
begin
  if v_actor is null or not private.has_staff_role(array['admin']::public.mort_role[]) then
    return jsonb_build_object('ok', false, 'code', 'administrator_required');
  end if;
  if p_user_id is null or p_status not in ('active', 'suspended')
     or nullif(btrim(coalesce(p_reason, '')), '') is null
     or nullif(btrim(coalesce(p_reason_code, '')), '') is null then
    return jsonb_build_object('ok', false, 'code', 'account_status_request_invalid');
  end if;
  if p_expires_at is not null and p_expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'expiration_must_be_in_future');
  end if;

  select * into v_profile
  from public.profiles
  where id = p_user_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;

  if p_status = 'active' then
    if v_profile.account_status = 'active' then
      return jsonb_build_object('ok', true, 'code', 'already_active');
    end if;
    select * into v_request
    from public.role_requests
    where user_id = p_user_id
      and requested_role = v_profile.role
      and status = 'pending'
    order by submitted_at desc
    limit 1
    for update;
    if not found then
      return jsonb_build_object('ok', false, 'code', 'activation_request_required');
    end if;
    begin
      perform public.mort_review_role_request(v_request.id, true, p_reason);
    exception when others then
      return jsonb_build_object('ok', false, 'code', 'activation_review_failed');
    end;
    return jsonb_build_object('ok', true, 'code', 'activation_approved', 'request_id', v_request.id);
  end if;

  update public.profiles
  set account_status = 'suspended', updated_at = now()
  where id = p_user_id;
  insert into public.admin_audit_log(actor_id, action, target_type, target_id, reason, metadata)
  values (
    v_actor, 'account_status_changed', 'profile', p_user_id::text,
    btrim(p_reason),
    jsonb_build_object('status', p_status, 'reason_code', p_reason_code, 'expires_at', p_expires_at)
  );
  return jsonb_build_object('ok', true, 'status', 'suspended');
end;
$function$;

revoke all on function public.admin_set_account_status_v2(uuid,text,text,text,timestamptz)
  from public, anon;
grant execute on function public.admin_set_account_status_v2(uuid,text,text,text,timestamptz)
  to authenticated, service_role;

commit;
