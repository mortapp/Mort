-- Progression is derived only from existing, guarded marketplace transitions.
-- The private ledger is the authority; clients receive narrow self-bound RPCs.
create table private.progression_accounts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  xp_total bigint not null default 0 check (xp_total >= 0),
  level smallint not null default 1 check (level between 1 and 50),
  rank text not null default 'bronze' check (rank in ('bronze','silver','gold','platinum','diamond')),
  motion_tokens_balance integer not null default 0 check (motion_tokens_balance >= 0),
  current_safety_streak integer not null default 0 check (current_safety_streak >= 0),
  best_safety_streak integer not null default 0 check (best_safety_streak >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table private.progression_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null check (event_type in (
    'completed_job','first_completed_job','first_category','safety_checkins',
    'post_job_review','cosmetic_unlock','admin_correction'
  )),
  source_type text not null check (source_type in ('application','review','cosmetic','correction')),
  source_id uuid not null,
  xp_delta integer not null default 0 check (xp_delta >= 0),
  motion_token_delta integer not null default 0,
  idempotency_key text not null unique
    check (pg_catalog.length(pg_catalog.btrim(idempotency_key)) between 1 and 200),
  occurred_at timestamptz not null default now(),
  safe_metadata jsonb not null default '{}'::jsonb
    check (pg_catalog.jsonb_typeof(safe_metadata) = 'object'),
  constraint progression_event_shape check (
    (event_type = 'completed_job' and source_type = 'application'
      and xp_delta = 100 and motion_token_delta >= 0)
    or (event_type = 'first_completed_job' and source_type = 'application'
      and xp_delta = 100 and motion_token_delta >= 0)
    or (event_type = 'first_category' and source_type = 'application'
      and xp_delta = 25 and motion_token_delta >= 0)
    or (event_type = 'safety_checkins' and source_type = 'application'
      and xp_delta = 10 and motion_token_delta >= 0)
    or (event_type = 'post_job_review' and source_type = 'review'
      and xp_delta = 15 and motion_token_delta >= 0)
    or (event_type = 'cosmetic_unlock' and source_type = 'cosmetic'
      and xp_delta = 0 and motion_token_delta < 0)
    or (event_type = 'admin_correction' and source_type = 'correction'
      and xp_delta > 0 and motion_token_delta >= 0)
  )
);
create index progression_events_user_time_idx on private.progression_events(user_id, occurred_at desc);
create index progression_events_type_user_idx on private.progression_events(event_type, user_id);

create table private.progression_badges (
  user_id uuid not null references public.profiles(id) on delete cascade,
  badge_key text not null check (pg_catalog.length(pg_catalog.btrim(badge_key)) between 1 and 100),
  source_event_id uuid not null references private.progression_events(id) on delete cascade,
  awarded_at timestamptz not null default now(),
  primary key (user_id, badge_key)
);

create table private.progression_cosmetics (
  cosmetic_key text primary key check (pg_catalog.length(pg_catalog.btrim(cosmetic_key)) between 1 and 100),
  title text not null check (pg_catalog.length(pg_catalog.btrim(title)) between 1 and 100),
  token_cost integer not null check (token_cost > 0),
  presentation text not null check (presentation in ('profile_frame','rank_card','accent')),
  active boolean not null default true,
  unique (cosmetic_key,presentation)
);
insert into private.progression_cosmetics(cosmetic_key,title,token_cost,presentation) values
  ('silver_edge','Silver Edge',3,'profile_frame'),
  ('night_signal','Night Signal',5,'rank_card'),
  ('ice_trace','Ice Trace',8,'accent');

create table private.progression_unlocks (
  user_id uuid not null references public.profiles(id) on delete cascade,
  cosmetic_key text not null,
  request_id uuid not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, cosmetic_key),
  unique (user_id, request_id)
);

create table private.progression_equipped (
  user_id uuid not null references public.profiles(id) on delete cascade,
  presentation text not null check (presentation in ('profile_frame','rank_card','accent')),
  cosmetic_key text not null references private.progression_cosmetics(cosmetic_key),
  equipped_at timestamptz not null default now(),
  primary key (user_id,presentation),
  foreign key (cosmetic_key,presentation)
    references private.progression_cosmetics(cosmetic_key,presentation)
);

alter table private.progression_accounts enable row level security;
alter table private.progression_events enable row level security;
alter table private.progression_badges enable row level security;
alter table private.progression_cosmetics enable row level security;
alter table private.progression_unlocks enable row level security;
alter table private.progression_equipped enable row level security;
revoke all on private.progression_accounts, private.progression_events,
  private.progression_badges, private.progression_cosmetics,
  private.progression_unlocks, private.progression_equipped from public, anon, authenticated;
grant select, insert, update on private.progression_accounts to service_role;
grant select, insert on private.progression_events, private.progression_badges,
  private.progression_unlocks to service_role;
grant select on private.progression_cosmetics, private.progression_equipped
  to service_role;

create function private.progression_level(p_xp bigint)
returns smallint language plpgsql immutable set search_path = '' as $$
declare v_level integer := 1; v_threshold bigint := 0;
begin
  while v_level < 50 loop
    v_threshold := v_threshold + 100 + 25 * (v_level - 1);
    exit when p_xp < v_threshold;
    v_level := v_level + 1;
  end loop;
  return v_level::smallint;
end;
$$;

create function private.progression_rank(p_level integer)
returns text language sql immutable set search_path = '' as $$
  select case when p_level <= 10 then 'bronze'
              when p_level <= 20 then 'silver'
              when p_level <= 30 then 'gold'
              when p_level <= 40 then 'platinum'
              else 'diamond' end;
$$;

alter table private.progression_accounts
  add constraint progression_level_matches_xp
    check (level = private.progression_level(xp_total)),
  add constraint progression_rank_matches_level
    check (rank = private.progression_rank(level));

create function private.progression_award(
  p_user_id uuid, p_type text, p_source_type text, p_source_id uuid,
  p_xp integer, p_key text, p_category text default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_account private.progression_accounts%rowtype;
  v_old_level integer;
  v_new_level integer;
  v_level integer;
  v_tokens integer := 0;
  v_event_id uuid;
  v_levels_crossed jsonb := '[]'::jsonb;
  v_rank_transitions jsonb := '[]'::jsonb;
begin
  if p_type = 'admin_correction' then
    if p_source_type is distinct from 'correction'
      or p_xp is null or p_xp <= 0 or p_xp > 100000 then
      raise exception 'invalid progression award';
    end if;
  else
    if p_xp is distinct from (case p_type
        when 'completed_job' then 100
        when 'first_completed_job' then 100
        when 'first_category' then 25
        when 'safety_checkins' then 10
        when 'post_job_review' then 15
        else -1 end)
      or (p_type = 'post_job_review' and p_source_type is distinct from 'review')
      or (p_type <> 'post_job_review' and p_source_type is distinct from 'application') then
      raise exception 'invalid progression award';
    end if;
  end if;
  insert into private.progression_accounts(user_id) values (p_user_id)
    on conflict (user_id) do nothing;
  select * into v_account from private.progression_accounts
    where user_id = p_user_id for update;
  select id into v_event_id from private.progression_events
    where idempotency_key = p_key;
  if v_event_id is not null then return null; end if;
  v_old_level := private.progression_level(v_account.xp_total);
  v_new_level := private.progression_level(v_account.xp_total + p_xp);
  for v_level in (v_old_level + 1)..v_new_level loop
    v_levels_crossed := v_levels_crossed || pg_catalog.jsonb_build_array(v_level);
    v_tokens := v_tokens + 1;
    if v_level in (11,21,31,41) then
      v_rank_transitions := v_rank_transitions || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('level',v_level,'rank',private.progression_rank(v_level))
      );
      v_tokens := v_tokens + case v_level
        when 11 then 5 when 21 then 10 when 31 then 15 when 41 then 25 end;
    end if;
  end loop;
  insert into private.progression_events(
    user_id,event_type,source_type,source_id,xp_delta,motion_token_delta,
    idempotency_key,safe_metadata
  ) values (
    p_user_id,p_type,p_source_type,p_source_id,p_xp,v_tokens,p_key,
    (case when p_category is null then '{}'::jsonb
         when p_type = 'admin_correction' then
           pg_catalog.jsonb_build_object('reason',pg_catalog.left(p_category,160))
         else pg_catalog.jsonb_build_object('category',p_category) end)
      || (case when v_new_level > v_old_level then
        pg_catalog.jsonb_build_object('new_level',v_new_level,
          'new_rank',case when private.progression_rank(v_new_level)
            <> private.progression_rank(v_old_level)
            then private.progression_rank(v_new_level) else null end,
          'levels_crossed',v_levels_crossed,
          'rank_transitions',v_rank_transitions)
        else '{}'::jsonb end)
  ) returning id into v_event_id;
  update private.progression_accounts set
    xp_total = xp_total + p_xp, level = v_new_level,
    rank = private.progression_rank(v_new_level),
    motion_tokens_balance = motion_tokens_balance + v_tokens,
    updated_at = now()
  where user_id = p_user_id;
  return v_event_id;
end;
$$;

create function private.progression_complete_job(p_application_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_application public.applications%rowtype;
  v_category text;
  v_event uuid;
  v_count integer;
  v_category_count integer;
  v_safe boolean;
  v_streak integer;
begin
  select * into v_application from public.applications where id = p_application_id;
  -- Account deletion retains completed applications but clears their teen ID.
  if v_application.id is null or v_application.status <> 'completed'
    or v_application.teen_id is null then return; end if;
  select job.category into v_category from public.jobs job where job.id = v_application.job_id;
  v_event := private.progression_award(v_application.teen_id,'completed_job',
    'application',p_application_id,100,'completed_job:' || p_application_id,v_category);
  if v_event is null then return; end if;

  select count(*) into v_count from private.progression_events
    where user_id = v_application.teen_id and event_type = 'completed_job';
  if v_count = 1 then
    perform private.progression_award(v_application.teen_id,'first_completed_job',
      'application',p_application_id,100,'first_completed_job:' || v_application.teen_id);
  end if;
  select count(*) into v_category_count from private.progression_events
    where user_id = v_application.teen_id and event_type = 'completed_job'
      and safe_metadata->>'category' = v_category;
  if v_category_count = 1 then
    perform private.progression_award(v_application.teen_id,'first_category',
      'application',p_application_id,25,
      'first_category:' || v_application.teen_id || ':' || v_category,v_category);
  end if;

  -- Only actual completed teen check-ins count. Reports, blocks, and incidents
  -- are intentionally absent from this calculation.
  select exists(select 1 from public.job_checkins c
      where c.application_id = p_application_id and c.user_id = v_application.teen_id
        and c.checkin_type = 'arrival' and c.status = 'completed')
    and exists(select 1 from public.job_checkins c
      where c.application_id = p_application_id and c.user_id = v_application.teen_id
        and c.checkin_type = 'departure' and c.status = 'completed')
    and not exists(select 1 from public.job_checkins c
      where c.application_id = p_application_id and c.user_id = v_application.teen_id
        and c.status in ('pending','missed')) into v_safe;
  if v_safe then
    perform private.progression_award(v_application.teen_id,'safety_checkins',
      'application',p_application_id,10,'safety_checkins:' || p_application_id);
  end if;
  update private.progression_accounts set
    current_safety_streak = case when v_safe then current_safety_streak + 1 else 0 end,
    best_safety_streak = greatest(best_safety_streak,
      case when v_safe then current_safety_streak + 1 else 0 end),
    updated_at = now()
  where user_id = v_application.teen_id returning current_safety_streak into v_streak;

  if v_count in (1,5,10,25,50) then
    insert into private.progression_badges(user_id,badge_key,source_event_id)
      values (v_application.teen_id,'jobs_' || v_count,v_event)
      on conflict do nothing;
  end if;
  if v_category_count in (1,5,20) then
    insert into private.progression_badges(user_id,badge_key,source_event_id)
      values (v_application.teen_id,
        'category_' || pg_catalog.regexp_replace(v_category,'[^a-z0-9]+','_','g')
        || '_' || v_category_count,v_event)
      on conflict do nothing;
  end if;
  if v_streak in (3,10) then
    insert into private.progression_badges(user_id,badge_key,source_event_id)
      values (v_application.teen_id,'safety_' || v_streak,v_event)
      on conflict do nothing;
  end if;
  -- A review submitted before the completion transition becomes eligible now.
  perform private.progression_award(v_application.teen_id,'post_job_review',
    'review',review.id,15,
    'post_job_review:' || v_application.job_id || ':' || v_application.teen_id)
  from public.reviews review
  where review.job_id = v_application.job_id
    and review.reviewer_id = v_application.teen_id
  limit 1;
end;
$$;

create function private.progression_on_application_completed()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'completed' and old.status is distinct from new.status then
    perform private.progression_complete_job(new.id);
  end if;
  return new;
end;
$$;
create trigger applications_progression_completed
after update of status on public.applications
for each row execute function private.progression_on_application_completed();

create function private.progression_on_review()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (
    select 1 from public.applications a
    join public.profiles p on p.id = a.teen_id
    where a.job_id = new.job_id and a.teen_id = new.reviewer_id
      and a.status = 'completed' and p.role = 'teen'
  ) then
    perform private.progression_award(new.reviewer_id,'post_job_review',
      'review',new.id,15,'post_job_review:' || new.job_id || ':' || new.reviewer_id);
  end if;
  return new;
end;
$$;
create trigger reviews_progression_submitted
after insert on public.reviews
for each row execute function private.progression_on_review();

create index if not exists progression_completed_application_idx
  on public.applications(teen_id,job_id) where status = 'completed';
create index if not exists progression_weekly_events_idx
  on private.progression_events(occurred_at,user_id) where xp_delta > 0;

create function public.get_progression_leaderboard_v1(
  p_board text default 'weekly_xp', p_limit integer default 20
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_result jsonb;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok',false,'code','authentication_required');
  end if;
  if p_board not in ('weekly_xp','completed_jobs','safety_streak',
      'beginner_helpers','pet_care','yard_work','tutoring','business_help')
      or p_board is null then
    return jsonb_build_object('ok',false,'code','invalid_board');
  end if;
  with completed as (
    select a.teen_id, count(*)::integer as jobs,
      count(*) filter (where j.category in ('pet care','dog walking'))::integer as pets,
      count(*) filter (where j.category = 'lawn care')::integer as yards,
      count(*) filter (where j.category = 'tutoring')::integer as tutoring,
      count(*) filter (where j.category = 'business help')::integer as business
    from public.applications a join public.jobs j on j.id = a.job_id
    where a.status = 'completed' group by a.teen_id
  ), weekly as (
    select e.user_id, sum(e.xp_delta)::integer as xp
    from private.progression_events e
    where e.xp_delta > 0 and e.occurred_at >= pg_catalog.date_trunc('week',now())
    group by e.user_id
  ), scored as (
    select p.id,p.username,p.avatar_path,acc.rank,acc.level,
      coalesce(c.jobs,0) as completed_count,
      case p_board
        when 'weekly_xp' then coalesce(w.xp,0)
        when 'completed_jobs' then coalesce(c.jobs,0)
        when 'safety_streak' then acc.current_safety_streak
        when 'beginner_helpers' then case when acc.level <= 10 then coalesce(c.jobs,0) else 0 end
        when 'pet_care' then coalesce(c.pets,0)
        when 'yard_work' then coalesce(c.yards,0)
        when 'tutoring' then coalesce(c.tutoring,0)
        when 'business_help' then coalesce(c.business,0)
      end as score
    from public.profiles p
    join private.progression_accounts acc on acc.user_id = p.id
    left join completed c on c.teen_id = p.id
    left join weekly w on w.user_id = p.id
    where p.role = 'teen' and p.account_status = 'active'
      and not p.is_test_account and not p.leaderboard_opt_out
      and p.username is not null
  ), ranked as (
    select *,row_number() over (order by score desc,completed_count desc,id) as position
    from scored where score > 0
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'position',position,'username',username,'avatar_path',avatar_path,
    'rank',rank,'level',level,'score',score,'completed_count',completed_count)
    order by position),'[]'::jsonb) into v_result
  from ranked where position <= greatest(1,least(coalesce(p_limit,20),50));
  return jsonb_build_object('ok',true,'board',p_board,'entries',v_result);
end;
$$;
revoke all on function public.get_progression_leaderboard_v1(text,integer) from public,anon;
grant execute on function public.get_progression_leaderboard_v1(text,integer) to authenticated;

-- Existing legitimate completions receive the same deterministic events.
do $$ declare v_id uuid;
begin
  for v_id in
    select a.id from public.applications a
    left join lateral (
      select min(ev.created_at) as completed_at
      from public.application_status_events ev
      where ev.application_id = a.id and ev.to_status = 'completed'
    ) history on true
    where a.status = 'completed'
      and a.teen_id is not null
      and exists (select 1 from public.application_status_events verified
        where verified.application_id = a.id and verified.to_status = 'completed')
    order by coalesce(history.completed_at,a.updated_at),a.id
  loop
    perform private.progression_complete_job(v_id);
  end loop;
  update private.progression_events e set occurred_at = coalesce(
    (select min(status_event.created_at)
      from public.application_status_events status_event
      where status_event.application_id = a.id
        and status_event.to_status = 'completed'),a.updated_at)
  from public.applications a
  where e.source_type = 'application' and e.source_id = a.id
    and e.event_type in ('completed_job','first_completed_job','first_category','safety_checkins');
  update private.progression_events e set occurred_at = r.created_at
  from public.reviews r
  where e.source_type = 'review' and e.source_id = r.id
    and e.event_type = 'post_job_review';
end $$;

-- The original leaderboard launched visible by default. Require explicit
-- opt-in for every existing and future teen before publishing any entry.
alter table public.profiles alter column leaderboard_opt_out set default true;
update public.profiles set leaderboard_opt_out = true where role = 'teen';

-- Keep the existing dashboard leaderboard usable while limiting its public
-- identity field to the same chosen username as the new boards.
create or replace function public.get_leaderboard_v1(p_limit integer default 20)
returns jsonb language sql stable security definer set search_path = '' as $$
  with completed as (
    select teen_id,count(*)::integer as completed_count
    from public.applications where status = 'completed' group by teen_id
  ), reviews as (
    select subject_id,count(*)::integer as review_count,
      avg(rating) as average_rating
    from public.reviews where moderation_status = 'approved'
      and revealed_at is not null group by subject_id
  ), scored as (
    select p.id,p.username,p.avatar_path,c.completed_count,
      (c.completed_count * 10 +
        pg_catalog.round(coalesce(r.average_rating,0) * coalesce(r.review_count,0)))::integer as score
    from public.profiles p
    join completed c on c.teen_id = p.id
    left join reviews r on r.subject_id = p.id
    where p.role = 'teen' and p.account_status = 'active'
      and not p.is_test_account and not p.leaderboard_opt_out
      and p.username is not null
  ), ranked as (
    select *,row_number() over(order by score desc,completed_count desc,id) as position
    from scored
  )
  select jsonb_build_object('ok',true,'entries',coalesce((
    select jsonb_agg(jsonb_build_object(
      'rank',position,'display_name','@' || username,
      'avatar_path',avatar_path,'score',score,
      'completed_count',completed_count,'tier',private.leaderboard_tier(score))
      order by position)
    from ranked where position <= greatest(1,least(coalesce(p_limit,20),50))
  ),'[]'::jsonb));
$$;
revoke all on function public.get_leaderboard_v1(integer) from public,anon;
grant execute on function public.get_leaderboard_v1(integer) to authenticated;

create function public.get_my_progression_v1()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_account private.progression_accounts%rowtype;
begin
  if v_user is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  if not exists (select 1 from public.profiles p where p.id = v_user and p.role = 'teen') then
    return jsonb_build_object('ok',false,'code','user_role_not_allowed');
  end if;
  select * into v_account from private.progression_accounts where user_id = v_user;
  return jsonb_build_object(
    'ok',true,'xp_total',coalesce(v_account.xp_total,0),
    'level',coalesce(v_account.level,1),'rank',coalesce(v_account.rank,'bronze'),
    'motion_tokens_balance',coalesce(v_account.motion_tokens_balance,0),
    'current_safety_streak',coalesce(v_account.current_safety_streak,0),
    'best_safety_streak',coalesce(v_account.best_safety_streak,0),
    'next_level_xp',case when coalesce(v_account.level,1) >= 50 then null
      else (coalesce(v_account.level,1)::bigint - 1) * 100
        + 25 * (coalesce(v_account.level,1)::bigint - 1)
          * (coalesce(v_account.level,1)::bigint - 2) / 2
        + 100 + 25 * (coalesce(v_account.level,1)::bigint - 1) end,
    'events',coalesce((select jsonb_agg(jsonb_build_object(
      'type',e.event_type,'xp',e.xp_delta,'tokens',e.motion_token_delta,
      'at',e.occurred_at,'category',e.safe_metadata->>'category',
      'new_level',e.safe_metadata->'new_level',
      'new_rank',e.safe_metadata->>'new_rank')
      order by e.occurred_at desc) from (select * from private.progression_events
        where user_id = v_user order by occurred_at desc limit 20) e),'[]'::jsonb),
    'badges',coalesce((select jsonb_agg(b.badge_key order by b.awarded_at)
      from private.progression_badges b where b.user_id = v_user),'[]'::jsonb),
    'goals',jsonb_build_array(
      jsonb_build_object('key','weekly_job','title','Complete 1 job this week',
        'progress',(select count(*) from private.progression_events e
          where e.user_id = v_user and e.event_type = 'completed_job'
            and e.occurred_at >= pg_catalog.date_trunc('week',now())),'target',1),
      jsonb_build_object('key','monthly_jobs','title','Complete 3 jobs this month',
        'progress',(select count(*) from private.progression_events e
          where e.user_id = v_user and e.event_type = 'completed_job'
            and e.occurred_at >= pg_catalog.date_trunc('month',now())),'target',3),
      jsonb_build_object('key','safety_steps','title','Complete safety check-ins',
        'progress',(select count(*) from private.progression_events e
          where e.user_id = v_user and e.event_type = 'safety_checkins'
            and e.occurred_at >= pg_catalog.date_trunc('month',now())),'target',1),
      jsonb_build_object('key','feedback','title','Leave post-job feedback',
        'progress',(select count(*) from private.progression_events e
          where e.user_id = v_user and e.event_type = 'post_job_review'
            and e.occurred_at >= pg_catalog.date_trunc('month',now())),'target',1)
    ),
    'cosmetics',coalesce((select jsonb_agg(jsonb_build_object(
      'key',c.cosmetic_key,'title',c.title,'cost',c.token_cost,
      'presentation',c.presentation,'owned',u.user_id is not null,
      'equipped',eq.cosmetic_key is not null)
      order by c.token_cost,c.cosmetic_key)
      from private.progression_cosmetics c left join private.progression_unlocks u
        on u.user_id = v_user and u.cosmetic_key = c.cosmetic_key
      left join private.progression_equipped eq
        on eq.user_id = v_user and eq.cosmetic_key = c.cosmetic_key
      where c.active),'[]'::jsonb)
  );
end;
$$;
revoke all on function public.get_my_progression_v1() from public, anon;
grant execute on function public.get_my_progression_v1() to authenticated;

create function public.unlock_progression_cosmetic_v1(p_cosmetic_key text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_cost integer; v_existing text; v_balance integer;
begin
  if v_user is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  if p_request_id is null or p_cosmetic_key is null then
    return jsonb_build_object('ok',false,'code','invalid_request'); end if;
  if not exists (select 1 from public.profiles p where p.id = v_user and p.role = 'teen'
      and p.account_status = 'active') then
    return jsonb_build_object('ok',false,'code','user_role_not_allowed'); end if;
  insert into private.progression_accounts(user_id) values (v_user) on conflict do nothing;
  select motion_tokens_balance into v_balance from private.progression_accounts
    where user_id = v_user for update;
  select cosmetic_key into v_existing from private.progression_unlocks
    where user_id = v_user and request_id = p_request_id;
  if v_existing is not null then
    return jsonb_build_object('ok',v_existing = p_cosmetic_key,
      'replayed',true,'code',case when v_existing = p_cosmetic_key then null else 'request_conflict' end);
  end if;
  if exists (select 1 from private.progression_unlocks
      where user_id = v_user and cosmetic_key = p_cosmetic_key) then
    return jsonb_build_object('ok',true,'already_owned',true); end if;
  select token_cost into v_cost from private.progression_cosmetics
    where cosmetic_key = p_cosmetic_key and active;
  if v_cost is null then return jsonb_build_object('ok',false,'code','cosmetic_unavailable'); end if;
  if v_balance < v_cost then return jsonb_build_object('ok',false,'code','insufficient_tokens'); end if;
  insert into private.progression_unlocks(user_id,cosmetic_key,request_id)
    values (v_user,p_cosmetic_key,p_request_id);
  insert into private.progression_events(user_id,event_type,source_type,source_id,
    xp_delta,motion_token_delta,idempotency_key)
    values (v_user,'cosmetic_unlock','cosmetic',p_request_id,0,-v_cost,
      'cosmetic_unlock:' || v_user || ':' || p_request_id);
  update private.progression_accounts set motion_tokens_balance = motion_tokens_balance - v_cost,
    updated_at = now() where user_id = v_user;
  return jsonb_build_object('ok',true,'balance',v_balance-v_cost);
end;
$$;
revoke all on function public.unlock_progression_cosmetic_v1(text,uuid) from public, anon;
grant execute on function public.unlock_progression_cosmetic_v1(text,uuid) to authenticated;

create function public.equip_progression_cosmetic_v1(p_cosmetic_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_presentation text;
begin
  if v_user is null then return jsonb_build_object('ok',false,'code','authentication_required'); end if;
  if not exists (select 1 from public.profiles p where p.id = v_user
      and p.role = 'teen' and p.account_status = 'active') then
    return jsonb_build_object('ok',false,'code','user_role_not_allowed'); end if;
  select c.presentation into v_presentation
  from private.progression_cosmetics c join private.progression_unlocks u
    on u.cosmetic_key = c.cosmetic_key and u.user_id = v_user
  where c.cosmetic_key = p_cosmetic_key and c.active;
  if v_presentation is null then
    return jsonb_build_object('ok',false,'code','cosmetic_not_owned'); end if;
  insert into private.progression_equipped(user_id,presentation,cosmetic_key)
    values (v_user,v_presentation,p_cosmetic_key)
  on conflict (user_id,presentation) do update set
    cosmetic_key = excluded.cosmetic_key,equipped_at = now();
  return jsonb_build_object('ok',true,'presentation',v_presentation);
end;
$$;
revoke all on function public.equip_progression_cosmetic_v1(text) from public,anon;
grant execute on function public.equip_progression_cosmetic_v1(text) to authenticated;

create function public.admin_award_progression_correction_v1(
  p_user_id uuid, p_xp integer, p_request_id uuid, p_reason text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_admin uuid := auth.uid();
  v_event uuid;
  v_account private.progression_accounts%rowtype;
begin
  if v_admin is null or not public.is_admin() then
    return pg_catalog.jsonb_build_object('ok',false,'code','admin_required');
  end if;
  if p_user_id is null or p_request_id is null or p_xp is null
    or p_xp <= 0 or p_xp > 100000
    or p_reason is null or pg_catalog.length(pg_catalog.btrim(p_reason)) not between 8 and 160 then
    return pg_catalog.jsonb_build_object('ok',false,'code','invalid_request');
  end if;
  if not exists (select 1 from public.profiles p
      where p.id = p_user_id and p.role = 'teen') then
    return pg_catalog.jsonb_build_object('ok',false,'code','teen_required');
  end if;
  v_event := private.progression_award(
    p_user_id,'admin_correction','correction',p_request_id,p_xp,
    'admin_correction:' || p_user_id || ':' || p_request_id,
    pg_catalog.btrim(p_reason)
  );
  if v_event is not null then
    update private.progression_events set safe_metadata = safe_metadata
      || pg_catalog.jsonb_build_object('admin_id',v_admin)
    where id = v_event;
  end if;
  select * into v_account from private.progression_accounts where user_id = p_user_id;
  return pg_catalog.jsonb_build_object(
    'ok',true,'replayed',v_event is null,'xp_total',v_account.xp_total,
    'level',v_account.level,'rank',v_account.rank,
    'motion_tokens_balance',v_account.motion_tokens_balance
  );
end;
$$;
revoke all on function public.admin_award_progression_correction_v1(uuid,integer,uuid,text)
  from public,anon;
grant execute on function public.admin_award_progression_correction_v1(uuid,integer,uuid,text)
  to authenticated;

revoke all on function private.progression_level(bigint), private.progression_rank(integer),
  private.progression_award(uuid,text,text,uuid,integer,text,text),
  private.progression_complete_job(uuid), private.progression_on_application_completed(),
  private.progression_on_review() from public, anon, authenticated;
