# MORT Schema Drift Report

Audit date: 2026-07-22

`npx supabase migration list --linked` reports every local migration paired with a remote migration through `20260722225742`. No local-only or remote-only migration was reported.

The final migration was created with Supabase CLI, dry-run before deployment, pushed to `rakjydmgwwgtdislanbt`, and confirmed in the linked list. It corrects a linter-detected runtime enum assignment without rewriting migration history.

Schema lint at error level returns an empty result. Warning-level lint still reports unused parameters in intentionally disabled identity-provider functions and one support registration parameter. Those warnings do not create schema drift but remain cleanup candidates.

No production restore test was performed. Migration parity is not equivalent to backup recoverability.
