# MORT Message Safety and Messaging Launch — 2026-11-14

This document records the production messaging deployment and its verified client/backend contract.

## Production state

The following migrations were applied to the authoritative production Supabase project `jxbnrkasktbhtiujkhay` on 2026-11-14:

- `20261114160000_message_safety_scanner_launch.sql`
- `20261114160100_message_safety_normalization_and_moderation_queue.sql`
- `20261114160200_message_safety_private_rls.sql`
- `20261114160300_publish_messaging_realtime.sql`
- `20261114160400_message_notifications_and_preferences.sql`
- `20261114160500_expand_message_safety_rules.sql`
- `20261114160600_harden_additional_message_safety_patterns.sql`

Production catalog verification confirms:
- 19 active message-safety rules.
- A `BEFORE INSERT` scanner trigger on `public.messages`.
- An `AFTER INSERT OR UPDATE` trigger that creates recipient notifications only after a message is approved.
- RLS enabled on `private.message_safety_rules` and `private.message_moderation_log`, with no direct anon/authenticated table access.
- A staff-only `list_message_moderation_queue()` RPC and audited `mort_moderate_message()` action.
- `messages`, `conversations`, and `conversation_members` published to `supabase_realtime`.
- `send_safe_message_v2()` remains the authenticated message-send entry point; it uses the server-side `mort_send_message()` implementation internally.

## Safety behavior

The server scanner maps content to the existing moderation states:
- `clean` → `approved`, delivered to conversation recipients.
- `flagged` → held for authorized human review.
- `blocked` → never delivered to recipients.

The 19 active rules cover sexualized contact and image requests, grooming/secrecy patterns, off-platform contact, unrealistic earnings lures, threats, coercion/blackmail, sensitive personal-information requests, exact street addresses, off-platform payment pressure, and harassment.

Normalization includes NFKC handling, zero-width and formatting-character removal, Cyrillic/Greek homoglyph folding, and compact-form checks. The scanner is heuristic and must not be represented as semantic or perfect detection. Human reporting and review remain required.

## Moderation and evidence

- `private.message_moderation_log` records matching rule evidence for held/blocked content.
- `list_message_moderation_queue()` returns only held/blocked messages after a server-side `admin`/`moderator` staff-role check.
- `mort_moderate_message()` records moderator decisions in `public.admin_audit_log`.
- The Flutter admin message route now uses the staff-authorized queue RPC instead of querying the messages table directly.
- Moderators must supply a reason in the UI before approving, keeping blocked, or removing a message.

## Notifications

- Approved messages create a generic `new_message` notification for the other active conversation member, if that member has message notifications enabled.
- Held/blocked messages do not notify recipients.
- Notification payloads contain `threadId` and `messageId`, not message body text.
- Flutter now queries `public.notifications.user_id`, matching the production schema.
- Notification preference read/update RPCs support categories, quiet hours, and timezone.
- Remote FCM push delivery is explicitly disabled and unverified. In-app notifications and foreground Realtime are implemented; background push must not be claimed as working.

## Realtime and client integration

- Flutter subscriptions now filter `public.messages.conversation_id`, not the nonexistent `thread_id` column.
- Flutter message decoding accepts both RPC fields (`thread_id`, `scanner_status`, `scanner_reason`) and raw Realtime fields (`conversation_id`, `moderation_status`, `moderation_reason`).
- Flutter's send UI retains a client request ID across in-screen retries.
- Web chat was updated in `mortapp/mort-web` PR #36 to use `send_safe_message_v2()` with a per-form idempotency key. PR #36 was merged and its production-config, typecheck, ESLint, and Next.js build checks passed.
- Apple/Swift code was deliberately not changed. Its current repository still calls legacy RPCs `get_my_message_threads()` and `send_safe_message()`, filters `messages.thread_id`, and decodes legacy field names. Those do not match the production API and require a separate Apple-only client correction before Apple messaging can be considered launch-ready.

## QA verification

Isolated QA project: `ckcxakhxqlkhppsxxjhv`.

- Message safety, moderation, read receipts, blocking, and message-report contract: **49/49 pgTAP assertions passed**.
- Unicode/obfuscation normalization contract: **10/10 pgTAP assertions passed**.
- Notification preference transaction test passed: default read, category update, quiet-hours/timezone persistence, and explicit remote-push-disabled status.
- Regression coverage includes blocked/flagged/delivered content, moderator-only queue access, moderator approval delivery, recipient-only notifications, generic notification text, deep-link payloads, read receipts, participant-only blocking, blocked-send enforcement, message-level safety reports, and idempotent report retries.
- All synthetic QA fixtures were rolled back. No synthetic production accounts, conversations, messages, or notifications were created.

## Explicit limitations

- Production currently has no conversation/message rows, so live two-account delivery against real launch accounts has not yet been exercised. QA tests use synthetic accounts in the isolated QA project.
- Chat attachments remain fail-closed: the bucket is private, there are no client Storage policies, and no upload workflow is wired. No claim of attachment support should be made.
- Remote FCM push is disabled/unverified; in-app notifications and foreground Realtime are the currently supported delivery paths.
- Scanner patterns are heuristic. New slang, coded language, images, and context-dependent grooming can evade detection. Continue reviewing evidence and user reports.
- No Android AAB work and no Apple/Swift source changes were included in this backend/Flutter/web messaging work.
