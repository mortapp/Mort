# AI Admin Review Guide

Admins are the final arbiters of moderation.

1. Check the `ai_moderation_events` table for `status = 'pending_review'`.
2. Evaluate `detected_flags`.
3. If an action is required, take action (e.g. banning user, rejecting job) and insert a row into `moderation_events`.
4. Update `ai_moderation_events.status` to `resolved`.
