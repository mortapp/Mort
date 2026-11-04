-- Preserve who and when for every transition of a guardian link to revoked.
alter table public.guardian_links
  add column if not exists revoked_by uuid references auth.users(id) on delete set null,
  add column if not exists revoked_at timestamptz;

create or replace function private.audit_guardian_link_revocation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'revoked' and old.status is distinct from new.status then
    new.revoked_by := coalesce(new.revoked_by, auth.uid(), new.initiated_by);
    new.revoked_at := coalesce(new.revoked_at, now());
  end if;
  return new;
end;
$$;
revoke all on function private.audit_guardian_link_revocation() from public, anon, authenticated;
drop trigger if exists guardian_links_audit_revocation on public.guardian_links;
create trigger guardian_links_audit_revocation
before update of status on public.guardian_links
for each row execute function private.audit_guardian_link_revocation();

comment on column public.guardian_links.revoked_by is
  'Authenticated account that initiated revocation; populated by a guarded transition trigger.';
comment on column public.guardian_links.revoked_at is
  'Timestamp of the first transition to revoked.';

