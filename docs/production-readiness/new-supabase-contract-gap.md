# New Supabase production-readiness gap

**Audit date:** 2026-10-27  
**Flutter branch:** `codex/mort-flutter-uiux-foundation`  
**Destination project:** `jxbnrkasktbhtiujkhay` (`mort p`, `us-east-2`)

## Current evidence

- The destination is `ACTIVE_HEALTHY`, but has 0 Auth users, 0 profiles, 0 jobs, and 0 payment records. All 20 listed tables report 0 rows.
- The destination has 5 recorded migrations, 8 public database functions, and 0 deployed Edge Functions.
- A static scan of Flutter data repositories finds at least 37 literal table references and 51 literal RPC references. Only `profiles`, `jobs`, and `notifications` overlap by table name with the destination. The destination's functions use the `mort_*` names and do not provide the Flutter client's expected RPC contract; in particular, `get_release_mode_status` is absent.
- The 5 destination migration sources are not present in the local `supabase/migrations` directory. That directory contains 248 migrations for the older application schema; it is not safe to replay those against the destination as a substitute.
- The connected Supabase account lists only the destination. `get_project(rakjydmgwwgtdislanbt)` returns a permission error, so the old production source cannot currently be inventoried or copied.

## Cutover decision

Do not switch production traffic or claim the data migration is complete. The destination has no user or marketplace data, the existing Flutter client does not match its schema/RPC contract, and the old source project is inaccessible to the connected account. No destination data or schema was changed during this audit.

The next safe migration step requires access to the old production project and its real migration history. Then reconcile the destination against the app contract, establish repeatable schema sources, and start a verified low-risk batch before touching user identities or live writes.

## Security advisory

Supabase reports `private.user_roles` with RLS disabled. A direct grants query found no `anon` or `authenticated` table grants, but the project still has a critical RLS advisory. The suggested hardening statement is:

```sql
ALTER TABLE "private"."user_roles" ENABLE ROW LEVEL SECURITY;
```

Enabling RLS without an intentional policy set blocks access for roles subject to RLS. This migration was not applied; the user must choose whether and which policies belong on this authorization table.
