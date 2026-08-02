# MORT Legal Review Packet

Status: DRAFT FOR LICENSED ATTORNEY REVIEW - NOT LEGAL ADVICE OR APPROVAL

Prepared: 2026-08-01

MORT is a proposed local job marketplace for people ages 13-17 and adult or
business job posters. Guardian Mode is optional. The public marketplace,
production identity verification, payments, advertising, in-app purchases,
external AI, and unrestricted access remain disabled.

This packet asks for written decisions from a licensed attorney familiar with
Indiana law, youth labor, online marketplaces, minors, privacy, location,
user-generated content (UGC), messaging, payments, identity verification, and
parental or guardian features. Engineering drafts must not be published as
attorney approved.

## Service And Role Model

- Teen: age 13-17; server-authorized job workflows only after release and
  jurisdiction gates permit them.
- Adult/business: age 18+; job posting and application review only after
  verification and release gates permit them.
- Guardian: age 18+; optional, bounded safety supervision; not an account owner,
  identity verifier, universal consent mechanism, employer, or emergency
  service.
- Staff: expiring, least-privilege assignments separated among support,
  moderation, safety, identity, financial, incident, and appeal responsibilities.

## Exact Attorney Questions

### Indiana And Youth Labor

1. Which Indiana statutes, regulations, agency rules, permits, hour limits,
   school-day limits, parental permissions, wage rules, recordkeeping duties,
   insurance duties, and prohibited occupations apply to each age band and job
   category MORT proposes to permit?
2. Is MORT, an adult poster, a business, or another party likely to be treated
   as an employer, employment agency, marketplace, contractor platform, or
   joint employer for any supported workflow?
3. Which job categories must be prohibited or limited by age, time, location,
   tools, chemicals, height, driving, machinery, supervision, or business type?
4. What evidence of age, work eligibility, parental permission, school status,
   permits, poster authority, and completed work may MORT lawfully require and
   retain, and for how long?
5. Must the first release be restricted to specific Indiana counties, partner
   organizations, job types, hours, or age bands?

### Minors, Contracting, And Guardians

6. Which agreements can a 13-17-year-old accept, which require a parent or legal
   guardian, and which are voidable or unenforceable?
7. Does any legal-consent requirement differ from optional Guardian Mode? State
   the exact legal relationship, verification, revocation, and record needed.
8. May a teen unlink Guardian Mode without notice, and what safety or legal
   exceptions, if any, apply?
9. What information may a guardian see without violating the teen's privacy,
   confidentiality, anti-retaliation rights, or safety?
10. What disclosures are required to avoid implying continuous monitoring,
    guaranteed delivery, emergency response, identity assurance, or legal
    consent through Guardian Mode?

### Marketplace, Safety, And Liability

11. What marketplace disclosures, insurance decisions, waivers, warranties,
    indemnities, limitations of liability, dispute rights, and consumer notices
    are lawful and appropriate for minors and adults in Indiana?
12. What duty, if any, arises from verification labels, automated scanners,
    report handling, Safety Pings, check-ins, job PINs, or moderation decisions?
13. What emergency-disclosure, mandated-reporting, evidence-preservation,
    anti-retaliation, law-enforcement-response, and CSAM/CSAE procedures are
    legally required?
14. Which account restrictions may be immediate, when must notice be given, and
    what independent appeal or ban-reversal process is required?
15. Are the proposed moderation reason codes, expiring staff access, audit logs,
    and independent ban appeals sufficient for the pilot's risk profile?

### Privacy, Location, And Deletion

16. Which federal and Indiana privacy laws apply to teens ages 13-17, including
    consent, notice, access, correction, deletion, profiling, and data
    minimization requirements?
17. Is date-of-birth collection appropriate for the neutral age gate, and what
    retention, access, and deletion rules should apply to DOB and age bands?
18. May MORT process approximate area for matching and temporary foreground
    precise location for an active-job safety feature? Specify consent,
    recipient, expiry, logging, and disclosure requirements.
19. Approve exact retention periods and deletion exceptions for messages,
    jobs, applications, contracts, reports, blocks, safety pings, evidence,
    disputes, support records, staff-access logs, identity results, and security
    events.
20. What public and in-app account-deletion disclosures are required, and which
    retained records must be de-identified, preserved, or disclosed to users?
21. Which processors and cross-border transfers require contracts, notices,
    assessments, or opt-out/consent mechanisms?

### UGC, Messaging, And Google Play

22. Are the Terms, Community Guidelines, Safety Rules, prohibited-work rules,
    job-context messaging limits, reporting, blocking, and moderation process
    sufficient for teen/adult UGC?
23. Does Google Play Families policy require adult action before any specific
    personal-information exchange in this service, and how should that differ
    from optional Guardian Mode?
24. What store category, target-audience, content-rating, Child Safety, Data
    Safety, UGC, and location declarations accurately describe MORT?
25. Does MORT fall within Google Play's Social category or Child Safety
    Standards scope, and what named trained-adult contact and published
    standards are required?

### Payments, Identity, Analytics, And AI

26. Before any real payment feature is considered, what minor contracting,
    wage, tax, refund, chargeback, money-transmission, escrow, marketplace,
    payout, KYC, and recordkeeping rules apply? MORT currently processes no
    money and guarantees no payment.
27. Before identity verification is enabled, what consent, provider contract,
    privacy notice, retention, biometric, manual-review, discrimination, and
    appeal obligations apply? Real ID collection is currently disabled.
28. Before push, crash reporting, product analytics, advertising, or in-app
    purchases are enabled, which teen privacy, consent, tracking, retention,
    SDK, and store disclosures are required?
29. Is the deterministic Support assistant disclosure sufficient, and what
    disclosure, consent, human-review, retention, and reporting rules would
    apply before any third-party generative AI is enabled?

## Documents Requiring Written Review

Counsel should review all document keys in the server's required public legal
set, including Terms of Service, Terms of Use, Privacy Policy, Community
Guidelines, Safety Rules, Guardian Terms, retention/deletion, location,
identity, moderation/appeals, prohibited work, payment disputes, and Support AI
disclosure. Current drafts are engineering work product only.

The three new 2026-08-01 drafts are:

- `MORT_COMMUNITY_GUIDELINES_DRAFT.md`
- `MORT_SAFETY_RULES_DRAFT.md`
- `MORT_GUARDIAN_TERMS_DRAFT.md`

## Required Written Outputs

- Approved launch jurisdictions, age bands, job categories, hours, supervision,
  consent model, and prohibited work matrix.
- Approved document text, locale, effective date, version, material-change and
  re-consent decision, counsel reference, and retention schedule.
- Approved staffing, urgent escalation, appeal independence, child-safety
  contact, privacy contact, support contact, and incident on-call obligations.
- Approved Play Console declarations for the exact release artifact.
- Explicit go, restricted-pilot, or no-go decision with assumptions and expiry.

## Engineering Activation Gate

Public activation is fail-closed. The hosted database requires all of the
following before it can be opened: recorded adult-owner approval; attorney
package approval and counsel reference; approved child-safety, privacy, and
support contacts; approved Play declarations; approved moderation staffing and
incident on-call coverage; an approved exact document-set hash; published,
effective, attorney-reviewed `en-US` versions of every required document;
approved US/Indiana jurisdiction entries; production identity readiness; a
production-public policy; and no unbounded active staff assignments.

There is no ordinary client or admin RPC that can grant these approvals.
Activating the public marketplace requires a separately reviewed server
migration and real external evidence. All controls currently remain false.
