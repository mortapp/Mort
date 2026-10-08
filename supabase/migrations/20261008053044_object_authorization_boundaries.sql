-- Message participants, parents and lifecycle are established by server RPCs.
-- Checking is_thread_participant(id) on UPDATE examines the existing row, so it
-- cannot protect a replacement participant or application in the new row.
drop policy if exists message_threads_insert_application_participant on public.message_threads;
drop policy if exists message_threads_update_participant on public.message_threads;
revoke insert, update, delete on public.message_threads from public, anon, authenticated;

-- Use the same job RLS visibility for this read as for a direct/nested job read.
-- Keep the existing payload and missing-job result for authorized callers.
alter function public.get_pilot_job_eligibility(uuid) security invoker;

-- The distance lookup needs privileged access to private coordinates, but its
-- result must contain only jobs the caller can actually see in the marketplace.
create or replace function public.get_nearby_job_distances_v1(
  p_job_ids uuid[], p_latitude double precision, p_longitude double precision
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile public.profiles%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null or v_profile.role <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;
  if p_job_ids is null or cardinality(p_job_ids) = 0 or cardinality(p_job_ids) > 50 then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_ids');
  end if;
  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180 then
    return jsonb_build_object('ok', false, 'code', 'invalid_teen_coordinates');
  end if;

  return jsonb_build_object(
    'ok', true,
    'distances', coalesce((
      select jsonb_agg(jsonb_build_object(
        'job_id', loc.job_id,
        'distance_miles', round(
          (2 * 3958.8 * asin(sqrt(
            power(sin(radians(p_latitude - loc.latitude) / 2), 2) +
            cos(radians(loc.latitude)) * cos(radians(p_latitude)) *
            power(sin(radians(p_longitude - loc.longitude) / 2), 2)
          )))::numeric, 1
        )
      ))
      from public.job_private_locations loc
      join public.jobs job on job.id = loc.job_id
      where loc.job_id = any(p_job_ids)
        and loc.latitude is not null
        and loc.longitude is not null
        and job.status = 'open'
        and job.applications_open
        and private.can_view_marketplace_job(job.id)
        -- Match the additional RESTRICTIVE jobs pilot policy as well.
        and (
          job.poster_id = auth.uid()
          or public.is_admin()
          or exists (
            select 1 from public.applications application
            where application.job_id = job.id
              and public.is_application_participant(application.id)
          )
          or (
            job.pilot_review_status = 'eligible'
            and (
              private.user_has_active_pilot_enrollment(auth.uid())
              or (job.is_test and private.is_sandbox_pilot_user(auth.uid()))
            )
          )
        )
    ), '[]'::jsonb)
  );
end;
$$;

-- A completed worker may ask only the poster of that completed job for a
-- reference. Owning the request is insufficient authorization for its parent
-- application and recipient.
drop policy if exists work_references_requester_insert on public.work_reference_requests;
create policy work_references_requester_insert
on public.work_reference_requests for insert to authenticated
with check (
  requester_id = (select auth.uid())
  and status = 'pending'
  and reference_text is null
  and responded_at is null
  and exists (
    select 1
    from public.applications application
    join public.jobs job on job.id = application.job_id
    where application.id = work_reference_requests.application_id
      and application.teen_id = (select auth.uid())
      and application.status = 'completed'
      and job.poster_id = work_reference_requests.requested_from
  )
);

-- Participants may respond or withdraw using the existing API, but a reference
-- never changes whose work it describes or who was asked to provide it.
create or replace function private.protect_work_reference_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.requester_id is distinct from old.requester_id
    or new.application_id is distinct from old.application_id
    or new.requested_from is distinct from old.requested_from then
    raise exception 'work_reference_identity_immutable' using errcode = '42501';
  end if;
  if current_user in ('authenticated', 'anon') then
    if new.created_at is distinct from old.created_at then
      raise exception 'work_reference_identity_immutable' using errcode = '42501';
    end if;
    if auth.uid() = old.requester_id then
      if new.status <> 'withdrawn'
        or new.reference_text is distinct from old.reference_text
        or new.responded_at is distinct from old.responded_at then
        raise exception 'work_reference_requester_withdrawal_only' using errcode = '42501';
      end if;
    elsif auth.uid() = old.requested_from then
      if old.status = 'withdrawn' or new.status not in ('provided', 'declined') then
        raise exception 'work_reference_recipient_response_required' using errcode = '42501';
      end if;
    else
      raise exception 'work_reference_participant_required' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.protect_work_reference_identity() from public, anon, authenticated;
drop trigger if exists work_reference_identity_immutable on public.work_reference_requests;
create trigger work_reference_identity_immutable
before update on public.work_reference_requests
for each row execute function private.protect_work_reference_identity();
