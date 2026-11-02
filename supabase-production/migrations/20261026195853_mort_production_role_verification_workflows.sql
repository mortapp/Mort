
-- Role/verification review primitives. These do not fake or auto-approve any verification.
create or replace function public.mort_review_verification_case(
  p_case_id uuid,
  p_status public.mort_verification_status,
  p_note text default null,
  p_expires_at timestamptz default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    raise exception 'Authorized verification reviewer required';
  end if;
  if p_status not in ('verified'::public.mort_verification_status,
                      'rejected'::public.mort_verification_status,
                      'needs_review'::public.mort_verification_status,
                      'expired'::public.mort_verification_status) then
    raise exception 'Invalid review outcome';
  end if;
  update public.verification_cases
  set status=p_status, reviewer_id=v_user,
      reviewer_note=nullif(btrim(p_note),''),
      reviewed_at=now(), expires_at=p_expires_at, updated_at=now()
  where id=p_case_id;
  if not found then raise exception 'Verification case not found'; end if;
  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values (v_user,'verification_reviewed','verification_case',p_case_id::text,
          nullif(btrim(p_note),''),jsonb_build_object('status',p_status));
  return p_case_id;
end;
$$;

create or replace function public.mort_review_role_request(
  p_request_id uuid,
  p_approve boolean,
  p_reason text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_req public.role_requests%rowtype;
begin
  if v_user is null or not private.has_staff_role(array['admin']::public.mort_role[]) then
    raise exception 'Administrator role required for role approval';
  end if;

  select * into v_req from public.role_requests where id=p_request_id for update;
  if not found or v_req.status <> 'pending' then
    raise exception 'Pending role request not found';
  end if;

  if p_approve then
    if v_req.requested_role='teen'::public.mort_role then
      if not exists (
        select 1 from public.verification_cases vc
        where vc.user_id=v_req.user_id and vc.verification_type='age'
          and vc.status='verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at>now())
      ) or not exists (
        select 1 from public.verification_cases vc
        where vc.user_id=v_req.user_id and vc.verification_type='school_id'
          and vc.status='verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at>now())
      ) or not exists (
        select 1 from public.verification_cases vc
        where vc.user_id=v_req.user_id and vc.verification_type='school_email'
          and vc.status='verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at>now())
      ) then
        raise exception 'Teen approval requires verified age, school ID, and school email';
      end if;
    elsif v_req.requested_role='adult'::public.mort_role then
      if not exists (
        select 1 from public.verification_cases vc
        where vc.user_id=v_req.user_id and vc.verification_type='identity'
          and vc.status='verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at>now())
      ) then
        raise exception 'Adult approval requires verified identity';
      end if;
    else
      raise exception 'Unsupported requested role';
    end if;

    update public.profiles
    set role=v_req.requested_role, account_status='active', updated_at=now()
    where id=v_req.user_id;
    if not found then raise exception 'Profile not found'; end if;
    update public.role_requests
    set status='approved', reviewed_at=now(), reviewed_by=v_user,
        review_note=nullif(btrim(p_reason),'')
    where id=p_request_id;
  else
    update public.role_requests
    set status='rejected', reviewed_at=now(), reviewed_by=v_user,
        review_note=nullif(btrim(p_reason),'')
    where id=p_request_id;
  end if;

  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values (v_user,case when p_approve then 'role_request_approved' else 'role_request_rejected' end,
          'role_request',p_request_id::text,nullif(btrim(p_reason),''),
          jsonb_build_object('user_id',v_req.user_id,'requested_role',v_req.requested_role));
  return p_request_id;
end;
$$;

revoke all on function public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamptz) from public, anon;
revoke all on function public.mort_review_role_request(uuid,boolean,text) from public, anon;
grant execute on function public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamptz) to authenticated;
grant execute on function public.mort_review_role_request(uuid,boolean,text) to authenticated;
