# MORT Data Authorization Matrix

Audit date: 2026-07-22

| Resource | Teen | Adult/business | Guardian | Support/admin | Server/provider |
|---|---|---|---|---|---|
| Own profile fields | Read/write allowlist | Read/write allowlist | Read/write allowlist | Minimized assigned view | Protected fields only |
| Other profile/avatar | Relationship/block-aware projection | Relationship/block-aware projection | Linked/minimized | Assigned tooling | Signed URL authorization |
| Jobs/applications | Eligible feed, own applications | Own jobs/applicants | No general access | Role queue | State transitions |
| Messages | Participant only | Participant only | Not shared by default | Authorized safety/support scope | Safety scanner/events |
| Guardian data | Own links/preferences | None by role alone | Own active links | Specialized role only | Invite/link functions |
| Support cases | Own cases | Own cases | Own cases | Assigned support role | Audit/status automation |
| Job/payment evidence | Participant-owned/linked | Participant-owned/linked | No default access | Assigned evidence role | Private Storage signer |
| Exact address/location | Accepted and mutually released job only | Owned/accepted job only | Explicit narrow share only | Specialized incident role | Private functions |
| Payment status | Minimized own status | Minimized own status | Provider-required relationship only | Expiring financial assignment | Stripe webhook/functions |
| Provider identifiers | Never | Never | Never | Excluded from normal queues | Private schema only |
| Admin/reviewer state | Never | Never | Never | Server-issued expiring role | Immutable audit records |
| AI usage/cost state | Own safe status only | Own safe status only | Own safe status only | Audit role | Atomic server controls |

Authorization is enforced in Postgres/RLS and caller-bound functions. Flutter route guards are user experience controls, not the security boundary. The 30-case multi-user regression, Storage QA, support isolation, payment queue, role-forgery, and direct RPC tests provide the current evidence.
