-- Seed the exact V3 legal text as draft versions so clean environments reproduce
-- the production records. This migration deliberately does not publish or approve
-- any document; attorney review and the production release gate remain mandatory.
begin;

insert into public.legal_documents
  (document_key, title, document_category, guardian_mode_independent, publication_status)
values
('master_terms_of_service','MORT Master Terms of Service','terms_of_service',true,'draft_attorney_review'),
('privacy_policy','MORT Privacy Policy','privacy_policy',true,'draft_attorney_review'),
('safety_rules','MORT Safety Rules','safety_rules',true,'draft_attorney_review'),
('community_guidelines','MORT Community Guidelines','community_guidelines',true,'draft_attorney_review')
on conflict (document_key) do nothing;

insert into public.legal_document_versions
  (document_id, version_label, content_hash, content_path, content_markdown,
   effective_at, published_at, retired_at, material_revision,
   requires_electronic_signature, publication_status, language_code,
   jurisdiction_policy, acceptance_ui_version, attorney_reviewed_at,
   approved_by_counsel_reference)
select
  document.id,
  source.version_label,
  encode(extensions.digest(convert_to(source.content_markdown, 'UTF8'), 'sha256'), 'hex'),
  source.content_path,
  source.content_markdown,
  null, null, null, true, false, 'draft_attorney_review', 'en-US',
  'requires_jurisdiction_specific_attorney_review', 'legal-clickwrap-v1', null, null
from (values
('master_terms_of_service','MORT-LEGAL-2026-V3','docs/legal/source-of-truth/MORT_Master_Terms_V3.md','# MORT Master Terms of Service
Marketplace, Safety & Guardian Framework

Document reference: MORT-LEGAL-2026-V3
Jurisdiction: United States / Indiana
Effective date: October 2026

## About these Terms

These Terms are a binding agreement between each User and MORT. They apply together with the MORT Privacy Policy, Community Guidelines, and Safety Rules, which are part of the agreement. Please read all four documents, and Guardians should review them with the Youth Worker before consenting.

## Contents
- 1. Scope and platform role
- 1.1. Definitions
- 1.2. Independent relationships
- 2. Eligibility, accounts, and Guardian consent
- 2.1. Who may use the Platform
- 2.2. Consent and account activation
- 2.3. Guardian oversight and responsibility
- 2.4. Account standards and verification
- 3. Safety, verification, and third-party conduct
- 3.1. Safety tools are not guarantees
- 3.2. Verification information
- 3.3. Emergencies, reporting, and authorities
- 3.4. Insurance
- 4. Prohibited Tasks and youth-safety boundaries
- 4.1. Prohibited and restricted Tasks
- 4.2. Conduct boundaries
- 4.3. Hours, permits, and legal compliance
- 4.4. Right to decline or stop
- 4.5. Enforcement
- 5. Payments, fees, and marketplace settlement
- 5.1. Payment processing
- 5.2. Payout Accounts
- 5.3. Fees, tips, and taxes
- 5.4. Booking, completion, and release of funds
- 5.5. Refunds on disputed Tasks
- 6. Privacy and Guardian controls
- 6.1. Data practices
- 6.2. Messaging and Guardian access
- 6.3. Deletion and retention
- 7. User Content and MORT Content
- 7.1. User Content
- 7.2. MORT Content and acceptable use
- 8. Disputes and governing law
- 8.1. Task and payment disputes
- 8.2. Informal resolution
- 8.3. Arbitration
- 8.4. Opt-out, exceptions, and Youth Worker claims
- 8.5. Governing law and venue
- 9. Disclaimers and limitation of liability
- 9.1. Disclaimers
- 9.2. Users, Tasks, and third parties
- 9.3. Limitation of liability
- 10. Indemnification and enforcement
- 10.1. Indemnification
- 10.2. Enforcement
- 11. Term, termination, and changes
- 11.1. Term and termination
- 11.2. Changes to these Terms
- 12. General terms and acceptance
- 12.1. General provisions
- 12.2. App stores
- 12.3. Electronic records and notices
- 12.4. Acceptance

## Plain-language summary
This summary is a convenience for Users and Guardians. It is not part of the binding Terms; if it differs from them, the Terms control.
- Marketplace, not employer. Posters and Youth Workers (ages 13–17) arrange Tasks with each other. MORT provides the tools (Section 1).
- Guardians are involved. A Guardian must consent before a Youth Worker account is activated and remains responsible for oversight (Section 2).
- Adult Posters only. Posters must be adults who complete MORT’s verification and screening steps (Section 2).
- Safe, lawful Tasks. Some Tasks are never allowed, Task communication stays on the Platform, and Tasks at a private residence need Guardian approval (Section 4).
- Safety tools are not guarantees. In an emergency, call 911 (Section 3).
- Payments run through Stripe. A Youth Worker’s payouts go to an account owned by an adult, normally their Guardian (Section 5).
- If something goes wrong, report it in the app. Claims against MORT start with written notice. Most adult account disputes are resolved in individual arbitration unless you opt out; claims by or for Youth Workers and bodily-injury claims are not subject to arbitration (Section 8).

## 1. Scope and platform role
MORT (the “Platform”) provides software and communications infrastructure that allows independent people and local businesses to discover, schedule, communicate about, and confirm completion of casual Tasks. MORT operates as a marketplace venue—not as an employer, staffing agency, employment agency, labor broker, or provider of Task performance.

Important distinction. MORT may provide rules, account controls, payment coordination, identity or age checks, safety prompts, and dispute procedures. Those administrative functions do not, by themselves, transfer control of the Task from the Poster or Youth Worker to MORT.

### 1.1. Definitions
In these Terms:
- “Poster” means an individual or business that lists, requests, books, or pays for a Task. A Poster must be an adult (see Section 2).
- “Youth Worker” means a participating person ages 13–17 (which the app may label a “Teen worker”), subject to applicable age, work-permit, school-hour, and safety requirements.
- “Guardian” means a parent or legal guardian who has authority to consent to a minor’s participation.
- “Task” means a casual service or errand listed through the Platform.
- “User” means a Poster, Youth Worker, Guardian, or other authorized Platform user.
- “MORT Content” means the Platform, software, interfaces, safety tools, and related materials, excluding User Content.
- “User Content” means content that Users submit through the Platform, including profiles, Task listings, messages, photos, ratings, and reviews.
- “Payment Provider” means Stripe, Inc. and its affiliates, or another payment provider that MORT authorizes.
- “Payout Account” means the account with the Payment Provider to which payment for a Task is paid out.
- “MORT Support Center” means the help and support channel that MORT makes available in the Platform and on its website.
- “Terms” means these Master Terms of Service and the documents they incorporate (see Section 12).

### 1.2. Independent relationships
MORT does not hire, employ, assign, direct, supervise, or guarantee work for Youth Workers. Posters and Youth Workers are responsible for deciding whether to participate, defining the Task, selecting the tools and methods, setting timing and location, making safety judgments, and confirming completion. Nothing in the Platform or these Terms creates an employment relationship, agency, partnership, joint venture, or fiduciary relationship between MORT and any User. Each Task arrangement is between the Poster and the Youth Worker, with the consent of the Youth Worker’s Guardian. MORT is not a party to that arrangement and, except as these Terms expressly state, is not responsible for how a Task is performed. These descriptions reflect MORT’s operating model. The legal characterization of a relationship may depend on applicable law and the facts of a particular engagement, and no label in these Terms overrides a non-waivable legal requirement.

## 2. Eligibility, accounts, and Guardian consent
### 2.1. Who may use the Platform
Posters must be at least 18 years old. A business Poster must act through an adult who is authorized to bind it. Before listing, booking, or paying for a Task, a Poster must complete the identity and age verification steps MORT requires. Youth Workers must be at least 13 and under 18, and may use the Platform only with Guardian consent under Section 2.2. No one under 13 may create an account or use the Platform. If MORT learns that an account belongs to a person under 13, MORT may suspend or close it and will handle the associated information as the Privacy Policy describes and the law requires. Guardians must be adults with legal authority to consent for the Youth Worker.

### 2.2. Consent and account activation
A Youth Worker account may be activated only after MORT receives consent from a Guardian through a reasonably verifiable process. The Guardian confirms that they have authority to provide consent, authorizes the minor’s participa­ tion, agrees to these Terms on the minor’s behalf to the extent permitted by law, and will maintain appropriate oversight of the account. The Guardian must provide accurate information, keep contact details current, and promptly notify MORT if consent is withdrawn or the Guardian no longer has authority. MORT may suspend or close an account when consent cannot be verified or appears to have been withdrawn. Withdrawing consent does not undo a Task already completed or a payment already authorized, which remain subject to Section 5.

### 2.3. Guardian oversight and responsibility
Guardians are responsible for reviewing the Platform’s features and safety controls, discussing appropriate Tasks with the Youth Worker, and monitoring the account as reasonably appropriate. To the maximum extent permitted by applicable law, a consenting Guardian is responsible for: (a) the Guardian’s own obligations under these Terms; (b) the ownership and use of any Payout Account the Guardian holds for the Youth Worker (see Section 5.2); and (c) any indemnification obligations the Guardian lawfully accepts under Section 10.1. Nothing in these Terms waives a minor’s rights, imposes liability that applicable law prohibits, or prevents a Guardian or User from reporting safety concerns or unlawful conduct to an appropriate authority.

### 2.4. Account standards and verification
Users must provide accurate information, keep their credentials secure, and not share accounts or create accounts using false information. MORT may require a User to re-verify identity, age, or consent, and may decline, suspend, or close an account that fails verification or appears ineligible. A Poster represents that they are not legally prohibited from working with or being around minors and are not required to register as a sex offender in any jurisdiction. As a condition of using the Platform, each Poster consents to MORT’s identity verification and, where permitted by law, screening that may include sex-offender-registry and criminal-background

checks. MORT will provide any notice and obtain any authorization that the law requires before it obtains a consumer report, including under the Fair Credit Reporting Act. MORT may decline, suspend, or close the account of a Poster who declines or fails screening, or whose results MORT reasonably considers unsuitable for work involving minors. Screening depends on the data sources available, and Section 3.2 applies to its results.

## 3. Safety, verification, and third-party conduct
### 3.1. Safety tools are not guarantees
MORT may offer identity checks, age or consent verification, PIN-based check-ins, location features, messaging controls, reporting tools, and other risk-reduction features. These features are administrative tools, not a promise of physical safety, job-site compliance, lawful conduct, or non-negligence by any User or third party.

### 3.2. Verification information
Verification and background information, where offered, may depend on third-party databases and User-provided infor­ mation. MORT does not warrant that any credential, identity assertion, background result, location signal, or profile is accurate, complete, current, or suitable for a particular Task. Users remain responsible for exercising independent judgment before meeting, accepting a Task, entering a location, or allowing a minor to participate.

### 3.3. Emergencies, reporting, and authorities
Users must use emergency services (911 in the United States) or other appropriate public resources for immediate danger. Platform reporting is not a substitute for emergency assistance. Users should report safety concerns, policy violations, and suspected unlawful conduct through the Platform’s reporting tools. MORT may review reports, preserve evidence, and share information with law enforcement or other authorities where required or permitted by law, including reports of suspected child exploitation to the National Center for Missing & Exploited Children where applicable.

### 3.4. Insurance
MORT does not provide insurance coverage to Users for Tasks, injury, property damage, or loss, and does not require Users to carry insurance. Users should review their own insurance, including any homeowner’s, renter’s, business, liability, or health coverage that may apply. Posters should confirm that their coverage applies to Tasks performed at their property or business, and Guardians should confirm the Youth Worker’s health coverage.

## 4. Prohibited Tasks and youth-safety boundaries
### 4.1. Prohibited and restricted Tasks
Posters may not list, and Youth Workers may not accept or perform, a Task that is unlawful, unsafe, age-inappropriate, or inconsistent with applicable child-labor, occupational-safety, school-hour, licensing, or local requirements.

Category Illustrative permitted Tasks Prohibited or restricted examples

Yard & outdoor Manual raking, watering, weeding, or Ride-on mowers, chainsaws, power cutters, push-mower work performed safely tree climbing, or work above six feet. and within applicable age limits.

Property & home Surface cleaning, organizing, light Roofing, scaffolding, structural demolition, packing, or paint preparation using hazardous chemicals, or entry into unsafe permitted materials. premises.

Animal care Domestic pet walking, feeding, or Aggressive or exotic animals, livestock basic yard cleanup. handling without appropriate supervision, or animal-care work requiring a license.

Category Illustrative permitted Tasks Prohibited or restricted examples

Business & events Flyer distribution, event setup, Heavy machinery, commercial transport, inventory sorting, tutoring, or similar alcohol or tobacco service areas, or work light work. requiring prohibited equipment.

Transport & delivery Local errands on foot, by bicycle, or by Motor-vehicle driving or delivery as part of public transit where lawful and safe. the Task, or any activity requiring a license the Youth Worker does not hold.

Other restrictions Light, daytime Tasks in public or Weapons; adult-oriented venues or content; clearly supervised settings, within alcohol, tobacco, vaping, or cannabis legally permitted hours. products; personal or medical care; handling large amounts of cash; or overnight or late- night work.

The examples above are not exhaustive. Applicable law, local rules, the Task’s actual conditions, and the Youth Worker’s age may impose additional restrictions.

### 4.2. Conduct boundaries
To protect Youth Workers, all Users must follow these rules in addition to the Task limits above and applicable law. (a) Keep Task communication on the Platform. Use Platform messaging for Task communication. Do not ask for or share personal contact details, social-media accounts, or private messaging handles, or move a conversation off the Platform. (b) No inappropriate conduct. Do not engage in sexual, romantic, or otherwise inappropriate conduct, conversation, or content directed at or involving a Youth Worker, and do not provide or use alcohol, tobacco, vaping or cannabis products, drugs, or weapons around a Youth Worker. (c) No secrecy, gifts, or pressure. Do not ask a Youth Worker to keep anything from a Guardian, offer gifts or money outside the Platform’s payment features, or pressure a Youth Worker to stay, return, or do more than the Task requires. (d) Private and enclosed spaces. Do not require a Youth Worker to be alone with you in a vehicle or a secluded place. A Task at a private residence may begin only after a Guardian approves that specific Task through the Platform. For work inside a residence, a second adult other than the Poster must be present and available throughout the Task. (e) Respect. Do not harass, bully, discriminate against, threaten, or retaliate against any User. Anyone who sees or experiences conduct that breaks these rules should use the Platform’s reporting tools, and Youth Workers are encouraged to tell a Guardian.

### 4.3. Hours, permits, and legal compliance
Posters, Youth Workers, and Guardians are each responsible for complying with the child-labor, work-permit or regis­ tration, hours-of-work, hazardous-occupation, and school-attendance rules that apply to a Task. MORT may ask for supporting documentation, may limit or block scheduling outside permitted hours, and may decline to display or activate a Task that appears inconsistent with those rules. MORT’s tools do not determine whether a particular Task, schedule, or arrangement is lawful.

### 4.4. Right to decline or stop
A Youth Worker may decline or stop any Task that feels unsafe or inappropriate, and a Poster may not penalize or retaliate against a Youth Worker for doing so. Payment for a Task that is stopped early is handled under Section 5.4 and Section 8.1.

### 4.5. Enforcement
MORT may remove a listing, suspend an account, permanently ban a User, withhold or reverse a payment where permitted by the Payment Provider, and refer suspected unlawful conduct to authorities. MORT may take these steps without prior notice when it believes they are necessary for safety or legal compliance. See also Section 10.2.

## 5. Payments, fees, and marketplace settlement
### 5.1. Payment processing
Payment processing is provided by Stripe, Inc. and its affiliates through Stripe Connect, subject to the applicable Connected Account Agreement and Stripe terms. MORT is not a bank, escrow agent, fiduciary, money transmitter, or insurer solely because it facilitates marketplace payment instructions. When a Poster books or confirms a Task, the Payment Provider may authorize, collect, hold, reverse, or settle funds under its rules and applicable law. Timing, fees, reserves, chargebacks, tax forms, and payout availability may be controlled by the Payment Provider or law. MORT is not responsible for a bank delay, provider outage, account restriction, chargeback, failed transfer, tax obligation, or other event outside MORT’s reasonable control.

### 5.2. Payout Accounts
A Payout Account is held with the Payment Provider and is subject to its terms. Under the Payment Provider’s require­ ments, a Youth Worker’s Payout Account must be owned and controlled by the Youth Worker’s Guardian, or by another adult the Payment Provider accepts. By completing payout setup, that adult agrees to the Payment Provider’s terms for the account, is responsible for its use, and is responsible for tax reporting related to it. Payouts are available only after the Payment Provider verifies the account.

### 5.3. Fees, tips, and taxes
MORT may charge service fees to Posters, Youth Workers, or both. The fee, and who pays it, is shown before a Task is booked or accepted, and any fee charged to a Poster is included in the total the Poster authorizes. Fees are not refundable except as these Terms state or the law requires. MORT may change its fees going forward with notice. Tips, if the Platform supports them, are voluntary, must be made through the Platform’s payment features, and are processed through the Payment Provider. Cash tips and other payments outside the Platform are not permitted. Users must provide accurate payout and tax information and are responsible for their own tax reporting and legal obligations. MORT does not provide tax advice. Tax forms for a Youth Worker’s earnings may be issued to the owner of the Payout Account.

### 5.4. Booking, completion, and release of funds
When a Poster books or confirms a Task, the Poster authorizes the Payment Provider to collect the agreed price and any fees. After the Youth Worker marks a Task complete, the Poster should confirm completion or report a problem through the Platform. If the Poster does neither within 48 hours, MORT may treat the Task as confirmed. Subject to Payment Provider rules and any dispute under Section 8.1, funds may be released to the Payout Account after completion is confirmed or a dispute is resolved. Unless the booking screen states otherwise, a Poster may cancel a booked Task without charge until 24 hours before its scheduled start. A later cancellation by the Poster may result in a late-cancellation charge in the amount shown before the Poster confirms the booking. A Youth Worker may cancel at any time, although repeated late cancellations may affect account standing. If a Task is not performed, or is materially different from what was agreed, a Poster may ask for a refund through the dispute process, and MORT may approve, adjust, or decline the request. Refunds are processed through the Payment Provider, and processing fees may not be recoverable.

### 5.5. Refunds on disputed Tasks
If the Payment Provider confirms a full or partial refund on a Task that is under dispute, the Task remains in dispute review. The refund does not, by itself, resolve the dispute, create a debt or new payment obligation between Users, or entitle any User to a payment that is not otherwise due under these Terms. MORT may take the refund into account when it decides the dispute.

## 6. Privacy and Guardian controls
### 6.1. Data practices
MORT seeks to collect and use information reasonably necessary to operate the Platform, support communications, process payments, prevent abuse, and provide safety features. Data practices are governed by MORT’s Privacy Policy, which should be reviewed alongside these Terms. MORT does not sell the personal information of Youth Workers, does not share it for cross-context behavioral advertising, and does not use it to show targeted advertising to Youth Workers.

### 6.2. Messaging and Guardian access
Messaging may be subject to automated safety filtering, abuse detection, moderation, retention, and disclosure when required by law. Guardians may receive account, Task-status, check-in, or payout information through the controls MORT makes available; message content may be limited except where disclosure is necessary for safety, platform integrity, or valid legal process.

### 6.3. Deletion and retention
Subject to applicable law and operational requirements, Users may request deletion of their own accounts, and Guardians may request suspension or deletion of a Youth Worker’s account. Deletion may not remove information MORT must retain for legal, fraud-prevention, payment, accounting, or dispute-resolution purposes.

## 7. User Content and MORT Content
### 7.1. User Content
Users are responsible for the User Content they submit and must have the rights needed to submit it. User Content must be lawful, accurate, and consistent with Section 4. MORT may moderate, remove, or decline to display User Content, including ratings and reviews, that breaks these Terms or that MORT reasonably believes is unsafe. A User grants MORT a non-exclusive, worldwide, royalty-free license to host, store, display, reproduce, and process User Content as needed to operate, secure, and provide the Platform and its features, as the Privacy Policy further describes. For a Youth Worker, the Guardian grants this license on the Youth Worker’s behalf to the extent permitted by law. MORT will not use a Youth Worker’s name, image, or likeness in public marketing without separate Guardian consent.

### 7.2. MORT Content and acceptable use
MORT and its licensors own MORT Content. Subject to these Terms, MORT grants each User a limited, revocable, non- exclusive, non-transferable license to use the Platform for its intended purpose. Users may not copy, scrape, reverse engineer, or interfere with the Platform, bypass age, consent, or safety controls, or use automated means to access the Platform without MORT’s written permission.

## 8. Disputes and governing law
### 8.1. Task and payment disputes
If a Poster and a Youth Worker disagree about a Task or its payment, they should first try to resolve it through Platform messaging. Either may then report the dispute through the Platform within 14 days after the Task’s scheduled completion. MORT may review information from both sides and, consistent with Payment Provider rules, may release, hold, split, or refund funds and take account actions under Section 4.5. A Youth Worker’s Guardian may take part in the process, and MORT may notify the Guardian of the outcome. MORT’s dispute decisions are administrative decisions made for marketplace purposes. They are not a court or arbitral judgment, do not decide claims for injury, property damage, or other legal liability, and do not prevent a User from pursuing any remedy the law allows against another User. Section 5.5 explains how a Payment Provider refund interacts with an open dispute.

### 8.2. Informal resolution
Before filing a formal claim against MORT, a User must send MORT a written notice describing the issue and the requested resolution, as provided in Section 12.3. The parties will attempt informal resolution for 30 days after MORT receives a complete notice.

### 8.3. Arbitration
Except as Section 8.4 provides, disputes between a User and MORT that are not resolved informally will be resolved by individual binding arbitration, rather than in court. The arbitration will be administered by the American Arbitration Association (AAA) under its Consumer Arbitration Rules in effect when the claim is filed. The Federal Arbitration Act governs this section. MORT will pay the AAA filing, administrative, and arbitrator fees that exceed the fee the User would pay to file a claim in court, unless the arbitrator finds that the claim was brought for an improper purpose. The hearing may be conducted by video, by telephone, or on written submissions, or in person in Marion County, Indiana or another location the parties agree on. The arbitrator decides questions about the scope and enforceability of this section, except as Section 8.4 provides. Claims subject to arbitration may be brought only in an individual capacity and not as a plaintiff or class member in a class, collective, consolidated, or representative proceeding. If this class-action waiver is held unenforceable for a claim, that claim will proceed in court rather than in arbitration. To the maximum extent permitted by law, the parties waive a jury trial for claims that are subject to arbitration.

### 8.4. Opt-out, exceptions, and Youth Worker claims
A User, or a Guardian on behalf of a Youth Worker, may opt out of arbitration by sending written notice to MORT within
## 30 days after first accepting these Terms. The notice must be submitted as Section 12.3 describes and must include the
User’s name and the email address on the account. Arbitration, the class-action waiver, and the jury-trial waiver in Section 8.3 do not apply to: (a) any claim by or on behalf of a Youth Worker, including a claim brought by a Guardian for the Youth Worker; (b) any claim for bodily injury or death; (c) any sexual-assault or sexual-harassment dispute that federal law allows the claimant to bring in court, if the claimant chooses to do so; (d) an eligible claim in small-claims court; (e) a request for emergency or public injunctive relief where legally available; or (f) any claim that federal or state law does not permit to be compelled to arbitration. These claims may be brought in court under Section 8.5. MORT will seek court approval of the settlement of a Youth Worker’s claim where the law requires it. Nothing in this section prevents a User from reporting suspected unlawful conduct to an authority or exercising a right that cannot lawfully be waived.

### 8.5. Governing law and venue
These Terms are governed by Indiana law, without regard to conflict-of-law rules, except to the extent federal law or another non-waivable law applies. Any court proceeding permitted outside arbitration must be brought in the state or federal courts located in Marion County, Indiana, unless applicable law requires another forum.

## 9. Disclaimers and limitation of liability
### 9.1. Disclaimers
To the maximum extent permitted by applicable law, the Platform and MORT Content are provided on an “as is” and “as available” basis. MORT disclaims implied warranties, including merchantability, fitness for a particular purpose, non- infringement, availability, and accuracy, except where a disclaimer is not legally permitted.

### 9.2. Users, Tasks, and third parties
To the maximum extent permitted by applicable law, MORT is not responsible for the acts, omissions, statements, or conduct of any User or third party, or for the quality, safety, legality, or timing of any Task, or for the accuracy of any listing, profile, or verification information. Users acknowledge that Tasks involve risks, including physical injury,

property damage, and interaction with people they do not know, and that each User is responsible for deciding whether to take part. This section does not limit MORT’s responsibility for its own conduct where the law imposes it, and Section 9.3 states the limits that apply to that responsibility.

### 9.3. Limitation of liability
To the maximum extent permitted by applicable law, MORT and its affiliates, officers, employees, agents, licensors, and service providers will not be liable for indirect, incidental, special, exemplary, punitive, or consequential damages, or for lost profits, data, goodwill, or opportunity. MORT’s total aggregate liability for claims arising out of or relating to the Platform will not exceed the greater of (a) USD 100 or (b) the fees the claiming User paid directly to MORT during the three months preceding the event giving rise to the claim. These limits apply to claims based on MORT’s own negligence, as well as to claims under other theories of liability, for economic loss and property damage. The limits in this section do not apply to liability for bodily injury or death, gross negligence, willful misconduct, or fraud, or to any other liability that cannot legally be excluded or limited.

## 10. Indemnification and enforcement
### 10.1. Indemnification
To the maximum extent permitted by applicable law, a User agrees to defend, indemnify, and hold harmless MORT and its covered affiliates and personnel from third-party claims, losses, liabilities, damages, costs, and reasonable attorneys’ fees arising from the User’s unlawful conduct, breach of these Terms, violation of another person’s rights, or misuse of the Platform. A Guardian’s indemnification obligation applies only to obligations the Guardian lawfully accepts and does not eliminate any non-waivable rights or duties. A Youth Worker has no indemnification obligation to the extent applicable law makes it unenforceable against a minor.

### 10.2. Enforcement
MORT may investigate suspected violations, remove User Content, restrict features, suspend or terminate accounts, preserve evidence, and cooperate with lawful requests. MORT may, but is not required to, monitor Users, Tasks, messages, or locations, and does not assume a duty to do so.

## 11. Term, termination, and changes
### 11.1. Term and termination
These Terms apply while a User has an account or uses the Platform. A User may close their account at any time, and a Guardian may close a Youth Worker’s account at any time. MORT may suspend or close an account for breach, for safety or legal reasons, or for inactivity, with notice where practicable. Closing an account does not cancel obligations that arose earlier, and Tasks or payments in progress are handled under Section 5. Provisions that by their nature should survive, including Sections 5, 7, 8, 9, 10, and 12, continue to apply.

### 11.2. Changes to these Terms
MORT may update these Terms and may change, suspend, or discontinue any feature of the Platform. MORT will give reasonable notice of material changes through the Platform or by email, and changes apply going forward from the effective date shown in the notice. If a change materially affects Youth Workers or Guardians, MORT may require renewed Guardian consent before the Youth Worker continues to use the Platform. Continued use after a change takes effect is acceptance of it, except where applicable law requires affirmative consent.

## 12. General terms and acceptance
### 12.1. General provisions
If any provision is held invalid or unenforceable, it will be modified to the minimum extent necessary or severed, and the remaining provisions will continue in effect. A failure to enforce a provision is not a waiver. A User may not assign these Terms without MORT’s consent; MORT may assign them in connection with a merger, acquisition, or sale of assets.

These Terms, together with the Privacy Policy, Community Guidelines, Safety Rules, payment terms, and any other incorporated policies, form the agreement governing use of the Platform, subject to any separately executed agreement. Certain features, such as subscriptions, rewards, referrals, or promotions, may be subject to additional terms that MORT presents before a User uses them. Those terms are part of these Terms and control for that feature.

### 12.2. App stores
If a User downloads the app through a third-party app store, that store’s terms also apply. The store is not a party to these Terms and has no obligation to provide support for the Platform. If a User obtains the app from the Apple App Store, the following also apply. These Terms are between the User and MORT only, and not Apple. MORT, not Apple, is responsible for the app, its content, its maintenance and support, and any claim relating to it. The license to use the app is limited to Apple-branded devices as the App Store usage rules permit. If the app fails to conform to an applicable warranty, the User may notify Apple, which may refund any purchase price, and Apple has no other warranty obligation. Apple and its subsidiaries are third-party beneficiaries of these Terms and may enforce them against the User.

### 12.3. Electronic records and notices
Users consent to receive notices and records electronically and to sign and consent electronically, including under the federal E-SIGN Act. MORT keeps an electronic record of each acceptance and Guardian consent, including its date, version, and method, and Users agree that these records may be used as evidence of acceptance. MORT may give notice through the Platform or by email, and may also send notices about a Youth Worker to the Guardian. Notices to MORT, including notices of a dispute under Section 8.2 and arbitration opt-out notices under Section 8.4, must be submitted through the MORT Support Center under Legal Notices, in the Platform or on MORT’s website. A notice is received when it is submitted, and the Support Center records the date and time.

### 12.4. Acceptance
By selecting “I Agree,” creating or using an account, booking or accepting a Task, or authorizing a Youth Worker account, the User and, where applicable, Guardian acknowledge that they have had an opportunity to review these Terms and consent to the provisions that are legally effective for them.

MORT-LEGAL-2026-V3 · Effective October 2026
'),
('privacy_policy','MORT-PRIVACY-2026-10','docs/legal/source-of-truth/MORT_Privacy_Policy.md','# MORT Privacy Policy
How MORT collects, uses, and protects information

Effective date: October 2026 · Applies to the MORT Platform

Privacy at a glance. MORT collects and uses information to operate the marketplace, support payments and communications, protect users, and comply with law. MORT does not sell the personal information of Youth Workers or use it for targeted advertising. This Policy does not limit any privacy right or protection that applicable law gives you.

## 1. Overview
MORT operates a marketplace platform connecting Posters, Youth Workers ages 13–17, Guardians, and other local users. This Privacy Policy explains what information MORT may collect, how it is used, when it is shared, and the choices available to users and Guardians. This Policy should be read together with MORT’s Terms of Service, Community Guidelines, and Safety Rules. If a separate notice applies to a particular feature, that notice controls for that feature.

## 2. Information MORT collects
### 2.1. Information users provide
MORT may collect account details such as name, email address, phone number, date of birth or age range, profile photo, location preferences, and account credentials. Guardians may provide consent records, relationship information, and contact details. Posters may provide business information, Task descriptions, addresses, schedules, and payment instructions. Users may also provide messages, reports, ratings, reviews, support requests, identity documents, emergency contacts, payout details, tax information, and other content submitted through the Platform.

### 2.2. Information collected automatically
MORT may collect device and usage information such as IP address, browser or device type, operating system, approximate location, timestamps, pages or features used, crash logs, check-in events, and security signals. Location features may require separate permission and may be disabled by the user or Guardian.

### 2.3. Information from others
MORT may receive information from Guardians, Posters, Youth Workers, payment providers, identity or age- verification vendors, background-screening vendors where permitted, analytics providers, safety-reporting sources, and public or government sources.

### 2.4. Children under 13
The Platform is not for children under 13, and MORT does not knowingly collect personal information from them. If MORT learns that it has collected personal information from a child under 13, it will close the account and delete the information promptly, except where the law requires MORT to keep it. A parent or Guardian who believes a child under 13 has an account can report it through the MORT Support Center.

## 3. How MORT uses information
MORT may use information to create and administer accounts; verify age, consent, identity, or payment eligibility; match users to Tasks; facilitate communications and payouts; provide check-ins and safety features;

prevent fraud, abuse, and prohibited conduct; respond to reports; improve products; maintain records; comply with law; and protect the rights, safety, and security of users, MORT, and the public. MORT may use aggregated or de-identified information for analytics, product development, and business planning when it is not reasonably used to identify a person.

## 4. Youth and Guardian privacy
MORT designs Youth Worker accounts with data minimization and age-appropriate defaults. Guardians may receive available account, Task-status, check-in, suspension, and payout information through designated controls. Message content may be subject to automated safety filtering, moderation, or disclosure for safety, abuse prevention, legal process, or platform integrity. MORT does not sell the personal information of Youth Workers, does not share it for cross-context behavioral advertising, and does not use it to show targeted advertising to Youth Workers. A Guardian may request account suspension, access, correction, or deletion, subject to identity verification and legal or operational retention requirements. MORT maintains procedures for handling requests involving minors and does not disclose a minor’s information to an unauthorized person except as described in this Policy or as permitted by law.

## 5. Sharing and disclosure
MORT may share information with service providers that support hosting, communications, identity or age checks, payments, fraud prevention, analytics, customer support, safety operations, and legal compliance. Providers receive only information reasonably necessary for their services and are required to maintain appropriate confidentiality and security protections. MORT may share information with other users when necessary to operate a Task, such as a name, profile, Task details, approximate location, check-in status, or contact method enabled by the feature. MORT limits the personal information about Youth Workers that is visible to other users. MORT may disclose information to law enforcement, regulators, courts, emergency responders, or other parties when required by law, legal process, or a good-faith belief that disclosure is necessary to prevent serious harm, fraud, abuse, or unlawful activity. MORT may also disclose information in connection with a merger, acquisition, financing, restructuring, or sale of assets.

## 6. Payments and third-party services
Payments are processed through Stripe Connect or another authorized provider. Payment providers may collect and process financial, identity, tax, and transaction information under their own notices and terms. MORT does not control third-party privacy practices and users should review those notices directly. MORT may use cookies, local storage, analytics tools, and similar technologies. Users may be able to limit some technologies through device or browser settings, although certain Platform functions may not work correctly without them.

## 7. Security and retention
MORT uses administrative, technical, and organizational safeguards appropriate to the nature of the information, such as access controls, encryption in transit where supported, logging, least-privilege access, vendor review, and incident-response procedures. No system is completely secure. MORT retains information for as long as reasonably necessary for the purposes described in this Policy, including account operation, safety, fraud prevention, payments, tax and accounting, dispute resolution, legal compliance, and enforcement. MORT applies retention periods based on data category, operational need, safety requirements, payment and tax obligations, dispute resolution, and applicable law.

## 8. Your choices and rights
Depending on location and applicable law, users may request access, correction, deletion, portability, restriction, or information about processing. Users may withdraw certain consents, disable optional location features, manage communications, or close an account. Some information cannot be deleted immediately when retention is required by law, payment rules, safety needs, or a pending dispute. Requests may be submitted through the MORT Support Center. MORT may verify identity and authority before completing a request, will respond within the time that applicable law requires, and will not retaliate against anyone for making a request. Users may have the right to appeal a denial or contact a privacy regulator.

## 9. Changes and contact
MORT may update this Policy as the Platform, law, or data practices change. MORT will post the updated version and revise the effective date. Material changes will be communicated through an appropriate notice and, where required, renewed consent. Privacy requests may be submitted through the MORT Support Center in the Platform under Privacy & Data Requests. MORT may verify identity and authority before completing a request.
'),
('safety_rules','MORT-SAFETY-2026-10','docs/legal/source-of-truth/MORT_Safety_Rules.md','# MORT Safety Rules
Practical safeguards for local Tasks involving Youth Workers

Effective date: October 2026

Safety first. These Rules are a safety framework, not a guarantee of safety and not a substitute for emergency services, professional supervision, or applicable law.

## 1. Safety comes first
MORT provides software tools and marketplace rules to reduce risk. MORT does not control every Task, person, location, vehicle, animal, tool, or event. Posters, Youth Workers, and Guardians must make independent safety decisions and stop when conditions are unsafe. For immediate danger, call emergency services (911 in the United States) or contact the appropriate public authority. Do not wait for an in-app response.

## 2. Before a Task
Posters must provide a complete and truthful description, including location type, expected work, tools, materials, animals, stairs, weather exposure, supervision, approximate duration, and any known hazards. Posters must not hide a condition that could affect a Youth Worker’s decision to accept the Task. Youth Workers should review the description with a Guardian, confirm the location and timing, understand the work, and accept only a Task that is lawful, age-appropriate, and within their ability. Guardians should confirm consent, discuss transportation and check-in expectations, and use available account controls. A Task at a private residence may begin only after a Guardian approves that specific Task through the Platform. For work inside a residence, a second adult other than the Poster must be present and available throughout the Task. Do not require a Youth Worker to be alone with you in a vehicle or a secluded place. Users should keep communication and check-ins within MORT’s available tools. Avoid sharing unnecessary personal information. Do not arrange secret meetings or ask a Youth Worker to bypass a Guardian, identity check, PIN, or safety control.

## 3. At the Task location
Meet only at the agreed location and follow the agreed scope. A Youth Worker may stop, leave, or request help at any time. Posters must not change the Task into a more hazardous or materially different activity without a new, informed agreement and any required Platform approval. Do not operate machinery, vehicles, power tools, chemicals, ladders, roofs, or other equipment unless the activity is expressly permitted, lawful, age-appropriate, and safely supervised where required. Do not enter an isolated, locked, restricted, or visibly unsafe area. Do not handle weapons, illegal drugs, dangerous substances, aggressive animals, or exposed electrical systems. Do not transport a Youth Worker in a private vehicle unless the arrangement is lawful, disclosed, consented to, and supported by MORT’s applicable controls. Youth Workers may not drive or perform motor-vehicle delivery as part of a Task unless expressly permitted by law and Platform policy.

## 4. Prohibited Task categories
```text
 Area                         Examples generally suitable only            Do not post or perform
                              when safe and permitted
 Yard & outdoor               Raking, watering, weeding, push-mower       Ride-on mowers, chainsaws, power
                              work within applicable age limits, or       cutters, tree climbing, roofs, or work
                              other light manual work.                    above six feet.
 Property & home              Organizing, surface cleaning, light         Roofing, scaffolding, demolition,
                              packing, or paint preparation with          hazardous chemicals, exposed wiring, or
                              permitted materials.                        unsafe premises.
 Animal care                  Domestic pet walking, feeding, or basic     Aggressive or exotic animals, livestock
                              yard cleanup.                               without appropriate supervision, or
                                                                          licensed veterinary tasks.
 Business & events            Flyers, tutoring, inventory sorting, or     Heavy machinery, commercial transport,
                              light event setup.                          alcohol or tobacco service areas, or
                                                                          crowd-control duties.
 Transport                    Local errands on foot, bicycle, or public   Motor-vehicle driving, delivery, or any task
                              transit where lawful and safe.              requiring an unheld license.
```

This list is illustrative, not exhaustive. State, federal, and local requirements may impose stricter limits based on age, hours, equipment, supervision, and industry.

## 5. Check-ins and incident response
When a check-in or PIN feature is available, use it as instructed. A check-in confirms an event in the Platform; it does not prove that a location is safe or that a person is acting lawfully. Do not share a PIN with an unauthorized person. If a Youth Worker feels unsafe: stop the Task, move to a safer public location if possible, contact a Guardian or trusted adult, use emergency services for immediate danger, and report the incident to MORT when safe. If an injury occurs, seek medical care and preserve relevant information. Posters must report accidents, threats, suspected exploitation, missing check-ins, or material safety changes promptly. MORT may suspend a Task or account while reviewing a report.

## 6. Privacy and dignity
Do not photograph, record, or publish a Youth Worker without a legitimate reason, appropriate notice, and any consent required by law. Never publish a home address, phone number, school, real-time location, identity document, or private message. Safety evidence should be shared only with MORT, a Guardian, emergency responders, or another appropriate authority.

## 7. MORT’s role and limits
MORT may provide verification, messaging controls, reports, location features, check-ins, moderation, and educational prompts. These are risk-reduction measures only. MORT does not guarantee identity accuracy, task- site safety, lawful conduct, non-negligence, response time, or a particular outcome. Users remain responsible for their own decisions and conduct. Nothing in these Rules limits rights or duties that applicable law does not allow MORT to limit.

## 8. Contact and review
Safety reports may be submitted through the in-app Report function or the MORT Support Center. For immediate danger, call emergency services or contact the appropriate public authority; do not wait for an in-app response. MORT may update these Rules as Task categories, Platform features, or applicable requirements change.
'),
('community_guidelines','MORT-COMMUNITY-2026-10','docs/legal/source-of-truth/MORT_Community_Guidelines.md','# MORT Community Guidelines
A respectful, reliable, and youth-safe marketplace

Effective date: October 2026

Community standard. These Guidelines describe expected conduct and enforcement principles. They supplement the Terms of Service and do not limit any right or protection that applicable law gives you.

## 1. Our community standard
MORT is built for practical local Tasks and respectful interactions among Posters, Youth Workers, Guardians, and community members. Use the Platform honestly, communicate clearly, respect boundaries, and prioritize safety over speed or convenience. Youth Workers are minors. Adults must act accordingly: communicate professionally, avoid unnecessary personal contact, respect Guardian oversight, and never pressure a Youth Worker to ignore safety rules or Platform controls.

## 2. Expected behavior
Users should provide accurate identity, age, consent, Task, location, payment, and availability information. Users should communicate promptly, arrive when agreed, describe changes honestly, confirm completion accurately, protect other people’s privacy, and treat everyone with patience and respect. Posters should provide a safe, lawful, age-appropriate Task description and disclose relevant conditions, equipment, animals, stairs, hazards, supervision expectations, and timing. Youth Workers should accept only Tasks they understand, can perform safely, and are permitted to perform. Guardians should discuss participation and use available oversight controls.

## 3. Prohibited conduct
The following conduct is prohibited:
- harassment, bullying, threats, stalking, intimidation, sexual content, grooming, or unwanted romantic or personal contact;
- discrimination or hateful conduct based on a protected characteristic or other personal attribute;
- requesting or sharing passwords, financial credentials, precise home details, private documents, or unnecessary personal information;
- off-platform pressure, retaliation for reporting, evasion of Guardian controls, or attempts to bypass age or identity checks;
- fraud, impersonation, fake reviews, payment manipulation, chargeback abuse, wage or payout diversion, or deceptive Task descriptions;
- posting or accepting unlawful, hazardous, age-inappropriate, or licensed work that the Youth Worker is not qualified or permitted to perform;
- bringing weapons, illegal drugs, or dangerous materials to a Task, or appearing impaired while using the Platform;
- scraping, probing, reverse engineering, malware, spam, automated abuse, or interference with MORT’s systems; and
- any other conduct that creates a credible safety, privacy, legal, or operational risk.

## 4. Youth-safe communication
Adults should use Platform messaging and avoid moving communication to personal channels unless necessary for a legitimate Task and permitted by MORT’s controls. Do not request secrecy from a Youth Worker or discourage Guardian involvement. Do not invite a Youth Worker to an isolated location or an overnight activity. Do not require a Youth Worker to be alone with you in a private vehicle; transport is allowed only as the Safety Rules describe. A Task at a private residence is allowed only after a Guardian approves that specific Task through the Platform and, for work inside the residence, with a second adult other than the Poster present throughout. Users must not ask a Youth Worker to conceal a Task, falsify an age, skip a check-in, use prohibited equipment, or continue after reporting discomfort or danger.

## 5. Reporting and urgent safety
Use the in-app report function or contact MORT support for suspected violations. Include the relevant account, Task, date, message, location, and a concise description when safe to do so. Preserve screenshots or other evidence without publicly sharing sensitive information. For immediate danger, call emergency services (911 in the United States) or contact an appropriate public authority first. MORT reporting is not an emergency-response service.

## 6. Reviews and content
Reviews should be accurate, relevant, and based on genuine interactions. Do not use reviews to threaten, extort, reveal private information, retaliate, or coordinate harassment. MORT may remove content that is unlawful, abusive, misleading, privacy-invasive, irrelevant, or designed to manipulate rankings. Users retain responsibility for content they submit and must have the rights needed to submit it. MORT may use, display, moderate, preserve, or remove content as necessary to operate the Platform, enforce policies, address safety, or comply with law.

## 7. Enforcement
Depending on severity and risk, MORT may warn a User, remove content, limit messaging or discovery, require additional verification, pause a Task, suspend an account, permanently ban a User, reverse or withhold a payment where permitted, preserve evidence, or refer conduct to authorities. MORT may act based on reports, automated signals, investigations, or information from third parties. MORT may take precautionary action before an investigation is complete. Enforcement is not a finding that every allegation is true, and MORT may correct an action when new information is provided. Users may contact support to provide context or appeal an enforcement action, unless doing so would create a safety, legal, or evidence-preservation risk. MORT will not retaliate against a good-faith safety report.

## 8. Updates and contact
These Guidelines may change as MORT learns from users, improves safety systems, or responds to legal requirements. MORT will post the current version and may provide additional notice for material changes. Community and safety reports may be submitted through the in-app Report function or the MORT Support Center. Include the relevant account, Task, date, message, location, and a concise description when safe to do so.

Remember. Be honest. Keep Tasks age-appropriate. Respect Guardian involvement. Use in-app tools. Report concerns early. When safety and convenience conflict, choose safety.
')
) as source(document_key, version_label, content_path, content_markdown)
join public.legal_documents document on document.document_key = source.document_key
on conflict (document_id, version_label) do nothing;

do $seed_legal_roles$
declare
  role_type_name text;
begin
  select format('%I.%I', namespace.nspname, role_type.typname)
    into role_type_name
  from pg_attribute attribute
  join pg_type role_type on role_type.oid = attribute.atttypid
  join pg_namespace namespace on namespace.oid = role_type.typnamespace
  where attribute.attrelid = 'public.legal_role_requirements'::regclass
    and attribute.attname = 'role'
    and not attribute.attisdropped;

  if role_type_name is null then
    raise exception 'Could not resolve legal_role_requirements.role type';
  end if;

  execute format($insert_roles$
    insert into public.legal_role_requirements
      (document_id, role, age_band, required, priority)
    select document.id, roles.role::%s, 'all', true,
      case document.document_key
        when 'master_terms_of_service' then 10
        when 'privacy_policy' then 20
        when 'safety_rules' then 30
        when 'community_guidelines' then 40
        else 50
      end
    from public.legal_documents document
    cross join (values ('teen'), ('adult'), ('guardian'), ('admin')) as roles(role)
    where document.document_key in (
      'master_terms_of_service',
      'privacy_policy',
      'safety_rules',
      'community_guidelines'
    )
    on conflict (document_id, role, age_band) do nothing
  $insert_roles$, role_type_name);
end
$seed_legal_roles$;

commit;
