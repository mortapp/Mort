# MORT AI Safety

Status: server controls and deterministic safety fallback implemented; external provider disabled.

- No AI provider key is present in Flutter, Expo, Swift, docs, or release artifacts.
- `ai-support` is authenticated and uses an atomic server reservation before any provider client can be created.
- Server-owned controls set request quotas, concurrency, timeout, model allowlist, maximum input/output, and daily/monthly cost ceilings.
- Provider budget values remain zero until an owner configures and verifies the server environment.
- Prompt injection, applicant ranking, payment/legal decisions, immediate danger, and sensitive-data requests are diverted to deterministic responses.
- The assistant cannot run raw SQL, perform money movement, issue bans, decide disputes, or access unrestricted records.
- Usage events and outcomes are server-owned. Human escalation and non-AI support remain available.

Remote evidence: `qa-ai-cost-prompt-boundary.mjs`. Provider-generated answers were not tested because external AI is intentionally off.
