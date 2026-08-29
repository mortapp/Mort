-- Preserve the onboarding-routing result of accounts that the legacy server
-- contract had already recorded as complete before onboarding v2 was deployed.
--
-- The cutover population is selected once from two agreeing legacy server
-- signals: the protected profiles.onboarding_completed flag and the legacy
-- onboarding_progress terminal state. Hosted preflight on 2026-08-28 proved
-- that all 24 completed profiles satisfy both signals and that no successful
-- v2 completion exists. This table is not a legal-acceptance, verification,
-- role, moderation, premium, or marketplace authority.

create table private.onboarding_v2_legacy_completion_compatibility (
  user_id uuid primary key
    references public.profiles(id) on delete cascade,
  grandfathered_at timestamptz not null default now(),
  source_version text not null
    check (source_version = 'pre_v2_20260828023033')
);

comment on table private.onboarding_v2_legacy_completion_compatibility is
'Frozen server-only snapshot of users completed under the legacy onboarding contract before onboarding v2. Onboarding routing only; legal reconsent and all other authorization remain separate.';
comment on column private.onboarding_v2_legacy_completion_compatibility.user_id is
'Legacy-completed account identifier. Deleted automatically with the profile.';
comment on column private.onboarding_v2_legacy_completion_compatibility.source_version is
'Immutable cutover identifier; never a client-supplied completion claim.';

alter table private.onboarding_v2_legacy_completion_compatibility
  enable row level security;
alter table private.onboarding_v2_legacy_completion_compatibility
  force row level security;

revoke all on table private.onboarding_v2_legacy_completion_compatibility
from public, anon, authenticated, service_role;
grant select on table private.onboarding_v2_legacy_completion_compatibility
to service_role;

insert into private.onboarding_v2_legacy_completion_compatibility (
  user_id,
  source_version
)
select
  profile.id,
  'pre_v2_20260828023033'
from public.profiles profile
join public.onboarding_progress progress
  on progress.user_id = profile.id
where profile.onboarding_completed
  and progress.current_step = 'complete'
  and progress.completed_steps @> array['complete']::text[];

-- Keep the original canonical evaluator intact and put the frozen compatibility
-- decision in a narrow wrapper. Historically incomplete and all future users
-- continue through the same canonical persisted-data evaluation as before.
alter function private.evaluate_onboarding_v2(uuid)
rename to evaluate_onboarding_v2_canonical;

comment on function private.evaluate_onboarding_v2_canonical(uuid) is
'Canonical persisted-data onboarding-v2 evaluator for historically incomplete and future accounts.';

create function private.evaluate_onboarding_v2(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_revision timestamptz;
begin
  if exists (
    select 1
    from private.onboarding_v2_legacy_completion_compatibility compatibility
    where compatibility.user_id = p_user_id
  ) then
    select profile.role::text, profile.updated_at
    into v_role, v_revision
    from public.profiles profile
    where profile.id = p_user_id;

    return jsonb_build_object(
      'ok', true,
      'completed', true,
      'active_step', 'complete',
      'primary_steps', array[
        'account',
        'work_preferences',
        'safety_support',
        'review'
      ],
      'completed_steps', array[
        'account',
        'work_preferences',
        'safety_support',
        'review'
      ],
      'missing_requirements', array[]::text[],
      'role', v_role,
      'revision', v_revision
    );
  end if;

  return private.evaluate_onboarding_v2_canonical(p_user_id);
end;
$$;

revoke all on function private.evaluate_onboarding_v2_canonical(uuid)
from public, anon, authenticated, service_role;
revoke all on function private.evaluate_onboarding_v2(uuid)
from public, anon, authenticated, service_role;

comment on function private.evaluate_onboarding_v2(uuid) is
'Returns frozen onboarding completion for the pre-v2 compatibility snapshot; otherwise delegates to canonical persisted-data v2 evaluation. It grants no legal, role, verification, moderation, premium, or marketplace authority.';
