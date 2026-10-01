-- Run inside an outer transaction after the classic school directory migration.
-- The caller rolls back so local test data and schema remain untouched.
do $$
declare
  v_count integer;
begin
  select count(*) into v_count from public.schools where status = 'listed';
  if v_count < 16 then
    raise exception 'Expected at least 16 listed schools, got %', v_count;
  end if;
  if not exists (
    select 1 from public.schools
    where official_name = 'Chapel Hill 7th & 8th Grade Center'
      and city = 'Indianapolis' and state = 'IN'
  ) then
    raise exception 'Current official Chapel Hill name is missing';
  end if;
  if not exists (
    select 1 from public.search_schools('imsa west', 10)
    where official_name = 'Indiana Math and Science Academy West'
  ) then
    raise exception 'IMSA alias search failed';
  end if;
  if not exists (
    select 1 from public.search_schools('decatur', 10)
    where official_name = 'Decatur Central High School'
  ) then
    raise exception 'District/name search failed';
  end if;
  if exists (
    select 1 from public.search_schools('unknown-synthetic-school', 10)
  ) then
    raise exception 'Unknown school search returned a match';
  end if;
  if exists (
    select 1 from public.school_domains
    where environment = 'production' and status = 'approved'
  ) then
    raise exception 'Directory seeding unexpectedly approved a production domain';
  end if;
end;
$$;

insert into public.schools (
  official_name, display_name, city, state, school_type, status,
  official_source_url
) values (
  'Suspended Synthetic School', 'Suspended Synthetic School',
  'Indianapolis', 'IN', 'other', 'suspended', 'https://example.invalid/school'
);

set local role anon;
do $$
begin
  if not exists (
    select 1 from public.search_schools('pike', 10)
    where official_name = 'Pike High School'
  ) then
    raise exception 'Anonymous directory search failed';
  end if;
  if exists (select 1 from public.search_schools('Suspended Synthetic', 10)) then
    raise exception 'Suspended school was exposed to anonymous search';
  end if;
  if pg_catalog.has_table_privilege('anon', 'public.schools', 'INSERT') then
    raise exception 'Anonymous school directory write was allowed';
  end if;
end;
$$;
reset role;
