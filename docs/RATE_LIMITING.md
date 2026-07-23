# Rate Limiting

Rate limiting is enforced at the database level via Supabase RPC functions (`check_rate_limit`, `is_action_allowed`) and tracked in the `rate_limit_events` table.

## Limits
- **username_change**: 2 per 30 days
- **job_post_create**: 10 per day
- **job_application_create**: 20 per day
- **message_send**: 500 per day
- **report_create**: 5 per hour
- **default**: 100 per hour

These limits protect against spam and abuse. Admin role bypasses these checks.
