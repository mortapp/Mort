# MORT Observability Architecture

Updated: 2026-07-30

## Status

Privacy-minimized observability is implemented. Sentry crash reporting and
product analytics both default to disabled. No Sentry DSN is configured and no
production crash-free-session claim is made.

## Crash Reporting

- Sentry is behind a provider abstraction and only initializes when both a
  release flag and a valid DSN are supplied.
- Flutter framework, platform dispatcher, root-zone, startup, repository, and
  background failures have distinct safe context tags.
- Exception messages, request data, user objects, screenshots, HTTP bodies,
  print breadcrumbs, user-interaction breadcrumbs, and default PII are removed
  or disabled.
- Stack frames, release, build, environment, fatal state, a generated
  correlation UUID, and fixed-category breadcrumbs remain available for
  diagnosis.

## Operational Events

- The client emits only fixed event types and error codes plus platform,
  version, release stage, network class, and opaque correlation/request IDs.
- Upload, message, job/PIN, deletion, and OAuth failure paths are instrumented.
- Raw operational rows are private, forced-RLS, service-only, and retained for
  90 days.
- Local structured logs use a bounded 100-event ring and a strict safe-key
  allowlist. They are not printed to the console.

## Product Analytics

- Analytics requires both a build-time enable flag and explicit account opt-in.
- Default is opt-out; sign-out clears local consent state immediately.
- Events use a fixed event/surface/outcome taxonomy. Routes are collapsed to a
  first-party surface and never include route UUIDs.
- Raw rows are private, forced-RLS, service-only, and retained for 30 days.
- The admin dashboard exposes aggregate counts only.

## Safe Diagnostics Export

The user-copyable diagnostic document includes app version/build, release,
platform, coarse network class, provider state, non-secret feature flags, and
the latest safe event categories. It excludes account IDs, message/job text,
addresses, coordinates, tokens, device identifiers, proof paths, URLs, provider
responses, and stack exception messages.

## Alert And Dashboard Boundary

- Crash-free sessions, release health, and fatal crash alerts belong in the
  configured Sentry project after owner activation.
- Operational failure rates and product event counts come from aggregate-only
  hosted RPCs.
- No public SLA, staffing response, or monitored alert claim is made until the
  owner configures recipients and completes a real alert drill.

