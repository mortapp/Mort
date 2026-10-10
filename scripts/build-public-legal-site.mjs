import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const output = resolve(root, 'web', 'public');
const legalTheme = resolve(root, 'web', 'legal-theme');
const supabaseBrowserBundle = resolve(root, 'node_modules', '@supabase', 'supabase-js', 'dist', 'umd', 'supabase.js');
const REVISION = '2026-10-10-nationwide-us-legal-v2';

const requiredConfigNames = [
  'MORT_PUBLIC_PUBLISHER_NAME',
  'MORT_PUBLIC_SUPPORT_EMAIL',
  'MORT_PUBLIC_PRIVACY_EMAIL',
  'MORT_PUBLIC_CHILD_SAFETY_EMAIL',
  'MORT_PUBLIC_WEBSITE_URL',
  'MORT_PUBLIC_EFFECTIVE_DATE',
];
const publicConfig = Object.fromEntries(requiredConfigNames.map((name) => [name, process.env[name]?.trim() ?? '']));
const missingMetadataConfig = requiredConfigNames.filter((name) => !publicConfig[name]);
const supabase = readSupabasePublicConfig();
const missingConfig = [...missingMetadataConfig, ...(!supabase.key ? ['EXPO_PUBLIC_SUPABASE_ANON_KEY'] : [])];
const deploymentReady = missingConfig.length === 0;

if (!existsSync(supabaseBrowserBundle)) throw new Error('The pinned local Supabase browser bundle is missing. Run pnpm install first.');
for (const asset of ['legal.css', 'atmosphere.js', 'mort-mark.svg']) {
  if (!existsSync(resolve(legalTheme, asset))) throw new Error(`The legal redesign asset is missing: ${asset}`);
}
mkdirSync(output, { recursive: true });
for (const entry of readdirSync(output)) {
  const target = resolve(output, entry);
  if (dirname(target) !== output) throw new Error('Invalid output path');
  rmSync(target, { recursive: true, force: true });
}

function write(relative, content) {
  const path = resolve(output, relative);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${content.trim()}\n`);
}
function escapeHtml(value) {
  return String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
}
function display(name, pending) { return escapeHtml(publicConfig[name] || pending); }
function readSupabasePublicConfig() {
  const envPath = resolve(root, '.env.local');
  let url = process.env.EXPO_PUBLIC_SUPABASE_URL?.trim() ?? '';
  let key = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY?.trim() ?? '';
  try {
    for (const raw of readFileSync(envPath, 'utf8').split(/\r?\n/)) {
      const match = raw.match(/^\s*([^#=]+?)\s*=\s*(.*?)\s*$/);
      if (!match) continue;
      const name = match[1];
      const value = match[2].replace(/^['"]|['"]$/g, '');
      if (name === 'EXPO_PUBLIC_SUPABASE_URL' && !url) url = value;
      if (name === 'EXPO_PUBLIC_SUPABASE_ANON_KEY' && !key) key = value;
    }
  } catch { /* Vercel environment may provide the public values directly. */ }
  const expectedUrl = 'https://rakjydmgwwgtdislanbt.supabase.co';
  if (url && url !== expectedUrl) throw new Error('Public legal site points to the wrong Supabase project.');
  if (key) {
    const payload = JSON.parse(Buffer.from(key.split('.')[1], 'base64url').toString('utf8'));
    if (payload.role !== 'anon') throw new Error('Only the Supabase anon key may be published.');
  }
  return { url: url || expectedUrl, key };
}

const routes = [
  ['/', 'Legal and safety center'],
  ['/privacy/', 'Privacy'],
  ['/terms/', 'Terms'],
  ['/dispute-resolution/', 'Dispute resolution'],
  ['/us-state-law-addendum/', 'U.S. state law'],
  ['/guardian-terms/', 'Guardian terms'],
  ['/verification-privacy-notice/', 'Verification privacy'],
  ['/paid-services/', 'Paid services'],
  ['/terms-of-use/', 'Terms of use'],
  ['/community-guidelines/', 'Community guidelines'],
  ['/safety/', 'Safety'],
  ['/child-safety-standards/', 'Child safety'],
  ['/prohibited-jobs/', 'Prohibited jobs'],
  ['/payment-disputes/', 'Payment disputes'],
  ['/account-deletion/', 'Delete account'],
  ['/support/', 'Support'],
  ['/contact/', 'Contact'],
  ['/accessibility/', 'Accessibility'],
];
const routeSummaries = {
  '/privacy/': 'How MORT handles account, teen, verification, safety, location, payment, and technical information.',
  '/terms/': 'Nationwide U.S. Terms of Service for Teen, Adult, Business, Guardian, marketplace, safety, and paid-service use.',
  '/dispute-resolution/': 'Informal resolution, individual arbitration, class-action and jury-trial waivers, exceptions, and opt-out rights.',
  '/us-state-law-addendum/': 'State-specific rights, mandatory-law savings rules, privacy, youth-work, biometric, and subscription supplements.',
  '/guardian-terms/': 'Parent and legal guardian authorization, responsibilities, and limits for Teen User participation.',
  '/verification-privacy-notice/': 'Additional notice for school, identity, age-assurance, liveness, facial, and biometric verification.',
  '/paid-services/': 'Subscriptions, in-app purchases, recurring billing, renewals, cancellation, refunds, and payment platforms.',
  '/terms-of-use/': 'Plain-language rules for lawful account, job, message, and safety-tool use.',
  '/community-guidelines/': 'Behavior and content standards for MORT participants and organizations.',
  '/safety/': 'Reporting, blocking, job-context, check-in, location, and real-world safety guidance.',
  '/child-safety-standards/': 'Standards against child sexual abuse, exploitation, grooming, trafficking, and solicitation.',
  '/prohibited-jobs/': 'Work categories and conditions that MORT does not allow.',
  '/payment-disputes/': 'Payment status, evidence, cancellations, holds, refunds, and disagreements.',
  '/account-deletion/': 'Request account deletion without reinstalling the app.',
  '/support/': 'Account, privacy, billing, verification, and safety support routes.',
  '/contact/': 'Public support, privacy, child-safety, legal-notice, and arbitration-opt-out contact points.',
  '/accessibility/': 'Accessibility commitments, supported controls, reduced motion, and feedback.',
};
function navFor(activeRoute) {
  return routes.map(([href, label]) => href === activeRoute ? `<a href="${href}" aria-current="page" class="active">${label}</a>` : `<a href="${href}">${label}</a>`).join('');
}

const publisher = display('MORT_PUBLIC_PUBLISHER_NAME', 'MORT');
const supportEmail = display('MORT_PUBLIC_SUPPORT_EMAIL', 'mortapp.help@gmail.com');
const privacyEmail = display('MORT_PUBLIC_PRIVACY_EMAIL', 'mortapp.help@gmail.com');
const childSafetyEmail = display('MORT_PUBLIC_CHILD_SAFETY_EMAIL', 'mortapp.help@gmail.com');
const websiteUrl = display('MORT_PUBLIC_WEBSITE_URL', 'https://mortapp.org');
const effectiveDate = display('MORT_PUBLIC_EFFECTIVE_DATE', '2026-10-10');
const blocker = deploymentReady ? '' : `<div class="blocker" role="status"><strong>Configuration notice:</strong> Some account-deletion functionality is unavailable in this build because required public configuration is incomplete.</div>`;

function page({ route, title, description, body, scripts = '' }) {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="theme-color" content="#02040a"><meta name="description" content="${escapeHtml(description)}"><title>${escapeHtml(title)} | MORT</title><link rel="icon" href="/mort-mark.svg" type="image/svg+xml"><link rel="stylesheet" href="/assets/legal.css"></head>
<body><a class="skip" href="#content">Skip to content</a><canvas id="legal-sky" aria-hidden="true"></canvas><div class="veil" aria-hidden="true"></div>
<header class="topbar"><a class="brand" href="/"><img src="/mort-mark.svg" width="28" height="28" alt="">MORT <small>Legal &amp; safety</small></a><span class="sp"></span><span class="draft">Effective ${effectiveDate} · United States</span><a class="back" href="https://mortapp.org">&larr; Back to MORT</a></header>
<div class="wrap"><aside class="side"><div class="lbl">Legal &amp; safety</div><nav aria-label="Legal and support">${navFor(route)}</nav></aside><main id="content" class="content"><div class="eyebrow">MORT Legal &amp; Safety · United States</div><h1>${escapeHtml(title)}</h1><p class="tagline">${escapeHtml(description)}</p>${blocker}<div class="callout"><b>Important:</b> MORT is a 13+ local-work marketplace and safety platform. Feature and job eligibility can vary by age, role, jurisdiction, school status, verification state, account status, app version, and provider readiness. Verification and safety tools reduce risk but do not guarantee identity, safety, job quality, payment, or legal compliance.</div>${body}</main></div>
<footer class="foot"><div class="row"><span><b>MORT</b> &nbsp;·&nbsp; Publisher: ${publisher}</span><span>Support: ${supportEmail}</span><span>Effective: ${effectiveDate}</span><span>Website: ${websiteUrl}</span></div><div class="row" style="margin-top:8px"><span>Mandatory rights under applicable law remain protected. State-specific provisions appear in the U.S. State Law Addendum.</span></div></footer>${scripts}<script src="/assets/atmosphere.js"></script></body></html>`;
}

const termsBody = `
<h2>1. Agreement and acceptance</h2><p>These Terms of Service (“Terms”) govern access to and use of MORT's applications, websites, marketplace, messaging, verification, safety, payment, subscription, purchase, support, and related services (“Services”). A contract is formed only through a legally sufficient acceptance process. Where MORT gives conspicuous notice that an action constitutes acceptance, you agree by tapping or clicking an identified acceptance control such as <b>I Agree, Accept, Create Account, Continue, Confirm, Buy, Subscribe, or Confirm Purchase</b>, or by another electronic action clearly presented as acceptance. MORT does not rely solely on a hidden link or the fact that a person visited a webpage.</p><p>Where permitted by law, continued use after conspicuous notice of updated Terms and their effective date may constitute acceptance. MORT may require affirmative re-acceptance of material changes.</p>
<h2>2. Electronic records</h2><p>An electronic acceptance action may constitute an electronic signature. MORT may retain the agreement version or immutable identifier, acceptance timestamp, account identifier, authentication state, acceptance surface, relevant device/session information, and guardian acceptance where applicable to establish what was presented and accepted.</p>
<h2>3. Incorporated agreements</h2><p>The <a href="/privacy/">Privacy Policy</a>, <a href="/dispute-resolution/">Arbitration and Dispute Resolution Agreement</a>, <a href="/us-state-law-addendum/">U.S. State Law Addendum</a>, <a href="/guardian-terms/">Guardian Terms</a>, <a href="/verification-privacy-notice/">Verification Privacy Notice</a>, <a href="/paid-services/">Paid Services Terms</a>, Community Guidelines, Safety rules, Child Safety Standards, Prohibited Jobs Policy, and Payment Dispute rules are incorporated where applicable. A specialized agreement controls over these Terms only for the feature or subject it specifically governs.</p>
<h2>4. Age and eligibility</h2><p>Ordinary MORT accounts are intended for people age 13 or older. Teen Users are users under the age of legal majority. Eligibility for an account does not establish eligibility for every job, payment feature, transaction, subscription, verification method, or location. MORT may require age, role, jurisdiction, school-status, permit, guardian, or verification conditions before enabling a feature.</p>
<h2>5. Teen assent and guardian authorization</h2><p>Teen Users must assent to rules presented to them. MORT may separately require a parent or legal guardian to accept the Guardian Terms and authorize specific marketplace, verification, safety, payment, or other functionality. A guardian represents that the guardian has authority to provide the authorization given. No provision claims to eliminate a minor's nonwaivable rights or to make a minor's agreement enforceable where applicable law provides otherwise.</p>
<h2>6. Accounts and truthful information</h2><p>You must provide accurate, current information and protect account credentials. You may not falsify age, identity, school, business, guardian relationship, verification result, credentials, eligibility, location, authority, or job history. MORT may restrict, recover, suspend, or terminate accounts reasonably necessary for safety, fraud prevention, legal compliance, security, or enforcement.</p>
<h2>7. Verification</h2><p>MORT may use school ID, school email, government ID, business information, age assurance, liveness or presence checks, provider reference IDs, and fraud or security signals. A verification badge means only that specified verification steps were completed. It is <b>not</b> a guarantee of identity, criminal history, trustworthiness, safety, job legality, financial responsibility, or future conduct.</p>
<h2>8. Marketplace role</h2><p>MORT provides technology for eligible users to discover, post, apply for, accept, schedule, communicate about, document, and resolve issues concerning local opportunities. Merely using MORT does not by itself make MORT the employer, employee, staffing agency, contractor, insurer, fiduciary, guardian, transportation provider, principal, or legal representative of marketplace users. Contract labels do not override any worker, employment, agency, or other classification imposed by applicable law based on actual facts.</p>
<h2>9. Adult and business responsibilities</h2><p>Adult and Business Users must accurately describe work, pay, duration, location type, supervision, equipment, material hazards, and expected conditions. They are responsible for laws that apply to their activity, including wage, child-labor, payroll, tax, permit, insurance, worker-classification, safety, nondiscrimination, recordkeeping, and supervision obligations. Publication or a MORT badge is not legal clearance.</p>
<h2>10. Youth work and jurisdiction</h2><p>Federal, state, and local youth-work rules may overlap. When multiple requirements apply, users must comply with the rule that actually governs and MORT may apply the more protective restriction. MORT may block or restrict work based on age, state, locality, school-day status, hours, night-work limits, hazardous occupations, permits or certificates, supervision, equipment, or other eligibility. MORT does not warrant that an eligibility engine alone proves legal compliance.</p>
<h2>11. Prohibited work and conduct</h2><p>Users may not use MORT for illegal activity; sexual or exploitative work; grooming; trafficking; adult-minor sexual solicitation; weapons, drugs, gambling, fraud, or credential theft; dangerous prohibited occupations; harassment; threats; impersonation; doxxing; malware; evidence manipulation; verification evasion; or other conduct prohibited by MORT policy or law.</p>
<h2>12. Real-world safety</h2><p>No MORT rule requires a Teen User to remain in a situation the Teen User reasonably believes is unsafe. MORT may offer check-ins, Guardian Mode, trusted contacts, Safety Exit, reports, blocking, job-status sharing, or emergency-related tools. These controls reduce risk but cannot eliminate it. MORT is not a police, fire, emergency medical, child-protection, or emergency-response service.</p>
<h2>13. Communications and moderation</h2><p>MORT may process communications using automated and human systems to deliver messages and detect scams, grooming, sexual solicitation, threats, harassment, fraud, policy violations, or unsafe job activity. Users should not assume messages are immune from authorized safety review. Automated systems may make mistakes, and MORT may warn, restrict, escalate, or review based on severity and confidence.</p>
<h2>14. Location</h2><p>Public discovery should use only the location precision reasonably necessary for the feature. Precise Teen User location is not an ordinary public profile field. More precise job or safety location may become available only at an appropriate transaction or safety stage. Users may not circumvent location protections or use information to stalk, harass, or endanger another person.</p>
<h2>15. Start, finish, check-in, and evidence systems</h2><p>MORT may use PINs, timestamps, confirmations, photos, files, device events, status history, and other records to document job activity. These are evidence tools and do not independently prove identity, legal compliance, entitlement to payment, quality, or safety.</p>
<h2>16. Payments</h2><p>Where enabled, MORT or identified providers may process authorizations, charges, holds, refunds, transfers, payouts, disputes, and related payment events. Provider terms may also apply. MORT does not guarantee authorization, settlement, chargeback outcomes, payout eligibility, processor availability, or recovery of every debt or loss. Users remain responsible for applicable tax and reporting duties unless MORT expressly assumes one.</p>
<h2>17. Paid services and in-app purchases</h2><p>Subscriptions, boosts, digital items, or other purchases are also governed by the <a href="/paid-services/">Paid Services Terms</a>. Completing a purchase reaffirms these Terms and the Arbitration Agreement only when the checkout interface provides conspicuous notice that the final purchase action constitutes that agreement and supplies accessible links before the action.</p>
<h2>18. XP, ranks, badges, Motion Tokens, and digital items</h2><p>Unless MORT expressly states otherwise, XP, levels, ranks, badges, Motion Tokens, cosmetics, and similar digital features have no cash value and are licensed for use within MORT rather than sold as legal tender, securities, deposits, cryptocurrency, or guaranteed property rights.</p>
<h2>19. User content</h2><p>You retain rights you own in your content. You grant MORT a non-exclusive, worldwide, royalty-free license to host, reproduce, process, format, transmit, display, moderate, preserve, and use submitted content as reasonably necessary to operate the Services, deliver requested functionality, investigate safety matters, resolve disputes, prevent abuse, enforce policy, and comply with law. This license does not authorize unrelated commercial exploitation of private Teen User safety information.</p>
<h2>20. Reviews and reputation</h2><p>Reviews must concern genuine experiences. Users may not buy, fabricate, coerce, retaliate through, or manipulate ratings, reviews, XP, badges, rankings, or reputation systems.</p>
<h2>21. Enforcement</h2><p>MORT may reject listings, remove content, restrict messaging or features, pause transactions, remove verification, preserve relevant evidence, suspend or terminate accounts, or contact appropriate authorities where reasonably necessary for safety, security, fraud prevention, legal compliance, or policy enforcement. Immediate action may occur before a full review where reasonably necessary to protect people or systems.</p>
<h2>22. Third-party services</h2><p>MORT may rely on providers for hosting, databases, authentication, notifications, identity, age assurance, app-store billing, payments, subscriptions, analytics, moderation, maps, fraud prevention, or support. Third parties may have separate terms and privacy practices. MORT is not responsible for independent services outside its control except where applicable law provides otherwise.</p>
<h2>23. No guarantee of jobs or income</h2><p>MORT does not guarantee listings, applications, acceptance, employment, customers, income, payment, ratings, transaction volume, or a particular result.</p>
<h2>24. Service changes and availability</h2><p>The Services may contain errors or experience outages. MORT may add, test, modify, restrict, suspend, or discontinue features, subject to applicable law and paid-service obligations.</p>
<h2>25. Disclaimer of warranties</h2><p><b>TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE SERVICES ARE PROVIDED “AS IS” AND “AS AVAILABLE.”</b> MORT disclaims warranties that may lawfully be disclaimed, including implied warranties of merchantability, fitness for a particular purpose, and non-infringement. MORT does not warrant that every user is who they claim to be, every job is safe or lawful, every payment succeeds, every alert arrives, or every feature is error-free. Nonwaivable warranties remain protected.</p>
<h2>26. Limitation of liability</h2><p><b>TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, MORT AND ITS LAWFUL OPERATORS, AFFILIATES, PERSONNEL, AND SERVICE PROVIDERS WILL NOT BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, PUNITIVE, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, BUSINESS, DATA, OR GOODWILL.</b></p><p>To the maximum extent permitted by applicable law, MORT's aggregate liability for claims arising from the Services will not exceed the <b>greater of $100</b> or the amount the claimant paid directly to MORT during the 12 months preceding the event giving rise to the claim. This limitation does not apply where applicable law prohibits limitation, including where required for fraud, intentional misconduct, gross negligence, death or personal injury, statutory remedies, or another nonwaivable obligation.</p>
<h2>27. User-to-user conduct</h2><p>To the maximum extent permitted by law, MORT is not liable merely because an independent user injures, deceives, threatens, scams, or breaches an agreement with another user. Nothing in this section excuses an obligation imposed directly on MORT by applicable law.</p>
<h2>28. Adult and business indemnification</h2><p>To the maximum extent permitted by law, Adult and Business Users agree to defend, indemnify, and hold harmless MORT from third-party claims arising from their unlawful listing, wage or youth-work violation, unsafe worksite, undisclosed hazard, fraud, intentional misconduct, infringement, misuse of personal information, or material breach of these Terms. This provision is not intended to impose an unlawful or unconscionable indemnification obligation on Teen Users.</p>
<h2>29. Disputes</h2><p>The <a href="/dispute-resolution/">Arbitration and Dispute Resolution Agreement</a> is incorporated into these Terms. It includes a 60-day informal process, individual arbitration where enforceable, a class-action waiver, jury-trial waiver, exceptions, and a 30-day opt-out.</p>
<h2>30. Changes, termination, and survival</h2><p>MORT may update these Terms prospectively. Material changes receive appropriate notice and affirmative re-acceptance where required. Users may stop using MORT and request account deletion. MORT may restrict or terminate access for violations, fraud, safety risks, security needs, or legal requirements. Provisions that logically must survive—such as payment, dispute, intellectual-property, evidence-preservation, liability, indemnification, and arbitration provisions—survive to the extent enforceable.</p>
<h2>31. State and federal savings</h2><p>These Terms do not waive rights that applicable law makes nonwaivable. If a mandatory federal, state, or local rule conflicts with these Terms, that rule controls only to the extent required. See the <a href="/us-state-law-addendum/">U.S. State Law Addendum</a>.</p>
<h2>32. Contact</h2><p>Support and legal notices may be sent to ${supportEmail}. Arbitration opt-outs must use the process in the Arbitration Agreement. MORT will publish a legal mailing address when an appropriate operating-entity address is established; no personal home address is designated by these Terms.</p>`;

const privacyBody = `
<h2>1. Scope and acknowledgement</h2><p>This Privacy Policy explains how MORT collects, uses, discloses, protects, retains, and deletes personal information. Receiving or using this Policy is not blanket consent to every possible data use. Where applicable law requires separate consent—such as for certain biometric, precise-location, sensitive-data, or marketing processing—MORT will request that consent separately.</p>
<h2>2. Who may use MORT</h2><p>Ordinary accounts are intended for people age 13 or older. MORT does not knowingly provide ordinary accounts to children under 13. If MORT learns that an ordinary account belongs to a child under 13, it may restrict or delete the account subject to narrow safety, fraud, abuse-prevention, payment, evidence-preservation, and legal obligations.</p>
<h2>3. Nationwide Teen User baseline</h2><ul><li><b>Data minimization:</b> collect information reasonably necessary for the feature, transaction, safety purpose, legal obligation, or user request.</li><li><b>Private by default:</b> sensitive teen information is not public merely because an account exists.</li><li><b>No sale of Teen User personal information for money.</b></li><li><b>No cross-context behavioral advertising to Teen Users.</b> Teen advertising, where enabled, is contextual or non-personalized.</li><li><b>Safety before monetization:</b> essential reporting, blocking, and emergency-related controls are not conditioned on a paid subscription or ad view.</li></ul>
<h2>4. Information MORT may collect</h2><p>Depending on features used, MORT may process account identifiers, email, username, display name, authentication data, role, date of birth or age band, general location, skills, availability, marketplace activity, listings, applications, schedules, communications, guardian relationships, reports, blocks, verification records, school information, transaction status, subscriptions, device and network information, push tokens, diagnostics, security events, acceptance records, and support interactions.</p>
<h2>5. Teen-sensitive information</h2><p>Full date of birth, exact home address, precise live location, private email or phone, school email, school ID, government ID, guardian information, trusted-contact information, private messages, safety reports, dispute evidence, job evidence, emergency information, payment credentials, and recovery information are not ordinary public profile fields.</p>
<h2>6. Age, school, identity, and business verification</h2><p>MORT may process school ID, school email, government ID, business information, age-assurance results, liveness or presence signals, provider identifiers, fraud signals, and eligibility results. Where reasonably possible, MORT should retain a verification result or provider reference instead of raw documents longer than needed. See the <a href="/verification-privacy-notice/">Verification Privacy Notice</a>.</p>
<h2>7. Facial and biometric information</h2><p>If a verification method uses a photograph, video, facial analysis, biometric identifier, or biometric information, MORT provides any separate notice and consent required by applicable law. Raw facial or biometric material is not advertising data. MORT does not intend to operate a general-purpose facial-recognition database.</p>
<h2>8. Location</h2><p>MORT may process city, state, service area, or approximate device location for discovery and eligibility. Where enabled and authorized, more precise location may be processed for an accepted job, arrival, active-job safety, check-ins, emergency-related functions, or authorized status sharing. Precise Teen User location is not an ordinary public profile field and is not used for personalized advertising.</p>
<h2>9. Communications and moderation</h2><p>MORT may process messages, attachments, support conversations, reports, appeals, and safety communications to deliver them and to detect scams, grooming, sexual solicitation, threats, harassment, fraud, abuse, or policy violations. Authorized automated and human review may be used. Private message bodies are not ordinary advertising analytics data.</p>
<h2>10. Marketplace, safety, guardian, and evidence records</h2><p>MORT may process listings, applications, schedules, accepted-job details, PIN events, check-ins, safety exits, Guardian Mode relationships, trusted contacts, status sharing, files, photos, reports, ratings, reviews, cancellations, disputes, and evidence needed to operate and protect marketplace interactions.</p>
<h2>11. Payments, purchases, and subscriptions</h2><p>Payment and platform providers may independently process card, bank, tax, payout, billing, or identity information. MORT may receive provider IDs, entitlement status, product, price, renewal, expiration, payment-method summary, transaction status, refund, dispute, charge, and payout status. Completing a purchase does not grant unlimited permission to process unrelated personal information.</p>
<h2>12. Progression and reputation</h2><p>MORT may process XP, levels, ranks, badges, Motion Tokens, goals, streaks, cosmetic selections, completion statistics, ratings, and leaderboard participation. Leaderboard visibility may be restricted or private by default for Teen Users according to product settings and safety rules.</p>
<h2>13. Technical information</h2><p>MORT may process IP address, device type, operating system, app version, identifiers used for security or notifications, network events, crash and diagnostic records, authentication events, timestamps, and abuse-prevention signals.</p>
<h2>14. Sources</h2><p>Information may come from the user, an authorized guardian, another marketplace participant, the user's device with permission, payment or verification providers, app stores, service providers, security systems, public or authorized records, or lawful authorities.</p>
<h2>15. How MORT uses information</h2><p>MORT may use information to operate accounts, authenticate users, determine eligibility, verify users, provide marketplace and communication functions, support safety features, process transactions and subscriptions, provide support, investigate disputes, prevent fraud and exploitation, secure systems, enforce rules, comply with law, improve reliability, and establish or defend legal claims.</p>
<h2>16. Service providers</h2><p>MORT may disclose information to contracted providers performing hosting, database, storage, authentication, notifications, verification, age assurance, payment, subscriptions, analytics, fraud prevention, security, moderation, mapping, support, or similar functions. Providers should receive information reasonably necessary for their role and be subject to applicable contractual or legal safeguards.</p>
<h2>17. Other users and guardians</h2><p>Information may be shared with another marketplace participant when reasonably necessary to operate an accepted transaction. MORT minimizes disclosure of sensitive Teen User information. An authorized guardian may receive information made available by Guardian Mode; linking a guardian does not automatically create unrestricted access to every private Teen User message.</p>
<h2>18. Legal and safety disclosures</h2><p>MORT may preserve or disclose information to respond to valid legal process, protect a person, investigate exploitation, prevent fraud, protect systems, enforce agreements, report suspected child sexual exploitation where required, or establish or defend legal claims. Users may contact a government agency or law enforcement as permitted by law.</p>
<h2>19. Advertising</h2><p>MORT does not sell Teen User personal information for money and does not use Teen User data for cross-context behavioral advertising. Precise location, verification documents, school verification, guardian data, private messages, dispute evidence, and private safety reports are not ordinary advertising data.</p>
<h2>20. Analytics</h2><p>MORT may use limited analytics for reliability, crashes, feature usage, marketplace health, security, aggregate engagement, and service improvement. Teen-sensitive data should not be added to ordinary advertising analytics merely because it exists elsewhere in MORT.</p>
<h2>21. Security</h2><p>MORT uses safeguards intended to protect information, which may include authentication, authorization controls, private storage, signed URLs, encryption in transit, rate limits, audit records, restricted administrative access, and security testing. No internet-connected service can guarantee absolute security.</p>
<h2>22. Security incidents</h2><p>If an incident triggers a legal notification duty, MORT will notify affected people, regulators, consumer-reporting agencies, or other recipients as required by applicable law. Timing, content, encryption exceptions, and regulator requirements differ by jurisdiction; this Policy does not replace those mandatory rules.</p>
<h2>23. Retention</h2><p>MORT retains information only as reasonably necessary for the purpose collected and for legitimate safety, fraud, transaction, dispute, security, tax, contractual, insurance, legal, or evidence-preservation needs. Verification material should be retained for the shortest reasonably necessary period where a verification result can serve the purpose.</p>
<h2>24. Deletion</h2><p>Users may request account deletion. Deletion does not necessarily require immediate deletion of information needed for unresolved payments, safety or abuse investigations, fraud prevention, disputes, taxes, legal duties, evidence preservation, or shared transaction records. Data no longer needed may be deleted or deidentified according to applicable law and retention controls.</p>
<h2>25. U.S. privacy rights</h2><p>Depending on residence and applicable law, users may have rights to confirm processing; access, correct, delete, or obtain data; opt out of qualifying sale, sharing, targeted advertising, or profiling; limit certain sensitive-data processing; withdraw consent; use an authorized agent; or appeal a privacy decision. MORT may verify identity or authority before acting. See the <a href="/us-state-law-addendum/">U.S. State Law Addendum</a>.</p>
<h2>26. California and minors</h2><p>Where California law applies, MORT preserves applicable CCPA/CPRA rights, Global Privacy Control treatment where legally required, and special rules for sale or sharing of personal information of people under 16. MORT's own teen baseline is stricter for ordinary MORT operations: no sale of Teen User personal information for money and no cross-context behavioral advertising to Teen Users.</p>
<h2>27. Child safety</h2><p>MORT prohibits child sexual exploitation, grooming, sexual solicitation, sextortion, trafficking, and sexual jobs involving minors. MORT may preserve and report information as required by applicable law and may restrict accounts or transactions to protect users.</p>
<h2>28. Business transfers and international processing</h2><p>If MORT undergoes a merger, financing, acquisition, reorganization, bankruptcy, or asset transfer, information may be transferred subject to applicable law and protections. Providers may process information in other U.S. states or countries; legally required transfer safeguards apply where relevant.</p>
<h2>29. Changes</h2><p>MORT may update this Policy when products, providers, laws, safety practices, or data uses change. Material changes receive appropriate notice and new consent where a materially new processing activity requires it. A changed webpage alone does not substitute for legally required consent.</p>
<h2>30. Contact</h2><p>Privacy: ${privacyEmail}. Support: ${supportEmail}. Do not email passwords, authentication codes, Start/Finish PINs, full card numbers, bank passwords, Social Security numbers, unrequested identity documents, or suspected CSAM.</p>`;

const disputeBody = `
<div class="callout"><b>ARBITRATION NOTICE:</b> Except for stated exceptions and to the maximum extent permitted by law, covered U.S. disputes must first go through a 60-day informal process and, if unresolved, binding <b>individual arbitration</b> rather than a court trial. This Agreement includes a <b>class-action waiver</b> and <b>jury-trial waiver</b>, subject to applicable law and the exceptions below.</div>
<h2>1. Acceptance and scope</h2><p>This Arbitration and Dispute Resolution Agreement is incorporated into the MORT Terms. It applies only where a user or guardian received conspicuous notice and validly accepted the agreement. It covers disputes between a user and MORT arising from or relating to MORT, an account, marketplace activity, moderation, verification, privacy, security, communications, payments, subscriptions, safety tools, content, suspension, deletion, or the relationship with MORT, under contract, tort, statute, regulation, common law, equity, negligence, misrepresentation, consumer law, or privacy law. It does not purport to govern a dispute solely between users.</p>
<h2>2. Teen Users and guardians</h2><p>MORT may require a parent or legal guardian to separately accept this Agreement before specified Teen User functionality is enabled. No provision claims to bind a minor where applicable law makes the agreement unenforceable. Unenforceability as to one person does not automatically invalidate an otherwise enforceable agreement with a separate adult, guardian, or business.</p>
<h2>3. Mandatory informal dispute resolution</h2><p>Before starting arbitration or covered litigation, a claimant must send a written Notice of Dispute to ${supportEmail} with subject <b>LEGAL NOTICE</b>, providing the claimant's name, MORT account information sufficient to identify the account, relevant guardian information if applicable, facts, dates, alleged harm, requested relief, and signature or authorized-representative signature. The parties will attempt in good faith to resolve the matter for <b>60 days</b>. Either side may request a telephone or video settlement conference. Limitation periods are tolled during this period where required by law.</p>
<h2>4. Individual arbitration</h2><p>If unresolved, covered disputes will be resolved through binding individual arbitration administered by the American Arbitration Association (“AAA”) under the applicable Consumer Arbitration Rules where those rules apply. The Federal Arbitration Act governs this Agreement to the maximum extent applicable. Arbitration has different discovery and appellate procedures from court.</p>
<h2>5. Court questions and arbitrator authority</h2><p>The arbitrator decides the merits of arbitrable claims and issues delegated to the arbitrator by enforceable law and agreement. A court decides whether an agreement was actually formed, whether a person validly opted out, and any question that applicable law requires a court to decide.</p>
<h2>6. Class, collective, and representative waiver</h2><p><b>TO THE MAXIMUM EXTENT PERMITTED BY LAW, EACH PARTY MAY BRING COVERED CLAIMS ONLY IN AN INDIVIDUAL CAPACITY AND NOT AS A PLAINTIFF, CLAIMANT, OR CLASS MEMBER IN A PURPORTED CLASS, COLLECTIVE, CONSOLIDATED, REPRESENTATIVE, OR PRIVATE-ATTORNEY-GENERAL PROCEEDING.</b> This clause does not eliminate public injunctive relief or another remedy that applicable law does not permit MORT to waive.</p>
<h2>7. Jury-trial waiver</h2><p>For covered claims lawfully subject to arbitration, the parties waive trial by jury. For a covered claim that lawfully remains in court, each side waives a jury only to the extent such waiver is enforceable.</p>
<h2>8. Small-claims exception</h2><p>Either side may bring an individual qualifying dispute in small-claims court while the matter remains within that court's jurisdiction.</p>
<h2>9. Government, regulatory, and reporting rights</h2><p>Nothing prevents a person from filing a complaint with or cooperating with a government agency, regulator, law-enforcement agency, child-protection authority, or emergency service. Government enforcement authority is not waived.</p>
<h2>10. Emergency and protective relief</h2><p>Nothing prevents legally permitted emergency court relief concerning imminent physical harm, child exploitation, serious cybersecurity harm, destruction of evidence, or comparable irreparable harm, nor appropriate intellectual-property relief where permitted.</p>
<h2>11. Sexual assault and sexual harassment</h2><p>Nothing eliminates a person's election under applicable federal law, including 9 U.S.C. chapter 4, to proceed in court for a dispute relating to sexual assault or sexual harassment where that law applies.</p>
<h2>12. Fees and hearing format</h2><p>AAA filing, administration, and arbitrator fees will be allocated under applicable AAA consumer rules and law, and MORT will pay amounts it is required to pay. Hearings may occur by documents, telephone, video, or another format permitted by the rules and law. Any in-person hearing will occur at a legally appropriate location.</p>
<h2>13. Non-public proceedings</h2><p>Arbitration proceedings should be non-public to the extent permitted by law and applicable rules. This does not prohibit disclosures reasonably necessary to a lawyer, guardian, witness, expert, insurer, auditor, regulator, law-enforcement agency, or court, and does not prohibit legally protected reporting.</p>
<h2>14. Coordinated and mass filings</h2><p>If substantially similar individual claims are coordinated by the same or related counsel, applicable AAA mass-arbitration rules and lawful procedures may apply. Nothing in this section authorizes class arbitration.</p>
<h2>15. 30-day arbitration opt-out</h2><p>You may opt out within <b>30 days</b> after first accepting this Arbitration Agreement. Email ${supportEmail} with subject <b>ARBITRATION OPT OUT</b> and include the account email or username, full name, a clear statement that you opt out of the MORT Arbitration Agreement, and the date. A legally authorized guardian may submit an opt-out concerning a Teen User where applicable. Opting out of arbitration alone will not terminate access to MORT.</p>
<h2>16. State-law remedies</h2><p>Nothing in this Agreement waives a remedy that applicable state law makes nonwaivable. In particular, California public injunctive relief that cannot lawfully be waived in every forum remains available in the forum required by law.</p>
<h2>17. Changes</h2><p>Material changes receive conspicuous notice and, where appropriate or required, affirmative re-acceptance and a new opt-out opportunity. MORT does not rely on silent retroactive changes to capture a dispute that arose before an amendment where law forbids that result.</p>
<h2>18. Severability and survival</h2><p>If a provision is unenforceable, enforceable portions remain effective to the maximum extent permitted by law. A claim that cannot lawfully be arbitrated may be severed while arbitrable claims proceed where permitted. This Agreement survives account termination or deletion to the extent enforceable.</p>`;

const stateBody = `
<h2>1. Purpose and mandatory-law rule</h2><p>This U.S. State Law Addendum supplements the MORT Terms, Privacy Policy, Arbitration Agreement, Verification Privacy Notice, and Paid Services Terms for residents or transactions subject to particular state law. It is not a representation that every MORT marketplace feature is activated in every state. If a mandatory state right conflicts with another MORT term, the mandatory state right controls to the extent of the conflict.</p>
<h2>2. All fifty states: youth work</h2><p>MORT treats youth-work eligibility as jurisdiction-sensitive. Relevant rules may include minimum age, occupation restrictions, school-day and school-week hours, non-school hours, night-work windows, hazardous occupations, employment or age certificates, school authorization, parental permission, wage requirements, and supervision. Federal, state, and local law may overlap; MORT may apply the more protective restriction. A listing, verification badge, or platform eligibility result is not legal clearance.</p><p>States in scope: Alabama, Alaska, Arizona, Arkansas, California, Colorado, Connecticut, Delaware, Florida, Georgia, Hawaii, Idaho, Illinois, Indiana, Iowa, Kansas, Kentucky, Louisiana, Maine, Maryland, Massachusetts, Michigan, Minnesota, Mississippi, Missouri, Montana, Nebraska, Nevada, New Hampshire, New Jersey, New Mexico, New York, North Carolina, North Dakota, Ohio, Oklahoma, Oregon, Pennsylvania, Rhode Island, South Carolina, South Dakota, Tennessee, Texas, Utah, Vermont, Virginia, Washington, West Virginia, Wisconsin, and Wyoming.</p>
<h2>3. All fifty states: security incidents</h2><p>Every state has security-breach notification requirements. MORT preserves state-specific timing, content, regulator, consumer-reporting-agency, encryption, risk-of-harm, and other mandatory requirements instead of promising one national deadline.</p>
<h2>4. State privacy laws</h2><p>Where applicable, MORT preserves rights under comprehensive privacy regimes, including rights that may apply in California, Colorado, Connecticut, Delaware, Florida, Indiana, Iowa, Kentucky, Maryland, Minnesota, Montana, Nebraska, New Hampshire, New Jersey, Oregon, Rhode Island, Tennessee, Texas, Utah, Virginia, and any other state whose law becomes applicable. Rights may include confirmation, access, correction, deletion, portability, opt-out, consent withdrawal, appeal, authorized-agent, targeted-advertising, sale or sharing, profiling, and sensitive-data protections.</p>
<h2>5. California</h2><p>Where applicable, California residents retain CCPA/CPRA rights to access, deletion, correction, qualifying sale or sharing opt-out, sensitive-information limitations, non-discrimination, and authorized-agent procedures. MORT will honor Global Privacy Control where legally required. California's special consent rules concerning sale or sharing of personal information of people under 16 remain protected; MORT's ordinary Teen User baseline is not to sell Teen User personal information for money or use Teen User data for cross-context behavioral advertising. California Automatic Renewal Law rights apply to covered recurring services. Nothing in MORT's dispute terms eliminates public injunctive relief where California law makes such relief nonwaivable.</p>
<h2>6. Colorado</h2><p>Where applicable, Colorado residents retain Colorado Privacy Act rights and covered recurring-service protections, including legally required disclosures, acknowledgments, cancellation methods, and notices.</p>
<h2>7. Illinois biometric information</h2><p>Where the Illinois Biometric Information Privacy Act applies, MORT will provide the required written notice of biometric collection or storage, disclose purpose and term, obtain the legally required written release before collection, maintain the required retention and destruction policy, not sell, lease, trade, or otherwise profit from biometric identifiers or biometric information as prohibited, restrict disclosures, and use the required standard of care for storage and protection.</p>
<h2>8. Texas biometric information</h2><p>Where Texas biometric law applies, MORT will provide legally required notice and obtain consent before commercial capture of covered biometric identifiers and will comply with applicable disclosure, retention, destruction, and protection restrictions.</p>
<h2>9. Washington biometric information</h2><p>Where Washington biometric law applies, MORT will comply with legally required notice or consent for biometric enrollment, permitted-use, disclosure, retention, security, and consumer-protection requirements.</p>
<h2>10. Vermont recurring contracts</h2><p>Where Vermont law applies to a covered automatically renewing consumer contract, MORT preserves applicable affirmative opt-in, disclosure, reminder, and cancellation requirements.</p>
<h2>11. Other state rights</h2><p>This Addendum is not an exhaustive catalogue of every state wage, worker-classification, youth-work, privacy, biometric, consumer-protection, subscription, health-data, security, contract, or safety law. A mandatory right not specifically named remains protected. MORT may update this Addendum prospectively as laws and product operations change.</p>`;

const guardianBody = `
<h2>1. Who this applies to</h2><p>These Guardian Terms apply when MORT requires or permits a parent or legal guardian to authorize specified activity for a Teen User. Guardian authorization is separate from the Teen User's own assent to age-appropriate platform rules.</p>
<h2>2. Authority</h2><p>By accepting as a guardian, you represent that you are the Teen User's parent or legal guardian or otherwise have legal authority to provide the authorization requested. You must provide truthful information and must not impersonate another guardian.</p>
<h2>3. What authorization may cover</h2><p>Depending on the feature and law, guardian authorization may cover marketplace participation, verification, safety settings, transportation-related representations, communication or status-sharing features, payments or payouts, or other functionality identified at the time of consent. MORT should not treat one guardian action as unlimited consent for unrelated future processing.</p>
<h2>4. No guarantee</h2><p>Guardian authorization does not guarantee that a job is safe, lawful, suitable, insured, supervised, or compliant with youth-work rules. Guardians and users remain responsible for reviewing job circumstances and applicable law, while MORT may impose stricter safety restrictions.</p>
<h2>5. Guardian visibility</h2><p>Guardian Mode may expose safety status, accepted-job context, check-ins, or other information identified by the feature. Guardian linking does not automatically create unrestricted access to every private Teen User conversation or sensitive record.</p>
<h2>6. Withdrawal and account effects</h2><p>A guardian may request withdrawal of authorization where law and the feature permit. Withdrawal may disable functionality that depends on that authorization and does not require deletion of records MORT must lawfully retain for safety, fraud, disputes, payments, evidence, or legal obligations.</p>
<h2>7. Minor-contract savings</h2><p>Nothing in these Guardian Terms claims that guardian authorization makes every contract involving a minor enforceable in every jurisdiction or eliminates a Teen User's nonwaivable rights. MORT preserves mandatory state and federal protections.</p>
<h2>8. Disputes</h2><p>When a guardian validly accepts MORT's <a href="/dispute-resolution/">Arbitration Agreement</a> on the guardian's own behalf, that agreement governs the guardian's covered disputes with MORT to the extent enforceable. Any effect on a minor is determined by applicable law.</p>`;

const verificationBody = `
<h2>1. Scope</h2><p>This notice supplements the Privacy Policy when MORT uses school, identity, age-assurance, liveness, facial, or biometric verification. It does not mean every verification method is active in every jurisdiction.</p>
<h2>2. Information</h2><p>Depending on the method, MORT or a disclosed provider may process school ID, school email, government ID, age-band evidence, photograph or video, liveness or presence signal, facial geometry or another biometric identifier where legally permitted, provider reference ID, fraud signals, review decisions, reviewer identity, and verification timestamps.</p>
<h2>3. Purpose</h2><p>Verification information may be used to determine age or role eligibility, school affiliation, business status, account integrity, fraud risk, duplicate or manipulated submissions, trust-and-safety status, or compliance with legal and product requirements. A verification result is not a criminal-background check or guarantee of safety.</p>
<h2>4. Teen school verification</h2><p>School email and school ID are private verification inputs, not ordinary public profile fields. MORT may associate a school using stable identifiers such as NCES School ID, State School ID, or equivalent records where available rather than relying on school name text alone. Grade-span information may be used to determine whether a school category is eligible for a feature.</p>
<h2>5. Retention and deletion</h2><p>MORT's design is to retain raw identity or biometric material for the shortest reasonably necessary period and, where practical, retain a verification result or provider reference instead. Retention may be extended where reasonably necessary for an active fraud, abuse, dispute, security, evidence-preservation, or legal obligation. Applicable biometric destruction deadlines control where stricter.</p>
<h2>6. No advertising use or sale</h2><p>School IDs, government IDs, school email, raw facial media, biometric identifiers, liveness material, and verification evidence are not ordinary advertising data. MORT does not sell biometric identifiers or biometric information and does not use Teen User verification data for cross-context behavioral advertising.</p>
<h2>7. Illinois</h2><p>If Illinois BIPA applies, before collecting or obtaining a covered biometric identifier or biometric information MORT will provide legally required written notice that the information is being collected or stored, state the specific purpose and length of term, and obtain a written release. MORT will maintain a publicly available retention/destruction policy as required, will not sell, lease, trade, or otherwise profit from covered biometric data as prohibited, will restrict disclosure, and will protect it using the legally required standard of care.</p>
<h2>8. Texas</h2><p>If Texas biometric requirements apply, MORT will provide notice and obtain consent before commercial capture of covered biometric identifiers and comply with applicable disclosure, retention, destruction, and security restrictions.</p>
<h2>9. Washington</h2><p>If Washington biometric requirements apply, MORT will comply with legally required notice or consent for enrollment, permitted use, disclosure, retention, and protection of biometric identifiers.</p>
<h2>10. Other states</h2><p>Other state privacy, biometric, health-data, consumer-protection, or youth-protection requirements remain applicable even if not individually listed here. MORT will request separate consent where required.</p>
<h2>11. Device biometrics</h2><p>When MORT uses device-level Face ID, Touch ID, fingerprint, or passcode protection through the operating system, MORT ordinarily receives an authentication success/failure result rather than the device's raw biometric template.</p>
<h2>12. Contact</h2><p>Verification and privacy questions: ${privacyEmail}. Do not send an unsolicited copy of an ID through ordinary support email.</p>`;

const paidBody = `
<h2>1. Scope</h2><p>These Paid Services Terms govern MORT subscriptions, in-app purchases, boosts, digital items, paid features, trials, and other consumer purchases where offered. Feature availability and payment provider can vary by platform and jurisdiction.</p>
<h2>2. Price and purchase disclosure</h2><p>Before the final purchase action, MORT will disclose the price, currency, material product or service, billing interval, whether billing recurs, trial conversion if any, material renewal terms, and a cancellation method as required by law and platform rules.</p>
<h2>3. Express consent</h2><p>Recurring charges require affirmative consent through a purchase flow that clearly discloses recurring billing before the final action. By tapping <b>Buy, Subscribe, or Confirm Purchase</b> after receiving conspicuous notice and accessible links, the user agrees to these Paid Services Terms and may reaffirm the current MORT Terms and Arbitration Agreement as the purchase screen states.</p>
<h2>4. Renewals and price changes</h2><p>Unless disclosed otherwise, an automatically renewing subscription continues until cancelled. MORT or the applicable platform will provide legally required renewal, long-duration, trial-ending, or price-change notices. A material price change applies only as permitted by law and the provider's rules.</p>
<h2>5. Cancellation</h2><p>Where a subscription was enrolled online, MORT will provide an online cancellation method where required and will not intentionally add artificial friction to prevent cancellation. A platform-billed subscription may need to be cancelled through Apple, Google, or the applicable store account settings.</p>
<h2>6. Refunds</h2><p>Refund eligibility depends on the product, payment platform, disclosed refund rules, and applicable law. Nothing in these Terms eliminates a statutory refund, cancellation, chargeback, or cooling-off right that cannot lawfully be waived.</p>
<h2>7. Payment and subscription providers</h2><p>Apple, Google, RevenueCat, Stripe, or another disclosed provider may process billing, entitlement, authorization, refund, tax, or transaction data under its own terms. MORT's use of a provider does not eliminate MORT obligations imposed directly by applicable law.</p>
<h2>8. Digital items</h2><p>Unless expressly stated otherwise, Motion Tokens, XP, badges, cosmetics, boosts, or other digital items have no cash value, cannot be redeemed for money, and are licensed for use in MORT rather than treated as deposits, legal tender, securities, or cryptocurrency.</p>
<h2>9. State recurring-service rights</h2><p>California, Colorado, Vermont, and other states may impose additional automatic-renewal, consent, notice, acknowledgment, or cancellation requirements. Those mandatory rights control. See the <a href="/us-state-law-addendum/">U.S. State Law Addendum</a>.</p>
<h2>10. Minors</h2><p>MORT may require guardian authorization or restrict purchases for Teen Users based on age, product, platform rules, account configuration, or applicable law. A purchase interface must not imply that payment creates eligibility for an otherwise restricted job or feature.</p>`;

const pages = {
  'privacy/index.html': page({ route: '/privacy/', title: 'Privacy Policy', description: routeSummaries['/privacy/'], body: privacyBody }),
  'terms/index.html': page({ route: '/terms/', title: 'Terms of Service', description: routeSummaries['/terms/'], body: termsBody }),
  'dispute-resolution/index.html': page({ route: '/dispute-resolution/', title: 'Arbitration & Dispute Resolution', description: routeSummaries['/dispute-resolution/'], body: disputeBody }),
  'us-state-law-addendum/index.html': page({ route: '/us-state-law-addendum/', title: 'U.S. State Law Addendum', description: routeSummaries['/us-state-law-addendum/'], body: stateBody }),
  'guardian-terms/index.html': page({ route: '/guardian-terms/', title: 'Parent & Guardian Terms', description: routeSummaries['/guardian-terms/'], body: guardianBody }),
  'verification-privacy-notice/index.html': page({ route: '/verification-privacy-notice/', title: 'Verification Privacy Notice', description: routeSummaries['/verification-privacy-notice/'], body: verificationBody }),
  'paid-services/index.html': page({ route: '/paid-services/', title: 'Paid Services Terms', description: routeSummaries['/paid-services/'], body: paidBody }),
  'terms-of-use/index.html': page({ route: '/terms-of-use/', title: 'Terms of use', description: routeSummaries['/terms-of-use/'], body: `<h2>Use MORT lawfully</h2><p>Use MORT only for lawful, age-appropriate activity. Do not impersonate others, falsify age or authority, evade bans, scrape private participant information, expose private addresses, pressure Teen Users off-platform, manipulate ratings, falsify evidence, or defeat safety controls.</p><h2>Legal package</h2><p>The <a href="/terms/">Terms</a>, <a href="/privacy/">Privacy Policy</a>, <a href="/dispute-resolution/">Arbitration Agreement</a>, and <a href="/us-state-law-addendum/">U.S. State Law Addendum</a> govern where applicable.</p>` }),
  'community-guidelines/index.html': page({ route: '/community-guidelines/', title: 'Community guidelines', description: routeSummaries['/community-guidelines/'], body: `<h2>Keep MORT job-focused</h2><p>Use accurate scope, schedule, supervision, location type, hazards, and pay information. No fraud, spam, impersonation, harassment, retaliation, coercion, doxxing, or evidence manipulation.</p><h2>Protect minors</h2><p>No grooming, sexual or romantic adult-minor conduct, sexual solicitation, trafficking, sextortion, requests for intimate material, private minor directories, or attempts to bypass MORT safety restrictions.</p><h2>Enforcement</h2><p>MORT may remove content, restrict features, suspend accounts, preserve evidence, or contact appropriate authorities consistent with law and the Terms.</p>` }),
  'safety/index.html': page({ route: '/safety/', title: 'Safety Center', description: routeSummaries['/safety/'], body: `<h2>Immediate danger</h2><p>If someone is in immediate danger, contact 911 or the appropriate local emergency service. MORT is not an emergency responder.</p><h2>Before a job</h2><p>Review job scope, approximate location, pay, timing, people expected to be present, supervision, transportation, tools, and hazards. Use Guardian Mode or trusted-contact features where available.</p><h2>During and after a job</h2><p>Use Start/Finish PINs, check-ins, status sharing, reporting, blocking, and Safety Exit as appropriate. Leave an unsafe situation. Preserve relevant evidence without putting yourself at additional risk.</p>` }),
  'child-safety-standards/index.html': page({ route: '/child-safety-standards/', title: 'Child Safety Standards', description: routeSummaries['/child-safety-standards/'], body: `<h2>Zero tolerance</h2><p>MORT prohibits child sexual abuse and exploitation, grooming, sexual solicitation, sextortion, trafficking, sexualized jobs involving minors, and attempts to obtain or distribute child sexual abuse material.</p><h2>Reports and evidence</h2><p>MORT may restrict accounts, preserve relevant evidence, and make legally required reports. Do not send suspected CSAM through ordinary email or re-upload it to report it.</p><h2>Contact</h2><p>Child-safety contact: ${childSafetyEmail}. For immediate danger, contact emergency services.</p>` }),
  'prohibited-jobs/index.html': page({ route: '/prohibited-jobs/', title: 'Prohibited Jobs Policy', description: routeSummaries['/prohibited-jobs/'], body: `<h2>Never allowed</h2><p>No sexual or exploitative work; illegal activity; weapons, drugs, gambling, trafficking, fraud, credential theft, or scams; or work designed to obtain private or intimate material from a minor.</p><h2>Dangerous work</h2><p>MORT may prohibit or restrict hazardous construction, roofing, demolition, excavation, heavy machinery, dangerous power-driven equipment, toxic or hazardous substances, driving or delivery by minors, extreme heat or cold exposure, isolated or hidden work, and any occupation prohibited for the user's age or jurisdiction.</p><h2>Law controls</h2><p>This list is not exhaustive. Federal, state, and local youth-work rules control, and MORT may apply stricter safety restrictions.</p>` }),
  'payment-disputes/index.html': page({ route: '/payment-disputes/', title: 'Payment disputes', description: routeSummaries['/payment-disputes/'], body: `<h2>When payment features are enabled</h2><p>MORT may record authorization, charge, payout, refund, cancellation, evidence, safety hold, and dispute states. Payment availability depends on provider readiness, age, role, transaction, and jurisdiction.</p><h2>Evidence</h2><p>MORT may consider job status, messages, PIN events, timestamps, scope changes, files, photos, cancellations, reports, provider records, and other relevant evidence. An internal decision is not a court judgment and does not eliminate nonwaivable legal rights.</p><h2>Provider disputes</h2><p>Card-network, bank, app-store, or payment-provider dispute rights may separately apply.</p>` }),
  'support/index.html': page({ route: '/support/', title: 'Support', description: routeSummaries['/support/'], body: `<h2>Get help</h2><p>Use the in-app Support Center when available. Email ${supportEmail} for account, privacy, verification, billing, or general support.</p><h2>Safety</h2><p>For immediate danger contact emergency services. For child-safety matters use ${childSafetyEmail}. Do not email passwords, authentication codes, full payment credentials, unsolicited identity documents, or suspected CSAM.</p>` }),
  'contact/index.html': page({ route: '/contact/', title: 'Contact MORT', description: routeSummaries['/contact/'], body: `<h2>Public contacts</h2><p>Publisher: ${publisher}<br>Support: ${supportEmail}<br>Privacy: ${privacyEmail}<br>Child safety: ${childSafetyEmail}</p><h2>Legal notices and arbitration opt-out</h2><p>Legal notices: ${supportEmail}, subject <b>LEGAL NOTICE</b>.<br>Arbitration opt-out: ${supportEmail}, subject <b>ARBITRATION OPT OUT</b>. Follow the information requirements in the <a href="/dispute-resolution/">Arbitration Agreement</a>.</p>` }),
  'accessibility/index.html': page({ route: '/accessibility/', title: 'Accessibility', description: routeSummaries['/accessibility/'], body: `<h2>Accessibility goals</h2><p>MORT aims to support screen readers, scalable text, keyboard navigation where applicable, visible focus, dark mode, and reduced-motion preferences. These are product commitments, not a claim of a specific formal conformance certification unless MORT separately verifies one.</p><h2>Feedback</h2><p>Send accessibility feedback to ${supportEmail}, including the page or feature and the barrier encountered.</p>` }),
};

const deletionBody = `<section class="sec"><h2>What happens</h2><p>After ownership verification, MORT creates an auditable request to remove the account and ordinary profile data. Narrow safety, fraud, dispute, security, evidence-preservation, payment, contractual, and legal records may be retained with restricted access when legitimately necessary.</p></section><section id="request-panel" class="glass form-panel"><h2>1. Verify account ownership</h2><form id="deletion-link-form" novalidate><div class="field"><label for="email">Account email</label><input id="email" name="email" type="email" autocomplete="email" required></div><button class="btn" type="submit">Send private sign-in link</button></form><p id="link-result" class="result" role="status" aria-live="polite"></p></section><section id="confirmed-panel" class="glass form-panel" hidden><h2>2. Submit deletion request</h2><p>You are signed in for this request. MORT will not require a support conversation first.</p><button id="submit-deletion" class="btn" type="button">Request account deletion</button><button id="sign-out" class="btn secondary" type="button">Sign out</button><p id="deletion-result" class="result" role="status" aria-live="polite"></p></section><section class="sec"><h2>Use the app</h2><p>Open Settings, Account, then Delete account. Reinstallation is not required.</p></section><section class="sec"><h2>Privacy</h2><p>The email-link form always gives a generic public response and does not reveal whether an account exists.</p></section>`;
pages['account-deletion/index.html'] = page({ route: '/account-deletion/', title: 'Delete your MORT account', description: routeSummaries['/account-deletion/'], body: deletionBody, scripts: '<script src="/assets/supabase.js"></script><script src="/assets/public-config.js"></script><script src="/assets/account-deletion.js"></script>' });

const indexCards = routes.filter(([route]) => route !== '/').map(([route, label]) => `<a class="glass card" href="${route}"><h2>${escapeHtml(label)}</h2><p>${escapeHtml(routeSummaries[route] || 'MORT legal, policy, safety, and support information.')}</p></a>`).join('');
pages['index.html'] = page({ route: '/', title: 'Legal and safety center', description: 'MORT legal, privacy, safety, verification, payments, state-law, guardian, and support information for the United States.', body: `<section class="glass"><h2>Effective ${effectiveDate}</h2><p>This legal package applies to MORT's United States service as described in each document. It does not claim that every marketplace feature is activated or legally eligible in every state.</p></section><div class="cards">${indexCards}</div>` });

for (const [relative, content] of Object.entries(pages)) write(relative, content);
write('assets/legal.css', readFileSync(resolve(legalTheme, 'legal.css'), 'utf8'));
write('assets/atmosphere.js', readFileSync(resolve(legalTheme, 'atmosphere.js'), 'utf8'));
write('mort-mark.svg', readFileSync(resolve(legalTheme, 'mort-mark.svg'), 'utf8'));
write('assets/supabase.js', readFileSync(supabaseBrowserBundle, 'utf8'));
write('assets/public-config.js', `window.MORT_PUBLIC_CONFIG = Object.freeze(${JSON.stringify({ supabaseUrl: supabase.url, supabaseAnonKey: supabase.key })});`);
write('assets/account-deletion.js', `
const config = window.MORT_PUBLIC_CONFIG || {};
const form = document.querySelector('#deletion-link-form');
const result = document.querySelector('#link-result');
const requestPanel = document.querySelector('#request-panel');
const confirmedPanel = document.querySelector('#confirmed-panel');
const deletionResult = document.querySelector('#deletion-result');
const submit = document.querySelector('#submit-deletion');
const signOut = document.querySelector('#sign-out');
if (!config.supabaseUrl || !config.supabaseAnonKey) {
  form.querySelector('button').disabled = true;
  result.textContent = 'Web account deletion is not configured in this preview. Use the in-app account deletion control.';
} else {
  const client = window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey, { auth: { persistSession: true, detectSessionInUrl: true, flowType: 'pkce' } });
  async function showSession() {
    const { data } = await client.auth.getSession();
    const signedIn = Boolean(data.session);
    requestPanel.hidden = signedIn;
    confirmedPanel.hidden = !signedIn;
    if (signedIn) {
      const { data: status } = await client.rpc('get_my_account_deletion_request');
      if (status?.request) deletionResult.textContent = 'Current request status: ' + status.request.status.replaceAll('_', ' ') + '.';
    }
  }
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const email = new FormData(form).get('email')?.toString().trim();
    if (!email) return;
    form.querySelector('button').disabled = true;
    try {
      await client.auth.signInWithOtp({ email, options: { shouldCreateUser: false, emailRedirectTo: new URL('/account-deletion/?confirm=1', location.origin).toString() } });
      result.textContent = 'If that address belongs to an eligible MORT account, a private sign-in link has been sent.';
    } catch { result.textContent = 'If that address belongs to an eligible MORT account, a private sign-in link has been sent.'; }
    finally { form.querySelector('button').disabled = false; }
  });
  submit.addEventListener('click', async () => {
    submit.disabled = true;
    try {
      const { data, error } = await client.rpc('request_account_deletion');
      if (error || data?.ok === false) throw error || new Error(data?.code || 'request_failed');
      deletionResult.textContent = 'Your deletion request was submitted.';
    } catch { deletionResult.textContent = 'We could not submit the request. Try again or use the in-app deletion control.'; }
    finally { submit.disabled = false; }
  });
  signOut.addEventListener('click', async () => { await client.auth.signOut(); await showSession(); });
  client.auth.onAuthStateChange(() => { showSession(); });
  showSession();
}
`);

write('release-status.json', JSON.stringify({
  revision: REVISION,
  generatedAt: new Date().toISOString(),
  effectiveDate: publicConfig.MORT_PUBLIC_EFFECTIVE_DATE || '2026-10-10',
  scope: 'United States',
  deploymentReady,
  missingConfig,
  legalApprovalClaimed: false,
  externalLegalReviewPending: true,
  publicDeploymentClaimed: true,
  routes: routes.map(([route]) => route),
}, null, 2));

write('vercel.json', JSON.stringify({
  cleanUrls: true,
  trailingSlash: true,
  headers: [{ source: '/(.*)', headers: [
    { key: 'X-Content-Type-Options', value: 'nosniff' },
    { key: 'X-Frame-Options', value: 'DENY' },
    { key: 'Referrer-Policy', value: 'no-referrer' },
    { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), payment=()' },
    { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
    { key: 'Content-Security-Policy', value: "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' https://rakjydmgwwgtdislanbt.supabase.co wss://rakjydmgwwgtdislanbt.supabase.co; object-src 'none'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'" },
  ] }],
}, null, 2));

console.log(JSON.stringify({ revision: REVISION, output, deploymentReady, missingConfig, routes: routes.length }, null, 2));
