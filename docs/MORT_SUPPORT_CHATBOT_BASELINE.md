# MORT Support Chatbot Baseline

Date: 2026-07-29  
Repository: `C:\Users\micha\Mort`  
Flutter app: `C:\Users\micha\Mort\flutter_mort`  
Supabase project: `rakjydmgwwgtdislanbt`

## Version Baseline

The source version after secure-session Part A is `0.9.10+100`. Local signed
artifacts exist for 0.9.8, 0.9.9, and 0.9.10. The next unused local source code
is 101, which maps naturally to `0.9.11+101`. Play Console history is not
available through this workspace, so local artifact inspection does not prove
that code 101 is unused in Play Console. That external check remains required
before Phase 12 upload.

## Existing Backend

Reusable support foundations already exist:

- `support_tickets` and `support_ticket_messages`
- private `support_staff_assignments`
- `support_ticket_audit_events`
- `support_evidence_attachments` and `support_evidence_access_events`
- private `support-evidence` bucket, JPEG-only, 4 MiB processed limit
- owner/staff ticket access helper and support staff role checks
- subject-link authorization for jobs, applications, contracts, and disputes
- user RPCs to create/list/read/reply/reopen/request human review
- staff RPCs to list queue/read thread/reply/change status
- idempotent client request IDs and server-side rate-limit calls
- operational alerts for urgent support tickets
- five-minute evidence URL authorization through `support-evidence-url`
- `ai_support_sessions` and `ai-safety` foundations
- MORT Guide consent, conversations, messages, FAQ retrieval, feedback,
  history export/deletion, retention, and provider request budgets
- existing `ai-support` Edge Function using a server-side OpenAI key

The current support RLS was hardened after the initial migration. Direct user
write access to assignment, priority, staff state, audit events, and evidence
review state is not part of the Flutter client workflow. Staff authority comes
from private server assignments rather than Flutter-local role switches.

## Existing Flutter Product

The app already contains:

- Support home with private case history and unauthenticated email fallback
- categorized new-case flow with related-entity links
- ticket thread, quick replies, status, human-review action, and Safety Center
- image picker/camera flow for dispute-linked support evidence
- local image decode/re-encode, size cap, SHA-256, manifest registration,
  submission, and draft cleanup
- admin support queue and authorized ticket detail/reply/status controls
- automated-versus-human message labels
- empty/loading/error handling covered by widget tests
- MORT Guide deterministic FAQ mode and guided human support fallback

The current support UI is a case workflow, not yet the richer conversational
assistant requested by this task. It has no grounded citation cards, helpful or
report controls, typed support actions, typing state driven by the server,
conversation preferences, or unified chat endpoint.

## Requested Model Gap

Requested names that are absent and need additive creation or a compatibility
mapping:

- `support_conversations`
- `support_messages`
- `support_ticket_events` (existing equivalent:
  `support_ticket_audit_events`)
- `support_attachments` (existing support-specific equivalent:
  `support_evidence_attachments`)
- `support_kb_documents`
- `support_kb_chunks`
- `support_ai_feedback`
- `support_ai_incidents`
- `support_ai_evaluations`
- `support_action_audit`
- `support_rate_limits`
- `support_escalation_rules`
- `support_macros`
- `support_retention_jobs`
- `support_user_preferences`

`support_tickets` already exists and must be extended, not recreated. The new
conversation/message tables should link to the existing ticket and preserve
the existing RPCs for backward compatibility. Existing ticket audit and
evidence tables remain authoritative for their older workflows; compatibility
views or dual writes are preferable to destructive renames.

## Edge Function Gap

Existing relevant functions are `ai-support`, `ai-safety`, and
`support-evidence-url`. The requested named endpoints do not yet exist:

- `support-chat`
- `support-intent-classify`
- `support-kb-search`
- `support-create-ticket`
- `support-escalate`
- `support-tool-execute`
- `support-upload-authorize`
- `support-feedback`
- `support-report-ai-response`
- `support-admin-copilot`
- `support-safety-triage`
- `support-retention-cleanup`
- `support-evaluation-runner`

The current `ai-support` implementation is OpenAI-specific. It does not satisfy
the requested Anthropic/deterministic/disabled/mock provider interface and
must not be used as the new client contract. Existing server-only secret
handling and budget RPCs are reusable.

## Security Baseline And Risks

Already present:

- Supabase Auth bearer validation in relevant Edge Functions
- server-owned service role use in Edge Functions only
- private staff assignments and scoped evidence access
- private storage with short-lived signed URLs
- rate-limit infrastructure and AI request reservation
- redaction/safety migrations and no-high-stakes-decision tests
- source and signed-binary secret scans

Required hardening for the new surface:

- runtime schemas and strict body caps on every endpoint
- deterministic safety classification before provider invocation
- per-user/hour, daily, and global AI budgets separate from safety actions
- correlation IDs and redacted structured logs everywhere
- explicit guardian non-access to teen support conversations
- access audit for staff reads, not only writes
- citations limited to approved and published KB rows
- executable/archive/key/card/government-ID attachment rejection
- provider output validation and tool allowlists
- no raw SQL, arbitrary RPC names, or user-selected tools from model output

## Documentation Conflicts

- Some older documents describe MORT Guide as the support assistant, while the
  master task requires a dedicated support chatbot and endpoint set.
- The existing `ai-support` function names OpenAI; the master task specifies a
  `SupportAiProvider` abstraction with Anthropic, deterministic, disabled, and
  mock implementations.
- The existing attachment path accepts only processed JPEG dispute evidence;
  the master task describes broader support attachments but also requires more
  rejection rules. Existing conservative JPEG support should remain the
  default until each additional type is justified.
- Existing queue statuses are operational support states. The requested queue
  labels include issue categories as well as lifecycle states, so they should
  be modeled as queue/category dimensions rather than overloading one status.
- The requested large chatbot research/evaluation counts are explicitly out of
  scope unless backed by real cases. No fabricated research or evaluation rows
  will be generated.

## Phase 0 Verdict

The existing support/ticket/evidence system is reusable and should remain
operational throughout the implementation. The safe path is additive schema,
compatibility RPCs, deterministic safety first, provider-disabled usefulness,
and a Flutter UI that progressively adopts the new conversation API without
removing current human support or evidence workflows.
