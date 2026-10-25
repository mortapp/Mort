# MORT Remote Push Scheduler Design

## Intent

Make queued MORT push notifications runnable by adding a backend-owned schedule for the existing `send-push` Edge Function. The schedule must remain inert until release policy, runtime configuration, and the required Vault credentials are present.

## Current State

- Flutter registration and the sender are gated by both release policy and the `remote_push_enabled` runtime switch.
- The authenticated push-status RPC stays read-only for PostgREST and reports missing preferences as opted out without creating a row.
- The hosted `send-push` Edge Function is active, has JWT verification enabled, and independently requires `x-mort-push-secret`.
- Hosted `pg_cron` is enabled, but `pg_net` is disabled, there is no push schedule, and there are no FCM or push-named Vault secrets.
- The Edge Function accepts an empty JSON batch request and checks the effective server push gate before it claims events.

## Goals

- Add an idempotent one-minute Supabase Cron job that invokes the existing sender through `pg_net`.
- Read the project URL, legacy anon JWT, and sender invoke secret from Supabase Vault at execution time.
- Make the scheduler return without network activity if either push gate is off or any required Vault value is missing.
- Keep push-status reads compatible with PostgREST's read-only transaction mode and avoid write-on-read preference initialization.
- Keep all credential values out of migrations, logs, generated artifacts, and source control.
- Add regression coverage proving the schedule exists, is not publicly executable, and is inert with missing gates or credentials.
- Document exact owner setup and runtime verification steps.

## Non-Goals

- Enabling hosted remote push, changing public release policy, or uploading/deploying database changes.
- Creating, rotating, or copying any Firebase, Supabase, or Play credential.
- Replacing the current Edge Function or weakening its JWT/custom-secret checks.
- Claiming real-device FCM delivery before the owner configures Firebase credentials and completes Android/iOS delivery checks.

## Approaches Considered

1. **Supabase `pg_cron` + `pg_net` + Vault (chosen):** the hosted database schedules the worker and reads credentials only when a permitted run is due. This uses the project's existing Cron service and keeps invocation credentials outside Git.
2. **GitHub Actions schedule:** a runner would need long-lived function credentials and introduces repository/environment availability and secret-custody dependencies for routine delivery. It is less suitable for a database-backed notification queue.
3. **Database-only delivery:** Postgres cannot perform Firebase's authenticated FCM send without an HTTP worker, so it cannot replace the existing Edge Function.

## Design

- A new migration enables `pg_net`, creates a `SECURITY DEFINER` helper in the non-exposed `private` schema with an empty `search_path`, and revokes execution from `PUBLIC`, `anon`, `authenticated`, and `service_role`.
- The helper calls the existing `private.push_delivery_available()` gate. It returns `NULL` without making a request when the effective release/runtime policy is false or when Vault lacks any required value.
- When available, the helper sends an empty JSON object to `/functions/v1/send-push` with the Vault-backed anon JWT in `apikey` and `Authorization`, plus the existing `x-mort-push-secret` header. It never reads or sends the service-role key.
- The migration creates or replaces the `mort-send-push` job at one-minute intervals. The job invokes only the private helper; it cannot enable delivery by itself.
- FCM project ID, service account email, and service account private key remain Edge Function secrets. Missing FCM values are handled by the existing function before queue events are claimed.
- The owner runbook will document Vault secret names `mort_supabase_url`, `mort_supabase_anon_key`, and `mort_send_push_invoke_secret`. Secret values are entered through the protected Supabase Dashboard/SQL session and are never committed.
- The project URL and current legacy anon JWT come from the Supabase project's API settings. The invoke secret is copied from the existing protected `SEND_PUSH_INVOKE_SECRET` Edge Function setting; the implementation never reads its value. Do not use a service-role key for scheduled invocation.
- SQL regression tests will verify disabled-policy and missing-Vault no-ops, plus the configured path queueing one `pg_net` request inside a transaction that is rolled back before the HTTP worker can run. They will not change hosted state or make a network request.

## Activation Sequence

1. Reconcile the hosted Supabase migration history through the owner's approved recovery process before applying the migration; the deployed project currently has migration drift relative to this checkout. This implementation does not guess or repair that history.
2. Apply the scheduler migration.
3. Add the three Vault values from approved protected sources and the three FCM Edge Function secrets.
4. Verify the job is active, verify the function receives authorized requests without processing events while the delivery gate is off, and complete real-device delivery checks.
5. Only then may the owner separately enable hosted release policy/runtime push flags.

## Acceptance

- Local SQL tests prove one schedule is installed and repeated migration application does not create duplicates.
- With push disabled, helper execution makes no HTTP request even if Vault values exist.
- With push enabled but Vault values absent, helper execution makes no HTTP request.
- Public roles cannot execute the private scheduler helper.
- Existing `send-push` JWT, invoke-secret, and release/runtime gates remain unchanged.
- Push status can be read in a read-only transaction; a missing preference returns opted-out state and persists no preference row.
- `docs/MORT_FIREBASE_PUSH_OWNER_SETUP.md` describes the new Vault requirements without containing credentials.
- No production database or Edge Function configuration is mutated by this implementation.
