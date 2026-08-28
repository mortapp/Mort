# MORT Profile Field Matrix

| Field | Classification | Write authority | Public visibility |
|---|---|---|---|
| `id` | Protected identity | Auth trigger/server | Directory identifier where policy permits |
| `role` | Protected authorization | Initial server onboarding; immutable afterward | Directory-safe role |
| `dob` | Sensitive eligibility | Initial server onboarding; immutable afterward | Never public |
| `display_name` | User editable | `update_my_profile` | Directory-safe |
| `username` | Controlled user editable | Dedicated username RPC and credit policy | Directory-safe |
| `bio` | User editable/UGC | `update_my_profile` | Directory-safe where profile visibility permits |
| `availability` | User editable | `update_my_profile` | Directory-safe |
| `preferred_job_categories` | User editable | `update_my_profile` | Directory-safe |
| `approximate_area` | User editable, coarse only | `update_my_profile` | Directory-safe; exact address prohibited |
| `goals` | User editable | `update_my_profile` | Directory-safe |
| `avatar_path` | User-bound media reference | Storage owner plus `update_my_profile` | Signed display URL only |
| `payment_preference` | Private user setting | Payment-preference flow plus `update_my_profile` | Never public |
| `onboarding_completed` | Protected workflow state | `complete_my_onboarding` | Never public |
| `verification_status` | Protected trust state | Verification backend/admin workflow | Limited status only |
| `account_status` / `blocked_until` | Protected moderation state | Authorized moderation workflow | Never public |
| `is_test_account` | Protected environment state | Service/admin fixture workflow | Never public |
| `guardian_setup_status` | Protected relationship state | Guardian workflow RPCs | Never public |
| `created_at` / `updated_at` | Server metadata | Database | Limited directory timestamp where selected |
