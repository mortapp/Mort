# AI/ML Architecture

## Overview
MORT uses a backend-mediated AI architecture via Supabase Edge Functions. AI logic is NEVER run purely client-side, and no AI provider keys (e.g. OpenAI, Anthropic, Google) are bundled into the Flutter mobile app.

## Components
- **ai-safety**: Authenticated deterministic draft scanner with bounded input, caller quotas, idempotency, and no raw-content persistence.
- **ai-support**: The external-provider adapter is disabled by default. The product uses the authenticated, deterministic approved-article path when no provider is configured.
- **Job safety**: Job validation and prohibited-work decisions remain server-owned database rules. There is no deployed fake risk-score endpoint.
- **Recommendations**: No personalized AI recommendation provider is deployed. MORT does not claim generated recommendations while that capability is disabled.

## Database Tables
- `ai_moderation_events`: Stores the result of every moderation check.
- Legacy risk/recommendation tables are not evidence that an AI provider is active.
- Support conversation and usage tables store only the authorized MORT Guide flow.
- `ai_model_audit_logs`: Technical logs for latency and hashing.
- `ai_rule_matches`: Triggers from regex rules.
