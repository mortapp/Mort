-- Run after progression_v1_baseline.sql and the progression migration on a
-- disposable PostgreSQL database. psql must use -v ON_ERROR_STOP=1.

-- Formula, rank boundaries, privileges, and privacy default.
do $$
declare
  v_level integer;
  v_xp bigint;
  v_expected_rank text;
begin
  foreach v_level in array array[1,10,11,20,21,30,31,40,41,50] loop
    v_xp := (v_level - 1)::bigint * 100
      + 25 * (v_level - 1)::bigint * (v_level - 2) / 2;
    if private.progression_level(v_xp) <> v_level then
      raise exception 'level threshold failed at level %',v_level;
    end if;
    if v_level > 1 and private.progression_level(v_xp - 1) <> v_level - 1 then
      raise exception 'pre-threshold failed at level %',v_level;
    end if;
    if private.progression_level(v_xp + 1) <> v_level then
      raise exception 'post-threshold failed at level %',v_level;
    end if;
    v_expected_rank := case when v_level <= 10 then 'bronze'
      when v_level <= 20 then 'silver' when v_level <= 30 then 'gold'
      when v_level <= 40 then 'platinum' else 'diamond' end;
    if private.progression_rank(v_level) <> v_expected_rank then
      raise exception 'rank mapping failed at level %',v_level;
    end if;
  end loop;
  if private.progression_level(1000000000) <> 50
    or private.progression_rank(50) <> 'diamond' then
    raise exception 'level or rank cap failed';
  end if;
  if pg_catalog.has_function_privilege('authenticated',
      'private.progression_award(uuid,text,text,uuid,integer,text,text)','EXECUTE') then
    raise exception 'authenticated can award XP';
  end if;
  if pg_catalog.has_table_privilege('authenticated','private.progression_accounts','UPDATE')
    or pg_catalog.has_table_privilege('authenticated','private.progression_events','INSERT')
    or pg_catalog.has_table_privilege('authenticated','private.progression_unlocks','INSERT')
    or pg_catalog.has_table_privilege('authenticated','private.progression_equipped','INSERT') then
    raise exception 'authenticated has direct progression write';
  end if;
  if (select column_default like 'true%' from information_schema.columns
      where table_schema = 'public' and table_name = 'profiles'
        and column_name = 'leaderboard_opt_out') is not true then
    raise exception 'leaderboard does not default to private';
  end if;
  if not (select leaderboard_opt_out from public.profiles
      where id = '00000000-0000-0000-0000-0000000000e5') then
    raise exception 'existing visible teen was not reset to private';
  end if;
end $$;

-- Teen, adult, admin, and concurrency fixtures.
insert into public.profiles(id,role,username,avatar_path) values
  ('00000000-0000-0000-0000-0000000000a1','teen','teen_a','avatars/a.png'),
  ('00000000-0000-0000-0000-0000000000b2','teen','teen_b','avatars/b.png'),
  ('00000000-0000-0000-0000-0000000000c3','adult','adult_a',null),
  ('00000000-0000-0000-0000-0000000000d4','admin','admin_a',null),
  ('00000000-0000-0000-0000-0000000000f6','teen','teen_concurrent',null);

insert into public.jobs(id,category) values
  ('10000000-0000-0000-0000-000000000001','lawn care'),
  ('10000000-0000-0000-0000-000000000002','lawn care'),
  ('10000000-0000-0000-0000-000000000003','pet care');

insert into public.applications(id,teen_id,job_id,status) values
  ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000001','accepted'),
  ('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002','accepted'),
  ('20000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000003','accepted');

-- First completion: 100 base + 100 first + 25 first category + 10 safety.
insert into public.job_checkins(application_id,user_id,checkin_type,status) values
  ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000a1','arrival','completed'),
  ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000a1','departure','completed');
update public.applications set status = 'completed',updated_at = now()
where id = '20000000-0000-0000-0000-000000000001';

do $$
declare v private.progression_accounts%rowtype;
begin
  select * into v from private.progression_accounts
  where user_id = '00000000-0000-0000-0000-0000000000a1';
  if v.xp_total <> 235 or v.level <> 3 or v.rank <> 'bronze'
    or v.motion_tokens_balance <> 2 or v.current_safety_streak <> 1 then
    raise exception 'first completion totals invalid: %',row_to_json(v);
  end if;
  if (select count(*) from private.progression_events where user_id = v.user_id
      and event_type = 'completed_job') <> 1
    or (select count(*) from private.progression_events where user_id = v.user_id
      and event_type = 'first_completed_job') <> 1
    or (select count(*) from private.progression_events where user_id = v.user_id
      and event_type = 'first_category') <> 1
    or (select count(*) from private.progression_events where user_id = v.user_id
      and event_type = 'safety_checkins') <> 1 then
    raise exception 'first completion event counts invalid';
  end if;
end $$;

-- Authoritative replay is a no-op.
select private.progression_complete_job('20000000-0000-0000-0000-000000000001');
do $$ begin
  if (select xp_total from private.progression_accounts
      where user_id = '00000000-0000-0000-0000-0000000000a1') <> 235 then
    raise exception 'completion replay changed XP';
  end if;
end $$;

-- Review awards once even if a second review row reaches the trigger.
insert into public.reviews(id,job_id,reviewer_id,subject_id,rating,revealed_at) values
  ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000c3',5,now()),
  ('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000c3',5,now());
do $$ begin
  if (select xp_total from private.progression_accounts
      where user_id = '00000000-0000-0000-0000-0000000000a1') <> 250
    or (select count(*) from private.progression_events
      where user_id = '00000000-0000-0000-0000-0000000000a1'
        and event_type = 'post_job_review') <> 1 then
    raise exception 'review idempotency failed';
  end if;
end $$;

-- Second job in the same category has no first-category bonus.
insert into public.job_checkins(application_id,user_id,checkin_type,status) values
  ('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000a1','arrival','completed'),
  ('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000a1','departure','completed');
update public.applications set status = 'completed',updated_at = now()
where id = '20000000-0000-0000-0000-000000000002';

-- Incomplete pet-care sequence gets base/category XP, no safety XP, and resets streak.
insert into public.job_checkins(application_id,user_id,checkin_type,status) values
  ('20000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-0000000000a1','arrival','completed'),
  ('20000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-0000000000a1','cadence','pending');
update public.applications set status = 'completed',updated_at = now()
where id = '20000000-0000-0000-0000-000000000003';

do $$
declare v private.progression_accounts%rowtype;
begin
  select * into v from private.progression_accounts
  where user_id = '00000000-0000-0000-0000-0000000000a1';
  if v.xp_total <> 485 or v.level <> 4 or v.motion_tokens_balance <> 3
    or v.current_safety_streak <> 0 or v.best_safety_streak <> 2 then
    raise exception 'multi-job totals invalid: %',row_to_json(v);
  end if;
  if (select count(*) from private.progression_events where user_id = v.user_id
      and event_type = 'completed_job') <> 3
    or (select count(*) from private.progression_events where user_id = v.user_id
      and event_type = 'first_category') <> 2
    or (select count(*) from private.progression_events where user_id = v.user_id
      and event_type = 'safety_checkins') <> 2 then
    raise exception 'category or safety event counts invalid';
  end if;
end $$;

-- Normal teen cannot use the admin correction path.
set role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000a1',false);
do $$ declare v jsonb; begin
  v := public.admin_award_progression_correction_v1(
    '00000000-0000-0000-0000-0000000000b2',13875,
    '40000000-0000-0000-0000-000000000001','Certification multi-level award');
  if v->>'code' <> 'admin_required' then
    raise exception 'normal teen reached admin correction path: %',v;
  end if;
end $$;
reset role;

-- Admin-authorized event crosses 30 levels and three rank boundaries once.
set role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000d4',false);
do $$ declare v jsonb; begin
  v := public.admin_award_progression_correction_v1(
    '00000000-0000-0000-0000-0000000000b2',13875,
    '40000000-0000-0000-0000-000000000001','Certification multi-level award');
  if v->>'ok' <> 'true' or (v->>'level')::integer <> 31
    or v->>'rank' <> 'platinum' or (v->>'motion_tokens_balance')::integer <> 60 then
    raise exception 'multi-level correction result invalid: %',v;
  end if;
  v := public.admin_award_progression_correction_v1(
    '00000000-0000-0000-0000-0000000000b2',13875,
    '40000000-0000-0000-0000-000000000001','Certification multi-level award');
  if v->>'ok' <> 'true' or v->>'replayed' <> 'true'
    or (v->>'xp_total')::bigint <> 13875 or (v->>'motion_tokens_balance')::integer <> 60 then
    raise exception 'multi-level replay invalid: %',v;
  end if;
end $$;
reset role;

do $$ declare v jsonb; begin
  select safe_metadata into v from private.progression_events
  where idempotency_key = 'admin_correction:00000000-0000-0000-0000-0000000000b2:40000000-0000-0000-0000-000000000001';
  if pg_catalog.jsonb_array_length(v->'levels_crossed') <> 30
    or pg_catalog.jsonb_array_length(v->'rank_transitions') <> 3
    or v->>'new_level' <> '31' or v->>'new_rank' <> 'platinum'
    or v->>'admin_id' <> '00000000-0000-0000-0000-0000000000d4' then
    raise exception 'multi-level ledger metadata invalid: %',v;
  end if;
end $$;

-- Constraint attack matrix as the database owner.
do $$
begin
  begin
    update private.progression_accounts set motion_tokens_balance = -1
    where user_id = '00000000-0000-0000-0000-0000000000a1';
    raise exception 'negative token balance accepted';
  exception when check_violation then null; end;
  begin
    update private.progression_accounts set level = 50
    where user_id = '00000000-0000-0000-0000-0000000000a1';
    raise exception 'level/xp mismatch accepted';
  exception when check_violation then null; end;
  begin
    update private.progression_accounts set rank = 'legend'
    where user_id = '00000000-0000-0000-0000-0000000000a1';
    raise exception 'hidden rank accepted';
  exception when check_violation then null; end;
  begin
    insert into private.progression_cosmetics(cosmetic_key,title,token_cost,presentation)
    values ('zero_cost','Zero Cost',0,'accent');
    raise exception 'zero-cost cosmetic accepted';
  exception when check_violation then null; end;
  begin
    insert into private.progression_events(user_id,event_type,source_type,source_id,
      xp_delta,idempotency_key)
    select user_id,'admin_correction','correction',gen_random_uuid(),1,idempotency_key
    from private.progression_events limit 1;
    raise exception 'duplicate idempotency key accepted';
  exception when unique_violation then null; end;
  begin
    insert into private.progression_badges(user_id,badge_key,source_event_id)
    select user_id,badge_key,source_event_id from private.progression_badges limit 1;
    raise exception 'duplicate badge accepted';
  exception when unique_violation then null; end;
end $$;

-- Direct and cross-user attacks as an authenticated teen.
set role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000a1',false);
do $$
declare v jsonb;
begin
  begin
    execute 'update private.progression_accounts set xp_total = 999999';
    raise exception 'direct XP update allowed';
  exception when insufficient_privilege then null; end;
  begin
    execute $attack$insert into private.progression_events(
      user_id,event_type,source_type,source_id,xp_delta,idempotency_key)
      values ('00000000-0000-0000-0000-0000000000a1','completed_job','application',
      gen_random_uuid(),100,'forged')$attack$;
    raise exception 'direct event insert allowed';
  exception when insufficient_privilege then null; end;
  begin
    execute 'select * from private.progression_accounts where user_id = ''00000000-0000-0000-0000-0000000000b2''';
    raise exception 'cross-user private read allowed';
  exception when insufficient_privilege then null; end;
  begin
    execute $attack$select private.progression_award(
      '00000000-0000-0000-0000-0000000000a1','completed_job','application',
      gen_random_uuid(),100,'forged-client',null)$attack$;
    raise exception 'internal award invocation allowed';
  exception when insufficient_privilege then null; end;
  begin
    execute $attack$insert into private.progression_badges(user_id,badge_key,source_event_id)
      values ('00000000-0000-0000-0000-0000000000b2','forged',gen_random_uuid())$attack$;
    raise exception 'cross-user badge mutation allowed';
  exception when insufficient_privilege then null; end;
  v := public.unlock_progression_cosmetic_v1('unknown_cosmetic',gen_random_uuid());
  if v->>'code' <> 'cosmetic_unavailable' then
    raise exception 'unknown cosmetic response invalid: %',v;
  end if;
end $$;

-- Legitimate spend, replay, request conflict, equip, and self snapshot.
do $$ declare v jsonb; begin
  v := public.unlock_progression_cosmetic_v1(
    'silver_edge','40000000-0000-0000-0000-000000000010');
  if v->>'ok' <> 'true' or (v->>'balance')::integer <> 0 then
    raise exception 'legitimate cosmetic spend failed: %',v;
  end if;
  v := public.unlock_progression_cosmetic_v1(
    'silver_edge','40000000-0000-0000-0000-000000000010');
  if v->>'ok' <> 'true' or v->>'replayed' <> 'true' then
    raise exception 'cosmetic replay failed: %',v;
  end if;
  v := public.unlock_progression_cosmetic_v1(
    'night_signal','40000000-0000-0000-0000-000000000010');
  if v->>'ok' <> 'false' or v->>'code' <> 'request_conflict' then
    raise exception 'request-id conflict not rejected: %',v;
  end if;
  v := public.equip_progression_cosmetic_v1('silver_edge');
  if v->>'ok' <> 'true' then raise exception 'owned cosmetic did not equip: %',v; end if;
  v := public.get_my_progression_v1();
  if (v->>'xp_total')::integer <> 485 or (v->>'motion_tokens_balance')::integer <> 0 then
    raise exception 'self snapshot totals invalid: %',v;
  end if;
end $$;
reset role;

-- Another teen cannot equip the first teen's cosmetic.
set role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000b2',false);
do $$ declare v jsonb; begin
  v := public.equip_progression_cosmetic_v1('silver_edge');
  if v->>'ok' <> 'false' or v->>'code' <> 'cosmetic_not_owned' then
    raise exception 'cross-user cosmetic equip succeeded: %',v;
  end if;
  v := public.set_leaderboard_opt_out_v1(false);
  if v->>'ok' <> 'true' then raise exception 'self opt-in failed: %',v; end if;
end $$;
reset role;

-- Adult and anonymous boundaries.
set role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000c3',false);
do $$ declare v jsonb; begin
  v := public.get_my_progression_v1();
  if v->>'code' <> 'user_role_not_allowed' then raise exception 'adult progression read allowed: %',v; end if;
  v := public.unlock_progression_cosmetic_v1('silver_edge',gen_random_uuid());
  if v->>'code' <> 'user_role_not_allowed' then raise exception 'adult token spend allowed: %',v; end if;
end $$;
reset role;

set role anon;
do $$ begin
  begin
    execute 'select public.get_my_progression_v1()';
    raise exception 'anonymous progression read allowed';
  exception when insufficient_privilege then null; end;
  begin
    execute 'select * from private.progression_accounts';
    raise exception 'anonymous private read allowed';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Raw leaderboard privacy allowlist.
set role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000a1',false);
do $$
declare v jsonb; entry jsonb; key text;
  allowed text[] := array['position','username','avatar_path','rank','level','score','completed_count'];
  forbidden text[] := array['email','dob','age','school','school_email','school_id','latitude',
    'longitude','address','exact_location','guardian','earnings','payout','pay_amount','tip',
    'report','moderation','verification_document'];
begin
  v := public.get_progression_leaderboard_v1('weekly_xp',50);
  if v->>'ok' <> 'true' or pg_catalog.jsonb_array_length(v->'entries') <> 1 then
    raise exception 'leaderboard opt-in result invalid: %',v;
  end if;
  entry := (v->'entries')->0;
  if entry->>'username' <> 'teen_b' then raise exception 'unexpected board identity: %',entry; end if;
  for key in select jsonb_object_keys(entry) loop
    if not key = any(allowed) then raise exception 'unapproved leaderboard key: %',key; end if;
  end loop;
  foreach key in array forbidden loop
    if v::text like '%"' || key || '"%' then raise exception 'forbidden leaderboard key leaked: %',key; end if;
  end loop;
end $$;
reset role;

-- Only completed applications and reviews are progression trigger sources.
do $$
declare v_tables text[];
begin
  select pg_catalog.array_agg(distinct event_object_table order by event_object_table)
    into v_tables from information_schema.triggers
    where trigger_name in ('applications_progression_completed','reviews_progression_submitted');
  if v_tables is distinct from array['applications','reviews']::text[] then
    raise exception 'unexpected progression trigger sources: %',v_tables;
  end if;
  if exists (select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
      where n.nspname in ('private','public') and p.proname like '%progression%'
        and pg_catalog.pg_get_functiondef(p.oid) ~* '(stripe|revenuecat|admob|payout|verification_document)') then
    raise exception 'progression function coupled to payment, ads, subscriptions, or Verify';
  end if;
end $$;

select 'progression_v1 certification SQL passed' as result;
