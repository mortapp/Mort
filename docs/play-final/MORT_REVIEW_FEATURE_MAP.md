# MORT Review Feature Map

| Review goal | Synthetic route/data | Primary evidence |
|---|---|---|
| Closed-pilot status | Welcome and Account Status | `get_release_mode_status` |
| Teen job/application | Jobs and Applications | `jobs`, `applications` RLS |
| Job-context messaging | Messages | `message_threads`, `send_safe_message` |
| Contract | Contracts | `job_contracts`, version/acceptance rows |
| Start/completion | Safety workspace | arrival handshake and completion assertions |
| Payment disagreement | Payment status/dispute | obligations and disputes; no guilt finding |
| Report/block | Safety Center | isolated report and block rows |
| Account deletion | Settings / Account deletion | one-use, expiring request flow |
| Partner scope | Partner workspace | organization context, connected roster, invite/attestation RPCs |
| Location denial | Native permissions / job setup | approximate and manual fallback |
| Disabled ID | Trust/verification explanation | server flags: disabled, no document collection |
| Optional guardian | Guardian explanation | eligibility RPC reports optional |
