create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.job_applications(id) on delete restrict,
  job_id uuid not null references public.jobs(id) on delete restrict,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  subject_id uuid not null references public.profiles(id) on delete restrict,
  rating integer not null check (rating between 1 and 5),
  body text,
  moderation_status text not null default 'approved',
  created_at timestamptz not null default now(),
  revealed_at timestamptz,
  constraint review_body_not_enabled check (body is null),
  constraint reviews_approved_rating_only check (moderation_status = 'approved'),
  constraint reviews_distinct_participants check (reviewer_id <> subject_id),
  constraint reviews_one_per_side_per_application unique (application_id, reviewer_id)
);

create index reviews_subject_revealed_created_idx
  on public.reviews (subject_id, revealed_at, created_at desc)
  where moderation_status = 'approved';

alter table public.reviews enable row level security;
revoke all on table public.reviews from public, anon, authenticated;
grant select, insert on table public.reviews to authenticated;

create policy blind_review_reveal
on public.reviews
for select
to authenticated
using (
  reviewer_id = (select auth.uid())
  or (
    subject_id = (select auth.uid())
    and moderation_status = 'approved'
    and (revealed_at is not null or created_at <= now() - interval '14 days')
  )
);

create policy reviews_insert_completed_assignment
on public.reviews
for insert
to authenticated
with check (
  reviewer_id = (select auth.uid())
  and body is null
  and moderation_status = 'approved'
  and exists (
    select 1
    from public.job_assignments as ja
    where ja.application_id = reviews.application_id
      and ja.job_id = reviews.job_id
      and ja.status = 'completed'
      and ja.completed_by_teen_at is not null
      and ja.completed_by_adult_at is not null
      and (
        (ja.teen_user_id = reviews.reviewer_id and ja.adult_user_id = reviews.subject_id)
        or (ja.adult_user_id = reviews.reviewer_id and ja.teen_user_id = reviews.subject_id)
      )
  )
);

create or replace function private.reveal_reciprocal_job_reviews()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if exists (
    select 1
    from public.reviews as other_review
    where other_review.application_id = new.application_id
      and other_review.reviewer_id = new.subject_id
      and other_review.subject_id = new.reviewer_id
  ) then
    update public.reviews
    set revealed_at = coalesce(revealed_at, now())
    where application_id = new.application_id
      and (reviewer_id = new.reviewer_id or reviewer_id = new.subject_id);
  end if;

  return new;
end;
$function$;

revoke all on function private.reveal_reciprocal_job_reviews() from public, anon, authenticated;

create trigger reviews_reveal_reciprocal_after_insert
after insert on public.reviews
for each row
execute function private.reveal_reciprocal_job_reviews();
