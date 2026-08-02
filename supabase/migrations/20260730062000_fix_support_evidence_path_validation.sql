-- Use a PostgreSQL-regex-safe literal dot for private support evidence paths.
-- The previous '\\.jpg' expression was interpreted as an escaped backslash
-- followed by any character under standard_conforming_strings.

alter table public.support_evidence_attachments
  drop constraint if exists support_evidence_path_check;

alter table public.support_evidence_attachments
  add constraint support_evidence_path_check
  check (object_path ~ ('^' || owner_id::text || '/[0-9a-f-]{36}[.]jpg$'));

drop policy if exists storage_support_evidence_insert_own on storage.objects;
create policy storage_support_evidence_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'support-evidence'
  and name ~ ('^' || (select auth.uid())::text || '/[0-9a-f-]{36}[.]jpg$')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

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
begin
  if v_user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
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
    statement, processed_byte_size, sha256, preservation_hold
  ) values (
    v_user_id, p_ticket_id, p_dispute_id, p_object_path, p_evidence_category,
    nullif(left(btrim(coalesce(p_statement, '')), 2000), ''), p_processed_byte_size, lower(p_sha256), p_dispute_id is not null
  )
  on conflict (object_path) do nothing
  returning * into v_evidence;
  if v_evidence.id is null then
    select * into v_evidence from public.support_evidence_attachments
    where object_path = p_object_path and owner_id = v_user_id;
  end if;
  return jsonb_build_object('ok', true, 'evidence', to_jsonb(v_evidence));
end;
$$;

revoke all on function public.register_support_evidence(uuid, uuid, text, text, text, integer, text, uuid) from public, anon;
grant execute on function public.register_support_evidence(uuid, uuid, text, text, text, integer, text, uuid) to authenticated, service_role;
