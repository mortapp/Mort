-- Final closed-test controls and scoped partner staff workflows.
-- This migration is additive. It keeps the active marketplace closed, keeps
-- real document collection disabled, and only prepares an inactive pilot mode.

alter table private.pilot_policy_versions
  add column if not exists release_mode text not null default 'closed_test',
  add column if not exists marketplace_mode text not null default 'closed_pilot',
  add column if not exists identity_verification_mode text not null default 'disabled',
  add column if not exists live_ads boolean not null default false,
  add column if not exists live_billing boolean not null default false,
  add column if not exists remote_push boolean not null default false;

alter table private.pilot_policy_versions
  drop constraint if exists pilot_policy_release_mode_check,
  drop constraint if exists pilot_policy_marketplace_mode_check,
  drop constraint if exists pilot_policy_identity_mode_check,
  drop constraint if exists pilot_policy_disabled_services_check,
  drop constraint if exists pilot_policy_public_activation_check;

alter table private.pilot_policy_versions
  add constraint pilot_policy_release_mode_check check (
    release_mode in (
      'development', 'internal_test', 'closed_test',
      'production_pilot', 'production_public'
    )
  ),
  add constraint pilot_policy_marketplace_mode_check
    check (marketplace_mode = 'closed_pilot'),
  add constraint pilot_policy_identity_mode_check
    check (identity_verification_mode = 'disabled'),
  add constraint pilot_policy_disabled_services_check
    check (not live_ads and not live_billing and not remote_push),
  add constraint pilot_policy_public_activation_check
    check (not is_active or release_mode <> 'production_public');

insert into private.pilot_policy_versions (
  version, policy_name, is_active, pilot_mode_enabled,
  unrestricted_public_access_enabled, real_document_collection_enabled,
  require_partner_supported_entry, require_manual_adult_approval,
  guardian_mode_optional, release_mode, marketplace_mode,
  identity_verification_mode, live_ads, live_billing, remote_push
)
select
  2, 'prepared-production-pilot-inactive', false, true,
  false, false, true, true, true, 'production_pilot', 'closed_pilot',
  'disabled', false, false, false
where not exists (
  select 1
  from private.pilot_policy_versions policy
  where policy.version = 2
);

create or replace function public.get_release_mode_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_policy private.pilot_policy_versions%rowtype;
begin
  select * into v_policy from private.current_pilot_policy();
  if v_policy.id is null then
    return jsonb_build_object(
      'ok', false,
      'code', 'release_policy_unavailable',
      'release_mode', 'closed_test',
      'marketplace_mode', 'closed_pilot',
      'public_marketplace_enabled', false,
      'real_document_collection', false,
      'live_ads', false,
      'live_billing', false,
      'remote_push', false
    );
  end if;
  return jsonb_build_object(
    'ok', true,
    'policy_version', v_policy.version,
    'release_mode', v_policy.release_mode,
    'marketplace_mode', v_policy.marketplace_mode,
    'identity_verification_mode', v_policy.identity_verification_mode,
    'public_marketplace_enabled', v_policy.unrestricted_public_access_enabled,
    'real_document_collection', v_policy.real_document_collection_enabled,
    'live_ads', v_policy.live_ads,
    'live_billing', v_policy.live_billing,
    'remote_push', v_policy.remote_push,
    'guardian_mode_optional', v_policy.guardian_mode_optional,
    'partner_supported_entry_required', v_policy.require_partner_supported_entry,
    'manual_adult_approval_required', v_policy.require_manual_adult_approval
  );
end;
$$;

create or replace function public.get_my_partner_staff_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_items jsonb;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'staff_id', staff.id,
    'organization_id', organization.id,
    'organization_name', organization.display_name,
    'organization_type', organization.organization_type,
    'staff_role', staff.staff_role,
    'status', staff.status,
    'expires_at', staff.expires_at,
    'pilot_approved', organization.pilot_approved,
    'permissions', coalesce((
      select jsonb_agg(permission.permission_key order by permission.permission_key)
      from public.partner_permissions permission
      where permission.partner_staff_id = staff.id
        and permission.enabled
        and permission.revoked_at is null
    ), '[]'::jsonb)
  ) order by organization.display_name), '[]'::jsonb)
  into v_items
  from public.partner_staff staff
  join public.partner_organizations organization
    on organization.id = staff.organization_id
  where staff.user_id = auth.uid()
    and staff.status = 'active'
    and staff.revoked_at is null
    and (staff.expires_at is null or staff.expires_at > now())
    and organization.status = 'verified'
    and organization.pilot_approved
    and (organization.expires_at is null or organization.expires_at > now());
  return jsonb_build_object(
    'ok', true,
    'items', v_items,
    'messages_included', false,
    'earnings_included', false,
    'raw_identity_documents_included', false,
    'housing_status_included', false
  );
end;
$$;

create or replace function public.partner_create_pilot_invite(
  p_organization_id uuid,
  p_program_id uuid,
  p_expires_at timestamptz,
  p_max_uses integer,
  p_purpose text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_organization public.partner_organizations%rowtype;
  v_code_id uuid;
  v_raw_code text;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.has_active_partner_permission(
    auth.uid(), p_organization_id, 'manage_partner_invites'
  ) then
    return jsonb_build_object('ok', false, 'code', 'partner_invite_permission_required');
  end if;
  if p_purpose not in ('affiliation', 'pilot_enrollment') then
    return jsonb_build_object('ok', false, 'code', 'partner_invite_purpose_invalid');
  end if;
  if p_expires_at <= now() + interval '1 hour'
     or p_expires_at > now() + interval '30 days'
     or p_max_uses not between 1 and 25 then
    return jsonb_build_object('ok', false, 'code', 'partner_invite_limits_invalid');
  end if;
  select * into v_organization
  from public.partner_organizations organization
  where organization.id = p_organization_id
    and organization.status = 'verified'
    and organization.pilot_approved
    and (organization.expires_at is null or organization.expires_at > now());
  if v_organization.id is null then
    return jsonb_build_object('ok', false, 'code', 'approved_partner_required');
  end if;
  if p_program_id is not null and not exists (
    select 1
    from public.partner_programs program
    where program.id = p_program_id
      and program.organization_id = p_organization_id
      and program.status = 'active'
      and (program.ends_at is null or program.ends_at > now())
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_partner_program_required');
  end if;

  v_raw_code := 'MORT-' || upper(encode(extensions.gen_random_bytes(16), 'hex'));
  insert into public.partner_invite_codes (
    organization_id, program_id, code_hash, code_prefix, max_uses,
    expires_at, created_by, audience_role, purpose
  ) values (
    p_organization_id, p_program_id,
    extensions.digest(convert_to(v_raw_code, 'UTF8'), 'sha256'),
    left(v_raw_code, 10), p_max_uses, p_expires_at, auth.uid(),
    'teen', p_purpose
  ) returning id into v_code_id;

  insert into public.partner_audit_events (
    actor_id, organization_id, action, resource_type, resource_id,
    access_reason, event_data
  ) values (
    auth.uid(), p_organization_id, 'partner_pilot_invite_created',
    'partner_invite_code', v_code_id,
    'Authorized partner staff created a scoped teen pilot invitation.',
    jsonb_build_object(
      'program_id', p_program_id,
      'max_uses', p_max_uses,
      'purpose', p_purpose,
      'audience_role', 'teen',
      'raw_code_stored', false
    )
  );
  return jsonb_build_object(
    'ok', true,
    'code_id', v_code_id,
    'invite_code', v_raw_code,
    'shown_once', true,
    'stored_as_hash_only', true,
    'audience_role', 'teen',
    'purpose', p_purpose,
    'expires_at', p_expires_at
  );
end;
$$;

create or replace function public.get_my_partner_invites(
  p_organization_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_items jsonb;
begin
  if auth.uid() is null
     or not private.has_active_partner_permission(
       auth.uid(), p_organization_id, 'manage_partner_invites'
     ) then
    return jsonb_build_object('ok', false, 'code', 'partner_invite_permission_required');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', code.id,
    'code_prefix', code.code_prefix,
    'audience_role', code.audience_role,
    'purpose', code.purpose,
    'max_uses', code.max_uses,
    'use_count', code.use_count,
    'expires_at', code.expires_at,
    'revoked_at', code.revoked_at
  ) order by code.created_at desc), '[]'::jsonb)
  into v_items
  from public.partner_invite_codes code
  where code.organization_id = p_organization_id
    and code.created_by = auth.uid();
  return jsonb_build_object('ok', true, 'items', v_items, 'raw_codes_included', false);
end;
$$;

create or replace function public.partner_revoke_pilot_invite(
  p_code_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code public.partner_invite_codes%rowtype;
begin
  select * into v_code
  from public.partner_invite_codes code
  where code.id = p_code_id;
  if v_code.id is null then
    return jsonb_build_object('ok', false, 'code', 'partner_invite_not_found');
  end if;
  if not private.has_active_partner_permission(
    auth.uid(), v_code.organization_id, 'manage_partner_invites'
  ) then
    return jsonb_build_object('ok', false, 'code', 'partner_invite_permission_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 8 and 500 then
    return jsonb_build_object('ok', false, 'code', 'revocation_reason_required');
  end if;
  if v_code.revoked_at is null then
    update public.partner_invite_codes
    set revoked_at = now(), revoked_by = auth.uid(),
        revocation_reason = btrim(p_reason)
    where id = p_code_id;
    insert into public.partner_audit_events (
      actor_id, organization_id, action, resource_type, resource_id,
      access_reason
    ) values (
      auth.uid(), v_code.organization_id, 'partner_pilot_invite_revoked',
      'partner_invite_code', p_code_id, btrim(p_reason)
    );
  end if;
  return jsonb_build_object('ok', true, 'status', 'revoked');
end;
$$;

revoke all on function public.get_release_mode_status() from public;
revoke all on function public.get_my_partner_staff_context() from public;
revoke all on function public.partner_create_pilot_invite(uuid, uuid, timestamptz, integer, text) from public;
revoke all on function public.get_my_partner_invites(uuid) from public;
revoke all on function public.partner_revoke_pilot_invite(uuid, text) from public;

grant execute on function public.get_release_mode_status() to anon, authenticated;
grant execute on function public.get_my_partner_staff_context() to authenticated;
grant execute on function public.partner_create_pilot_invite(uuid, uuid, timestamptz, integer, text) to authenticated;
grant execute on function public.get_my_partner_invites(uuid) to authenticated;
grant execute on function public.partner_revoke_pilot_invite(uuid, text) to authenticated;

-- The existing function records an audit event, so it must be volatile.
alter function public.get_partner_connected_participants(uuid) volatile;
