-- A profile deletion closes its open jobs and applications before FK
-- deidentification. The applicant may already have deleted their profile, so
-- ordinary marketplace verification must not block this Auth-admin cleanup.
-- Preserve the Safety Contact message exception from the latest definition.
create or replace function private.enforce_marketplace_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
  v_deleting_user_id uuid;
begin
  begin
    v_deleting_user_id := nullif(
      current_setting('mort.account_deletion_user_id', true), ''
    )::uuid;
  exception when invalid_text_representation then
    v_deleting_user_id := null;
  end;

  if tg_table_name = 'jobs' then
    if session_user = 'supabase_auth_admin'
       and new.poster_id is null
       and old.poster_id = v_deleting_user_id then
      return new;
    end if;
    if session_user = 'supabase_auth_admin'
       and old.poster_id = v_deleting_user_id
       and new.poster_id = old.poster_id
       and new.status = 'canceled'
       and new.applications_open = false
       and (to_jsonb(new) - array['status', 'applications_open', 'updated_at'])
         = (to_jsonb(old) - array['status', 'applications_open', 'updated_at']) then
      return new;
    end if;
    if new.status <> 'draft'
       and not private.has_marketplace_identity(new.poster_id) then
      raise exception 'poster_verification_required';
    end if;
  elsif tg_table_name = 'applications' then
    if session_user = 'supabase_auth_admin'
       and new.teen_id is null
       and old.teen_id = v_deleting_user_id then
      return new;
    end if;
    if session_user = 'supabase_auth_admin'
       and v_deleting_user_id is not null
       and new.job_id = old.job_id
       and new.teen_id is not distinct from old.teen_id
       and new.status in ('rejected', 'canceled')
       and (to_jsonb(new) - array['status', 'updated_at'])
         = (to_jsonb(old) - array['status', 'updated_at'])
       and exists (
         select 1 from public.jobs job
         where job.id = old.job_id
           and job.poster_id = v_deleting_user_id
       ) then
      return new;
    end if;
    if not private.has_marketplace_identity(new.teen_id) then
      raise exception 'applicant_verification_required';
    end if;
    if new.status in ('accepted', 'in_progress', 'proof_submitted', 'completed') then
      select * into v_job from public.jobs where id = new.job_id;
      if not private.has_marketplace_identity(v_job.poster_id) then
        raise exception 'poster_verification_required';
      end if;
    end if;
  elsif tg_table_name = 'messages' then
    if not private.has_marketplace_identity(new.sender_id)
       and not (
         new.sender_id = auth.uid()
         and private.is_safety_contact_participant(new.thread_id, new.sender_id)
       ) then
      raise exception 'identity_verification_required';
    end if;
  elsif tg_table_name = 'proof_uploads' then
    if not private.has_marketplace_identity(new.uploaded_by) then
      raise exception 'identity_verification_required';
    end if;
  elsif tg_table_name = 'reviews' then
    if not private.has_marketplace_identity(new.reviewer_id) then
      raise exception 'identity_verification_required';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_marketplace_identity()
from public, anon, authenticated;
