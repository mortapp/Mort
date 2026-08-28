> RECOMMENDED - ADULT ACCOUNT OWNER MUST CONFIRM

| Console field | Recommended answer | Evidence | Owner confirmation | Risk if incorrect |
|---|---|---|---|---|
| App access | Restricted; provide persistent teen and adult reviewer accounts | Review tenant QA and app-access docs | [ ] | Review rejection if login fails |
| Ads | No ads in this release | No ads SDK or AD_ID in final bundle | [ ] | Data Safety/policy mismatch |
| UGC | Yes; profiles, jobs, messages, reviews, proofs, organization content | Report/block/moderation/rate-limit QA | [ ] | UGC policy violation |
| Child safety | 13+ service with published standards and dedicated trained-adult contact | Age gate, standards page, child-safety QA | [ ] | Severe policy/safety exposure |
| Financial features | No payment processing, escrow, lending, wallet, transfer, or guarantee | Payment preference/obligation models only | [ ] | Incorrect financial declaration |
| Identity verification | Real document/provider verification disabled | Release flags and bundle behavior | [ ] | Misleading safety claim |
| Account deletion | In-app and public web request paths | Deletion suites and public route | [ ] | User Data policy rejection |
