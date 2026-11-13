# MORT Message Safety Hardening — 2026-11-13

Research summary and implementation notes for the message safety scanner
(migration `20261113150000_message_safety_scanner.sql`, contract
`supabase/production-baseline-tests/message_safety_scanner.test.sql`).

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
6. Lockdown — rule table, log, and scanner functions are not
   executable/readable by anon or authenticated clients (prevents rule
   probing).

### Verified on QA (project ckcxakhxqlkhppsxxjhv), 24/24 pgTAP assertions

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
- Known limitation: regex screening is a floor, not a ceiling. Obfuscated
  text passes; the moderation queue (flagged messages) and user reports
  remain the human-review path.
