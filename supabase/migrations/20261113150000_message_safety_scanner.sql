-- MORT message safety scanner (issue #49 moderation hardening)
--
-- Implements content screening for in-app messages before delivery, closing
-- the gap where mort_send_message() inserted every message as
-- moderation_status='pending' with no scanner: recipients never saw messages
-- and predatory content (sexualized requests, off-platform contact
-- redirection, grooming lures) was stored unreviewed.
--
-- Design:
--   * private.message_safety_rules: operator-tunable regex rule table
--     (block / flag / review severities, category).
--   * private.scan_message_body(): evaluates rules against a message body.
--     Sender age is taken into account: teen senders get the strictest
--     interpretation ('flag' rules escalate to held-for-review rather than
--     delivered).
--   * BEFORE INSERT trigger on public.messages (defense in depth: applies
--     to every insert path, including service_role edge functions):
--       clean    -> moderation_status 'approved' (delivered immediately)
--       flagged  -> moderation_status 'flagged'  (held: sender-only until a
--                   moderator approves via mort_moderate_message)
--       blocked  -> moderation_status 'blocked'  (never delivered to the
--                   recipient; evidence preserved)
--   * private.message_moderation_log: which rule fired, for every blocked or
--     flagged message, with sender identity and timestamp preserved for
--     human review and evidence preservation. Staff-only (private schema,
--     no grants to anon/authenticated).
--   * send_safe_message_v2(): now surfaces moderation_reason so senders see
--     a generic, non-revealing explanation; list_thread_messages_page() and
--     thread summaries already expose only 'approved' messages, so blocked or
--     flagged content never leaks into previews or unread counts.
--
-- Rule patterns use PostgreSQL ARE syntax: \y is the word boundary (NOT \b),
-- and \s \d \w work as class shorthands.
--
-- Rule set informed by the Nov 2026 UK resale-app grooming coverage
-- (sexualized messages, worn-item/payment requests, AI deepfake photo theft),
-- the CEASE/Collective Shout TikTok-to-OnlyFans pipeline report (coded
-- off-platform redirection, unrealistic earnings lures), and Meta's teen
-- account protections (adult-to-teen contact limits, ambiguous-pattern
-- escalation to human review).

create table if not exists private.message_safety_rules (
  id text primary key,
  pattern text not null,
  description text not null,
  category text not null,
  severity text not null default 'block'
    check (severity in ('block','flag','review')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists message_safety_rules_active_idx
  on private.message_safety_rules(active, category);

insert into private.message_safety_rules(id, pattern, description, category, severity) values
 ('sexual underwear','(?i)(worn|used)\s+(underwear|underpants|panties|pants|socks|bra|swimsuit|swimwear|bathing suit)','requests for worn clothing items','sexualized','block'),
 ('sexual photos','(?i)(send|share|trade|sell)[^\n]{0,80}\y(selfies?|nudes?|naked)\y','requests for selfies or explicit photos','sexualized','block'),
 ('personal photos','(?i)(send|share|trade|sell)[^\n]{0,50}\y(pics?|photos?|images?)\y[^\n]{0,30}\y(of you|of yourself|yourself|your face|your body)\y','requests for photos of the recipient','sexualized','block'),
 ('sexual payment','(?i)\y(if you include|include your|add your|extra if you|pay (you )?(more )?(if|for))[^\n]{0,80}\y(pants|underwear|panties|nudes?|pics?|photos?)','payment offered for personal items or images','sexualized','block'),
 ('sexual words','(?i)\y(nudes?|naked pics?|onlyfans|fansly|sugar (baby|daddy)|cam ?girl|escort|horny|sexy pics?|dick pic|sext(ing)?)\y','explicit sexual terms','sexualized','block'),
 ('grooming secrecy','(?i)\y(don.t tell (your )?(parents|mom|dad|guardian)|keep this (just )?between (us|me and you)|our (little )?secret)\y','secrecy pressure targeting minors','grooming','block'),
 ('contact offplatform','(?i)\y(dm me|hit me up|add me|hmu)[^\n]{0,40}\y(on|at|via|through)\y[^\n]{0,30}\y(instagram|snap(chat)?|telegram|whatsapp|discord|tiktok|kik|signal|facebook|twitter|threads|cashapp|venmo|zelle)\y','redirecting contact to off-platform socials','offplatform','block'),
 ('phone number','(?i)(call|text|ring|reach) me (at|on) [+.\d][\d .()-]{7,}','phone number sharing','offplatform','block'),
 ('handle request','(?i)\ywhats your (snap|insta|instagram|telegram|number|phone)\y','requesting contact handles','offplatform','flag'),
 ('links','(?i)https?://(?![^\s]*mortapp)[a-z0-9-]+(\.[a-z0-9-]+)+[^\s]*','external links','offplatform','flag'),
 ('earnings lure','(?i)\y(make|earn|get)\s+\$?\d{3,}(\+)?\s*(a|per|each|every)?\s*(day|week|month)?\y','unrealistic earnings offers','financial','flag'),
 ('job bait','(?i)\y(cash (in hand|only)|get (paid )?in (gift ?cards?|crypto)|modeling (job|gig)|photoshoot (job|gig))\y','common grooming/exploitation lures','financial','flag'),
 ('number pattern','[+.\d][\d .()-]{8,}\d','possible phone number','offplatform','review')
on conflict (id) do update
  set pattern = excluded.pattern,
      description = excluded.description,
      category = excluded.category,
      severity = excluded.severity;

create table if not exists private.message_moderation_log (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null,
  conversation_id uuid not null,
  sender_id uuid not null,
  rule_id text,
  category text,
  scan_result text not null,
  created_at timestamptz not null default now()
);

create index if not exists message_moderation_log_msg_idx
  on private.message_moderation_log(message_id);
create index if not exists message_moderation_log_result_idx
  on private.message_moderation_log(scan_result, created_at desc);

create or replace function private.scan_message_body(p_body text, p_sender_is_adult boolean)
returns text
language plpgsql
stable
as $fn$
declare
  v_result text := 'clean';
  v_rule record;
begin
  if p_body is null then
    return 'clean';
  end if;
  for v_rule in
    select id, pattern, category, severity
    from private.message_safety_rules
    where active
  loop
    if p_body ~ v_rule.pattern then
      if not p_sender_is_adult and v_rule.severity = 'flag' then
        return 'flag';
      end if;
      if v_rule.severity = 'review' then
        if v_result <> 'blocked' then
          v_result := 'flag';
        end if;
      elsif v_rule.severity = 'flag' then
        if v_result not in ('blocked','flag') then
          v_result := 'flag';
        end if;
      else
        return 'blocked';
      end if;
    end if;
  end loop;
  return v_result;
end;
$fn$;

create or replace function private.apply_message_safety_scanner()
returns trigger
language plpgsql
as $fn$
declare
  v_sender_is_adult boolean := false;
  v_rule record;
  v_scan text;
begin
  select (p.role = 'adult') into v_sender_is_adult
  from public.profiles p
  where p.id = new.sender_id;

  v_scan := private.scan_message_body(new.body, v_sender_is_adult);

  new.moderation_status := case v_scan
    when 'blocked' then 'blocked'
    when 'flag' then 'flagged'
    else 'approved'
  end;

  new.moderation_reason := case v_scan
    when 'blocked' then 'This message cannot be delivered because it may break MORT safety rules (for example: sexual content, requests for personal photos, or moving contact off-platform).'
    when 'flag' then 'This message is held for safety review and will only be delivered if a MORT moderator approves it.'
  end;

  if v_scan in ('blocked','flag') then
    for v_rule in
      select id, category
      from private.message_safety_rules
      where active and new.body ~ pattern
    loop
      insert into private.message_moderation_log(
        message_id, conversation_id, sender_id, rule_id, category, scan_result
      ) values (
        new.id, new.conversation_id, new.sender_id, v_rule.id, v_rule.category, v_scan
      );
    end loop;
  end if;

  return new;
end;
$fn$;

drop trigger if exists messages_safety_scanner on public.messages;
create trigger messages_safety_scanner
  before insert on public.messages
  for each row execute function private.apply_message_safety_scanner();

-- send_safe_message_v2: surface the scanner outcome and the generic reason.
-- The original returned a `messages` row; the scanner outcome envelope is
-- jsonb. CREATE OR REPLACE cannot change a return type, so the function is
-- replaced outright. The grant statements at the end of this migration
-- restore the original execute posture (authenticated + service_role only).
drop function if exists public.send_safe_message_v2(uuid, text, uuid);
create or replace function public.send_safe_message_v2(p_thread_id uuid, p_body text, p_client_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_user_id uuid := (select auth.uid());
  v_message_id uuid;
  v_message public.messages%rowtype;
  v_body text := btrim(coalesce(p_body, ''));
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_thread_id is null or p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'message_request_invalid');
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text || ':' || p_client_request_id::text, 0)
  );

  select message.id, message.conversation_id, message.body
    into v_message_id, v_message.conversation_id, v_message.body
  from public.messages as message
  where message.sender_id = v_user_id
    and message.client_request_id = p_client_request_id;
  if found then
    if v_message.conversation_id <> p_thread_id or v_message.body <> v_body then
      return jsonb_build_object('ok', false, 'code', 'message_request_id_reused');
    end if;
    select * into v_message from public.messages where id = v_message_id;
  else
    v_message_id := public.mort_send_message(p_thread_id, v_body);
    update public.messages
    set client_request_id = p_client_request_id
    where id = v_message_id and sender_id = v_user_id
    returning * into v_message;
  end if;

  return jsonb_build_object(
    'id', v_message.id,
    'thread_id', v_message.conversation_id,
    'sender_id', v_message.sender_id,
    'body', v_message.body,
    'scanner_status', v_message.moderation_status,
    'scanner_reason', v_message.moderation_reason,
    'created_at', v_message.created_at
  );
end;
$fn$;

-- list_thread_messages_page: return the generic scanner reason alongside
-- status (cursor logic and return shape unchanged from the original).
create or replace function public.list_thread_messages_page(
  p_thread_id uuid,
  p_cursor_created_at timestamp with time zone default null,
  p_cursor_id uuid default null,
  p_limit integer default 40
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_user_id uuid := (select auth.uid());
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 100);
  v_items jsonb;
  v_has_more boolean;
  v_next_cursor jsonb;
  v_thread jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_thread_id is null or not private.can_access_conversation(p_thread_id) then
    return jsonb_build_object('ok', false, 'code', 'conversation_unavailable');
  end if;
  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    return jsonb_build_object('ok', false, 'code', 'message_cursor_invalid');
  end if;

  v_thread := private.message_thread_summary(p_thread_id, v_user_id);
  if v_thread is null then
    return jsonb_build_object('ok', false, 'code', 'conversation_unavailable');
  end if;

  with candidates as (
    select message.id, message.conversation_id, message.sender_id,
      message.body, message.moderation_status, message.moderation_reason,
      message.created_at
    from public.messages as message
    where message.conversation_id = p_thread_id
      and message.deleted_at is null
      and (
        message.moderation_status = 'approved'
        or message.sender_id = v_user_id
      )
      and (p_cursor_created_at is null
        or (message.created_at, message.id) < (p_cursor_created_at, p_cursor_id))
    order by message.created_at desc, message.id desc
    limit v_limit + 1
  ), numbered as (
    select candidates.*,
      row_number() over (order by candidates.created_at desc, candidates.id desc) as row_number
    from candidates
  )
  select coalesce(
      jsonb_agg(jsonb_build_object(
        'id', numbered.id,
        'thread_id', numbered.conversation_id,
        'sender_id', numbered.sender_id,
        'body', numbered.body,
        'scanner_status', numbered.moderation_status,
        'scanner_reason', numbered.moderation_reason,
        'created_at', numbered.created_at
      ) order by numbered.created_at desc, numbered.id desc)
        filter (where numbered.row_number <= v_limit),
      '[]'::jsonb
    ),
    count(*) > v_limit
  into v_items, v_has_more
  from numbered;

  if v_has_more then
    with candidates as (
      select message.id, message.created_at
      from public.messages as message
      where message.conversation_id = p_thread_id
        and message.deleted_at is null
        and (
          message.moderation_status = 'approved'
          or message.sender_id = v_user_id
        )
        and (p_cursor_created_at is null
          or (message.created_at, message.id) < (p_cursor_created_at, p_cursor_id))
      order by message.created_at desc, message.id desc
      limit v_limit + 1
    )
    select jsonb_build_object('created_at', candidates.created_at, 'id', candidates.id)
      into v_next_cursor
    from candidates
    order by candidates.created_at desc, candidates.id desc
    offset v_limit - 1 limit 1;
  end if;

  return jsonb_build_object(
    'items', v_items,
    'has_more', coalesce(v_has_more, false),
    'next_cursor', v_next_cursor,
    'lifecycle_status', v_thread->>'lifecycle_status',
    'thread', v_thread
  );
end;
$fn$;

-- Lockdown: the rule table and scanner internals are not callable or readable
-- by anon/authenticated clients (prevents rule probing and enumeration).
revoke execute on function private.scan_message_body(text, boolean) from public, anon, authenticated;
revoke execute on function private.apply_message_safety_scanner() from public, anon, authenticated;
revoke all on private.message_safety_rules from public, anon, authenticated;
revoke all on private.message_moderation_log from public, anon, authenticated;
revoke execute on function public.send_safe_message_v2(uuid, text, uuid) from public, anon;
revoke execute on function public.list_thread_messages_page(uuid, timestamp with time zone, uuid, integer) from public, anon;
grant execute on function public.send_safe_message_v2(uuid, text, uuid) to authenticated, service_role;
grant execute on function public.list_thread_messages_page(uuid, timestamp with time zone, uuid, integer) to authenticated, service_role;
