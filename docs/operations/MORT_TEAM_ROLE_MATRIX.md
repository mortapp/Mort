# MORT Team Role Matrix

> **DRAFT — NOT ATTORNEY REVIEWED OR LEGALLY APPROVED**

| Role | Permitted scope | Explicit exclusions | Prerequisites |
|---|---|---|---|
| product_tester | synthetic product flows | production users and evidence | confidentiality, device baseline |
| accessibility_tester | accessibility review with synthetic data | identity decisions | accessibility training |
| qa_tester | isolated QA fixtures | production records | QA and data-minimization training |
| security_advisor | architecture, RLS, audit, secrets, threat model | legal, identity, child-safety approval | confidentiality, security scope |
| developer | code and approved environments | unassigned evidence | MFA, environment and secret training |
| partner_coordinator | approved partner metadata | raw IDs and incidents | partner training |
| support_trainee | synthetic support cases | production users | training only |
| document_reviewer_trainee | synthetic documents | real evidence | all reviewer modules |
| document_reviewer | assigned case metadata when readiness is enabled | unassigned cases and final mismatch alone | approval, training, device review |
| senior_document_reviewer | assigned second review and appeal | automatic identity approval | reviewer experience and approval |
| safety_moderator | assigned reports and restrictions | unassigned IDs | safety and evidence training |
| incident_manager | assigned high-risk incident coordination | amateur criminal investigation | incident training and approval |
| super_admin | platform configuration and role governance | automatic raw-ID access | exceptional time-limited approval |

All permissions are individual, least privilege, purpose bound, time limited, audited, and revocable. Friendship, family relationship, founder status, or group-chat membership grants no access.
