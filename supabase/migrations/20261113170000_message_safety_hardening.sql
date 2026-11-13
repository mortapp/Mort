-- MORT message-safety hardening follow-up.
-- Adds normalization/obfuscation screening, attachment quarantine, and a staff-only queue.
-- Apply to QA first; production rollout requires a separate reviewed migration.

create or replace function private.normalize_message_body(p_body text)
returns text
language sql
immutable
set search_path to ''
as $fn$
  select lower(
    regexp_replace(
      translate(
        regexp_replace(
          normalize(coalesce(p_body, ''), NFKC),
          U&'[\\200B-\\200F\\202A-\\202E\\2060\\FEFF]',
          '',
          'g'
        ),
        'аеорсхуіјѕΑΒΕΖΗΙΚΜΝΟΡΤΥΧ',
        'aeopcxyijsABEZHIKMNOPTYX'
      ),
      '[[:cntrl:]]',
      '',
      'g'
    )
  );
$fn$;

create or replace function private.scan_message_body(p_body text, p_sender_is_adult boolean)
returns text
language plpgsql
stable
set search_path to ''
as $fn$
declare
  v_normal text := private.normalize_message_body(p_body);
  v_compact text;
  v_result text := 'clean';
  v_rule record;
begin
  if p_body is null then return 'clean'; end if;

  v_compact := regexp_replace(v_normal, '[^a-z0-9]+', '', 'g');

  -- Existing configurable rules run against the Unicode-normalized text.
  for v_rule in
    select id, pattern, severity
    from private.message_safety_rules
    where active
  loop
    if v_normal ~ v_rule.pattern then
      if v_rule.severity = 'review' or v_rule.severity = 'flag' then
        v_result := 'flag';
      else
        return 'blocked';
      end if;
    end if;
  end loop;

  -- Compact-form checks catch spacing/punctuation insertion and common coded terms.
  if v_compact ~ '(nudes?|nakedpics?|onlyfans|fansly|sexting|dickpic|horny|sexy)' then
    return 'blocked';
  end if;
  if v_compact ~ '(dmme(on)?(instagram|insta|snap(chat)?|telegram|whatsapp|discord|tiktok|kik|signal)|textme(at|on)|callme(at|on))' then
    return 'blocked';
  end if;
  if v_compact ~ '(donttell(your)?(parents|mom|dad|guardian)|keep(this)?(just)?between(us|meandyou)|our(little)?secret)' then
    return 'blocked';
  end if;
  if v_compact ~ '(worn(underwear|underpants|panties|socks|bra|swimsuit)|include(your)?(underwear|panties|nudes?))' then
    return 'blocked';
  end if;
  if v_compact ~ '(whatsyour(snap|insta|instagram|telegram|number|phone)|earn[0-9]{3,}(aweek|aday|amonth)?)' then
    v_result := 'flag';
  end if;

  return v_result;
end;
$fn$;

create or replace function private.apply_message_safety_scanner()
returns trigger
language plpgsql
set search_path to ''
as $fn$
declare
  v_sender_is_adult boolean := false;
  v_scan text;
  v_rule record;
  v_logged_rules integer := 0;
begin
  select (p.role = 'adult') into v_sender_is_adult
  from public.profiles p
  where p.id = new.sender_id;

  v_scan := private.scan_message_body(new.body, coalesce(v_sender_is_adult, false));

  -- Attachments are quarantined for staff review until a real image/content
  -- moderation provider is integrated. A path alone is never treated as safe.
  if new.attachment_path is not null and v_scan = 'clean' then
    v_scan := 'flag';
  end if;

  new.moderation_status := case v_scan
    when 'blocked' then 'blocked'
    when 'flag' then 'flagged'
    else 'approved'
  end;
  new.moderation_reason := case
    when v_scan = 'blocked' then
      'This message cannot be delivered because it may break MORT safety rules.'
    when v_scan = 'flag' and new.attachment_path is not null then
      'This attachment is held for safety review before it can be delivered.'
    when v_scan = 'flag' then
      'This message is held for safety review before it can be delivered.'
    else null
  end;

  if v_scan in ('blocked','flag') then
    for v_rule in
      select id, category
      from private.message_safety_rules
      where active and private.normalize_message_body(new.body) ~ pattern
    loop
      insert into private.message_moderation_log(
        message_id, conversation_id, sender_id, rule_id, category, scan_result
      ) values (
        new.id, new.conversation_id, new.sender_id, v_rule.id, v_rule.category, v_scan
      );
    end loop;
    get diagnostics v_logged_rules = row_count;

    -- Compact/obfuscation signals may not correspond to a configurable regex
    -- rule. Preserve an evidence row for those detections as well.
    if v_logged_rules = 0 then
      insert into private.message_moderation_log(
        message_id, conversation_id, sender_id, rule_id, category, scan_result
      ) values (
        new.id, new.conversation_id, new.sender_id, 'normalized-pattern',
        'normalization', v_scan
      );
    end if;

    if new.attachment_path is not null then
      insert into private.message_moderation_log(
        message_id, conversation_id, sender_id, rule_id, category, scan_result
      ) values (
        new.id, new.conversation_id, new.sender_id, 'attachment-quarantine',
        'attachment', 'flag'
      );
    end if;
  end if;
  return new;
end;
$fn$;

-- Staff-facing moderation queue. Message bodies and attachment paths are
-- intentionally returned only after an explicit admin/moderator role check.
create or replace function public.list_message_moderation_queue(p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_user uuid := (select auth.uid());
  v_items jsonb;
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    raise exception 'Authorized moderation role required';
  end if;

  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at asc), '[]'::jsonb)
  into v_items
  from (
    select m.id, m.conversation_id, m.sender_id, m.body,
      m.attachment_path, m.moderation_status, m.moderation_reason, m.created_at
    from public.messages m
    where m.deleted_at is null
      and m.moderation_status in ('flagged','blocked')
    order by m.created_at asc, m.id asc
    limit least(greatest(coalesce(p_limit, 50), 1), 100)
  ) q;

  return jsonb_build_object('items', v_items, 'count', jsonb_array_length(v_items));
end;
$fn$;

revoke all on function private.normalize_message_body(text) from public, anon, authenticated;
revoke all on function private.scan_message_body(text, boolean) from public, anon, authenticated;
revoke all on function private.apply_message_safety_scanner() from public, anon, authenticated;
revoke all on function public.list_message_moderation_queue(integer) from public, anon;
grant execute on function public.list_message_moderation_queue(integer) to authenticated;
