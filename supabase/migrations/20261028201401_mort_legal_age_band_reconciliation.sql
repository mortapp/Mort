-- Restore the production age-band helper in the repository migration chain.
-- The helper is consumed by SECURITY DEFINER legal RPCs; callers do not need
-- direct execute permission on it.
create schema if not exists private;

create or replace function private.mort_legal_age_band(p_date_of_birth date)
returns text
language sql
stable
set search_path to ''
as $function$
  select case
    when p_date_of_birth is null then 'unknown'
    when age(current_date, p_date_of_birth) < interval '13 years' then 'ineligible'
    when age(current_date, p_date_of_birth) < interval '16 years' then 'teen_13_15'
    when age(current_date, p_date_of_birth) < interval '18 years' then 'teen_16_17'
    else 'adult_18_plus'
  end;
$function$;

revoke all on function private.mort_legal_age_band(date) from public, anon, authenticated;
