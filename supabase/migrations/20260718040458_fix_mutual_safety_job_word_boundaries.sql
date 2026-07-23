-- Keep prohibited teen-work classification precise. Without word boundaries,
-- valid words such as "proof" are misclassified because they contain "roof".
create or replace function private.classify_job_risk()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_content text := lower(
    coalesce(new.title, '') || ' ' || coalesce(new.description, '') || ' ' ||
    coalesce(new.special_instructions, '') || ' ' || coalesce(new.equipment_provided, '') || ' ' ||
    coalesce(new.equipment_worker_brings, '')
  );
begin
  if v_content ~ '(mroofM|mfirearms?M|mgunM|mhazardous chemicals?M|madult entertainmentM|msexual services?M|millegal activityM|movernightM|malcohol handlingM|mdrug handlingM|mheavy machineryM|mintimate careM|mnudityM)' then
    new.risk_tier := 'prohibited_for_teens';
  elsif new.location_type in ('private_residence', 'isolated_property')
    or new.transportation_required
    or new.recurring
    or v_content ~ '(mpower tools?M|mheavy liftM|maggressive animalM|munsupervised accessM)'
    or (new.starts_at is not null and extract(hour from new.starts_at at time zone new.timezone) not between 7 and 19) then
    new.risk_tier := 'elevated_review';
  else
    new.risk_tier := 'lower_risk';
  end if;

  if new.status <> 'draft' and new.risk_tier = 'prohibited_for_teens' then
    raise exception 'prohibited_teen_job';
  end if;
  if new.status <> 'draft' and new.animal_risk_notes is not null and not new.animal_risk_disclosed then
    raise exception 'animal_risk_disclosure_required';
  end if;
  if new.status <> 'draft' and new.equipment_risk_notes is not null and not new.equipment_risk_disclosed then
    raise exception 'equipment_risk_disclosure_required';
  end if;
  return new;
end;
$$;

revoke all on function private.classify_job_risk() from public, anon, authenticated;
grant execute on function private.classify_job_risk() to service_role;
