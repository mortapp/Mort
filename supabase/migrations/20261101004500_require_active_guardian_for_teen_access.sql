-- Only active, email-confirmed adult Guardian accounts may accept invitations
-- or read a linked teen's guardian-only records.

CREATE OR REPLACE FUNCTION public.accept_guardian_invite(p_invite_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  guardian_id uuid := auth.uid();
  guardian_profile public.profiles%rowtype;
  auth_email text;
  invite private.guardian_invite_codes%rowtype;
  link public.guardian_links%rowtype;
  code_hash text;
  window_start timestamptz := date_trunc('minute', now());
  attempts integer;
begin
  if guardian_id is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  insert into private.guardian_invite_accept_limits(user_id, window_started_at, attempt_count)
  values (guardian_id, window_start, 1)
  on conflict (user_id, window_started_at) do update
  set attempt_count = private.guardian_invite_accept_limits.attempt_count + 1
  returning attempt_count into attempts;
  if attempts > 10 then raise exception 'guardian_invite_accept_rate_limit_reached' using errcode = '42501'; end if;

  select * into guardian_profile from public.profiles where id = guardian_id for update;
  if not found or guardian_profile.role <> 'guardian'::public.mort_role
    or guardian_profile.account_status <> 'active'
    or guardian_profile.date_of_birth is null
    or extract(year from age(current_date, guardian_profile.date_of_birth)) < 18 then
    raise exception 'adult_guardian_account_required' using errcode = '42501';
  end if;
  select lower(u.email) into auth_email from auth.users u where u.id = guardian_id;
  if not exists (
    select 1 from auth.users u
    where u.id = guardian_id and u.email_confirmed_at is not null
  ) then
    raise exception 'guardian_email_confirmation_required' using errcode = '42501';
  end if;
  if p_invite_code is null or p_invite_code !~* '^[a-f0-9]{64}$' then
    raise exception 'guardian_invite_invalid_or_expired' using errcode = '22023';
  end if;
  code_hash := encode(extensions.digest(convert_to(lower(p_invite_code), 'utf8'), 'sha256'), 'hex');
  select * into invite from private.guardian_invite_codes
  where code_sha256 = code_hash and consumed_at is null and expires_at > now()
  for update;
  if not found or (invite.invited_email is not null and invite.invited_email <> coalesce(auth_email, '')) then
    raise exception 'guardian_invite_invalid_or_expired' using errcode = '22023';
  end if;
  select * into link from public.guardian_links where id = invite.guardian_link_id for update;
  if not found or link.status <> 'pending' or link.guardian_user_id is not null
    or link.teen_user_id = guardian_id then
    raise exception 'guardian_invite_invalid_or_expired' using errcode = '22023';
  end if;
  if exists (select 1 from public.guardian_links active
    where active.teen_user_id = link.teen_user_id and active.status = 'active') then
    raise exception 'guardian_link_already_exists' using errcode = '23505';
  end if;
  update public.guardian_links
  set guardian_user_id = guardian_id, status = 'active', guardian_consent_at = now(), updated_at = now()
  where id = link.id;
  update private.guardian_invite_codes set consumed_at = now() where id = invite.id;
  update public.profiles set guardian_setup_status = 'linked', updated_at = now() where id = link.teen_user_id;
  return link.id;
end;
$function$
;

DROP POLICY IF EXISTS guardian_links_select_participants_or_staff ON public.guardian_links;
CREATE POLICY guardian_links_select_participants_or_staff ON public.guardian_links
FOR SELECT TO authenticated
USING (
  teen_user_id = (SELECT auth.uid())
  OR (
    guardian_user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.profiles AS guardian_profile
      WHERE guardian_profile.id = (SELECT auth.uid())
        AND guardian_profile.role = 'guardian'::public.mort_role
        AND guardian_profile.account_status = 'active'
        AND guardian_profile.date_of_birth IS NOT NULL
        AND extract(year FROM age(current_date, guardian_profile.date_of_birth)) >= 18
    )
  )
  OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])
);

DROP POLICY IF EXISTS guardian_preferences_select_participants ON public.guardian_preferences;
CREATE POLICY guardian_preferences_select_participants ON public.guardian_preferences
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.guardian_links AS link
    WHERE link.id = guardian_preferences.link_id
      AND link.status = 'active'
      AND (
        link.teen_user_id = (SELECT auth.uid())
        OR (
          link.guardian_user_id = (SELECT auth.uid())
          AND EXISTS (
            SELECT 1 FROM public.profiles AS guardian_profile
            WHERE guardian_profile.id = (SELECT auth.uid())
              AND guardian_profile.role = 'guardian'::public.mort_role
              AND guardian_profile.account_status = 'active'
              AND guardian_profile.date_of_birth IS NOT NULL
              AND extract(year FROM age(current_date, guardian_profile.date_of_birth)) >= 18
          )
        )
      )
  )
);

DROP POLICY IF EXISTS safety_pings_select_authorized_parties ON public.safety_pings;
CREATE POLICY safety_pings_select_authorized_parties ON public.safety_pings
FOR SELECT TO authenticated
USING (
  teen_id = (SELECT auth.uid())
  OR (
    EXISTS (
      SELECT 1
      FROM public.guardian_links AS link
      LEFT JOIN public.guardian_preferences AS preferences ON preferences.link_id = link.id
      WHERE link.teen_user_id = safety_pings.teen_id
        AND link.guardian_user_id = (SELECT auth.uid())
        AND link.status = 'active'
        AND coalesce(preferences.safety_ping_alerts, true)
        AND EXISTS (
          SELECT 1 FROM public.profiles AS guardian_profile
          WHERE guardian_profile.id = (SELECT auth.uid())
            AND guardian_profile.role = 'guardian'::public.mort_role
            AND guardian_profile.account_status = 'active'
            AND guardian_profile.date_of_birth IS NOT NULL
            AND extract(year FROM age(current_date, guardian_profile.date_of_birth)) >= 18
        )
    )
  )
  OR private.has_staff_role(ARRAY['admin'::public.mort_role, 'moderator'::public.mort_role])
);
