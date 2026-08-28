alter table public.profiles
  drop constraint profiles_completed_required_fields;

alter table public.profiles
  add constraint profiles_completed_required_fields
  check (
    not onboarding_completed
    or (
      role is not null
      and display_name is not null
      and btrim(display_name) <> ''
      and dob is not null
      and date_part('year', age(dob)) >= 13
      and (
        (
          location_setup_mode = 'city_state'
          and city is not null
          and btrim(city) <> ''
          and state is not null
          and char_length(state) = 2
        )
        or (
          role = 'teen'
          and location_setup_mode in ('partner_supported', 'location_deferred')
        )
      )
    )
  );
