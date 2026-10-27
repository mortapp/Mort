begin;

revoke select on table public.jobs from anon, authenticated;

grant select (
  id,
  poster_id,
  title,
  description,
  category,
  status,
  pay_type,
  pay_amount,
  estimated_minutes,
  city,
  region,
  location_notes,
  age_min,
  age_max,
  remote_allowed,
  starts_at,
  ends_at,
  safety_review_status,
  published_at,
  created_at,
  updated_at,
  completed_at
)
on table public.jobs to authenticated;

commit;
