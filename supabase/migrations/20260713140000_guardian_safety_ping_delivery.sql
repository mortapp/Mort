create or replace function public.guardian_receives_safety_pings(
  p_teen_id uuid,
  p_guardian_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.guardian_connections connection
    join public.guardian_preferences preference
      on preference.link_id = connection.id
    where connection.teen_id = p_teen_id
      and connection.guardian_id = p_guardian_id
      and connection.status = 'active'
      and preference.safety_ping_alerts
  );
$$;

drop policy if exists safety_pings_select_participant
on public.safety_pings;
create policy safety_pings_select_participant
on public.safety_pings for select to authenticated
using (
  teen_id = auth.uid()
  or public.guardian_receives_safety_pings(teen_id, auth.uid())
  or public.is_admin()
);

create or replace function public.queue_safety_ping_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_guardian record;
  v_guardian_count integer := 0;
  v_admin record;
begin
  for v_guardian in
    select distinct connection.guardian_id
    from public.guardian_connections connection
    join public.guardian_preferences preference
      on preference.link_id = connection.id
    where connection.teen_id = new.teen_id
      and connection.status = 'active'
      and connection.guardian_id is not null
      and preference.safety_ping_alerts
  loop
    perform public.enqueue_notification(
      v_guardian.guardian_id,
      'Teen safety ping',
      'A linked teen sent a safety ping: ' || replace(new.status::text, '_', ' ') || '.',
      jsonb_build_object(
        'safetyPingId', new.id,
        'teenId', new.teen_id,
        'status', new.status
      )
    );
    v_guardian_count := v_guardian_count + 1;
  end loop;

  if v_guardian_count = 0 then
    for v_admin in
      select id from public.profiles where role = 'admin'
    loop
      perform public.enqueue_notification(
        v_admin.id,
        'Unsupervised safety ping',
        'A teen sent a safety ping without an enabled guardian alert.',
        jsonb_build_object(
          'safetyPingId', new.id,
          'teenId', new.teen_id,
          'status', new.status
        )
      );
    end loop;
  end if;

  return new;
end;
$$;

revoke execute on function public.guardian_receives_safety_pings(uuid, uuid)
from public, anon;
grant execute on function public.guardian_receives_safety_pings(uuid, uuid)
to authenticated, service_role;
revoke execute on function public.queue_safety_ping_notifications()
from public, anon, authenticated;
