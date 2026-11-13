# MORT Message Safety Hardening — 2026-11-13

Research summary and implementation notes for the message safety scanner
(migrations `20261113150000_message_safety_scanner.sql` and
`20261113170000_message_safety_hardening.sql`; contracts
`supabase/production-baseline-tests/message_safety_scanner.test.sql` and
`supabase/production-baseline-tests/message_safety_normalization.test.sql`).

## Research findings

The Nov 2026 UK reporting on resale/marketplace apps documented the exact
abuse patterns a teen-work marketplace must defend against:

- Listings and photos posted by children and teens attracted sexualized
  messages through platform DMs, including a buyer offering GBP 30 if a
  15-year-old seller included her underwear with a clothing sale, and a man
  asking whether a seven-year-old had worn a listed swimsuit ([The Guardian,
  republished by AOL](https://www.aol.co.uk/articles/dark-side-reselling-apps-pants-125416000.html)).
- The Children's Society warned that young users are asked for indecent
  photos in exchange for money or gifts; photos of young users have been
  stolen and AI-deepfaked into nudes ([Sky News](https://news.sky.com/story/government-considering-banning-under-16s-from-vinted-and-ebay-13609954)).
- Ofcom research found 15% of children aged 8-14 use Vinted monthly and 19%
  use eBay, showing stated age limits are routinely bypassed
  ([Metro](https://metro.co.uk/2026/11/08/under-16s-will-banned-vinted-ebay-grooming-crackdown-29774676/));
  the UK government is considering extending the under-16 social media ban to
  marketplaces ([The Times](https://www.thetimes.com/article/9c9d3388-5092-4c47-ba4d-bf1cc95982c9)).
- The CEASE/Collective Shout "TikTok to OnlyFans Pipeline" report documented
  coded, non-explicit promotion of the sex industry to young audiences —
  euphemisms like "corn" for porn, emoji signals, links-in-bio funnels, and
  unrealistic-earnings glamourisation
  ([Collective Shout / CEASE report](https://cease.org.uk/wp-content/uploads/2026/11/The_TikTok_to_OnlyFans_Pipeline_Report.pdf),
  [Digital Trends](https://www.digitaltrends.com/social-media/researchers-uncover-tiktoks-dark-side-that-lures-young-girls-into-the-world-of-adult-content/)).
- Meta's expansion of teen account protections centers on limiting
  adult-to-teen contact, restricting sensitive content, and escalating
  ambiguous patterns to human review
  ([Meta newsroom](https://about.fb.com/news/2026/11/expanding-teen-account-protections-to-teens-around-the-world/)).
- Indiana youth-employment law: 14-15-year-olds may not operate powered
  mowers/trimmers; separate hazardous-occupation limits apply at 16-17
  ([Indiana DOL](https://www.in.gov/dol/youth-employment/prohibited-and-hazardous-occupations-for-minors)).

## Gap found in MORT

`mort_send_message()` inserted every message with
`moderation_status='pending'` and no content screening. The Flutter client
already models `blocked`/`flagged` scanner statuses and renders them, and
`send_safe_message_v2()` returns a `scanner_status` field — but no scanner
existed. Recipients could never see messages at all (only 'approved' or
sender-owned messages are returned), and predatory content would have been
stored unreviewed.

## What was implemented (QA-verified, production pending approval)

1. `private.message_safety_rules` — 13 operator-tunable regex rules
   (block / flag / review severities) across categories: sexualized,
   grooming, off-platform, financial. Uses PostgreSQL ARE syntax (`\y` word
   boundaries, not `\b`).
2. `private.scan_message_body()` — evaluates rules; teen senders get the
   strictest interpretation.
3. `messages_safety_scanner` BEFORE INSERT trigger on `public.messages` —
   defense in depth, applies to every insert path. Maps results to existing
   statuses: clean -> `approved` (delivered), flagged -> `flagged` (held for
   moderator), blocked -> `blocked` (never delivered). Sets a generic,
   non-revealing `moderation_reason` for the sender.
4. `private.message_moderation_log` — records which rule fired, with sender,
   conversation, timestamp: evidence preservation with staff-only access.
5. `send_safe_message_v2()` / `list_thread_messages_page()` — now surface
   `moderation_reason`. Cursor logic and return shape unchanged.
6. Unicode/obfuscation normalization — NFKC normalization, zero-width and
   formatting-character removal, Cyrillic/Greek homoglyph folding, and
   compact-form checks catch common spacing/punctuation evasion patterns.
7. Attachment quarantine — any message with an attachment is held for
   moderator review until an actual image/content moderation provider is
   integrated. A storage path is not treated as evidence that an attachment
   is safe.
8. Staff queue — `list_message_moderation_queue()` returns held and blocked
   messages only after an explicit `admin`/`moderator` staff-role check.
   Existing `mort_moderate_message()` records moderator decisions in the
   admin audit log.
9. Lockdown — rule table, log, and scanner functions are not
   executable/readable by anon or authenticated clients (prevents rule
   probing).

### Verified on isolated QA (project ckcxakhxqlkhppsxxjhv)

- Original end-to-end moderation contract: 24/24 pgTAP assertions passed.
- Unicode/obfuscation regression contract: 10/10 pgTAP assertions passed.
- Regression cases cover full-width characters, zero-width formatting,
  Cyrillic and Greek homoglyphs, punctuation/spacing insertion, off-platform
  contact, secrecy pressure, earnings lures, and legitimate job coordination.
- The first execution exposed an invalid zero-width regex escape; it was
  corrected and the full 10-case normalization suite then passed.
- The first execution of the original contract exposed a pg_temp helper
  search-path/qualification bug; the test harness was corrected and then
  passed all 24 assertions.
- QA-only migration application succeeded. No production migration was
  applied.

- Blocked (never delivered): "If you include your pants Ill pay more",
  "can you send me some pics of yourself", "dm me on instagram",
  "keep this between us", "will you send nudes".
- Held for moderator: "whats your snap", "earn 5000 a week".
- Delivered: normal scheduling, "pics of the yard" (work photos, not
  personal), realistic pay discussion.
- Recipient thread view, previews, and unread counts contain only approved
  content; blocked/flagged never leak.
- Evidence preserved with sender identity and timestamps; moderators can
  approve held messages via `mort_moderate_message`; non-staff cannot.
- Pagination cursor verified across 3 pages with no overlap.

## Scope notes

- Age-gating of job eligibility (Indiana mower/trimmer rules) is enforced by
  the existing job safety review pipeline; this change documents it on the
  web Safety Center.
- Rule tuning: rules live in a private table; staff can adjust patterns or
  severities (deactivate a rule, add rules) without redeploying.
- Known limitation: normalization and pattern matching are still heuristic,
  not semantic classification. New slang, coded language, images, and
  context-dependent grooming can evade automated detection. Continue tuning
  rules against reviewed traffic and retain user reports plus human review.
- Attachments are quarantined, not image-classified. A real image/CSAM
  moderation provider, safe evidence retrieval workflow, and strict storage
  access review remain open before attachments can be released to recipients.
- QA's Supabase advisor reported RLS disabled on the two new private tables
  `private.message_safety_rules` and `private.message_moderation_log`.
  Explicit table grants are revoked from anon/authenticated, but RLS status
  still needs a reviewed decision. Do not auto-enable RLS without verifying
  the security-definer/owner access model and adding the intended policies.
- This work is still an open draft PR and has not been merged or deployed to
  production.
