# Account deletion rollout and rollback

This is not release approval. Production project `jxbnrkasktbhtiujkhay` and hosted QA project `ckcxakhxqlkhppsxxjhv` must not share credentials, callback allowlists, provider fixtures or queues. Use approved staged changes only.

## Dependencies and rollout

1. Pause any deletion scheduler and confirm no worker has an active lease. Record queue counts, current grants, current function definitions, image/source hashes, Storage policies and current deployment settings. No migration in this change creates a schedule.
2. On a production baseline without a queue, `20261119100000_account_deletion_processor_port.sql` requires `public.profiles`, its role/status schema, `pgcrypto` in `extensions`, the Auth schema and Storage catalog. Do not apply it over hosted QA's pre-existing queue. The port and its follow-up must become externally available together, not as separate live rollout stages.
3. `20261122151000_deletion_lease_identity_and_receipt.sql` requires the queue, its existing service function signatures, `auth.sessions`, `auth.mfa_factors`, and both Storage ownership columns. Validate protected relations and relation columns on the intended target. `20261122150000_staff_role_active_account.sql` is independently deployable with existing `private.user_roles`, `public.profiles`, and `public.mort_role`; retain the existing signature and ACL.
4. Use `supabase/production-baseline-migrations/validation/account_deletion_release_gate.sql`. Expected privileges, in query order: true, false, true, false, true, false, false. Compare every restrictive FK with its actual disposition before authorizing deletion for populated accounts. A hold is not an approved final retention decision. An unexpected restrictive FK or unsafe Storage bucket must halt completion, never trigger generic cascading deletes.
5. Deploy the reviewed worker only after verifying the scoped project, secret binding and rollback package. Give the invocation secret only to the scheduler or named backend ops owners. Use a real GoTrue session for deletion, cancellation and receipt verification. For Apple-authenticated accounts, verify the provider token revocation process before release; deleting Supabase Auth does not prove Apple revocation.
6. Allowlist the precise `/account-deletion/confirm` absolute URL and test verified email delivery, same-browser PKCE, expiry, no creation of accounts, and completion/cancellation notices. Verify the public path signed out and the actual native in-app path on both signed candidates. Enable approved operational scheduling only after provider, safety retention and device evidence is complete.

## Safe rollback

- Pause scheduling, block new request issuance at the server and show an actionable status/fallback. Never roll back to a worker that accepts a generic Auth error as proof of identity absence.
- Preserve queue rows, receipts, legal holds, audit information and all retained content. Use a forward corrective migration; do not run the base port's destructive drop example on a populated database. Do not cancel or mark requests completed in bulk.
- Before a retry, reconcile current Auth identity, any active session, owned Storage and the specific lease. A successfully removed Auth identity or stored file cannot be restored by reversing a migration; consult the independently tested backup and retention process.
- Keep the active-staff check during an unrelated rollback. Any break-glass operator action needs a named owner, case record, narrow scope and independently reviewed evidence.
