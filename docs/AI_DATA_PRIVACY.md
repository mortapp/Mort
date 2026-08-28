# AI Data Privacy

- **Data Locality**: All prompts and context sent to third-party AI models must be anonymized or stripped of PII (Personally Identifiable Information) before leaving the Supabase environment.
- **Retention**: AI outputs and inputs are stored for 90 days in `ai_moderation_events` for audit purposes.
- **Access Control**: Users can see their own AI support logs. Only Admins can see raw moderation events and audit logs. Guardians see only actionable safety alerts regarding their linked teens.
