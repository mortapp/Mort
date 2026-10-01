-- Public school names are separate from private student-email domain review.
-- Listing a school never approves an email domain or grants teen eligibility.
create extension if not exists pg_trgm with schema extensions;

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  official_name text not null check (char_length(btrim(official_name)) between 3 and 180),
  display_name text not null check (char_length(btrim(display_name)) between 3 and 180),
  district text,
  city text not null check (char_length(btrim(city)) between 2 and 100),
  state text not null check (state ~ '^[A-Z]{2}$'),
  country text not null default 'US' check (country = 'US'),
  school_type text not null check (school_type in ('high_school', 'middle_school', 'k8', 'other')),
  status text not null default 'listed' check (status in ('listed', 'suspended', 'retired')),
  official_source_url text not null check (official_source_url ~ '^https://'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (official_name, city, state)
);

create table public.school_aliases (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  alias text not null check (char_length(btrim(alias)) between 2 and 120),
  normalized_alias text generated always as (lower(btrim(alias))) stored,
  created_at timestamptz not null default now(),
  unique (school_id, normalized_alias)
);

create index schools_name_search_idx
  on public.schools using gin (lower(official_name) extensions.gin_trgm_ops);
create index schools_display_search_idx
  on public.schools using gin (lower(display_name) extensions.gin_trgm_ops);
create index schools_district_search_idx
  on public.schools using gin (lower(district) extensions.gin_trgm_ops);
create index school_aliases_search_idx
  on public.school_aliases using gin (normalized_alias extensions.gin_trgm_ops);
create index schools_listed_city_idx on public.schools (status, state, city);

alter table public.schools enable row level security;
alter table public.school_aliases enable row level security;
revoke all on public.schools, public.school_aliases from public, anon, authenticated;
grant select on public.schools, public.school_aliases to anon, authenticated;

create policy schools_listed_select on public.schools
  for select to anon, authenticated using (status = 'listed');
create policy school_aliases_listed_select on public.school_aliases
  for select to anon, authenticated using (
    exists (
      select 1 from public.schools school
      where school.id = school_id and school.status = 'listed'
    )
  );

create or replace function public.search_schools(
  p_query text,
  p_limit integer default 25
)
returns table (
  id uuid,
  official_name text,
  display_name text,
  district text,
  city text,
  state text,
  school_type text
)
language sql
stable
security invoker
set search_path = ''
as $$
  with search as (
    select lower(btrim(coalesce(p_query, ''))) as term,
           least(greatest(coalesce(p_limit, 25), 1), 50) as row_limit
  )
  select school.id, school.official_name, school.display_name,
         school.district, school.city, school.state, school.school_type
  from public.schools school cross join search
  where school.status = 'listed'
    and (
      search.term = ''
      or lower(school.official_name) like '%' || search.term || '%'
      or lower(school.display_name) like '%' || search.term || '%'
      or lower(coalesce(school.district, '')) like '%' || search.term || '%'
      or lower(school.city) like '%' || search.term || '%'
      or exists (
        select 1 from public.school_aliases alias
        where alias.school_id = school.id
          and alias.normalized_alias like '%' || search.term || '%'
      )
    )
  order by
    case when lower(school.display_name) = search.term then 0
         when lower(school.display_name) like search.term || '%' then 1
         when lower(school.official_name) like search.term || '%' then 2
         else 3 end,
    school.display_name,
    school.city,
    school.id
  limit (select row_limit from search);
$$;
revoke all on function public.search_schools(text, integer) from public;
grant execute on function public.search_schools(text, integer) to anon, authenticated;

-- Official names and locations were checked against the linked school or
-- district pages on 2026-09-30. These URLs do not establish student domains.
insert into public.schools (
  official_name, display_name, district, city, state, school_type, official_source_url
) values
  ('Herron-Riverside High School', 'Herron-Riverside High School', 'Herron Classical Schools', 'Indianapolis', 'IN', 'high_school', 'https://www.herronriverside.org/'),
  ('Indiana Math and Science Academy West', 'Indiana Math and Science Academy West', 'Indiana Math and Science Academy', 'Indianapolis', 'IN', 'k8', 'https://west.imsaindy.org/'),
  ('Pike High School', 'Pike High School', 'MSD of Pike Township', 'Indianapolis', 'IN', 'high_school', 'https://phs.pike.k12.in.us/'),
  ('Lawrence Central High School', 'Lawrence Central High School', 'MSD of Lawrence Township', 'Indianapolis', 'IN', 'high_school', 'https://lawrencecentral.ltschools.org/'),
  ('Lawrence North High School', 'Lawrence North High School', 'MSD of Lawrence Township', 'Indianapolis', 'IN', 'high_school', 'https://lawrencenorth.ltschools.org/'),
  ('Decatur Central High School', 'Decatur Central High School', 'MSD of Decatur Township', 'Indianapolis', 'IN', 'high_school', 'https://www.decaturproud.org/central-high'),
  ('Chapel Hill 7th & 8th Grade Center', 'Chapel Hill 7th & 8th Grade Center', 'MSD of Wayne Township', 'Indianapolis', 'IN', 'middle_school', 'https://chc.wayne.k12.in.us/about/about-us'),
  ('Ben Davis High School', 'Ben Davis High School', 'MSD of Wayne Township', 'Indianapolis', 'IN', 'high_school', 'https://bdhs.wayne.k12.in.us/'),
  ('North Central High School', 'North Central High School', 'MSD of Washington Township', 'Indianapolis', 'IN', 'high_school', 'https://nc.msdwt.k12.in.us/'),
  ('Arsenal Technical High School', 'Arsenal Technical High School', 'Indianapolis Public Schools', 'Indianapolis', 'IN', 'high_school', 'https://www.myips.org/enrollment-options/high-school-options'),
  ('Shortridge High School', 'Shortridge High School', 'Indianapolis Public Schools', 'Indianapolis', 'IN', 'high_school', 'https://www.myips.org/enrollment-options/high-school-options'),
  ('Crispus Attucks High School', 'Crispus Attucks High School', 'Indianapolis Public Schools', 'Indianapolis', 'IN', 'high_school', 'https://www.myips.org/enrollment-options/high-school-options'),
  ('George Washington High School', 'George Washington High School', 'Indianapolis Public Schools', 'Indianapolis', 'IN', 'high_school', 'https://www.myips.org/enrollment-options/high-school-options'),
  ('Herron High School', 'Herron High School', 'Herron Classical Schools', 'Indianapolis', 'IN', 'high_school', 'https://www.myips.org/enrollment-options/high-school-options'),
  ('KIPP Indy Legacy High School', 'KIPP Indy Legacy High School', 'KIPP Indy Public Schools', 'Indianapolis', 'IN', 'high_school', 'https://www.myips.org/enrollment-options/high-school-options'),
  ('Purdue Polytechnic High School Englewood', 'Purdue Polytechnic High School Englewood', 'Purdue Polytechnic High Schools', 'Indianapolis', 'IN', 'high_school', 'https://www.myips.org/enrollment-options/high-school-options')
on conflict (official_name, city, state) do nothing;

insert into public.school_aliases (school_id, alias)
select school.id, alias.alias
from (values
  ('Indiana Math and Science Academy West', 'imsa west'),
  ('Herron-Riverside High School', 'herron riverside'),
  ('Chapel Hill 7th & 8th Grade Center', 'chapel hill'),
  ('Decatur Central High School', 'decatur'),
  ('Arsenal Technical High School', 'arsenal tech'),
  ('North Central High School', 'north central'),
  ('Purdue Polytechnic High School Englewood', 'purdue polytechnic englewood')
) as alias(official_name, alias)
join public.schools school on school.official_name = alias.official_name
  and school.city = 'Indianapolis' and school.state = 'IN'
on conflict (school_id, normalized_alias) do nothing;

comment on table public.schools is
  'Public school directory. A listed school does not imply any approved student-email domain.';
comment on function public.search_schools(text, integer) is
  'Bounded public school search over official names, aliases, district, and city; excludes email domains.';
