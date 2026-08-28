# MORT Feature Dependency Graph

The graph is architectural, not a claim that every roadmap node is implemented.

```mermaid
flowchart TD
  A[Hosted Supabase Auth and account status] --> B[Role and age authorization]
  B --> C[RLS and checked RPC contracts]
  C --> D[Core jobs, applications, messaging, proof, report, block, Safety Ping]
  D --> E[Trust, profiles, repeat work, optional Guardian Mode]
  D --> F[Private storage and privacy-safe notifications]
  E --> G[Discovery, community, healthy retention]
  F --> H[Admin evidence, appeals, analytics]
  G --> I[Bounded AI assistance and sustainable growth]
  H --> I
  I --> J[Optional RevenueCat and ad perks]
  D --> K[SwiftUI and Flutter Web clients]
  K --> L[Mac compile, physical iPhone, TestFlight, legal and operations gates]
```

## Cross-Cutting Gates

Every release slice requires accessible states, privacy minimization, server authority where needed, abuse tests, observability without sensitive payloads, and rollback/recovery behavior.
