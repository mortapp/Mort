-- pgcrypto is installed in Supabase's extensions schema. Keep that trusted schema
-- explicit for invite generation and hashing while retaining a locked search path.
alter function public.create_guardian_invite_v2(text)
  set search_path = public, extensions, pg_temp;
alter function public.accept_guardian_invite(text)
  set search_path = public, extensions, pg_temp;
alter function public.resend_guardian_invite(uuid)
  set search_path = public, extensions, pg_temp;

