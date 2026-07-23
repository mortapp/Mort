import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const draftBanner = "DRAFT — NOT ATTORNEY REVIEWED OR LEGALLY APPROVED";

function write(relativePath, content) {
  const destination = join(root, relativePath);
  mkdirSync(dirname(destination), { recursive: true });
  writeFileSync(destination, `${content.trim()}\n`, "utf8");
}

function legalDraft(title, purpose, sections) {
  const body = sections
    .map(([heading, paragraphs]) => `## ${heading}\n\n${paragraphs.join("\n\n")}`)
    .join("\n\n");
  return `# ${title}\n\n> **${draftBanner}**\n>\n> This document is an original MORT working draft for review by licensed counsel and qualified youth-safety, privacy, labor, insurance, and operations professionals. It is not legal advice, does not make MORT legally approved, and must not be presented as a final contract or policy.\n\n## Purpose and status\n\n${purpose}\n\n${body}\n\n## Required professional review\n\nBefore publication, licensed counsel must determine enforceability, age and capacity rules, required parental consent, electronic-signature requirements, labor classification, wage law, privacy and biometric duties, negligence and statutory duties, dispute terms, insurance, indemnification, arbitration, class-action treatment, limitation of liability, governing law, and nonwaivable rights for each launch jurisdiction. Material revisions require a new version, content hash, effective date, and affirmative reacceptance where applicable.\n`;
}

const balancedRisk = [
  "MORT cannot guarantee that any participant is harmless or that crime, injury, kidnapping, assault, theft, harassment, property damage, or another unsafe event will never occur. MORT provides controls intended to reduce identifiable risks, but screening, reviews, safety tools, and account status are not guarantees of character, conduct, or future safety.",
  "A participant may leave, cancel, or seek help when they reasonably perceive danger. Immediate danger should be reported to emergency services. MORT does not replace emergency services or law enforcement. MORT may preserve relevant evidence and respond to lawful requests, while other users remain responsible for their own unlawful conduct.",
  "Any liability limitation applies only where legally enforceable. Nothing in this draft attempts to waive nonwaivable rights or duties, excuse intentional or reckless conduct, blame a victim, or predetermine responsibility. Negligence, gross negligence, statutory duties, indemnification, arbitration, class actions, and damages require jurisdiction-specific attorney review.",
];

const paymentBoundary = [
  "MORT currently records an agreed amount, payment preference, due time, completion evidence, and payment-confirmation status. It does not process funds, hold money, provide escrow, or independently know that an off-platform payment was received.",
  "A payment dispute is a private platform process, not a court judgment or criminal accusation. MORT may preserve evidence, restrict marketplace privileges after review, offer an appeal, and link to official resources. It does not automatically file a lawsuit, choose a legal claim, represent a party, promise recovery, or determine conclusively whether a wage, contractor, volunteer, internship, or other legal relationship exists.",
];

const legalFiles = {
  "docs/legal/MORT_TERMS_OF_SERVICE_DRAFT.md": legalDraft(
    "MORT Terms of Service Draft",
    "These proposed platform terms describe account eligibility, marketplace conduct, job records, safety, privacy, moderation, and disputes for MORT's closed-pilot teen-safe local hustle marketplace.",
    [
      ["Eligibility and accounts", ["MORT is designed for teens ages 13-17, adults or businesses posting jobs, optional guardians, trained reviewers, and authorized administrators. Each person must use an individual Supabase Auth account, provide accurate age and role information, protect credentials, and avoid account sharing. Public marketplace participation remains closed until production verification and operational readiness exist.", "A teen's legal capacity to contract and any required parent or guardian consent depend on jurisdiction. Optional Guardian Mode is a product feature and is not a substitute for a legally required consent process. Refusing optional Guardian Mode does not by itself prevent account use."]],
      ["Marketplace relationship", ["MORT provides software for discovering, documenting, and managing local work opportunities. The parties decide whether to enter a job-specific arrangement. MORT does not conclusively classify the relationship as employment, independent contracting, volunteering, internship, training, or business-to-business work.", "Users must comply with applicable youth-employment, wage, tax, licensing, permit, safety, supervision, and business rules. The platform may block prohibited or high-risk work and may require a closed-pilot organization, trained staff visibility, or additional review."]],
      ["Job agreements and changes", ["An accepted application creates a versioned job agreement recording scope, excluded work, schedule, location release state, amount, maximum hours, expenses, equipment, hazards, people present, proof, payment timing, cancellation, and dispute terms. Both parties must affirm the applicable version.", "A material change cannot be imposed silently. Lowering payment, expanding scope, extending hours, changing location, adding hazards or expenses, or changing payment timing requires a recorded change request and confirmation by both parties."]],
      ["Safety and participant conduct", balancedRisk],
      ["Payment and disputes", paymentBoundary],
      ["Content, privacy, and evidence", ["Users may submit messages, job information, and narrowly necessary proof. They must have the right to submit it and must not upload Social Security numbers, unrelated identity documents, sexual content involving minors, doxxing material, malware, or another person's private data without authority.", "MORT may retain immutable audit events and preserve relevant contract, safety, completion, payment, and incident records as described in the Privacy Policy and retention schedule. Access is limited by role, assignment, purpose, and row-level security."]],
      ["Moderation, suspension, and appeal", ["MORT may privately warn, restrict, suspend, or close an account when reasonably necessary for safety, fraud prevention, unpaid-work review, policy enforcement, or legal compliance. Consequential action should include recorded reasons, bounded reviewer access, and an appeal unless emergency containment requires immediate temporary action."]],
      ["Disputes and legal terms", ["No arbitration, class-action waiver, indemnification duty, liability cap, governing-law clause, or forum-selection clause is approved in this draft. Counsel must decide whether any such provision is lawful, fair, age-appropriate, and enforceable before publication."]],
    ],
  ),
  "docs/legal/MORT_TERMS_OF_USE_DRAFT.md": legalDraft(
    "MORT Terms of Use Draft",
    "These website and application use rules cover access to MORT software separately from any job-specific agreement.",
    [
      ["Permitted use", ["Users may use MORT only through supported clients and authorized APIs for lawful marketplace, safety, support, and administrative purposes. Access is revocable and does not transfer ownership of MORT software, branding, or content."]],
      ["Prohibited technical conduct", ["Users may not bypass access controls, probe another user's records, scrape private data, introduce malicious code, evade rate limits, forge audit events, reverse-engineer secrets, interfere with service availability, or use group-chat membership as evidence of authorization."]],
      ["Age-aware access", ["Teen users receive plain-language summaries before full legal text. No checkbox is preselected, browsing alone is not acceptance, and required documents must be accepted through the version-bound server flow. Guardian Mode remains optional unless a separate jurisdiction-specific legal-consent rule applies."]],
      ["Availability and changes", ["MORT may change or discontinue features, especially closed-pilot and experimental safety features. A material legal change requires a new document version and reacceptance; continued browsing alone is not treated as assent."]],
      ["Safety and risk", balancedRisk],
      ["Intellectual property and feedback", ["MORT retains rights in its software and original materials. A user retains ownership of lawful content they submit and grants only the limited rights needed to operate, secure, moderate, preserve, and provide the service. Product feedback may be used without exposing private user data."]],
    ],
  ),
  "docs/legal/MORT_PRIVACY_POLICY_DRAFT.md": legalDraft(
    "MORT Privacy Policy Draft",
    "This draft describes intended collection, use, sharing, retention, security, and user controls for a youth-centered marketplace.",
    [
      ["Data categories", ["MORT may process account identifiers, role and age band, date of birth for age gating, profile and approximate area, job and application records, messages, safety reports, blocks, location release state, proof metadata, notification tokens, device-security settings, legal acceptances, payment preference, audit events, and support records.", "Real government or school identity documents, face video, and external web-reuse processing remain disabled. Development and QA use synthetic fixtures only. MORT does not collect Social Security numbers or store biometric templates."]],
      ["Purposes", ["Data is used to authenticate users, enforce age and role rules, operate jobs and messaging, preserve job agreements, deliver safety controls, investigate reports, support disputes, prevent abuse, maintain security, satisfy lawful obligations, and improve accessibility and reliability."]],
      ["Location", ["MORT uses city, state, approximate area, and staged exact-location release. A residential address must not be public. Exact job location is available only to authorized accepted-job participants and designated safety contexts, with audit records and device authentication where supported."]],
      ["Identity and biometric boundaries", ["Apple Face ID or Touch ID can protect information on the user's device. MORT receives only a success or failure result from the operating system and does not receive or store raw biometric data. Device authentication does not verify legal identity.", "Future document quality, web-reuse, live-presence, and appearance-consistency features are separate signals. No public web match proves fraud; no absent match proves authenticity; gestures do not prove legal identity; and appearance review must not create a persistent face-recognition database."]],
      ["Sharing and service providers", ["MORT may share the minimum necessary information with contracted infrastructure, notification, hosting, security, and approved verification providers under appropriate terms. Sensitive identity processing requires a separate privacy review, vendor agreement, retention review, disclosure, and readiness approval before enablement."]],
      ["Retention and deletion", ["Retention is category-specific. Account deletion requests do not automatically erase records that must be preserved for safety, fraud prevention, contracts, disputes, legal obligations, or security. Expired sensitive derivatives should be deleted through audited server-side retention actions when no hold applies."]],
      ["Rights and contact", ["Access, correction, deletion, restriction, appeal, and portability rights vary by jurisdiction and user status. MORT must provide a verified request channel and must not expose another person's data in a response."]],
    ],
  ),
  "docs/legal/MORT_TEEN_PLAIN_LANGUAGE_TERMS.md": legalDraft(
    "MORT Teen Plain-Language Terms",
    "This summary is written for teen users. It supplements, but does not replace, the full terms that must remain available before acceptance.",
    [
      ["What MORT does", ["MORT helps you find local jobs and keep important details in one place. It records who agreed to the job, what work is included, the amount, timing, safety details, proof, and payment status. MORT does not hold or send the money."]],
      ["Your choices", ["Guardian Mode is optional. You can use safety tools without paying. You can leave or cancel if you reasonably feel unsafe. You can report, block, use Safety Ping, and ask for help without buying an upgrade."]],
      ["Your responsibilities", ["Use your own account, be honest about your age and job activity, keep communication respectful, follow the agreed scope, do not share private addresses or identity files, and never upload sexual content, threats, weapons, drugs, or another person's private information."]],
      ["When a job changes", ["The adult cannot quietly lower your pay, add work, extend the time, move the location, add hazards, add expenses, or delay payment. You both must review and confirm a material change."]],
      ["Safety limits", balancedRisk],
      ["Payment problems", paymentBoundary],
      ["Legal review note", ["Because teen contract rights and required adult consent can differ by location, a lawyer must review the final version for every place MORT launches. This draft is not the final agreement."]],
    ],
  ),
  "docs/legal/MORT_ADULT_POSTER_AGREEMENT_DRAFT.md": legalDraft(
    "MORT Adult Poster Agreement Draft",
    "This proposed agreement sets added duties for an adult who publishes or manages a teen job.",
    [
      ["Poster eligibility", ["The poster must be an adult authorized to offer the work and must complete the verification, business, closed-pilot, and jurisdiction controls that apply. Account badges and reviews are signals, not guarantees."]],
      ["Accurate job disclosure", ["The poster must state the real scope, exclusions, schedule, amount, maximum hours, payment timing, location type, hazards, equipment, expected people, supervision, transportation, animals, and proof needs. Hidden hazardous work, sexualized work, illegal work, weapons, controlled substances, unsupervised transport, and prohibited youth labor are not allowed."]],
      ["No unilateral changes", ["The poster may not silently lower payment, expand scope, extend hours, change location, add hazards, add unapproved expenses, or change the due time. A material change requires a recorded request and both parties' confirmation."]],
      ["Payment duty", ["The poster must pay an undisputed completed-job obligation at the agreed time and truthfully confirm payment only after it occurs. Failure to pay may result in private evidence preservation, dispute review, temporary posting restrictions, appeal, and links to official remedies. It is not automatically treated as theft or a court judgment."]],
      ["Safety and conduct", balancedRisk],
      ["Classification", ["The poster is responsible for evaluating employment, contractor, volunteer, internship, tax, wage, permit, supervision, insurance, and recordkeeping duties with qualified advisers. MORT does not conclusively classify the relationship."]],
    ],
  ),
  "docs/legal/MORT_BUSINESS_ACCOUNT_AGREEMENT_DRAFT.md": legalDraft(
    "MORT Business Account Agreement Draft",
    "This draft adds obligations for businesses and their authorized representatives.",
    [
      ["Authority and records", ["A representative must have actual authority to act for the business, use an individual account, provide accurate registry and contact information, and keep representative claims current. Shared credentials are prohibited."]],
      ["Youth-work compliance", ["The business must review child-labor hours, prohibited occupations, permits, supervision, wage, payroll, tax, insurance, accessibility, nondiscrimination, and recordkeeping requirements before offering work. A platform eligibility result is not legal clearance."]],
      ["Operational duties", ["The business must designate an on-site responsible adult, disclose all expected people and hazards, preserve contract and payment records, prevent retaliation, and promptly report safety incidents or material location changes."]],
      ["Payment and disputes", paymentBoundary],
      ["Verification limitations", ["Registry, representative, document, or identity signals do not guarantee that a business or person is safe, solvent, lawful, or suitable. MORT may restrict access while a material discrepancy is reviewed."]],
    ],
  ),
  "docs/legal/MORT_PARTNER_ORGANIZATION_AGREEMENT_DRAFT.md": legalDraft(
    "MORT Partner Organization Agreement Draft",
    "This draft governs schools, nonprofits, youth programs, and community organizations participating in a controlled pilot.",
    [
      ["Authority and scope", ["The partner identifies its legal entity, authorized representative, approved program, participating staff, locations, intended roles, and permitted pilot activities. Partnership does not imply endorsement of every user or job."]],
      ["Safeguarding", ["The partner must maintain youth-safety rules, staff screening appropriate to its role, mandatory-reporting guidance, escalation contacts, supervision, confidentiality, disability accommodation, and immediate revocation procedures."]],
      ["Data access", ["Partner access is least privilege, individually assigned, time limited, purpose bound, and audited. No raw identity file, residential address, incident evidence, or production secret may be shared through group chat, text, personal email, or social media."]],
      ["Pilot limits", ["Public marketplace access and real identity-document collection remain disabled. The partner must not represent synthetic QA, document quality checks, or sandbox status as authoritative identity verification."]],
      ["Termination and incident cooperation", ["Either party may stop the pilot under the final negotiated terms. Safety containment may be immediate. Evidence preservation and lawful-request handling follow written policy and do not authorize amateur investigations."]],
    ],
  ),
  "docs/legal/MORT_JOB_SERVICE_AGREEMENT_DRAFT.md": legalDraft(
    "MORT Job Service Agreement Draft",
    "This is the proposed template for the immutable, job-specific agreement created after an application is accepted.",
    [
      ["Required terms", ["Each version identifies the job and application, public party identifiers, exact included and excluded work, location type and release state, date, start and end window, fixed or hourly amount, rate, maximum hours, fixed total, payment preference and due time, expenses, equipment, hazards, expected people, supervision, proof, completion, cancellation, change, dispute, and safety terms."]],
      ["Confirmation", ["The teen and adult each affirm the same version using an unchecked-by-default control. Server records include version, content hash, role, timestamp, platform, app version, and affirmation text. One party cannot write the other party's confirmation."]],
      ["Changes", ["Material changes require a proposed replacement version and both parties' confirmation. Prior versions remain immutable and visible in authorized history. Emergency safety cancellation does not require agreement from a person who reasonably perceives danger."]],
      ["Classification and law", ["The agreement records facts but does not conclusively determine employee, contractor, volunteer, internship, program, or business status. Youth-work and contract-capacity questions require local counsel."]],
      ["Risk", balancedRisk],
    ],
  ),
  "docs/legal/MORT_PAYMENT_OBLIGATION_AGREEMENT_DRAFT.md": legalDraft(
    "MORT Payment Obligation Agreement Draft",
    "This draft explains the poster's recorded payment obligation without implying payment processing or escrow.",
    [
      ["Obligation record", ["The record identifies the contract version, obligated poster, worker, amount, currency, due time, payment preference, current status, confirmation events, and dispute state. Amount changes require a mutually accepted contract version."]],
      ["No payment custody", ["MORT does not hold funds, transmit money, guarantee solvency, or mark an off-platform payment received without an authorized confirmation. A preference such as cash or another service is not proof of payment."]],
      ["Missed payment", ["Failure to pay an undisputed completed-job obligation may result in account restriction, evidence preservation, private dispute review, and the worker pursuing available remedies through the appropriate official process."]],
      ["Remedy limits", paymentBoundary],
    ],
  ),
  "docs/legal/MORT_MARKETPLACE_RISK_DISCLOSURE.md": legalDraft(
    "MORT Marketplace Risk Disclosure",
    "This disclosure describes material marketplace risks without blaming victims or suggesting that safety controls eliminate danger.",
    [
      ["People and places", balancedRisk],
      ["Work risks", ["Local work can involve tools, lifting, weather, animals, transportation, private property, unfamiliar adults, and schedule changes. MORT limits work categories and records disclosures, but a participant must still use judgment and follow applicable safety rules."]],
      ["Verification limits", ["An email, phone number, school affiliation, program membership, business registry match, reviewed document, web-reuse signal, live-presence gesture, profile photo, or device biometric is only the signal described. None alone proves legal identity or future safety."]],
      ["Financial and legal risks", ["Off-platform payment may be late, disputed, or unpaid. Evidence may help but does not guarantee recovery. Classification, enforceability, insurance, and official remedies depend on facts and local law."]],
    ],
  ),
  "docs/legal/MORT_ACCEPTABLE_USE_POLICY.md": legalDraft(
    "MORT Acceptable Use Policy",
    "This policy defines conduct and content boundaries for all roles.",
    [
      ["Required conduct", ["Use an individual account, communicate respectfully, provide accurate job facts, protect private information, honor recorded agreements, cooperate with safety review, and use reports in good faith."]],
      ["Prohibited conduct", ["No grooming, sexual content involving minors, harassment, hate, threats, stalking, trafficking, weapons, drugs, fraud, retaliation, doxxing, extortion, impersonation, account sharing, unlawful discrimination, malware, access-control bypass, forged acceptance, false payment confirmation, or fabricated acknowledgment."]],
      ["Sensitive information", ["Do not place Social Security numbers, full identity-document numbers, raw IDs, face video, residential addresses, incident evidence, production secrets, or private screenshots in public posts, ordinary messages, group chats, analytics, or logs."]],
      ["Enforcement", ["MORT may remove content, limit features, preserve evidence, restrict accounts, escalate imminent danger, and provide appeal. A report or restriction is not a public finding of criminal guilt."]],
    ],
  ),
  "docs/legal/MORT_COMMUNITY_AND_SAFETY_RULES.md": legalDraft(
    "MORT Community and Safety Rules",
    "These plain conduct rules apply to teens, adults, businesses, guardians, reviewers, partners, and administrators.",
    [
      ["Respect and boundaries", ["Keep job communication professional. Do not sexualize, groom, isolate, pressure, threaten, shame, retaliate, demand secrecy, or force off-platform contact. Respect a participant's decision to leave an unsafe situation."]],
      ["Job integrity", ["Do only the agreed work at the agreed place and time. Disclose people, animals, equipment, hazards, transportation, and supervision. Material changes need both parties' confirmation."]],
      ["Safety response", ["Use block, report, Safety Ping, support contacts, and emergency services as appropriate. MORT staff preserve evidence and follow runbooks; they do not conduct amateur criminal investigations."]],
      ["Fair review", ["Reports remain private to authorized people. Reviewers avoid victim blaming, stereotypes, disability discrimination, public accusations, and conclusions beyond the evidence and their role."]],
    ],
  ),
  "docs/legal/MORT_PROHIBITED_WORK_POLICY.md": legalDraft(
    "MORT Prohibited Work Policy",
    "This policy blocks work that is unlawful, unsuitable for minors, or outside the controlled pilot's safety model.",
    [
      ["Always prohibited", ["No sexual services or content; weapons or explosives; controlled substances; alcohol or tobacco handling; gambling; criminal activity; adult entertainment; private surveillance; harassment; political coercion; medical care; hazardous machinery; roofing; demolition; excavation; confined spaces; live electrical work; pesticide application; driving jobs; unsupervised overnight work; or any occupation prohibited for the teen's age or jurisdiction."]],
      ["Requires professional review", ["Construction, food service, childcare, animal handling, transportation-adjacent tasks, power tools, ladders, chemicals, heavy lifting, late hours, private-home entry, and jobs involving vulnerable people require jurisdiction and pilot-policy review and may remain unavailable."]],
      ["No evasion", ["A poster may not disguise prohibited work, move material scope into messages, or add it after acceptance. Safety cancellation and reporting remain available without charge."]],
    ],
  ),
  "docs/legal/MORT_LOCATION_AND_MEETING_POLICY.md": legalDraft(
    "MORT Location and Meeting Policy",
    "This policy uses staged location disclosure and safer meeting controls.",
    [
      ["Public information", ["Public job listings use city, state, approximate area, and a broad location type. Residential addresses and precise coordinates are never public."]],
      ["Release stages", ["Exact location may be released only after an application is accepted, required confirmations exist, authorization is current, and the viewer is a participant or narrowly authorized safety contact. Sensitive location views should require device authentication where supported and create audit events."]],
      ["Safer meeting options", ["Prefer daylight, staffed, public, or visible locations when possible. Record expected people, supervision, arrival handshake, change requests, and departure. An unexpected person or location change permits cancellation and escalation."]],
      ["Emergency limits", ["Location tools can be delayed or inaccurate and do not replace emergency services. Sharing is minimized, revocable where possible, and retained only according to policy and legal holds."]],
    ],
  ),
  "docs/legal/MORT_IDENTITY_REVIEW_DISCLOSURE.md": legalDraft(
    "MORT Identity Review Disclosure",
    "This disclosure separates evidence collection, quality review, human review, and authoritative verification.",
    [
      ["Current status", ["Hosted production identity-document collection is disabled. Real government IDs, school IDs, selfies, and face videos are not accepted. Sandbox verification uses synthetic QA fixtures only and does not open the public marketplace."]],
      ["Result labels", ["Capture completed, quality passed, data extracted, format consistent, web-reuse signal clear or flagged, manual review completed, age evidence reviewed, appearance consistency reviewed, and live-presence challenge passed are limited findings. They do not mean authoritative identity verified."]],
      ["Limits", ["OCR, barcodes, MRZ data, visual review, no public web match, a visible face, gestures, school email, school ID, phone OTP, or Apple Face ID cannot by themselves establish legal identity, document authenticity, account ownership, or harmlessness."]],
      ["Readiness", ["Any future real collection requires counsel, privacy and biometric review, vendor and retention decisions, trained and screened reviewers, two-person controls, accommodations, appeals, incident response, secure deletion, insurance review, and all operational gates enabled."]],
    ],
  ),
  "docs/legal/MORT_LIVENESS_CHECK_DISCLOSURE.md": legalDraft(
    "MORT Live-Presence Check Disclosure",
    "This disclosure describes a future first-party live-presence challenge without calling it certified biometric liveness or legal identity verification.",
    [
      ["Current status", ["Real-user live-presence capture is disabled. Only synthetic metadata may be used in QA. No real face video belongs in source control, archives, logs, analytics, or ordinary database tables."]],
      ["Proposed challenge", ["A server nonce, short expiration, random subset and order of accessible movements, challenge binding, replay checks, frame continuity, face-presence, and multiple-face rejection may support the limited result live_presence_challenge_passed."]],
      ["Accessibility", ["A user who cannot perform a movement receives an alternative route and manual exception process without punishment. MORT must not infer emotion, attractiveness, race, ethnicity, disability, or health."]],
      ["Limits and retention", ["Head movement, blink, nod, or marker following does not prove legal identity. Any future encrypted short video must be minimized, access controlled, automatically deleted, and never converted into a permanent reusable face template."]],
    ],
  ),
  "docs/legal/MORT_FACE_ID_DISCLOSURE.md": legalDraft(
    "MORT Face ID and Touch ID Disclosure",
    "This disclosure explains local device authentication as an account-protection control, not an identity-verification system.",
    [
      ["Device protection", ["MORT uses Face ID or Touch ID to protect private information on this device. It does not verify your legal identity. Supported controls may protect app reopening, private location, incident status, proof actions, data export, deletion requests, support changes, and reviewer access."]],
      ["Data boundary", ["Apple evaluates the biometric locally. MORT receives an authentication result, not a face image, fingerprint, biometric template, or sensor data. No biometric data is sent to Supabase."]],
      ["Fallback and failure", ["The app handles unavailable, not enrolled, user canceled, failed match, lockout, system canceled, enrollment change, and device-passcode fallback states. A success cannot raise an identity-verification level."]],
      ["Web", ["Flutter Web may explain passkeys or WebAuthn where supported but must not claim direct Face ID access or treat a passkey as legal identity proof."]],
    ],
  ),
  "docs/legal/MORT_PAYMENT_DISPUTE_POLICY.md": legalDraft(
    "MORT Payment Dispute Policy",
    "This policy defines a private, graduated response to reported unpaid work.",
    [
      ["Payment due", ["The worker sees pending status and the poster receives a reminder based on the accepted obligation. MORT does not state that off-platform payment was received without confirmation."]],
      ["Missed payment", ["The worker may report unpaid work and submit relevant contract, proof, message, reminder, or witness metadata. The poster may confirm payment or open a good-faith dispute. Evidence is preserved, retaliation controls apply, and publication may pause."]],
      ["Restriction", ["After preliminary review, a poster may be temporarily blocked from publishing jobs, accepting new teens, or sending repeat invitations. The status is private and is not a public accusation."]],
      ["Review and appeal", ["Authorized reviewers compare the contract, proof, messages, change orders, and statements. They may recommend payment, partial payment, more evidence, or no platform determination. They do not act as a court. An appeal and conflict review are available."]],
      ["Resources", paymentBoundary],
    ],
  ),
  "docs/legal/MORT_MODERATION_AND_APPEALS_POLICY.md": legalDraft(
    "MORT Moderation and Appeals Policy",
    "This policy establishes reasoned, private, age-aware moderation and review.",
    [
      ["Intake and containment", ["MORT records the report, affected accounts, safety severity, evidence references, and immediate containment. Imminent danger may require temporary action before full review."]],
      ["Decision quality", ["Authorized reviewers use least privilege, declared purpose, conflict checks, and only assigned records. Decisions distinguish allegation, observed evidence, platform finding, and legal uncertainty. No reviewer labels a person criminally guilty."]],
      ["Notice and appeal", ["Where safe and lawful, the affected user receives the policy basis, action, duration, and appeal route without disclosure of another person's private data. High-impact identity or appearance mismatches require two independent reviewers."]],
      ["Audit", ["Assignments, access, decisions, changes, and revocations are immutable audit events. Founder status, friendship, family relationship, or group-chat membership grants no automatic evidence access."]],
    ],
  ),
  "docs/legal/MORT_INCIDENT_AND_EVIDENCE_POLICY.md": legalDraft(
    "MORT Incident and Evidence Policy",
    "This policy governs minimized incident evidence, preservation, access, export, and deletion.",
    [
      ["Collection", ["Collect only material facts and authorized evidence. Do not ask a teen to recreate danger, confront an accused person, investigate a crime, or provide invasive proof. Do not collect unrelated identity files or residential data."]],
      ["Preservation", ["Evidence records use hashes, timestamps, source role, case association, access grants, and preservation holds. Participants cannot delete preserved records or rewrite immutable history."]],
      ["Access and disclosure", ["Access requires an individual account, approved role, assigned case, stated purpose, training, device compliance, and an audit event. Law-enforcement requests follow the dedicated runbook and qualified review. No group-chat sharing."]],
      ["Exports", ["An authorized export includes only records the requester may receive, redacts third-party identity and residential information, labels allegations and decisions accurately, and contains integrity hashes and a plain-language timeline."]],
    ],
  ),
  "docs/legal/MORT_DATA_RETENTION_AND_DELETION_DRAFT.md": legalDraft(
    "MORT Data Retention and Deletion Draft",
    "This draft defines category-based retention and audited deletion instead of indefinite storage or unsafe blanket deletion.",
    [
      ["Categories", ["Account, legal acceptance, contract, payment, safety, incident, document metadata, temporary derivatives, liveness, access logs, notification, and support records require separate schedules based on purpose and law."]],
      ["Sensitive defaults", ["Raw identity and face data remain disabled. If later approved, temporary derivatives and short video must have the shortest justified timer, encrypted storage, access logging, legal-hold checks, and server-side deletion. No raw ID belongs in logs or analytics."]],
      ["Deletion requests", ["A verified request triggers a category review. MORT should delete or deidentify records no longer needed, while retaining narrowly necessary contract, security, fraud, incident, dispute, legal-hold, and statutory records with documented authority."]],
      ["Audit", ["Retention actions record category, object reference, policy version, actor or server process, reason, hold state, outcome, and timestamp. Ordinary admins cannot bypass holds or backdate actions."]],
    ],
  ),
  "docs/legal/MORT_LIMITATION_OF_LIABILITY_DRAFT.md": legalDraft(
    "MORT Limitation of Liability Draft",
    "This is a drafting issue list, not an approved waiver or liability cap.",
    [
      ["Balanced boundary", balancedRisk],
      ["Nonwaivable rights", ["Nothing should exclude duties or remedies that law does not permit a party to waive. Any treatment of negligence, gross negligence, reckless or intentional conduct, statutory duties, personal injury, privacy, youth protection, consumer rights, or third-party misconduct requires counsel."]],
      ["No blanket immunity", ["MORT must not claim immunity from every lawsuit, blame a victim, guarantee screening, or use an absolute statement about kidnapping or other harm. Insurance and indemnification cannot be assumed to cover a risk."]],
      ["Unresolved terms", ["No damages cap, consequential-damages exclusion, warranty disclaimer, indemnification, arbitration, class waiver, choice of law, or forum is approved. Counsel must draft and validate any final language for each role, age band, and jurisdiction."]],
    ],
  ),
  "docs/legal/MORT_INSURANCE_DISCLOSURE_DRAFT.md": legalDraft(
    "MORT Insurance Disclosure Draft",
    "This draft prevents users from assuming that MORT, a poster, a worker, or a partner has insurance for a particular job.",
    [
      ["No automatic coverage", ["Unless MORT provides a specific written, current, approved disclosure for a named program, users must not assume that general liability, workers' compensation, accident, auto, property, cyber, professional, abuse and molestation, or other coverage applies."]],
      ["Poster duties", ["Adults, businesses, and partners are responsible for determining required coverage and exclusions with qualified professionals. A badge, account status, registry match, or pilot approval is not proof that a claim will be covered."]],
      ["Claims", ["MORT does not promise payment of an insurance claim or determine coverage. Users should preserve facts and use the insurer's official process. Immediate danger still goes to emergency services."]],
    ],
  ),
  "docs/legal/MORT_CLOSED_PILOT_RULES.md": legalDraft(
    "MORT Closed Pilot Rules",
    "These rules keep the marketplace closed while verification, legal, safety, and operations readiness remains incomplete.",
    [
      ["Eligibility", ["Participation requires an approved test account, permitted partner or pilot enrollment, supported jurisdiction, role-appropriate acknowledgments, and job-level review. Real-document verification is disabled and sandbox status does not confer production trust."]],
      ["Job limits", ["Only lower-risk, reviewed jobs at approved, staffed or visible locations may proceed. Prohibited work, unclassified private-home work, unsafe transportation, hidden scope, and unsupported locations remain blocked."]],
      ["Safety and payment", ["Reporting, blocking, Safety Ping, cancellation, basic job applying, and optional Guardian Mode remain free. Payment is off-platform and no escrow exists. Contract, proof, payment, and dispute records are testable without promising legal recovery."]],
      ["Stop conditions", ["MORT may pause the pilot after a safety incident, privacy concern, access-control failure, legal uncertainty, reviewer shortage, data breach, or failed readiness gate. The pilot is not a public launch or production-readiness claim."]],
    ],
  ),
  "docs/legal/MORT_VOLUNTEER_AND_TESTER_POLICY_DRAFT.md": legalDraft(
    "MORT Volunteer and Tester Policy Draft",
    "This draft defines safe participation for family members, friends, and trusted adults without deciding their legal work classification.",
    [
      ["No automatic status", ["Calling someone a volunteer, contractor, tester, intern, ambassador, family member, or friend does not determine employment, wage, tax, insurance, recordkeeping, or classification obligations. No hourly compensation, including a $3 rate, is approved."]],
      ["Access", ["Participation requires an individual account, approved role, least privilege, confidentiality acknowledgment, training, conflict disclosure, device controls, time limit, access reason, and revocation path. Group-chat membership grants nothing."]],
      ["Prohibited handling", ["No production secret, raw ID, face video, residential address, incident evidence, sensitive screenshot, or user export may be sent through group chat, text, social media, personal storage, or unapproved email."]],
      ["Scope", ["Testers use synthetic or specifically authorized pilot data. Cybersecurity advisers may review architecture and controls but do not approve legal terms, child-safety policy, biometric privacy, labor classification, document authenticity, court strategy, or law-enforcement disclosure."]],
    ],
  ),
};

for (const [path, content] of Object.entries(legalFiles)) write(path, content);

write("docs/MORT_NONPAYMENT_OPERATIONAL_PROCESS.md", `# MORT Nonpayment Operational Process\n\n> **${draftBanner}**\n\n## Boundary\n\nMORT records obligations and evidence but does not process money, hold escrow, decide criminal guilt, act as a court, provide legal representation, or guarantee recovery.\n\n## Stage 1: payment due\n\nThe accepted contract creates a due amount and time. The worker sees pending status. The poster receives a clear reminder. No off-platform payment is marked received without an authorized confirmation.\n\n## Stage 2: missed payment\n\nThe worker may report unpaid work and submit minimally necessary evidence. The poster may confirm payment or open a good-faith dispute. Relevant evidence is preserved, retaliation controls activate, and ordinary review publication may pause.\n\n## Stage 3: restricted account\n\nAfter preliminary evidence review, a poster may be privately prevented from publishing jobs, accepting new teens, or sending repeat invitations. The restriction has a reason, reviewer, duration, appeal, and audit record. No public accusation is published.\n\n## Stage 4: review\n\nAssigned reviewers compare the immutable contract version, change orders, completion assertions, proof, authorized messages, reminders, and party statements. Outcomes may recommend payment, partial payment, more evidence, or no platform determination. The reviewer does not decide legal classification or act as a court.\n\n## Stage 5: export and official resources\n\nAn authorized party may receive a redacted contract, timeline, amount, proof status, authorized messages, reminder history, dispute status, evidence hashes, and plain-language summary. Official court, wage-claim, mediation, legal-aid, or attorney links are shown only conditionally by jurisdiction and relationship.\n\nFailure to pay an undisputed completed-job obligation may result in account restriction, evidence preservation, dispute review, and the worker pursuing available remedies through the appropriate official process. Court or wage-claim eligibility depends on the working relationship and local law. MORT cannot guarantee recovery or provide legal representation. For a minor's capacity, representation, guardian or next-friend requirements, and enforceability: **REQUIRES JURISDICTION-SPECIFIC ATTORNEY REVIEW**.\n`);

write("docs/MORT_LEGAL_INFORMATION_NOT_ADVICE_POLICY.md", `# MORT Legal Information, Not Advice Policy\n\n> **${draftBanner}**\n\nMORT may provide general, official, jurisdiction-tagged links and explain its own records and processes. It does not diagnose a legal claim, decide whether someone is an employee or contractor, predict success, select a court, calculate a filing deadline, draft individualized pleadings, threaten arrest or litigation, represent a user, or promise recovery.\n\nClassification values are limited to classification_unknown, possible_employee_relationship, possible_independent_service_relationship, organization_program_role, and requires_review. They are routing warnings, not legal conclusions.\n\nEmployee wage-claim information appears only as potentially relevant general information. Small-claims, mediation, legal-aid, bar-referral, child-labor, and emergency resources must link to an allowlisted official source and include jurisdiction and last-review metadata. A user is told to seek licensed counsel for individualized advice.\n\nAutomated content must never produce a legal conclusion from age, role, job title, payment method, or dispute status. High-risk questions route to trained support with a clear scope boundary.\n`);

write("docs/MORT_PAYMENT_EVIDENCE_EXPORT_STANDARD.md", `# MORT Payment Evidence Export Standard\n\n> **${draftBanner}**\n\n## Authorized scope\n\nOnly a contract party or specifically authorized reviewer may request an export. The server calculates scope from the authenticated user, contract, dispute, and access grants; a client cannot select another user's records.\n\n## Included records\n\n- immutable job contract versions and party confirmations\n- approved change requests and confirmations\n- amount, due time, preference, and obligation status\n- completion assertions, checklist, and authorized proof metadata\n- authorized job messages and payment reminders\n- payment confirmations and dispute timeline\n- decision and appeal status\n- evidence hashes, timestamps, source roles, and policy versions\n- plain-language classification and legal-information warning\n\n## Exclusions and redaction\n\nExclude raw IDs, document numbers, face data, unrelated incidents, residential addresses, precise coordinates, other users' private data, reviewer personal data, secrets, internal risk rules, and records outside the requester's authorization. Allegations remain labeled as allegations; platform decisions are not court judgments.\n\n## Integrity\n\nExports receive a generated timestamp, schema version, record manifest, per-record hashes where available, and overall manifest hash. Export events are audited and cannot modify source records.\n`);

write("docs/MORT_WEB_REUSE_SIGNAL_LIMITATIONS.md", `# MORT Web Reuse Signal Limitations\n\n> **${draftBanner}**\n\nReal document submission and external web processing are disabled. The architecture is server-side, provider-neutral, synthetic-QA only, and cannot use consumer Google Images, Google Lens, or client-held provider keys.\n\nA future provider may report exact or partial public matches, known sample-ID fixtures, public templates, or repeated synthetic fraud fixtures. A match creates only document_web_reuse_signal_flagged and requires human review. No match permits only: “No public web reuse was detected by the configured provider.” It must never mean genuine, authentic, owned by the submitter, or legally verified.\n\nCoverage is incomplete; pages may be private, deleted, unindexed, transformed, blocked, newly posted, or outside provider reach. False positives and false negatives are possible. URLs are reviewer restricted and treated as untrusted input. Results do not automatically approve or reject a person.\n`);

write("docs/MORT_EXTERNAL_IMAGE_PROCESSING_PRIVACY_REVIEW.md", `# MORT External Image Processing Privacy Review\n\n> **${draftBanner}**\n\nExternal processing of a minor's identity document or face is prohibited until all items below are approved and evidenced:\n\n- licensed privacy and biometric counsel review\n- child-safety and youth-consent review\n- explicit, age-appropriate disclosure and any required consent\n- vendor agreement, data-processing terms, subprocessor list, and breach duties\n- permitted purpose, region, transfer mechanism, and retention schedule\n- server-only credentials and egress allowlist\n- temporary derivative or redaction where technically possible\n- deletion after response and verified provider deletion terms\n- malicious URL handling and reviewer-only result access\n- accessibility alternative, appeal, and nondiscrimination review\n- operational readiness, incident response, insurance, and audit approval\n\nNo raw image or provider URL is returned to Swift or Flutter. No provider result independently establishes authenticity or legal identity. Current status: **DISABLED; SYNTHETIC QA ONLY**.\n`);

const operationDocs = {
  "docs/operations/MORT_TEAM_ROLE_MATRIX.md": `# MORT Team Role Matrix\n\n> **${draftBanner}**\n\n| Role | Permitted scope | Explicit exclusions | Prerequisites |\n|---|---|---|---|\n| product_tester | synthetic product flows | production users and evidence | confidentiality, device baseline |\n| accessibility_tester | accessibility review with synthetic data | identity decisions | accessibility training |\n| qa_tester | isolated QA fixtures | production records | QA and data-minimization training |\n| security_advisor | architecture, RLS, audit, secrets, threat model | legal, identity, child-safety approval | confidentiality, security scope |\n| developer | code and approved environments | unassigned evidence | MFA, environment and secret training |\n| partner_coordinator | approved partner metadata | raw IDs and incidents | partner training |\n| support_trainee | synthetic support cases | production users | training only |\n| document_reviewer_trainee | synthetic documents | real evidence | all reviewer modules |\n| document_reviewer | assigned case metadata when readiness is enabled | unassigned cases and final mismatch alone | approval, training, device review |\n| senior_document_reviewer | assigned second review and appeal | automatic identity approval | reviewer experience and approval |\n| safety_moderator | assigned reports and restrictions | unassigned IDs | safety and evidence training |\n| incident_manager | assigned high-risk incident coordination | amateur criminal investigation | incident training and approval |\n| super_admin | platform configuration and role governance | automatic raw-ID access | exceptional time-limited approval |\n\nAll permissions are individual, least privilege, purpose bound, time limited, audited, and revocable. Friendship, family relationship, founder status, or group-chat membership grants no access.`,
  "docs/operations/MORT_VOLUNTEER_EXPECTATIONS_DRAFT.md": `# MORT Volunteer Expectations Draft\n\n> **${draftBanner}**\n\nVolunteer status is not legally determined by this document. Participation is optional, bounded, and subject to counsel review. Helpers use individual accounts, complete assigned training, follow confidentiality and device rules, disclose conflicts, stay within role, report incidents, and return or delete authorized materials at offboarding. No production secret or sensitive user evidence goes into group chat. No compensation promise is made.`,
  "docs/operations/MORT_PAID_WORK_COMPLIANCE_HOLD.md": `# MORT Paid Work Compliance Hold\n\n> **${draftBanner}**\n\nNo hourly rate, including $3 per hour, is approved or promised. Before anyone performs compensated work, an authorized adult and qualified counsel or tax/payroll adviser must review employment status, minimum wage, youth labor, overtime, tax withholding, contractor rules, recordkeeping, insurance, workers' compensation, expense reimbursement, and local registration. Family or friendship does not remove these duties. MORT ordinary tables must not collect payroll Social Security numbers or banking information.`,
  "docs/operations/MORT_CONFIDENTIALITY_AND_DATA_ACCESS.md": `# MORT Confidentiality and Data Access\n\n> **${draftBanner}**\n\nAccess requires an individual account, approved role, training, confidentiality acknowledgment, conflict disclosure, secure device, purpose, case assignment, expiration, and immutable log. No shared password. No raw ID, face video, address, incident evidence, user export, or secret in group chat, text, social media, personal cloud storage, screenshot, or unapproved email. Suspected exposure is reported immediately and access is revoked during containment.`,
  "docs/operations/MORT_SECURITY_ADVISOR_SCOPE.md": `# MORT Security Advisor Scope\n\n> **${draftBanner}**\n\nA security adviser may review architecture, RLS, encryption, access controls, audit logs, threat models, incident logging, dependency risk, secrets, backups, and security tests. The role does not approve legal terms, child-safety policy, biometric privacy, labor classification, document authenticity, court strategy, law-enforcement disclosure, or production launch. Findings are recorded with evidence, severity, owner, and remediation status.`,
  "docs/operations/MORT_REVIEWER_ACCESS_READINESS.md": `# MORT Reviewer Access Readiness\n\n> **${draftBanner}**\n\nReal evidence access remains disabled until adult status, all 20 training modules, confidentiality, role approval, conflict disclosure, device requirements, MFA/passkey, background/access review where required, operational readiness, case assignment, purpose, retention controls, appeal staffing, two-person escalation, and incident response are evidenced. Founder or super-admin status alone is insufficient. Current real-document collection is disabled and synthetic QA only.`,
};
for (const [path, content] of Object.entries(operationDocs)) write(path, content);

const runbookFooter = `\n\n## Boundaries\n\nStaff preserve facts, protect affected people, and use qualified escalation. They do not confront a suspected offender, promise secrecy they cannot keep, conduct amateur criminal investigations, give individualized legal advice, publish accusations, or represent that this draft is legally approved. Every access and disclosure is minimized and logged.\n`;
const runbooks = {
  "docs/runbooks/MORT_MISSING_PERSON_ESCALATION.md": `# MORT Missing Person Escalation\n\n> **${draftBanner}**\n\n## Trigger\n\nA teen is unexpectedly unreachable, misses a required check-in, or an authorized contact raises a credible concern.\n\n## Immediate actions\n\n1. If danger may be immediate, direct the reporter to emergency services; do not impose a waiting period.\n2. Preserve account, job, location-release, check-in, message, and incident metadata without altering source records.\n3. Notify the incident manager and only authorized safety contacts according to the teen's permissions and emergency policy.\n4. Do not ask volunteers to search private property or contact a suspected person.\n5. Record times, factual statements, actions, and lawful-request references.\n\n## Closure\n\nConfirm safety through an authorized source, document the basis, remove temporary access when no longer needed, offer support and appeal, and conduct a privacy-preserving review.${runbookFooter}`,
  "docs/runbooks/MORT_ABDUCTION_CONCERN_RUNBOOK.md": `# MORT Abduction Concern Runbook\n\n> **${draftBanner}**\n\n## Trigger\n\nA report suggests force, coercion, confinement, transportation against will, grooming-linked removal, or another possible abduction.\n\n## Actions\n\n1. Treat possible immediate danger as an emergency and direct the reporter to emergency services.\n2. Do not contact or warn the suspected person. Do not tell staff to recover the teen.\n3. Apply emergency preservation to relevant job, participant, location, check-in, message, and access records.\n4. Restrict suspected accounts only as needed for containment and preserve appeal records.\n5. Route law-enforcement requests through the request runbook and qualified reviewer.\n6. Limit internal discussion to assigned responders; no group-chat screenshots or public statements.${runbookFooter}`,
  "docs/runbooks/MORT_SEXUAL_SAFETY_RUNBOOK.md": `# MORT Sexual Safety Runbook\n\n> **${draftBanner}**\n\n## Trigger\n\nSexual content involving a minor, grooming, sexual solicitation, coercion, assault, unwanted touching, image abuse, or credible boundary escalation.\n\n## Actions\n\n1. Center immediate safety and emergency services where danger is present.\n2. Do not blame, interrogate, demand repeated retelling, or require the affected person to confront anyone.\n3. Preserve minimally necessary evidence and restrict access to assigned trained staff.\n4. Follow applicable mandatory-reporting and child-safety escalation only after qualified policy review; do not improvise legal conclusions.\n5. Contain accounts and communication channels as necessary without publishing accusations.\n6. Offer accessible support, appeal, and privacy-preserving follow-up.${runbookFooter}`,
  "docs/runbooks/MORT_NONPAYMENT_RUNBOOK.md": `# MORT Nonpayment Runbook\n\n> **${draftBanner}**\n\n## Intake\n\nConfirm the authenticated worker is a contract party, the due time has passed, and the report identifies the obligation without declaring guilt. Preserve contract versions, confirmations, change orders, completion records, proof metadata, authorized messages, and reminders.\n\n## Review\n\nGive the poster an opportunity to confirm payment or dispute in good faith. Check retaliation and conflict signals. An assigned reviewer may recommend payment, partial payment, more evidence, or no determination. Temporary private posting restrictions require a recorded preliminary basis and appeal.\n\n## Export\n\nProvide only authorized, redacted records and conditional official resources. Do not threaten arrest, file a lawsuit, select claims, predict success, or call the poster a thief solely because payment is disputed.${runbookFooter}`,
  "docs/runbooks/MORT_LAW_ENFORCEMENT_REQUEST_RUNBOOK.md": `# MORT Law Enforcement Request Runbook\n\n> **${draftBanner}**\n\n## Intake\n\nRoute every request to the designated qualified reviewer. Record agency, requester, verified contact channel, legal process type, jurisdiction, scope, deadline, emergency assertion, preservation request, and conflict. Do not rely solely on caller ID or an emailed badge image.\n\n## Review and response\n\nValidate authority and scope with counsel where required. Preserve relevant records without disclosing them. Minimize and log any response, protect unrelated users, honor applicable notice rights or prohibitions, and use secure transfer. Emergency disclosure requires documented good-faith criteria and retrospective review.\n\n## Prohibitions\n\nNo volunteer or ordinary moderator responds independently, expands scope, supplies passwords, provides raw databases, or discusses the request in group chat.${runbookFooter}`,
  "docs/runbooks/MORT_DATA_BREACH_RUNBOOK.md": `# MORT Data Breach Runbook\n\n> **${draftBanner}**\n\n## Detect and contain\n\nOpen an incident, preserve logs, revoke exposed credentials and sessions, isolate affected services, stop unauthorized data flow, and protect evidence. Do not delete logs or announce an unverified cause.\n\n## Assess\n\nIdentify affected systems, data categories, people, time window, access path, persistence, and whether youth, location, identity, incident, payment, or biometric-related data could be involved. Engage qualified security, privacy, legal, child-safety, and insurance contacts.\n\n## Notify and recover\n\nDetermine legally required notices and timing with counsel. Give accurate, actionable information without speculation or victim blame. Rotate secrets, patch root causes, validate RLS and backups, monitor abuse, document decisions, and complete a post-incident review.${runbookFooter}`,
};
for (const [path, content] of Object.entries(runbooks)) write(path, content);

write("docs/operations/MORT_REVIEWER_TRAINING_CURRICULUM.md", `# MORT Reviewer Training Curriculum\n\n> **${draftBanner}**\n\nA reviewer must complete and pass all modules before real evidence access: privacy and confidentiality; data minimization; identity-review limitations; document-security features; image-manipulation indicators; school-ID limitations; government-ID limitations; live-presence limitations; web-image-match limitations; disability accommodation; bias and nondiscrimination; teen safety; sexual-safety escalation; evidence handling; conflict of interest; appeals; no criminal accusations; incident escalation; breach reporting; and access revocation.\n\nEach completion records module version, score or attestation, completion time, expiration, and approver where required. Training alone grants no role or case access.\n`);

console.log(`[legal-docs] Wrote ${Object.keys(legalFiles).length} legal drafts, ${Object.keys(operationDocs).length + 6} operational documents, and ${Object.keys(runbooks).length} runbooks.`);
