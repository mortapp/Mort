# Hosted Migration Reconciliation Ledger — 2026-08-28

This ledger records the authorized append-only migration-history reconciliation and deployment of the genuine support wording and four-step onboarding migrations. Existing hosted migration rows must never be reverted, deleted, renamed, squashed, or rewritten.

## Before repair

- Captured UTC: `2026-08-28T10:58:08.1557279Z`
- `START_HEAD=dcd0fbcd7a1744d6ce383642dda055f952e918d3`
- `PRE_REPAIR_HEAD=039de0d889da67d17af367fc64972a93af13cbdd`
- `ORIGIN_MAIN=7bcfca79a5a41708d3ccc7d0342f1dc9ade56008`
- Working tree: clean; branch matched `origin/feature/compact-onboarding-and-screen-polish`
- Local migration files: `193`
- `LOCAL_HISTORY_SHA256=90d6180af7a9474359834c8b20613eae219e42fb867bd8bfd07c458ec497d53f`
- Hosted migration rows: `184`
- `HOSTED_HISTORY_BEFORE_SHA256=526d86aa73b282623a25f35733dfd4710bfe2ab42f2236757609fbbcce9032a0`

The SHA-256 values above cover the complete ordered local filename list and complete ordered hosted `(version, name, statement_count)` list respectively. The hosted tail at the divergence boundary was:

```text
20260816010000 support_ai_full_contract_parity_fix 4
20260818233800 quick_accept_job_v1 1
20260819003851 quick_accept_job_opt_in 1
20260819004344 job_site_precise_location_and_distance 1
20260819004628 fix_job_private_location_address_nullable 1
20260819025837 leaderboard_v1 1
20260820113638 apple_identity_controls 1
20260820122024 mort_spark_rewarded_ads 1
```

## Verified mappings

| Hosted timestamp | Canonical local migration | Normalized semantic SHA-256 | Comparison | Compatibility alias |
| --- | --- | --- | --- | --- |
| `20260818233800` | `20260818200000_quick_accept_job_v1.sql` | `4ae72e06347fb9118e1576b3099a0e544359a7256739e574f741da41286da713` | Semantically equivalent | `20260818233800_compatibility_alias_quick_accept_job_v1.sql` |
| `20260819003851` | `20260818210000_quick_accept_job_opt_in.sql` | `8bc4f080788408736e6ea532f9e263020be1d0515bbc2a6f26d12d7b99036fcf` | Semantically equivalent | `20260819003851_compatibility_alias_quick_accept_job_opt_in.sql` |
| `20260819004344` | `20260819000000_job_site_precise_location_and_distance.sql` | `293a14370f27b2b892d82d8bddfc829265ab7ee6433b399b65db7fad59daefdd` | Semantically equivalent | `20260819004344_compatibility_alias_job_site_precise_location_and_distance.sql` |
| `20260819004628` | `20260819000100_fix_job_private_location_address_nullable.sql` | `0c10a23b6cb2f35e3c52142e9e31e7489b0d38a9dd83fdc60d70a999614af9ab` | Semantically equivalent | `20260819004628_compatibility_alias_fix_job_private_location_address_nullable.sql` |
| `20260819025837` | `20260819010000_leaderboard_v1.sql` | `b4c843a01d79f3ed2e4513ec23d0580674505c632dc85a8fa90038bfc9dedac4` | Semantically equivalent | `20260819025837_compatibility_alias_leaderboard_v1.sql` |
| `20260820113638` | `20260820000000_apple_identity_controls.sql` | `d5e6943fb89f76596d75016e2e5c8d217c0b727871d52fb0b6fe0486202680d6` | Semantically equivalent | `20260820113638_compatibility_alias_apple_identity_controls.sql` |
| `20260820122024` | `20260820120000_mort_spark_rewarded_ads.sql` | `b99c7b0c6eb615a2234711c801a2ed5c749a0aabc0a4d71c37312046caa900c0` | Semantically equivalent | `20260820122024_compatibility_alias_mort_spark_rewarded_ads.sql` |

Durable check: `pnpm qa:migration-reconciliation-parity` passed before repair. It hashes executable SQL after removing full-line comments and normalizing whitespace, and proves all seven aliases contain no executable SQL.

## Dry run before repair

Command:

```powershell
pnpm exec supabase db push --dry-run --include-all
```

Observed pending migrations:

```text
20260817120000_support_ai_account_wording_coverage_fix.sql
20260818200000_quick_accept_job_v1.sql
20260818210000_quick_accept_job_opt_in.sql
20260819000000_job_site_precise_location_and_distance.sql
20260819000100_fix_job_private_location_address_nullable.sql
20260819010000_leaderboard_v1.sql
20260820000000_apple_identity_controls.sql
20260820120000_mort_spark_rewarded_ads.sql
20260828023033_four_step_onboarding_v2.sql
```

This is the expected pre-repair set: seven verified canonical timestamp aliases plus the two genuine pending forward migrations.

## Authorized repair commands

Status before execution: not yet executed.

```powershell
pnpm exec supabase migration repair --status applied 20260818200000 20260818210000 20260819000000 20260819000100 20260819010000 20260820000000 20260820120000
```

No `reverted` repair is authorized. No repair is authorized for `20260817120000` or `20260828023033`.

## After repair and deployment

Pending execution. This section will record the after-history hash, both post-repair dry runs, migrations actually applied, hosted verification, and final parity state.
