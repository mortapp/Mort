create or replace function public.service_list_account_deletion_storage_objects(
  p_user_id uuid,
  p_limit integer default 500
)
returns table(bucket_id text, object_name text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  if p_user_id is null then
    return;
  end if;

  return query
  select object.bucket_id, object.name
  from storage.objects object
  where object.owner_id = p_user_id::text
  order by object.bucket_id, object.name
  limit least(greatest(coalesce(p_limit, 500), 1), 500);
end;
$$;

revoke all on function public.service_list_account_deletion_storage_objects(uuid, integer)
from public, anon, authenticated;
grant execute on function public.service_list_account_deletion_storage_objects(uuid, integer)
to service_role;
