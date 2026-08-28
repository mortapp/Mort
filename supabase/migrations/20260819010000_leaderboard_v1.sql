-- Leaderboard: server-authoritative by construction, not merely by
-- convention. There is deliberately NO stored/mutable "score" column
-- anywhere -- score is computed on every read from data that is already
-- independently hardened: applications.status = 'completed' (can only be
-- set once per application, via the already-tested PIN/proof state
-- machine -- no "replay" is possible because there is no repeatable
-- increment event, just a single immutable status transition), and
-- reviews (reviewer_id <> subject_id is a DB CHECK constraint --
-- self-review is already impossible at the schema level; ratings are
-- 1-5, moderation-gated, blind-reveal-timed). This makes most of the
-- classic leaderboard-forgery attack surface (forged increments, replayed
-- completion events, client-modified score) structurally unavailable
-- rather than merely denied by a policy that could have a bug.
--
-- Never rewards speed (no Quick Accept reaction time signal), volume
-- (no raw job count without verification), hours worked, or job risk.
-- Never exposes exact earnings, exact location, or private teen data --
-- only a computed score, a coarse tier label, and the teen's own chosen
-- display name/avatar (the same information already shown to other
-- participants elsewhere in the app, e.g. on accepted job cards).

alter table public.profiles
  add column if not exists leaderboard_opt_out boolean not null default false;

-- The tier-label helper lives in `private` since it's an implementation
-- detail of the score->badge mapping, not something a client should
-- call directly with an arbitrary score to reverse-engineer thresholds
-- for gaming purposes (thresholds are visible in this migration's source
-- anyway, but there is no reason to expose a public RPC for it). Defined
-- before get_leaderboard_v1, which calls it.
create or replace function private.leaderboard_tier(p_score integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_score >= 200 then 'community_leader'
    when p_score >= 80 then 'trusted_worker'
    when p_score >= 20 then 'rising_star'
    else 'newcomer'
  end;
$$;

-- Public leaderboard: top N eligible teens by computed score. Excludes
-- test/QA accounts, restricted accounts, and anyone who opted out.
create or replace function public.get_leaderboard_v1(p_limit integer default 20)
returns jsonb
language sql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
  with completed_counts as (
    select teen_id, count(*) as completed_count
    from public.applications
    where status = 'completed'
    group by teen_id
  ),
  review_stats as (
    select subject_id,
      count(*) as review_count,
      avg(rating) as average_rating
    from public.reviews
    where moderation_status = 'approved'
      and revealed_at is not null
    group by subject_id
  ),
  scored as (
    select
      profile.id as teen_id,
      profile.display_name,
      profile.avatar_path,
      coalesce(completed.completed_count, 0) as completed_count,
      coalesce(review.review_count, 0) as review_count,
      coalesce(review.average_rating, 0) as average_rating,
      (
        coalesce(completed.completed_count, 0) * 10
        + round(coalesce(review.average_rating, 0) * coalesce(review.review_count, 0))
      )::integer as score
    from public.profiles profile
    left join completed_counts completed on completed.teen_id = profile.id
    left join review_stats review on review.subject_id = profile.id
    where profile.role = 'teen'
      and profile.account_status = 'active'
      and profile.is_test_account = false
      and profile.leaderboard_opt_out = false
      and coalesce(completed.completed_count, 0) > 0
  ),
  ranked as (
    select *, row_number() over (order by score desc, completed_count desc, teen_id) as rank
    from scored
  )
  select jsonb_build_object(
    'ok', true,
    'entries', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'rank', rank,
          'display_name', display_name,
          'avatar_path', avatar_path,
          'score', score,
          'completed_count', completed_count,
          'tier', private.leaderboard_tier(score)
        )
        order by rank
      )
      from ranked
      where rank <= greatest(1, least(p_limit, 50))
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_leaderboard_v1(integer) from public, anon;
grant execute on function public.get_leaderboard_v1(integer) to authenticated;

-- A teen's own private, detailed leaderboard standing -- includes their
-- rank even if they've opted out of the PUBLIC list (so opting out only
-- hides them from others, not from themselves), and their opt-out state.
create or replace function public.get_my_leaderboard_rank_v1()
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_profile public.profiles%rowtype;
  v_completed_count integer;
  v_review_count integer;
  v_average_rating numeric;
  v_score integer;
  v_rank bigint;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null or v_profile.role <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;

  select count(*) into v_completed_count
  from public.applications
  where teen_id = auth.uid() and status = 'completed';

  select count(*), coalesce(avg(rating), 0)
  into v_review_count, v_average_rating
  from public.reviews
  where subject_id = auth.uid()
    and moderation_status = 'approved'
    and revealed_at is not null;

  v_score := (v_completed_count * 10 + round(v_average_rating * v_review_count))::integer;

  select count(*) + 1 into v_rank
  from public.profiles other
  left join (
    select teen_id, count(*) as completed_count
    from public.applications
    where status = 'completed'
    group by teen_id
  ) completed on completed.teen_id = other.id
  left join (
    select subject_id, count(*) as review_count, avg(rating) as average_rating
    from public.reviews
    where moderation_status = 'approved' and revealed_at is not null
    group by subject_id
  ) review on review.subject_id = other.id
  where other.role = 'teen'
    and other.account_status = 'active'
    and other.is_test_account = false
    and other.id <> auth.uid()
    and (
      coalesce(completed.completed_count, 0) * 10
      + round(coalesce(review.average_rating, 0) * coalesce(review.review_count, 0))
    ) > v_score;

  return jsonb_build_object(
    'ok', true,
    'score', v_score,
    'completed_count', v_completed_count,
    'review_count', v_review_count,
    'average_rating', v_average_rating,
    'tier', private.leaderboard_tier(v_score),
    'rank', v_rank,
    'leaderboard_opt_out', v_profile.leaderboard_opt_out
  );
end;
$$;

revoke all on function public.get_my_leaderboard_rank_v1() from public, anon;
grant execute on function public.get_my_leaderboard_rank_v1() to authenticated;

-- Self-service opt-out toggle. A teen controls their own visibility;
-- nobody else (including guardians, for now) can change another user's
-- leaderboard preference through this RPC.
create or replace function public.set_leaderboard_opt_out_v1(p_opt_out boolean)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  update public.profiles
  set leaderboard_opt_out = p_opt_out,
      updated_at = now()
  where id = auth.uid()
    and role = 'teen';
  if not found then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;
  return jsonb_build_object('ok', true, 'leaderboard_opt_out', p_opt_out);
end;
$$;

revoke all on function public.set_leaderboard_opt_out_v1(boolean) from public, anon;
grant execute on function public.set_leaderboard_opt_out_v1(boolean) to authenticated;
