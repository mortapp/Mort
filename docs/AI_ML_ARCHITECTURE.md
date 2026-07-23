# AI/ML Architecture

## Overview
MORT uses a backend-mediated AI architecture via Supabase Edge Functions. AI logic is NEVER run purely client-side, and no AI provider keys (e.g. OpenAI, Anthropic, Google) are bundled into the Flutter mobile app.

## Components
- **ai-safety**: Analyzes content (messages, job postings, reports) for safety violations. Uses rule-based regex fallback when AI is unavailable.
- **ai-recommendations**: Analyzes user activity and job data to provide tailored recommendations.
- **ai-support**: An intelligent assistant for users to find help.
- **ai-risk-score**: Evaluates jobs for potential risks to teens based on category, time, and location.

## Database Tables
- `ai_moderation_events`: Stores the result of every moderation check.
- `ai_risk_scores`: Caches computed risk scores for jobs.
- `ai_recommendation_events`: Logs recommendations presented to users.
- `ai_support_sessions`: Chat transcripts with the support bot.
- `ai_model_audit_logs`: Technical logs for latency and hashing.
- `ai_rule_matches`: Triggers from regex rules.
