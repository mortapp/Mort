-- Some profiles created before resumable onboarding already have a validated
-- DOB and role but no onboarding_progress row. Profile setup is atomic and
-- expects the completed age and role prerequisites to exist before it records
-- the profile step, so those legacy profiles cannot advance.

create or replace function private.bootstrap_onboarding_progress_from_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_step text;
  v_completed_steps text[];
begin
  -- A DOB and a marketplace role are written only after server-side age/role
  -- validation. A DOB without a role has completed only the age step.
  if new.dob is null
     or (
       new.role is not null
       and new.role not in ('teen', 'adult', 'guardian', 'admin')
     ) then
    return new;
  end if;

  if new.onboarding_completed then
    v_current_step := 'complete';
    v_completed_steps := array[
      'age', 'role', 'profile', 'skills', 'availability', 'transportation',
      'payment', 'guardian', 'preferences', 'safety', 'review', 'complete'
    ]::text[];
  elsif new.role is null then
    v_current_step := 'role';
    v_completed_steps := array['age']::text[];
  elsif new.role in ('teen', 'adult', 'guardian') then
    v_current_step := 'profile';
    v_completed_steps := array['age', 'role']::text[];
  else
    -- Admin accounts do not use marketplace onboarding.
    return new;
  end if;

  insert into public.onboarding_progress (
    user_id,
    current_step,
    completed_steps
  ) values (
    new.id,
    v_current_step,
    v_completed_steps
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function private.bootstrap_onboarding_progress_from_profile()
from public, anon, authenticated;

drop trigger if exists profiles_bootstrap_onboarding_progress
on public.profiles;
create trigger profiles_bootstrap_onboarding_progress
after insert or update of dob, role, onboarding_completed on public.profiles
for each row
when (new.dob is not null)
execute function private.bootstrap_onboarding_progress_from_profile();

insert into public.onboarding_progress (
  user_id,
  current_step,
  completed_steps
)
select
  profile.id,
  case
    when profile.onboarding_completed then 'complete'
    when profile.role is null then 'role'
    else 'profile'
  end,
  case
    when profile.onboarding_completed then array[
      'age', 'role', 'profile', 'skills', 'availability', 'transportation',
      'payment', 'guardian', 'preferences', 'safety', 'review', 'complete'
    ]::text[]
    when profile.role is null then array['age']::text[]
    else array['age', 'role']::text[]
  end
from public.profiles profile
where profile.dob is not null
  and (
    profile.onboarding_completed
    or profile.role is null
    or profile.role in ('teen', 'adult', 'guardian')
  )
on conflict (user_id) do nothing;

comment on function private.bootstrap_onboarding_progress_from_profile() is
'Restores missing resumable-onboarding prerequisites from server-validated profile DOB and role fields without changing existing progress or recording legal acknowledgements.';
