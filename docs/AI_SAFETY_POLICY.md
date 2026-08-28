# AI Safety Policy

The AI Safety policy dictates that all communication and content must be vetted to protect teens.

## Enforcement
1. **Pings and Reports**: Users can manually flag unsafe content.
2. **Automated AI/Regex**: Edge Functions process content on creation. The fallback engine scans for:
   - Personal info (Phone numbers, exact addresses, email).
   - Off-platform attempts (Snapchat, Instagram handles).
   - Payments (CashApp, Venmo).
   - Harm (Threats, harassment).
   - Grooming / Guardian Evasion.

## Action
When flagged, content status is updated to `pending_review` in `ai_moderation_events`. Severe infractions may automatically trigger `blocks` or `reports` for human administrative action.
