# MORT Legal Source of Truth — V3 upload

> **Status: DRAFT — attorney review required.** These records are intentionally unpublished. This manifest does not claim attorney review, legal approval, or public effectiveness.

- Uploaded and staged: 2026-10-28
- Mobile production Supabase project configured by the current Flutter release branch: `jxbnrkasktbhtiujkhay`
- Repository branch: `codex/public-production-release-mainline`
- Markdown app content is extracted from the supplied rendered PDFs and stored in the existing `content_markdown` clickwrap field. Original uploaded-file hashes below preserve upload provenance.
- The repository Typst text copies are newline-normalized text returned by the file reader; their copy hashes are listed separately from the original uploaded-file hashes.
- No `effective_at`, `published_at`, `attorney_reviewed_at`, or `approved_by_counsel_reference` values were set. Do not publish or mark approved without actual counsel review and product-behavior reconciliation.

## Supabase draft records

### MORT Master Terms of Service
- Document key: `master_terms_of_service`
- Version label: `MORT-LEGAL-2026-V3`
- Document ID: `332f598e-b4e6-4626-8c39-7b6fb2261064`
- Version ID: `78de4f42-1223-4dcf-9220-e43e76b0b4ad`
- Publication status: `draft_attorney_review`
- Markdown characters: 34362
- Supabase content SHA-256: `4de47f02c575cccaa90620336fdcaead0c8a23a9165e0b1955088b6994001273`
- App content path: `docs/legal/source-of-truth/MORT_Master_Terms_V3.md`
- Original PDF SHA-256: `1106789d12a660cae57c76edc928f27a3b27ec57cbbb6f41ce0ae3079a450248`
- Original uploaded Typst SHA-256: `648ebf688f8c2aa38dd614e72b725b0906036169384a863a06f650bb78837fba`
- Repository Typst text-copy SHA-256: `648ebf688f8c2aa38dd614e72b725b0906036169384a863a06f650bb78837fba`

### MORT Privacy Policy
- Document key: `privacy_policy`
- Version label: `MORT-PRIVACY-2026-10`
- Document ID: `1f6a3eeb-9f2b-4a98-9c4c-1f9b2461eb10`
- Version ID: `d78d848e-8e88-4f7c-ad70-096a39f03e03`
- Publication status: `draft_attorney_review`
- Markdown characters: 7820
- Supabase content SHA-256: `600eaaf57b3b496fcae70ef43e59c92a82ef4361525a8aba7a524e7789f92491`
- App content path: `docs/legal/source-of-truth/MORT_Privacy_Policy.md`
- Original PDF SHA-256: `dae133cda0036ed976d9bd2f17021968f72935830ce55f6513242ad9d990f122`
- Original uploaded Typst SHA-256: `72a3b805ec5ea39d6d4d50af993627fd09b7b0585809a00decd27e5298827fa5`
- Repository Typst text-copy SHA-256: `72a3b805ec5ea39d6d4d50af993627fd09b7b0585809a00decd27e5298827fa5`

### MORT Safety Rules
- Document key: `safety_rules`
- Version label: `MORT-SAFETY-2026-10`
- Document ID: `e510f14e-bc8d-480b-9aff-1f761fac05bf`
- Version ID: `1a64f713-4621-45c8-b0c1-76119aacd900`
- Publication status: `draft_attorney_review`
- Markdown characters: 6744
- Supabase content SHA-256: `13318930ae3430fba8855581c3367a8f6e0fbe776dc9936ba442ff651e64954b`
- App content path: `docs/legal/source-of-truth/MORT_Safety_Rules.md`
- Original PDF SHA-256: `7a40e76434569136751d375536a735b7ea6b57f0da5409bb80d8de7d14aebc7d`
- Original uploaded Typst SHA-256: `3e1c42d60a5e7489f503f9bb745f2b71aa682a2f022f5f12822f281825b68d93`
- Repository Typst text-copy SHA-256: `3e1c42d60a5e7489f503f9bb745f2b71aa682a2f022f5f12822f281825b68d93`

### MORT Community Guidelines
- Document key: `community_guidelines`
- Version label: `MORT-COMMUNITY-2026-10`
- Document ID: `a8bf022c-3981-4504-9d5e-30840ac0f0ac`
- Version ID: `72b280bb-e773-4617-8a57-9363921b15c4`
- Publication status: `draft_attorney_review`
- Markdown characters: 6027
- Supabase content SHA-256: `1d82c9af557cac14ab98a3f00c7b8b087478ffe8fc7de8f93e51db926564b68c`
- App content path: `docs/legal/source-of-truth/MORT_Community_Guidelines.md`
- Original PDF SHA-256: `a4f64709ad59c542b94cb3b7c738b0d862fc136f7b187fcf32e8d79f72e94406`
- Original uploaded Typst SHA-256: `479407e467ac5d6f050ac30022ca38f0c25cd6c2f768be0258e4e74e541c0632`
- Repository Typst text-copy SHA-256: `479407e467ac5d6f050ac30022ca38f0c25cd6c2f768be0258e4e74e541c0632`

## Release gates that remain

- No legal document version is published or attorney-reviewed by this import.
- Guardian consent before teen account activation and private-residence Guardian approval remain requirements to verify against the actual backend and client; storing the text does not prove implementation.
- The production AAB gate must continue to reject placeholder or unpublished legal versions.
- The legal source must be reviewed for consistency with actual identity verification, payment/payout behavior, data retention/deletion, moderation, and Guardian controls before publication.