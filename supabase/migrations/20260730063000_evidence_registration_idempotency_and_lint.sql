-- Align regex classifier volatility with PostgreSQL and bind private evidence
-- registration retries to their original payload.

alter function private.classify_message_safety(text) stable;

alter table public.support_evidence_attachments
  add column if not exists registration_request_id uuid;

create unique index if not exists support_evidence_owner_registration_request_idx
on public.support_evidence_attachments(owner_id, registration_request_id)
where registration_request_id is not null;

create or replace function public.register_support_evidence(
  p_ticket_id uuid,
  p_dispute_id uuid,
  p_evidence_category text,
  p_object_path text,
  p_sha256 text,
  p_processed_byte_size integer,
  p_statement text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_evidence public.support_evidence_attachments%rowtype;
  v_count integer;
  v_mime text;
  v_size integer;
  v_statement text := nullif(left(btrim(coalesce(p_statement, '')), 2000), '');
begin
  if v_user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text || ':' || p_client_request_id::text, 0)
  );
  select * into v_evidence
  from public.support_evidence_attachments evidence
  where evidence.owner_id = v_user_id
    and evidence.registration_request_id = p_client_request_id;
  if found then
    if v_evidence.ticket_id is distinct from p_ticket_id
       or v_evidence.dispute_id is distinct from p_dispute_id
       or v_evidence.evidence_category <> p_evidence_category
       or v_evidence.object_path <> p_object_path
       or v_evidence.sha256 <> lower(coalesce(p_sha256, ''))
       or v_evidence.processed_byte_size <> p_processed_byte_size
       or v_evidence.statement is distinct from v_statement then
      return jsonb_build_object('ok', false, 'code', 'evidence_request_payload_mismatch');
    end if;
    return jsonb_build_object('ok', true, 'replayed', true, 'evidence', to_jsonb(v_evidence));
  end if;
  if p_ticket_id is null and p_dispute_id is null then return jsonb_build_object('ok', false, 'code', 'evidence_subject_required'); end if;
  if p_object_path !~ ('^' || v_user_id::text || '/[0-9a-f-]{36}[.]jpg$')
     or p_sha256 !~ '^[a-f0-9]{64}$'
     or p_processed_byte_size not between 1 and 4194304 then
    return jsonb_build_object('ok', false, 'code', 'invalid_evidence_manifest');
  end if;
  if p_evidence_category not in ('before_photo', 'after_photo', 'work_result', 'mort_message_screenshot', 'time_note_attachment') then
    return jsonb_build_object('ok', false, 'code', 'invalid_evidence_category');
  end if;
  if p_ticket_id is not null and not exists (
    select 1 from public.support_tickets where id = p_ticket_id and requester_id = v_user_id
  ) then return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized'); end if;
  if p_dispute_id is not null and not exists (
    select 1 from public.payment_disputes where id = p_dispute_id and v_user_id in (worker_id, poster_id)
  ) then return jsonb_build_object('ok', false, 'code', 'payment_dispute_not_authorized'); end if;
  if p_ticket_id is not null and p_dispute_id is not null and not exists (
    select 1 from public.support_tickets where id = p_ticket_id and related_dispute_id = p_dispute_id
  ) then return jsonb_build_object('ok', false, 'code', 'ticket_dispute_link_required'); end if;
  select coalesce((metadata->>'mimetype')::text, ''), coalesce((metadata->>'size')::integer, 0)
  into v_mime, v_size
  from storage.objects where bucket_id = 'support-evidence' and name = p_object_path;
  if v_mime <> 'image/jpeg' or v_size <> p_processed_byte_size then
    return jsonb_build_object('ok', false, 'code', 'storage_manifest_mismatch');
  end if;
  select count(*) into v_count from public.support_evidence_attachments
  where owner_id = v_user_id and status <> 'deleted'
    and ((p_ticket_id is not null and ticket_id = p_ticket_id) or (p_dispute_id is not null and dispute_id = p_dispute_id));
  if v_count >= 8 then return jsonb_build_object('ok', false, 'code', 'evidence_attachment_limit_reached'); end if;
  insert into public.support_evidence_attachments (
    owner_id, ticket_id, dispute_id, object_path, evidence_category,
    statement, processed_byte_size, sha256, preservation_hold,
    registration_request_id
  ) values (
    v_user_id, p_ticket_id, p_dispute_id, p_object_path, p_evidence_category,
    v_statement, p_processed_byte_size, lower(p_sha256), p_dispute_id is not null,
    p_client_request_id
  )
  returning * into v_evidence;
  return jsonb_build_object('ok', true, 'replayed', false, 'evidence', to_jsonb(v_evidence));
end;
$$;

revoke all on function public.register_support_evidence(uuid, uuid, text, text, text, integer, text, uuid) from public, anon;
grant execute on function public.register_support_evidence(uuid, uuid, text, text, text, integer, text, uuid) to authenticated, service_role;

comment on column public.support_evidence_attachments.registration_request_id is
'Owner-scoped idempotency key for payload-bound private evidence registration.';
