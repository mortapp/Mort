-- Activate only the two exact student email domains published by Herron.
-- Evidence: https://www.herronriverside.org/technology and
-- https://www.herronhighschool.org/technology.
-- Do not add wildcard or sibling domains without separate official evidence.

insert into private.school_email_domains (
  domain, school_name, status, verification_source, verified_at
)
values
  (
    'herronriverside.org',
    'Herron-Riverside High School',
    'active',
    'Official Herron-Riverside technology page: https://www.herronriverside.org/technology (student email username formats)',
    now()
  ),
  (
    'herronclassical.org',
    'Herron Classical Schools',
    'active',
    'Official Herron High School technology page: https://www.herronhighschool.org/technology (student email username formats)',
    now()
  )
on conflict (domain) do update
set school_name = excluded.school_name,
    status = 'active',
    verification_source = excluded.verification_source,
    verified_at = excluded.verified_at,
    updated_at = now();
