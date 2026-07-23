# Supabase Live Setup Warnings

Before running any Supabase command, decide whether you are using a fresh project or reconciling the existing project.

Safe commands for a fresh project:

```powershell
supabase login
supabase link --project-ref <fresh-project-ref>
supabase db push
supabase functions deploy send-push
```

Commands to avoid on the current mismatched project unless you have a backup and reviewed migration:

```powershell
supabase db reset
supabase db push
drop schema public cascade;
truncate table public.profiles cascade;
```

Do not place `SUPABASE_SERVICE_ROLE_KEY` in `.env.local` for Expo. Keep it in Supabase Edge Function secrets only.
