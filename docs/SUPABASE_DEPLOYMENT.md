# Supabase Deployment for Flutter MORT

Use [Flutter Supabase Setup](SUPABASE_SETUP.md) for the current fresh-project workflow. It covers the guarded migration dry-run, schema and advisor checks, Flutter's public client configuration, and server-only secrets.

## Deployment order

1. Create the new Supabase project and verify its project reference.
2. Apply the repository migrations with `scripts/apply-fresh-supabase.ps1`; inspect the dry-run before the script applies them.
3. Review migration history, RLS, storage policies, and database advisors.
4. Reconcile the required Edge Functions, auth settings, storage buckets, scheduled jobs, and server-side secrets against the current Flutter app and migrations.
5. Run backend regression checks and verify authenticated user isolation on the new project.
6. Configure Flutter with the project's HTTPS URL and public anon or publishable key, then run the release-profile validation and app smoke checks.

The Supabase service-role or secret API key is server-only. It must not be embedded in the Flutter app or any Android/iOS artifact. Public client keys do not replace RLS or authorization checks.

Google Play production access and Supabase backend readiness are separate. A public-production AAB remains gated on the backend, app release profile, signing, and operational checks passing for the new project.
