create or replace function public.remove_draft_support_evidence(p_evidence_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_evidence public.support_evidence_attachments%rowtype;
begin
  select * into v_evidence from public.support_evidence_attachments
  where id = p_evidence_id for update;
  if v_evidence.id is null or v_evidence.owner_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'evidence_not_authorized');
  end if;
  if v_evidence.status <> 'draft' or v_evidence.preservation_hold then
    return jsonb_build_object('ok', false, 'code', 'submitted_evidence_is_preserved');
  end if;
  -- Keep the manifest in draft while Storage evaluates its draft-only delete
  -- policy. The client confirms deletion in a second authenticated step.
  return jsonb_build_object(
    'ok', true,
    'evidence_id', v_evidence.id,
    'object_path', v_evidence.object_path,
    'storage_delete_allowed', true,
    'status', v_evidence.status
  );
end;
$$;

create or replace function public.confirm_draft_support_evidence_removed(
  p_evidence_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_evidence public.support_evidence_attachments%rowtype;
begin
  select * into v_evidence from public.support_evidence_attachments
  where id = p_evidence_id for update;
  if v_evidence.id is null or v_evidence.owner_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'evidence_not_authorized');
  end if;
  if v_evidence.status = 'deleted' then
    return jsonb_build_object('ok', true, 'replayed', true, 'status', 'deleted');
  end if;
  if v_evidence.status <> 'draft' or v_evidence.preservation_hold then
    return jsonb_build_object('ok', false, 'code', 'submitted_evidence_is_preserved');
  end if;
  if exists (
    select 1 from storage.objects
    where bucket_id = v_evidence.bucket_id and name = v_evidence.object_path
  ) then return jsonb_build_object('ok', false, 'code', 'storage_object_still_present'); end if;
  update public.support_evidence_attachments
  set status = 'deleted', updated_at = now()
  where id = v_evidence.id returning * into v_evidence;
  if v_evidence.ticket_id is not null then
    insert into public.support_ticket_audit_events(
      ticket_id, actor_id, event_type, safe_metadata
    ) values (
      v_evidence.ticket_id, auth.uid(), 'draft_evidence_removed',
      jsonb_build_object('evidence_id', v_evidence.id)
    );
  end if;
  return jsonb_build_object(
    'ok', true, 'replayed', false,
    'evidence_id', v_evidence.id, 'status', v_evidence.status
  );
end;
$$;

revoke all on function public.remove_draft_support_evidence(uuid)
from public, anon;
revoke all on function public.confirm_draft_support_evidence_removed(uuid)
from public, anon;
grant execute on function public.remove_draft_support_evidence(uuid)
to authenticated, service_role;
grant execute on function public.confirm_draft_support_evidence_removed(uuid)
to authenticated, service_role;
