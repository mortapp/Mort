# Identity Verification Storage Lockdown

## Current Result

The hosted `identity-evidence` bucket is private. Current catalog verification found zero authenticated INSERT policies and zero authenticated UPDATE policies that target identity evidence. Hosted QA also denied upload, copy/move, delete, list, cross-user access, guardian access, and ordinary-admin access.

No real identity files were used in QA.

## Disabled And Sandbox Rules

- Ordinary users cannot upload identity evidence while disabled.
- Sandbox is a document-free simulation; QA users cannot upload identity evidence.
- There is no client path for government IDs, school IDs, passports, selfies/liveness media, residential evidence, or student numbers.
- Direct metadata inserts and the evidence-registration RPC fail closed.
- Sandbox objects cannot be copied or moved into production paths because no client insert/update path exists.
- Users cannot overwrite an approved object or registered evidence row.
- Bucket/object listing is unavailable to ordinary clients.

## Role Isolation

- Account owners receive only minimized verification status.
- Guardians and Safety Circle members receive no identity evidence access.
- Ordinary admins receive no raw identity evidence access.
- Production evidence review requires both production readiness and an active trained-reviewer record plus a reasoned, time-bounded access grant.
- Those production prerequisites are not configured in the hosted project.

## Retention Boundary

The schema preserves evidence status, access grants, audit events, and preservation controls for a future approved provider workflow. This does not authorize collection today. A production retention/deletion schedule, legal hold procedure, reviewer process, and verified provider deletion API must be approved and tested before any real identity evidence is accepted.

Job-completion proof and incident evidence use separate private buckets and policies. They are not identity documents and remain covered by their existing ownership, participant, moderation, and preservation tests.

