create or replace function public.reject_reserved_play_reviewer_identity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.email is not null
     and lower(btrim(new.email)) = 'play-review@mortapp.test' then
    raise exception using
      errcode = 'P0001',
      message = 'This identifier is reserved for Google Play review.';
  end if;

  return new;
end;
$$;

revoke all on function public.reject_reserved_play_reviewer_identity()
from public, anon, authenticated;

drop trigger if exists auth_users_reject_play_reviewer_identity
on auth.users;

create trigger auth_users_reject_play_reviewer_identity
before insert or update of email on auth.users
for each row execute function public.reject_reserved_play_reviewer_identity();
