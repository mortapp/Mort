# MORT Feature Platform Architecture

## Authority Model

Hosted Supabase is authoritative for identity, role, age/account status, jobs, applications, participant messaging, guardian links, reports, blocks, evidence metadata, moderation, notification records, and entitlement cache. SwiftUI and Flutter Web are untrusted clients. Any action that changes another user's access, job state, application state, evidence decision, verification state, moderation state, or paid entitlement requires RLS plus a checked server contract.

## Product Layers

| Layer | Responsibility | Release rule |
| --- | --- | --- |
| Identity and account | Supabase Auth, DOB-derived age band, role, restriction state | Never use client-only authorization or fake IDs |
| Safety policy | Prohibited work, blocks, reports, Safety Ping, age/jurisdiction gates | Free, explainable, reviewable, and tested for bypass |
| Marketplace core | Jobs, applications, scheduling, messaging, proof, reviews | State transitions are checked, auditable, and idempotent |
| Private media | Avatar, proof, verification, report evidence | Private buckets, authorized paths, short-lived URLs, retention rules |
| Engagement | Saved searches, reminders, repeat work, goals, history | Optimize useful outcomes, not screen time or pressure |
| Monetization | RevenueCat offerings/entitlements and AdMob placements | Optional only; SDK/server truth; no fake success; no safety paywall |
| Automation | Rules and server-mediated AI | Minimal inputs, no client provider key, editable output, human final authority |
| Operations | Admin queues, evidence, assignment, appeal, support, audit | Least privilege, attributed actions, staffing and SLA ownership |
| Observability | Adoption, outcome, safety, latency, failure, abuse | No sensitive payloads or exact teen location in analytics |

## Cross-Client Contract

One registry feature represents one capability across platforms. Shared models should preserve backend enum/state meaning, use typed RPC payloads, surface structured errors, and avoid platform-specific forks in safety logic. Native-only integrations such as APNs, PhotosPicker, RevenueCat, AdMob, ATT, and haptics remain one product capability with a web-safe fallback.

## Required States

Every interactive feature needs a defined initial, loading, empty, content, validation, success, error, retry, cancellation, blocked/restricted, offline/interrupted, accessibility, and authorization state where applicable. A route or button without its authority and recovery behavior is not implementation evidence.

## Data-Change Rules

- Additive migrations only for this program of work.
- Backup remote metadata and data before change.
- Index foreign-key and policy hot paths based on access patterns.
- Bind security-definer functions to the caller, set a safe search path, restrict grants, and check role/ownership/block/account state explicitly.
- Use append-only event records for high-impact decisions.
- Order multi-row locks consistently and make repeated client actions idempotent.
- Run isolated multi-user RLS, storage, abuse, concurrency, and load-sanity QA.

## Delivery Gates

Flutter Web can validate hosted data flows and responsive PWA behavior. It cannot validate APNs, native purchases, AdMob, ATT/UMP, Swift concurrency, Keychain behavior, camera metadata, or real-device accessibility. Those remain Mac, physical-iPhone, TestFlight, dashboard, legal, and operational gates.
