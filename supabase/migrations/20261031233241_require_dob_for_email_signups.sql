-- Require a DOB in the same Auth transaction for ordinary email signup.
-- Invited users and Google OAuth users are handled by their own controlled
-- onboarding path; neither is activated until a DOB is persisted and validated.

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_dob_text text;
  v_dob date;
  v_provider text;
begin
  v_provider := coalesce(new.raw_app_meta_data ->> 'provider', 'email');
  v_dob_text := nullif(btrim(coalesce(
    new.raw_user_meta_data ->> 'date_of_birth',
    new.raw_user_meta_data ->> 'dob',
    ''
  )), '');

  if v_dob_text is null and new.invited_at is null and v_provider = 'email' then
    raise exception using errcode = 'check_violation', message = 'MORT_DOB_REQUIRED';
  end if;

  if v_dob_text is not null then
    begin v_dob := v_dob_text::date;
    exception when others then
      raise exception using errcode = 'check_violation', message = 'MORT_DOB_INVALID';
    end;
    if v_dob > current_date then
      raise exception using errcode = 'check_violation', message = 'MORT_DOB_INVALID';
    end if;
    if private.mort_age_years(v_dob) < 13 then
      raise exception using errcode = 'check_violation', message = 'MORT_MINIMUM_AGE_REQUIRED';
    end if;
  end if;

  insert into public.profiles (id, display_name, role, account_status, date_of_birth)
  values (
    new.id,
    nullif(left(coalesce(new.raw_user_meta_data ->> 'display_name', ''), 80), ''),
    'pending'::public.mort_role,
    'pending',
    v_dob
  )
  on conflict (id) do nothing;
  return new;
end;
$function$;

revoke all on function private.handle_new_user() from public, anon, authenticated;
