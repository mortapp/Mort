do $$
begin
  if has_column_privilege('anon', 'public.jobs', 'exact_address', 'SELECT') then
    raise exception 'anon must not read exact job addresses';
  end if;
  if has_column_privilege(
    'authenticated', 'public.jobs', 'exact_address', 'SELECT'
  ) then
    raise exception 'authenticated users must not read exact job addresses';
  end if;
  if not has_column_privilege('authenticated', 'public.jobs', 'title', 'SELECT') then
    raise exception 'authenticated users must still read safe job titles';
  end if;
  if not has_column_privilege(
    'authenticated', 'public.jobs', 'location_notes', 'SELECT'
  ) then
    raise exception 'authenticated users must still read approximate location notes';
  end if;
  if not (
    select c.relrowsecurity
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'jobs'
  ) then
    raise exception 'jobs row-level security must remain enabled';
  end if;
end;
$$;
