# MORT Support Chatbot Security Review

Date: 2026-07-29  
Project: `rakjydmgwwgtdislanbt`

## Security Result

The implemented support-assistant boundary passed remote RLS, cross-user,
private-storage, rate-limit, handoff, and adversarial classification tests. This
review does not certify the whole product as production-ready.

## Access Control

- Supabase Auth sessions are verified server-side for every user endpoint.
- All 16 support tables have RLS and forced RLS.
- Owners can read only their conversations, messages, attachments, feedback,
  and preferences.
- Guardians do not inherit teen support access.
- Staff direct table reads remain blocked; approved staff RPCs write audit rows.
- Internal cleanup, evaluation, and global-budget functions require the
  gateway-validated service role.
- Service-role, database, provider, and access-token secrets are absent from
  Flutter and from the packaged source archive.

## Input And Output Controls

- Request bodies are capped at 24 KiB and parsed as JSON objects.
- UUID, enum, string length, integer, MIME, extension, size, checksum, and route
  values are allowlisted or bounded.
- Provider input is allowed only after deterministic classification.
- Level 2 and 3 messages cannot reach the provider.
- Provider output is untrusted text, scanned for prohibited authority claims,
  and cannot execute tools.
- Tools can only open approved app routes or create a confirmed human handoff.
- Logs contain event codes, safe metadata, and correlation IDs, not raw message
  text or credentials.

## Abuse And Cost Controls

- Ordinary chat: 30 requests per 10 minutes per user.
- Safety chat: separate 60 per 10 minutes per user.
- Provider calls: 5 per day per user and 500 per day globally.
- Handoffs: 5 per hour; attachment authorization: 8 per hour.
- KB, tool, feedback, download, and admin-copilot endpoints have independent
  database counters.
- Repeated ordinary messages are rejected.
- Safety, reporting, blocking, and emergency guidance remain available when
  ordinary chat is throttled.

## Attachment Security

- Bucket is private and has no public object URL path.
- Opaque owner-bound manifests authorize uploads.
- Images are selected without full metadata and re-encoded in Flutter.
- Server validates MIME, extension, byte count, SHA-256, purpose, status, and
  expiration before accepting a manifest.
- Signed download expiry was verified with a real byte roundtrip and a
  one-second URL that failed after 2.1 seconds.

## Real Test Evidence

- Four isolated users proved owner, adult, guardian, and admin boundaries.
- Anonymous Edge access returned 401.
- Cross-user conversation and ticket reads returned no rows.
- Ordinary staff table access returned no rows; audited RPC access succeeded.
- Prompt injection, cross-user exfiltration, and job PIN requests were level 2
  and provider-ineligible.
- Immediate danger was level 3, opened a real human ticket, and made no dispatch
  claim.
- 31 existing Supabase regression scripts passed after deployment.
- Source, staged tree, ZIP, APK, and AAB scans found no available secret value.

## Residual Risks

- Deterministic text rules are defense in depth, not a complete abuse detector.
  Human safety review and monitoring are still required.
- The Anthropic path has not been exercised because no key/model is configured.
  Enabling it requires model-specific prompt-injection, privacy, latency, cost,
  and response-quality tests.
- A 500/day global provider cap is a starting control and needs operational
  tuning based on real closed-test traffic.
- Existing older `ai-support` and `ai-safety` endpoints remain separate and were
  preserved; their continued need should be reviewed before public launch.
- CORS is permissive while JWT and RLS enforce access. A hosted-web origin policy
  should be narrowed if browser deployment requirements permit it.
- Moderation staffing, incident SLAs, alerting, and abuse trend review are
  operational blockers rather than code-complete controls.
- Supabase leaked-password protection is a deferred, plan-limited security
  enhancement, not an unresolved code bug. When Supabase is upgraded to Pro,
  enable leaked-password protection immediately and rerun Auth security
  advisors.

