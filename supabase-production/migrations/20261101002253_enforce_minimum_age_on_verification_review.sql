-- Staff cannot approve any verification case for an account whose DOB is
-- missing or establishes an age below MORT's minimum of 13.

CREATE OR REPLACE FUNCTION public.mort_review_verification_case(p_case_id uuid, p_status mort_verification_status, p_note text DEFAULT NULL::text, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  if p_status = 'verified'::public.mort_verification_status and exists (
    select 1
    from public.verification_cases vc
    join public.profiles profile on profile.id = vc.user_id
    where vc.id = p_case_id
      and (
        profile.date_of_birth is null
        or extract(year from age(current_date, profile.date_of_birth)) < 13
      )
  ) then
    raise exception 'minimum_age_verification_required';
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
$function$
;
