create or replace function private.is_support_circle_owner(
  p_circle_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.support_circles circle_record
    where circle_record.id = p_circle_id
      and circle_record.teen_id = p_user_id
  );
$$;

create or replace function private.is_active_support_circle_member(
  p_circle_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.support_circle_members member
    where member.circle_id = p_circle_id
      and member.member_user_id = p_user_id
      and member.status = 'active'
      and member.revoked_at is null
  );
$$;

create or replace function private.can_view_support_member_record(
  p_member_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.support_circle_members member
    join public.support_circles circle_record on circle_record.id = member.circle_id
    where member.id = p_member_id
      and (
        (
          member.member_user_id = p_user_id
          and member.status = 'active'
          and member.revoked_at is null
        )
        or circle_record.teen_id = p_user_id
      )
  );
$$;

grant execute on function private.is_support_circle_owner(uuid, uuid),
  private.is_active_support_circle_member(uuid, uuid),
  private.can_view_support_member_record(uuid, uuid)
to authenticated;

drop policy support_circles_participant_select on public.support_circles;
create policy support_circles_participant_select
on public.support_circles for select to authenticated
using (
  teen_id = (select auth.uid())
  or private.is_active_support_circle_member(id, (select auth.uid()))
);

drop policy support_circle_members_scoped_select on public.support_circle_members;
create policy support_circle_members_scoped_select
on public.support_circle_members for select to authenticated
using (
  member_user_id = (select auth.uid())
  or private.is_support_circle_owner(circle_id, (select auth.uid()))
);

drop policy support_circle_permissions_scoped_select on public.support_circle_permissions;
create policy support_circle_permissions_scoped_select
on public.support_circle_permissions for select to authenticated
using (
  private.can_view_support_member_record(member_id, (select auth.uid()))
);

drop policy support_circle_alerts_recipient_or_owner on public.support_circle_alert_events;
create policy support_circle_alerts_recipient_or_owner
on public.support_circle_alert_events for select to authenticated
using (
  teen_id = (select auth.uid())
  or private.can_view_support_member_record(member_id, (select auth.uid()))
);
