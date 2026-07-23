-- Fair-access onboarding without recording housing status. Location setup mode
-- is private account configuration, not a public vulnerability label.

alter table public.profiles
  add column location_setup_mode text not null default 'city_state'
    check (location_setup_mode in ('city_state', 'partner_supported', 'location_deferred'));

create or replace function public.enforce_profile_completion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  profile_age integer;
begin
  if new.state is not null then
    new.state := upper(btrim(new.state));
  end if;
  if new.city is not null then
    new.city := nullif(btrim(new.city), '');
  end if;

  if new.onboarding_completed then
    if new.display_name is null or btrim(new.display_name) = '' then
      raise exception 'Display name is required to complete onboarding.';
    end if;
    if new.dob is null then
      raise exception 'Date of birth is required to complete onboarding.';
    end if;
    if new.role is null then
      raise exception 'Role is required to complete onboarding.';
    end if;

    if new.location_setup_mode = 'city_state' then
      if new.city is null then
        raise exception 'City is required when city/state location setup is selected.';
      end if;
      if new.state is null or char_length(new.state) <> 2 then
        raise exception 'A 2-letter state is required when city/state location setup is selected.';
      end if;
    elsif new.role <> 'teen' then
      raise exception 'Partner-supported or deferred location setup is available only to teen accounts.';
    end if;

    profile_age := date_part('year', age(new.dob));
    if profile_age < 13 then
      raise exception 'MORT is available only to users age 13 and older.';
    end if;
    if new.role = 'teen' and not (profile_age >= 13 and profile_age < 18) then
      raise exception 'Teen role requires age 13 through 17.';
    end if;
    if new.role in ('adult', 'guardian', 'admin') and profile_age < 18 then
      raise exception 'Adult, guardian, and admin roles require age 18 or older.';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_profile_completion()
from public, anon, authenticated;

comment on column public.profiles.location_setup_mode is
  'Private onboarding configuration. It must never be interpreted or displayed as housing status.';
