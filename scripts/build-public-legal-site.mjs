import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const output = resolve(root, 'web', 'public');
const legalTheme = resolve(root, 'web', 'legal-theme');
const supabaseBrowserBundle = resolve(
  root,
  'node_modules',
  '@supabase',
  'supabase-js',
  'dist',
  'umd',
  'supabase.js',
);
const requiredConfigNames = [
  'MORT_PUBLIC_PUBLISHER_NAME',
  'MORT_PUBLIC_SUPPORT_EMAIL',
  'MORT_PUBLIC_PRIVACY_EMAIL',
  'MORT_PUBLIC_CHILD_SAFETY_EMAIL',
  'MORT_PUBLIC_WEBSITE_URL',
  'MORT_PUBLIC_EFFECTIVE_DATE',
];
const publicConfig = Object.fromEntries(
  requiredConfigNames.map((name) => [name, process.env[name]?.trim() ?? '']),
);
const missingMetadataConfig = requiredConfigNames.filter((name) => !publicConfig[name]);
const supabase = readSupabasePublicConfig();
const missingConfig = [
  ...missingMetadataConfig,
  ...(!supabase.key ? ['EXPO_PUBLIC_SUPABASE_ANON_KEY'] : []),
];
const deploymentReady = missingConfig.length === 0;

if (!existsSync(supabaseBrowserBundle)) {
  throw new Error('The pinned local Supabase browser bundle is missing. Run pnpm install first.');
}
for (const asset of ['legal.css', 'atmosphere.js', 'mort-mark.svg']) {
  if (!existsSync(resolve(legalTheme, asset))) {
    throw new Error(`The legal redesign asset is missing: ${asset}`);
  }
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
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}
function display(name, pending) {
  return escapeHtml(publicConfig[name] || pending);
}
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
  } catch {
    // Account deletion remains visibly unavailable until public config exists.
  }
  const expectedUrl = 'https://rakjydmgwwgtdislanbt.supabase.co';
  if (url && url !== expectedUrl) throw new Error('Public legal site points to the wrong Supabase project.');
  if (key) {
    try {
      const payload = JSON.parse(Buffer.from(key.split('.')[1], 'base64url').toString('utf8'));
      if (payload.role !== 'anon') throw new Error('Only the Supabase anon key may be published.');
    } catch (error) {
      if (error instanceof SyntaxError) throw new Error('The configured Supabase public key is not a valid JWT.');
      throw error;
    }
  }
  return { url: url || expectedUrl, key };
}

const routes = [
  ['/', 'Legal and safety center'],
  ['/privacy/', 'Privacy'],
  ['/terms/', 'Terms'],
  ['/dispute-resolution/', 'Dispute resolution'],
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
  '/privacy/': 'Production privacy disclosures for accounts, teen data, verification, location, safety, ads, payments, retention, and rights.',
  '/terms/': 'Comprehensive MORT Terms of Service for teen, adult, business, guardian, marketplace, safety, payment, and subscription use.',
  '/dispute-resolution/': 'Mandatory informal resolution, individual arbitration, class-action waiver, jury waiver, and legal exceptions.',
  '/terms-of-use/': 'Plain-language rules for lawful account, job, message, safety, and marketplace use.',
  '/community-guidelines/': 'Behavior and content standards for participants and organizations.',
  '/safety/': 'Reporting, blocking, job-context, and real-world safety guidance.',
  '/child-safety-standards/': 'Standards against child sexual abuse, exploitation, grooming, and solicitation.',
  '/prohibited-jobs/': 'Work categories and conditions that are not allowed in MORT.',
  '/payment-disputes/': 'How MORT handles payment status, evidence, cancellations, and disagreements.',
  '/account-deletion/': 'Request account deletion without reinstalling the app.',
  '/support/': 'Account, privacy, and safety support routes.',
  '/contact/': 'Public contact points for support, privacy, and child safety.',
  '/accessibility/': 'Accessibility commitments, supported controls, and feedback.',
};

function navFor(activeRoute) {
  return routes
    .map(([href, label]) => href === activeRoute
      ? `<a href="${href}" aria-current="page" class="active">${label}</a>`
      : `<a href="${href}">${label}</a>`)
    .join('');
}
const publisher = display('MORT_PUBLIC_PUBLISHER_NAME', 'Publisher identity pending - deployment blocked');
const supportEmail = display('MORT_PUBLIC_SUPPORT_EMAIL', 'Support contact pending - deployment blocked');
const privacyEmail = display('MORT_PUBLIC_PRIVACY_EMAIL', 'Privacy contact pending - deployment blocked');
const childSafetyEmail = display('MORT_PUBLIC_CHILD_SAFETY_EMAIL', 'Child-safety contact pending - deployment blocked');
const websiteUrl = display('MORT_PUBLIC_WEBSITE_URL', 'Public website URL pending - deployment blocked');
const effectiveDate = display('MORT_PUBLIC_EFFECTIVE_DATE', 'Effective date pending - deployment blocked');
const blocker = deploymentReady
  ? ''
  : `<div class="blocker" role="status"><strong>Release blocker:</strong> Required publisher or public configuration is incomplete.</div>`;

function page({ route, title, description, body, scripts = '' }) {
  const nav = navFor(route);
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
  <meta name="theme-color" content="#02040a">
  <meta name="description" content="${escapeHtml(description)}">
  <title>${escapeHtml(title)} | MORT</title>
  <link rel="icon" href="/mort-mark.svg" type="image/svg+xml">
  <link rel="stylesheet" href="/assets/legal.css">
</head>
<body>
  <a class="skip" href="#content">Skip to content</a>
  <canvas id="legal-sky" aria-hidden="true"></canvas>
  <div class="veil" aria-hidden="true"></div>
  <header class="topbar"><a class="brand" href="/"><img src="/mort-mark.svg" width="28" height="28" alt="">MORT <small>Legal &amp; safety</small></a><span class="sp"></span><span class="draft">Draft — pending qualified legal review</span><a class="back" href="https://mortapp.org">&larr; Back to MORT</a></header>
  <div class="wrap">
    <aside class="side"><div class="lbl">Legal &amp; safety</div><nav aria-label="Legal and support">${nav}</nav></aside>
    <main id="content" class="content">
      <div class="eyebrow">Public policy &amp; safety</div>
      <h1>${escapeHtml(title)}</h1>
      <p class="tagline">${escapeHtml(description)}</p>
${blocker}
      <div class="callout"><b>Important:</b> MORT is a 13+ local-work marketplace and safety platform. Feature availability can vary by age, role, jurisdiction, account status, app version, verification state, and payment-provider readiness. Verification and safety tools reduce risk but do not guarantee identity, safety, job quality, payment, or legal compliance.</div>
      ${body}
    </main>
  </div>
  <footer class="foot"><div class="row"><span><b>MORT</b> &nbsp;&middot;&nbsp; Publisher: ${publisher}</span><span>Support: ${supportEmail}</span><span>Effective: ${effectiveDate}</span><span>Website: ${websiteUrl}</span></div><div class="row" style="margin-top:8px"><span>Draft — pending qualified legal review. Rights that applicable law makes nonwaivable remain protected.</span></div></footer>
  ${scripts}
  <script src="/assets/atmosphere.js"></script>
</body>
</html>`.replace(/^[ \t]+$/gm, '');
}

write('assets/legal.css', readFileSync(resolve(legalTheme, 'legal.css'), 'utf8'));
write('assets/atmosphere.js', readFileSync(resolve(legalTheme, 'atmosphere.js'), 'utf8'));
write('mort-mark.svg', readFileSync(resolve(legalTheme, 'mort-mark.svg'), 'utf8'));

const privacyBody = `
<h2>1. Scope</h2>
<p>This Privacy Policy explains how MORT collects, uses, shares, protects, retains, and deletes information when people use the MORT mobile application, websites, public policy pages, marketplace, support, safety, verification, subscription, advertising, and related services.</p>
<p>MORT does not collect every category described here from every user. Collection depends on the features a person uses and the person's age, role, location, permissions, verification status, and account configuration.</p>

<h2>2. Who may use MORT</h2>
<p>MORT accounts are generally intended for people age 13 or older. Teen accounts are intended primarily for eligible users ages 13–17. Adult, business, guardian, moderator, support, and administrator roles may have additional eligibility requirements.</p>
<p>MORT does not knowingly provide ordinary MORT accounts to children under 13. If MORT learns that an ordinary account belongs to a person under 13, MORT may restrict or delete the account and associated information, subject to narrow safety, fraud-prevention, abuse-prevention, legal, and evidence-preservation requirements.</p>

<h2>3. Teen privacy principles</h2>
<ul>
<li><b>Data minimization.</b> MORT should collect only information reasonably necessary for the applicable feature, safety purpose, legal obligation, marketplace transaction, or user request.</li>
<li><b>Private by default.</b> Sensitive teen information is not public merely because an account exists.</li>
<li><b>No sale of teen personal information for money.</b></li>
<li><b>No cross-context behavioral advertising to Teen Users.</b> Teen ads, where enabled, are contextual or non-personalized.</li>
<li><b>Safety before monetization.</b> Essential reporting, blocking, safety, and emergency-related functions are not conditioned on a paid subscription or ad view.</li>
</ul>

<h2>4. Account and authentication information</h2>
<p>MORT may process an account ID, email address, username, display name, authentication provider, optional recovery information, session data, login history, role, onboarding status, account restrictions, policy acceptance records, and security events. Password authentication is handled by the authentication provider; MORT is not designed to store readable passwords.</p>

<h2>5. Age and eligibility information</h2>
<p>MORT may process date of birth, age band, jurisdiction, teen/adult status, role eligibility, marketplace eligibility, job-category eligibility, guardian requirements, verification status, age-assurance results, and legal-document acceptance. MORT should ordinarily use age bands or eligibility results instead of exposing an exact date of birth.</p>

<h2>6. Profile information</h2>
<p>Users may provide a profile image, username, biography, skills, availability, general service area, job preferences, badges, rank, XP, completion statistics, ratings, reviews, and trust or safety indicators. Public visibility depends on role, age, feature, privacy setting, and safety requirements.</p>

<h2>7. Sensitive teen information that is not an ordinary public profile field</h2>
<p>MORT does not treat a Teen User's full date of birth, exact home address, precise live location, private email, private phone number, school email, school ID, government ID, guardian identity, trusted-contact identity, private messages, safety reports, dispute evidence, private job evidence, emergency information, or account-recovery information as an ordinary public directory field.</p>

<h2>8. Marketplace and job information</h2>
<p>MORT may process job posts, categories, descriptions, approximate locations, requirements, pay information, schedules, skills, equipment, hazards, expected people, supervision, applications, applicant decisions, accepted jobs, job agreements, cancellations, scope changes, safety holds, work progress, Start and Finish PIN events, completion, reviews, ratings, work history, payment status, and dispute status.</p>

<h2>9. Communications and moderation</h2>
<p>MORT may process job-context messages, support conversations, report descriptions, appeals, safety messages, dispute communications, attachments, and moderation events. Communications may be scanned or reviewed to deliver messages, detect spam or scams, identify grooming or sexual solicitation, detect threats and harassment, prevent prohibited off-platform contact, protect minors, investigate reports, enforce policies, and comply with law.</p>
<p>Automated systems can make mistakes. Depending on severity and confidence, MORT may warn, block, hide, restrict, escalate, or refer content for human review. MORT does not place private message bodies into ordinary advertising analytics.</p>

<h2>10. Identity, age, school, and business verification</h2>
<p>MORT may offer or require verification using government ID, school ID, school email, business information, age-assurance results, liveness or presence signals where lawful, provider reference IDs, or fraud-prevention signals. Verification is one trust-and-safety signal and is not a guarantee that a person is safe, trustworthy, lawful, financially responsible, or suitable for every job.</p>
<p>School IDs, school email addresses, and verification documents are not ordinary public profile information and are not used for personalized advertising.</p>

<h2>11. Facial and biometric information</h2>
<p>If an age-assurance or identity feature uses a photograph, video, facial analysis, or biometric identifier, MORT will provide any additional notice or consent required by law. MORT's intended design is to restrict use to verification, security, fraud prevention, or a legally required purpose; retain raw media for the shortest reasonably necessary period; avoid advertising uses; avoid sale; and retain a verification result or provider reference instead of raw material whenever reasonably possible.</p>
<p>MORT does not intend to operate a general-purpose facial-recognition database. Device Face ID, Touch ID, fingerprint, or passcode protection ordinarily returns an authentication success/failure result to MORT rather than the device's raw biometric template.</p>

<h2>12. Location</h2>
<p>MORT may process city, state, general area, service radius, manually selected area, or approximate device location for local discovery and eligibility. Where enabled and authorized, MORT may temporarily process more precise location for an accepted job, arrival, active-job safety, check-ins, emergency-related functions, or authorized status sharing.</p>
<p>Precise Teen User location is not a public field and is not used for personalized advertising. If device permission is denied, MORT does not secretly bypass that permission, although location-dependent features may become unavailable.</p>

<h2>13. Safety and guardian information</h2>
<p>MORT may process safety check-ins, Safety Exit events, emergency states, trusted contacts, Guardian Mode links, guardian approvals, arrival/departure status, safety escalations, incident reports, and related evidence. Guardian access is not automatic merely because someone knows a Teen User's name, username, or email. Access is limited to what the authorized feature, permissions, and law allow.</p>
<p>Guardian Mode does not silently grant unrestricted access to every private Teen User message. Additional information may be disclosed when permitted or required in a serious safety situation.</p>

<h2>14. Photos, video, camera, and files</h2>
<p>MORT may process images or files selected for avatars, identity verification, job proof, disputes, support, reports, or safety investigations. MORT may resize files, remove unnecessary metadata, scan for malicious or prohibited content, validate file type, and generate secure previews.</p>

<h2>15. Payments and subscriptions</h2>
<p>MORT may maintain agreed job compensation, payment status, refund status, dispute status, provider identifiers, transaction identifiers, provider status, and limited payment-method descriptions supplied by an approved provider. Payment providers may separately process card, bank, tax, identity, or payout information under their own privacy terms.</p>
<p>For Plus, Pro, or other digital products, MORT may process subscription tier, product ID, purchase status, renewal status, entitlement, purchase platform, transaction reference, and expiration. App stores, RevenueCat, or another authorized billing provider may separately process billing information.</p>

<h2>16. Progression and leaderboards</h2>
<p>MORT may process XP, level, rank, badges, completed-job count, safety streak, goals, Motion Tokens, cosmetic unlocks, and leaderboard preferences. Teen leaderboard participation is intended to be optional where required by the feature design, and public leaderboard data should not expose exact age, home address, school, private email, or precise location.</p>

<h2>17. Device and technical information</h2>
<p>MORT and its providers may process device type, operating system, app version, IP address, language, time zone, push token, session identifiers, request metadata, network information, security events, rate limits, app-integrity results, crash information, error records, and performance information to operate, secure, diagnose, and improve the service.</p>

<h2>18. Information from other sources</h2>
<p>MORT may receive information from authentication providers, app stores, verification providers, payment providers, fraud-prevention providers, linked guardians, businesses, support providers, users involved in the same job, public business registries, law enforcement, government authorities, safety organizations, and other sources authorized by the user or law. MORT does not purchase broad data-broker dossiers about Teen Users for advertising.</p>

<h2>19. How MORT uses information</h2>
<p>MORT may use information to provide and maintain the service, authenticate and recover accounts, determine age and role eligibility, verify identity or business status, operate jobs and messaging, support Guardian Mode, operate safety tools, document completion, maintain job records, process subscriptions and approved payments, deliver notifications, support users, investigate reports and disputes, prevent fraud and exploitation, enforce policies, secure systems, comply with law, establish or defend legal claims, and improve reliability, accessibility, and safety.</p>

<h2>20. Sharing</h2>
<p>MORT may disclose information to authorized job participants, verified guardians or safety contacts, and contracted service providers only as reasonably necessary for the feature or purpose involved. Providers may include authentication, database, hosting, file storage, notification, fraud, moderation, age-assurance, identity-verification, payment, subscription, advertising, analytics, support, crash-diagnostics, and security providers.</p>
<p>MORT may also preserve or disclose information where reasonably necessary to protect a person, investigate suspected abuse or fraud, comply with valid legal process, enforce policies, report child sexual abuse material as required, or establish or defend legal claims.</p>

<h2>21. Advertising</h2>
<p>MORT may display advertising on eligible non-sensitive surfaces. Teen advertising is intended to be non-personalized or contextual. Precise location, private messages, identity documents, school-verification information, guardian data, private safety data, and dispute evidence are not advertising data.</p>
<p>MORT does not sell Teen Users' personal information for money and does not use Teen User personal information for cross-context behavioral advertising. Where a law defines sale, sharing, or targeted advertising more broadly, MORT will provide any legally required control or opt-out.</p>

<h2>22. Analytics</h2>
<p>Limited analytics may be used for reliability, performance, crashes, feature usage, aggregate engagement, marketplace health, security, and technical failures. Ordinary analytics should exclude private message bodies, raw identity documents, raw school IDs, precise live location, private safety-report narratives, private dispute evidence, passwords, authentication secrets, and Start or Finish PINs.</p>

<h2>23. Security</h2>
<p>MORT uses administrative, organizational, and technical safeguards designed to protect information, including authentication, private storage, row-level and server-side authorization, short-lived signed links, access controls, rate limits, logs, audit events, restricted administrative roles, encrypted network transport, security testing, and separation of public and private data.</p>
<p>No internet-connected system can guarantee absolute security. Users should protect their credentials, email account, device, and authentication factors and should report suspected unauthorized access promptly.</p>

<h2>24. Retention</h2>
<p>MORT retains information only as long as reasonably necessary for the purpose collected and legitimate account, marketplace, safety, fraud-prevention, security, contractual, tax, payment, dispute, insurance, legal, and evidence-preservation needs. Raw identity or age-assurance material should be retained for the shortest reasonably necessary period where MORT can instead preserve a verification result or reference.</p>
<p>Temporary precise-location sessions are intended to expire when the active job or safety purpose ends, subject to narrow incident, security, dispute, or legal holds. Backups may retain deleted information for a limited rotation period. When retention is no longer justified, MORT may delete, anonymize, aggregate, or deidentify information.</p>

<h2>25. Account and data deletion</h2>
<p>Users can request deletion through MORT account controls or the <a href="/account-deletion/">public deletion page</a>. MORT may verify account ownership. Deletion generally removes or deidentifies ordinary account data that is no longer needed, but limited information may remain for unresolved safety investigations, fraud prevention, security, disputes, appeals, payment or job records, tax obligations, legal compliance, preventing repeat abuse, valid legal process, and evidence preservation.</p>
<p>Some records involve more than one person. Deleting one account does not necessarily require deletion of another person's lawful copy or a legitimate shared transaction, safety, or dispute record.</p>

<h2>26. Privacy rights</h2>
<p>Depending on applicable law, users may have rights to confirm processing, access, correction, deletion, portability, opt out of qualifying sale, targeted advertising, or profiling, withdraw consent where relevant, limit certain sensitive-data uses, appeal a denied privacy request, and exercise rights without unlawful discrimination. MORT may verify identity, account ownership, guardian authority, or authorized-agent status before fulfilling a request.</p>
<p>Eligible Indiana residents may have rights under the Indiana Consumer Data Protection Act, including access, correction, deletion, portability, applicable opt-outs, and appeal. Other state or international rights may also apply.</p>

<h2>27. Child sexual abuse and exploitation</h2>
<p>MORT has zero tolerance for child sexual abuse or exploitation, grooming, sexual solicitation, sextortion, trafficking, requests for sexual images, sexual jobs, or attempts to use MORT to endanger a minor. MORT may preserve and report apparent child sexual abuse material or related information when required by law. Do not email, download, forward, or redistribute suspected child sexual abuse material.</p>

<h2>28. Business transfers</h2>
<p>If MORT is involved in a merger, acquisition, financing, restructuring, bankruptcy, asset transfer, sale, or corporate reorganization, information may be transferred where permitted by law, subject to applicable privacy obligations and notice where required.</p>

<h2>29. International processing</h2>
<p>MORT and approved providers may process information in the United States and other places where they operate. Where required, MORT will use an appropriate transfer mechanism or lawful safeguard.</p>

<h2>30. Changes and contact</h2>
<p>MORT may update this Policy when products, providers, laws, safety practices, or data uses change. Material changes may receive in-app, email, or website notice and renewed consent or acceptance where required. A new policy page alone does not replace legally required consent for a materially new sensitive-data use.</p>
<p>Privacy contact: ${privacyEmail}. Support: ${supportEmail}.</p>
<p><b>Do not send passwords, authentication codes, Start/Finish PINs, full card numbers, bank passwords, Social Security numbers, unrequested identity documents, or suspected CSAM through ordinary support email.</b></p>
`;

const termsBody = `
<h2>1. Agreement and incorporated policies</h2>
<p>These Terms govern access to and use of the MORT mobile application, websites, marketplace, communications, verification, safety, subscription, payment, and related services. By creating or using an account or otherwise accepting these Terms, you agree to them and to incorporated policies presented by MORT, including the Privacy Policy, Community Guidelines, Teen Safety rules, Parent/Guardian notices, prohibited-job rules, and payment/dispute rules where applicable.</p>

<h2>2. What MORT is</h2>
<p>MORT is a local opportunity and work marketplace designed primarily to help eligible teenagers discover and participate in appropriate nearby opportunities while giving eligible adults and businesses tools to post work. Features may include listings, applications, scheduling, messaging, age or identity verification, school verification, business verification, safety check-ins, Guardian Mode, approximate location, Start/Finish PINs, evidence, ratings, disputes, XP, ranks, badges, leaderboards, subscriptions, notifications, advertising, and payment-related services.</p>
<p>Not every feature is available to every user, age group, role, jurisdiction, platform, or release.</p>

<h2>3. Minimum age and teen eligibility</h2>
<p>You must generally be at least 13 to hold an ordinary MORT account. A Teen User is generally an eligible user ages 13–17. Account age eligibility does not mean a Teen User is legally eligible for every paid job. Job access may be restricted by age, location, law, school schedule, guardian requirements, verification status, account standing, job category, safety classification, and other requirements.</p>

<h2>4. Parent and guardian involvement</h2>
<p>MORT may require parent or guardian notice, linking, authorization, confirmation, or approval for specified teen activities where required by law, policy, risk level, or product configuration. A Teen User may not impersonate a guardian or falsify guardian information. Guardian access is limited to the information disclosed by the feature and does not automatically grant unrestricted access to all private messages.</p>

<h2>5. Adult and business responsibilities</h2>
<p>Adults interacting with Teen Users have heightened responsibilities. Adults and businesses must use accurate identities and authority, accurately describe work, disclose relevant hazards and expected people, provide lawful and age-appropriate work, respect teen privacy, communicate through permitted channels, and comply with applicable youth-employment, wage, supervision, safety, tax, insurance, nondiscrimination, permit, and recordkeeping requirements.</p>
<p>A MORT eligibility result or verification badge is not legal clearance to employ or engage a minor.</p>

<h2>6. Account security and verification</h2>
<p>Users must provide accurate information, protect credentials, and promptly report suspected compromise. Users may not falsify age, guardian status, business authority, verification data, or identity. MORT may require government ID, school ID, school email, age assurance, guardian verification, business verification, or other checks. A verified indicator means only that specified checks were completed; it is not a guarantee of safety, trustworthiness, solvency, criminal-history status, legal eligibility, or performance.</p>

<h2>7. Marketplace and job rules</h2>
<p>Job posters must accurately state the work, category, general location, schedule, estimated duration, compensation, skills, equipment, known hazards, people expected to be present, supervision, completion expectations, and lawful cancellation terms. A material job change after acceptance requires the Teen User's agreement and may require renewed safety or guardian approval. Teen Users may refuse unexpected work.</p>

<h2>8. Youth-employment compliance</h2>
<p>All participants must comply with applicable federal, state, and local rules governing minors and work, including age, hours, school-day restrictions, permitted occupations, hazardous work, equipment, supervision, wage, payroll, tax, permit, and recordkeeping rules. MORT may impose stricter restrictions for safety. A job appearing in MORT does not establish that the job is lawful for every Teen User.</p>

<h2>9. Prohibited work</h2>
<p>Without express authorization and legal review, MORT prohibits sexual or adult services, pornography, escort activity, alcohol, tobacco, vaping or nicotine products, illegal drugs, controlled substances outside lawful contexts, weapons, explosives, gambling, transporting unknown packages, driving jobs for Teen Users, dangerous construction, demolition, roofing, mining, prohibited machinery, dangerous cutting equipment, hazardous chemicals, unsafe heights, isolated locked-room work, jobs designed to evade labor law, exploitation, illegal activity, deceptive work, or tasks requiring unnecessary disclosure of sensitive teen information. See <a href="/prohibited-jobs/">Prohibited Jobs</a> for additional rules.</p>

<h2>10. Safety comes before completion</h2>
<p>No user is required by MORT to continue a job the user reasonably believes is unsafe. A Teen User may leave or use a safety-exit feature. Safety-related cancellations should not automatically be treated as misconduct, though MORT may review what occurred. MORT is not an emergency service and its safety technology can fail or be delayed.</p>

<h2>11. Location and meetings</h2>
<p>Public job listings should use approximate location rather than a private residential address or precise coordinates. Exact job location may be released only at an appropriate authorized stage. Users may not attempt to obtain hidden location information through technical or social-engineering methods. Unexpected changes involving address, people present, transportation, private areas, schedule, equipment, or scope may justify delaying, declining, canceling, or reporting a job.</p>

<h2>12. Messaging and off-platform contact</h2>
<p>MORT messaging may be monitored by automated and human safety systems. Users may not sexually communicate with a minor, groom or exploit a minor, request intimate images, threaten, harass, extort, scam, solicit illegal activity, request passwords or unnecessary sensitive information, pressure Teen Users into secrecy, manipulate users into unsafe meetings, evade safety controls, or engage in discriminatory abuse.</p>
<p>MORT may restrict adult attempts to move conversations with Teen Users to private texting, Snapchat, Instagram, Discord, WhatsApp, Telegram, private email, or other channels when doing so would bypass MORT safety controls.</p>

<h2>13. Job status, PINs, and evidence</h2>
<p>A job may move through Applied, Accepted, Scheduled, In Progress, Completed, Paid, canceled, safety-hold, dispute, review, or appeal states. Start and Finish PINs document stage actions but are not identity, safety, quality, legal-compliance, or payment guarantees. Users may submit relevant evidence for job, safety, or dispute review and may not fabricate, manipulate, or unnecessarily expose private material.</p>

<h2>14. Payments and compensation</h2>
<p>MORT may operate different payment modes depending on release, provider readiness, and jurisdiction. Compensation, fees, and provider terms should be displayed before commitment. Unless a checkout screen expressly states that MORT or an identified provider is processing a payment, MORT does not represent that it holds the funds. Provider terms, chargeback rules, payout requirements, tax requirements, and verification requirements may apply when live payments are enabled.</p>

<h2>15. Payment disputes and cancellations</h2>
<p>MORT may review job records, messages, timestamps, PIN events, safety events, evidence, reports, and payment records when resolving a platform dispute. MORT's internal decision is a platform-contract decision, not a court judgment, criminal finding, legal representation, or definitive employment-law classification. Cancellation consequences may depend on timing, work completed, safety concerns, participant conduct, provider rules, and applicable law.</p>

<h2>16. Digital subscriptions</h2>
<p>MORT may offer optional Plus, Pro, or other plans. Price, billing period, included features, renewal, trial terms, and cancellation methods must be shown before purchase. Automatically renewing subscriptions continue until canceled according to the purchase terms and applicable platform rules. App-store purchases may be governed by Apple, Google, or another authorized platform.</p>

<h2>17. Ratings, progression, and leaderboards</h2>
<p>Ratings must reflect genuine marketplace experiences and may not be purchased, fabricated, coordinated, or used for retaliation. XP, levels, ranks, badges, safety streaks, Motion Tokens, goals, and cosmetic unlocks are digital experience features and, unless expressly stated otherwise, have no cash value, are not currency, and do not guarantee jobs or earnings. Teen leaderboard participation should be optional where required by the feature design.</p>

<h2>18. User content</h2>
<p>Users retain ownership of content they lawfully own. By submitting content, users grant MORT a limited, non-exclusive license to host, store, reproduce, process, display, and use that content as reasonably necessary to operate features, moderate content, investigate safety issues, resolve disputes, prevent fraud, enforce policies, and comply with law. Users may not upload illegal material, child sexual abuse material, nonconsensual intimate imagery, malware, fraudulent evidence, or content that infringes another person's rights.</p>

<h2>19. Moderation and enforcement</h2>
<p>MORT may reject or remove listings, block communications, restrict features, pause jobs, place accounts under review, suspend or ban accounts, remove verification indicators, disable leaderboard participation, preserve relevant evidence, and investigate suspected fraud or abuse. Immediate restrictions may occur before a full investigation when reasonably necessary for safety or security. Appeals may be available but do not automatically restore access.</p>

<h2>20. MORT's role and no guarantees</h2>
<p>MORT provides technology to help users connect, communicate, coordinate, and use safety and marketplace tools. These Terms do not determine the legal classification of a particular work relationship. MORT does not guarantee job availability, applicants, acceptance, completion, payment, income, work quality, ratings, continued access, user honesty, or safety. Verification, moderation, ratings, check-ins, guardian tools, and location controls reduce risk but cannot eliminate it.</p>

<h2>21. Taxes, insurance, and transportation</h2>
<p>Users and businesses are responsible for determining their own tax, insurance, permit, payroll, wage, transportation, and other legal obligations. Unless MORT expressly states otherwise, MORT does not automatically provide workers' compensation, health, automobile, property, general-liability, or professional-liability insurance.</p>

<h2>22. Third-party services and service availability</h2>
<p>MORT may rely on providers for authentication, hosting, verification, notifications, analytics, crash reporting, payments, app-store billing, maps, and other functions. Third parties have their own terms and privacy policies. MORT may modify, suspend, test, or discontinue features and does not guarantee uninterrupted operation.</p>

<h2>23. Disclaimers</h2>
<p>To the maximum extent permitted by law, MORT is provided on an “as available” and “as is” basis. MORT does not promise that every user is safe, every listing is accurate, every verification is perfect, every job is lawful, every participant performs as promised, every dispute can be resolved, every safety message arrives, or every feature always works. Nonwaivable warranties and rights remain protected.</p>

<h2>24. Limitation of liability</h2>
<p>To the maximum extent permitted by applicable law, MORT and its lawful operators, personnel, affiliates, and service providers are not liable for indirect, incidental, special, consequential, exemplary, or punitive damages arising from the service where such limitation is legally permitted. Any final aggregate monetary liability cap must be approved by qualified counsel after MORT's legal entity, insurance, payment structure, marketplace structure, and launch jurisdictions are finalized. Nothing limits liability where applicable law prohibits limitation.</p>

<h2>25. Adult and business indemnification</h2>
<p>To the maximum extent permitted by law, Adult and Business Users agree to defend, indemnify, and hold harmless MORT and its lawful operators, officers, employees, agents, affiliates, successors, and service providers from third-party claims arising from that user's unlawful job posting, child-labor or wage violations, unsafe workplace, undisclosed hazard, fraud, intentional misconduct, policy breach, infringing content, or misuse of another person's information. MORT does not rely on broad minor indemnification as its primary risk-management mechanism.</p>

<h2>26. Dispute resolution</h2>
<p>U.S. users are subject to the separate <a href="/dispute-resolution/">MORT Dispute Resolution and Arbitration Agreement</a>, which includes a mandatory informal dispute process and, for covered claims where enforceable, binding individual arbitration, a class-action waiver, and a jury-trial waiver. Exceptions and nonwaivable rights apply. The arbitration language is intentionally separate from this Privacy Policy.</p>

<h2>27. Termination and survival</h2>
<p>Users may request account deletion through available controls. MORT may suspend or terminate accounts for serious safety threats, grooming, exploitation, fraud, scams, identity manipulation, harassment, prohibited jobs, payment abuse, ban evasion, falsified evidence, or other serious violations. Dispute, payment, evidence-preservation, intellectual-property, indemnification, and other provisions that by their nature should survive may remain effective after account termination to the extent permitted by law.</p>

<h2>28. Changes</h2>
<p>MORT may revise these Terms as the product, law, providers, and safety practices change. Material changes should receive a new version, effective date, appropriate notice, and renewed acceptance where required. Continued use cannot waive rights that applicable law makes nonwaivable.</p>

<h2>29. Contact</h2>
<p>Support: ${supportEmail}. Legal operator and mailing address will be displayed once finalized for broader public marketplace activation.</p>
`;

const disputeBody = `
<h2>Important notice</h2>
<p><b>Except for the exceptions below and to the maximum extent permitted by law, covered U.S. disputes between a user and MORT must first go through mandatory informal dispute resolution and, if unresolved, binding individual arbitration rather than a court trial. Covered claims may be brought only on an individual basis, not as a class, collective, consolidated, representative, or private-attorney-general action where that waiver is enforceable. Arbitration has different procedures, including more limited discovery and appellate review. Nothing here eliminates rights that applicable law does not permit a user to waive.</b></p>

<h2>1. Covered disputes</h2>
<p>“Dispute” is intended to be interpreted broadly and includes, to the maximum extent permitted by law, past, present, or future claims arising from or relating to MORT, these Terms, an account, marketplace activity, moderation, verification, privacy, security, communications, payments, subscriptions, safety tools, content, suspension, deletion, or the relationship between a user and MORT, whether based in contract, tort, statute, regulation, common law, equity, negligence, misrepresentation, consumer law, privacy law, or another legal theory.</p>

<h2>2. Minors and guardian consent</h2>
<p>MORT may require a Teen User's parent or legal guardian to separately review and accept the Terms and this Agreement before specified marketplace functionality is enabled. Where legally permitted, the guardian agrees on the guardian's own behalf and consents to the minor's use. Nothing claims to bind a minor where applicable law makes the agreement unenforceable; unenforceability as to a minor does not automatically invalidate an otherwise enforceable agreement with an adult, guardian, business, or other contracting party.</p>

<h2>3. Mandatory informal dispute resolution</h2>
<p>Before starting arbitration or covered litigation, a claimant must send MORT a written Notice of Dispute containing the claimant's full legal name, MORT username, account email, mailing address, applicable guardian information, detailed description, relevant dates, support case number if any, alleged harm, requested relief, and signature or authorized representative signature.</p>
<p>Notice should be sent to the legal address MORT designates in its current Terms and may also be sent to ${supportEmail} when electronic notice is enabled. The parties will then attempt in good faith to resolve the matter for 60 days. Either side may request a telephone or video settlement conference. Applicable limitation periods are tolled during this process to the extent required by law.</p>

<h2>4. Settlement confidentiality</h2>
<p>To the maximum extent permitted by law, settlement offers, compromise proposals, and statements made solely for settlement are confidential and subject to applicable evidentiary protections. Evidence otherwise discoverable does not become undiscoverable merely because it was referenced during settlement.</p>

<h2>5. Binding individual arbitration</h2>
<p>If a covered dispute remains unresolved after the informal process, it will be resolved by binding individual arbitration rather than litigation in court, subject to the exceptions below. Arbitration will be administered by the American Arbitration Association under the rules it determines apply, generally including its Consumer Arbitration Rules for qualifying consumer disputes and other rule sets where legally required.</p>

<h2>6. Federal Arbitration Act</h2>
<p>To the maximum extent permitted by law, this Arbitration Agreement involves interstate commerce and is governed by the Federal Arbitration Act, 9 U.S.C. § 1 et seq.</p>

<h2>7. No judge or jury</h2>
<p>Arbitration is conducted before a neutral arbitrator rather than a judge or jury, and court review of an award is limited. The arbitrator may award individualized relief authorized by applicable law.</p>

<h2>8. Individual relief and class-action waiver</h2>
<p><b>TO THE MAXIMUM EXTENT PERMITTED BY LAW, USER AND MORT EACH WAIVE THE RIGHT TO BRING, JOIN, PARTICIPATE IN, OR RECEIVE RELIEF THROUGH A CLASS ACTION, CLASS ARBITRATION, COLLECTIVE ACTION, CONSOLIDATED ACTION, REPRESENTATIVE ACTION, OR PRIVATE-ATTORNEY-GENERAL ACTION AGAINST THE OTHER.</b></p>
<p>Claims must proceed individually unless applicable law makes that limitation unenforceable for a particular claim or remedy. Applicable mass-arbitration procedures may govern coordinated individual filings when their requirements are satisfied.</p>

<h2>9. Jury-trial waiver</h2>
<p><b>TO THE MAXIMUM EXTENT PERMITTED BY LAW, FOR ANY COVERED DISPUTE THAT IS PERMITTED TO PROCEED IN COURT, USER AND MORT EACH KNOWINGLY AND VOLUNTARILY WAIVE THE RIGHT TO TRIAL BY JURY.</b></p>

<h2>10. Confidentiality</h2>
<p>To the maximum extent permitted by law and applicable arbitration rules, arbitration is non-public. Arbitration submissions, discovery exchanged solely for arbitration, non-public exhibits, hearing testimony, settlement information, and awards should be treated as confidential except as reasonably necessary for the proceeding, counsel, guardians, experts, witnesses, insurers, auditors, regulators, law enforcement, legal compliance, safety, or court confirmation/enforcement of an award.</p>

<h2>11. Location, format, fees, and attorneys' fees</h2>
<p>Where permitted, arbitration may occur by documents, phone, or video. Any in-person hearing will occur at a location permitted by applicable rules and consumer-protection law. Fees are allocated according to applicable law, AAA rules, and the applicable fee schedule. MORT will pay fees it is legally or contractually required to pay. Each side ordinarily bears its own attorneys' fees except where law, rules, or an arbitrator authorize otherwise.</p>

<h2>12. Small claims</h2>
<p>Either party may pursue an individual qualifying claim in a legally authorized small-claims court if the case remains within that court's jurisdiction and remains individual.</p>

<h2>13. Emergency, safety, and intellectual-property relief</h2>
<p>Nothing prevents a party from seeking legally permitted temporary or emergency individualized court relief necessary to address imminent physical harm, child exploitation, unauthorized disclosure of highly sensitive information, serious cybersecurity harm, destruction of evidence, or irreparable intellectual-property harm. Qualifying intellectual-property claims may also proceed in court where law or this Agreement permits.</p>

<h2>14. Government agencies and nonwaivable rights</h2>
<p>This Agreement does not prevent reporting suspected unlawful conduct, filing a government complaint, cooperating with regulators or law enforcement, or participating in a government investigation. It does not waive statutory government-enforcement authority, protected whistleblower rights, legally nonwaivable claims, or any right applicable law prohibits parties from waiving.</p>

<h2>15. Arbitration opt-out</h2>
<p>A new user may opt out of the Arbitration Agreement within 30 days after first accepting it, unless a longer period is required by law, without losing MORT access solely because of that choice. A legally authorized parent or guardian may submit an opt-out for a minor where applicable. The notice must include the user's full name, MORT username, account email, a clear statement opting out, and the user's or authorized guardian's signature. The final production Terms will designate the legal mailing address and may permit electronic opt-out.</p>

<h2>16. Changes and severability</h2>
<p>If MORT materially changes this Arbitration Agreement, MORT may provide renewed notice and any legally required new opt-out opportunity. If a provision is unenforceable, it will be limited or severed to the minimum extent permitted while the remaining enforceable provisions continue. If a particular claim cannot lawfully be arbitrated, that claim may be severed while other covered claims remain subject to arbitration where enforceable.</p>

<h2>17. Survival</h2>
<p>Dispute-resolution, arbitration, class-waiver, jury-waiver, confidentiality, applicable indemnification, limitation-of-liability, intellectual-property, payment, evidence-preservation, and other provisions that by their nature should survive account termination will survive to the extent permitted by law.</p>

<h2>18. Emergency services</h2>
<p>Nothing in this Agreement prevents any person from calling 911, police, emergency medical services, child-protection authorities, or other emergency resources. MORT's dispute procedures are never a substitute for emergency assistance.</p>
`;

const pages = {
  'index.html': page({
    route: '/',
    title: 'Legal and safety center',
    description: 'Public privacy, terms, dispute resolution, safety, support, accessibility, and account-control information for MORT.',
    body: `<section class="sec"><h2>The written record</h2><p>MORT is a 13+ local-work marketplace and safety platform. These public pages explain MORT's current privacy, account, safety, marketplace, and dispute rules. Marketplace access remains subject to server-approved eligibility and feature-specific requirements.</p><p><b>Legal status:</b> the current public package remains a draft pending qualified legal review. Publication does not mean a lawyer has approved every provision.</p></section><div class="hubgrid">${routes.slice(1).map(([href, label]) => `<a class="glass hubcard" href="${href}"><h3>${label}</h3><p>${routeSummaries[href]}</p><span class="arw">Read &rarr;</span></a>`).join('')}</div>`,
  }),
  'privacy/index.html': page({
    route: '/privacy/',
    title: 'Privacy policy',
    description: 'How MORT collects, uses, shares, protects, retains, and deletes information, with heightened teen protections.',
    body: privacyBody,
  }),
  'terms/index.html': page({
    route: '/terms/',
    title: 'Terms of Service',
    description: 'Comprehensive rules governing MORT accounts, marketplace activity, teen safety, payments, subscriptions, content, and enforcement.',
    body: termsBody,
  }),
  'dispute-resolution/index.html': page({
    route: '/dispute-resolution/',
    title: 'Dispute resolution & arbitration',
    description: 'Informal dispute resolution, individual arbitration, class-action waiver, jury waiver, exceptions, and opt-out terms.',
    body: disputeBody,
  }),
  'terms-of-use/index.html': page({
    route: '/terms-of-use/',
    title: 'Terms of use',
    description: 'Plain-language rules for using MORT accounts, jobs, messages, and safety tools.',
    body: `<h2>Use MORT lawfully</h2><p>Use MORT only for lawful, age-appropriate, job-related activity. Do not impersonate others, falsify age or authority, evade blocks or bans, scrape participant data, expose private addresses, pressure Teen Users off-platform, manipulate ratings, falsify evidence, or misuse reporting tools.</p><h2>Messaging</h2><p>Messaging is job-contextual and subject to eligibility, restrictions, rate limits, automated safety checks, and human review. No sexual content involving minors, grooming, threats, scams, harassment, coercion, private-photo requests, unsafe meeting pressure, or attempts to defeat MORT safety controls.</p><h2>Safety</h2><p>Follow job, location, check-in, Guardian Mode, PIN, report, and Safety Exit rules. MORT is not an emergency service and does not guarantee that automated detection or notifications will always work.</p><h2>Legal terms</h2><p>The full <a href="/terms/">Terms of Service</a>, <a href="/privacy/">Privacy Policy</a>, and <a href="/dispute-resolution/">Dispute Resolution &amp; Arbitration Agreement</a> govern where applicable.</p>`,
  }),
  'community-guidelines/index.html': page({
    route: '/community-guidelines/',
    title: 'Community guidelines',
    description: 'Behavior and content standards for MORT participants and organizations.',
    body: `<h2>Be job-focused</h2><p>Keep posts and conversations relevant to a legitimate work opportunity. Use accurate scope, schedule, supervision, location type, and payment information.</p><h2>Protect minors</h2><p>No grooming, romantic or sexual adult-minor interaction, sexual solicitation, trafficking, sexual images, private minor directory, anonymous chat, or retaliation for reports.</p><h2>Respect boundaries</h2><p>No harassment, hate, discrimination, threats, doxxing, fraud, spam, block evasion, coercion, unsafe off-platform pressure, deceptive verification, or manipulation of evidence or ratings.</p><h2>Report concerns</h2><p>Use report and block controls. Do not place private incident evidence in ordinary messages. Contact local emergency services for immediate danger.</p>`,
  }),
  'safety/index.html': page({
    route: '/safety/',
    title: 'Safety center',
    description: 'Reporting, blocking, job-context, and real-world safety guidance for MORT.',
    body: `<h2>Immediate danger</h2><p>MORT is not an emergency service and is not continuously monitored. Leave an unsafe situation and contact local emergency services.</p><h2>Before work</h2><ul><li>Review scope, people present, location type, transportation, tools, and compensation.</li><li>Use general areas until an authorized location stage and never post a home address publicly.</li><li>Decline work that is sexual, isolated, illegal, dangerous, deceptive, or materially different from the listing.</li></ul><h2>During work</h2><p>Use check-ins, job-context messages, Guardian or trusted-contact features where configured, Start/Finish controls, and Safety Exit. Safety notifications can fail or be delayed and do not replace emergency services.</p><h2>Contact</h2><p>Child-safety contact: ${childSafetyEmail}</p>`,
  }),
  'child-safety-standards/index.html': page({
    route: '/child-safety-standards/',
    title: 'Child safety standards',
    description: 'MORT standards against child sexual abuse, exploitation, grooming, trafficking, and solicitation.',
    body: `<h2>Zero tolerance</h2><p>MORT prohibits CSAM, child sexual abuse and exploitation, grooming, sextortion, trafficking, sexual solicitation, sexual jobs, romantic or sexual adult-minor interaction, requests for sexual images, sexual off-platform pressure, and evasion after blocking.</p><h2>Reporting and enforcement</h2><p>Users can report supported profiles, jobs, messages, and conduct and can block accounts. MORT may block content, restrict accounts, preserve narrow lawful evidence, prevent contact, and escalate serious matters to trained adults or lawful authorities.</p><h2>Evidence boundaries</h2><p>Never ask a child to resend sexual material. Do not email, download, forward, or place suspected CSAM in ordinary tickets. Authorized adults follow applicable reporting and preservation law.</p><h2>Child-safety contact</h2><p>${childSafetyEmail}</p><p>MORT is not an emergency service.</p>`,
  }),
  'prohibited-jobs/index.html': page({
    route: '/prohibited-jobs/',
    title: 'Prohibited jobs',
    description: 'Work categories and conditions that are not allowed in MORT.',
    body: `<h2>Always prohibited or restricted</h2><ul><li>Sexual, romantic, escort, pornography, exploitative, or trafficking-related services.</li><li>Illegal activity, weapons, explosives, controlled substances, age-restricted goods, gambling, fraud, theft, or surveillance abuse.</li><li>Dangerous construction, demolition, roofing, heavy machinery, prohibited power equipment, hazardous chemicals, driving jobs for Teen Users, or other unlawful youth work.</li><li>Secret or isolated locations designed to bypass safety controls, locked private-room work, requests to hide the job, or unnecessary exposure of private teen information.</li><li>Deceptive compensation, requests for money or gift cards, banking credentials, passwords, or account access.</li></ul><h2>Review</h2><p>Jobs may be rejected, paused, or removed. Account eligibility never overrides labor, licensing, wage, safety, or supervision law.</p>`,
  }),
  'payment-disputes/index.html': page({
    route: '/payment-disputes/',
    title: 'Payment disputes',
    description: 'How MORT handles payment status, evidence, cancellations, and marketplace disagreements.',
    body: `<h2>Payment mode matters</h2><p>MORT may track compensation and payment status and, where enabled, may use an approved payment provider. The checkout screen and provider terms determine whether MORT or a provider is processing a particular payment. MORT is not a bank and does not ask users to send full card or bank credentials through ordinary messages.</p><h2>Disagreement workflow</h2><p>Participants may dispute completion, cancellation, payment, scope changes, or related issues. MORT may review job-context records, messages, timestamps, PIN events, safety events, reports, evidence, and provider records. Anti-retaliation controls may apply.</p><h2>Decision limits</h2><p>MORT's internal decision is a platform decision, not a court judgment, criminal finding, legal representation, or definitive employment-law classification. Outside legal, labor-agency, payment-provider, or court remedies may still exist.</p>`,
  }),
  'support/index.html': page({
    route: '/support/',
    title: 'Support',
    description: 'Account, privacy, and safety support routes for MORT users and reviewers.',
    body: `<h2>Account-linked help</h2><p>Signed-in users should use the in-app Support Center when available so requests carry authorized account context.</p><h2>Other routes</h2><p>Delete an account through <a href="/account-deletion/">account deletion</a>. Review safety guidance in the <a href="/safety/">Safety Center</a>. For urgent danger, contact local emergency services.</p><h2>Support contact</h2><p>${supportEmail}</p>`,
  }),
  'contact/index.html': page({
    route: '/contact/',
    title: 'Contact',
    description: 'Public contact points for MORT support, privacy, and child safety.',
    body: `<h2>Publisher</h2><p>${publisher}</p><h2>Support</h2><p>${supportEmail}</p><h2>Privacy</h2><p>${privacyEmail}</p><h2>Child safety</h2><p>${childSafetyEmail}</p><p>Do not send suspected CSAM, passwords, PINs, full financial credentials, or unrequested identity documents by ordinary email. Contact emergency services for immediate danger.</p>`,
  }),
  'accessibility/index.html': page({
    route: '/accessibility/',
    title: 'Accessibility',
    description: 'Accessibility commitments, supported controls, and feedback for MORT.',
    body: `<h2>Products covered</h2><p>This statement covers MORT public web pages and the MORT mobile applications.</p><h2>Design goals</h2><p>MORT is designed for screen readers, scalable text, keyboard navigation on web, visible focus, dark mode, reduced motion, descriptive labels, and permission-denial alternatives. MORT does not claim a specific WCAG conformance level unless and until that level has been verified.</p><h2>Feedback</h2><p>Report accessibility barriers to ${supportEmail}. Include the platform, device, OS, page or screen, assistive technology if any, and what you expected, without sending passwords or sensitive evidence.</p>`,
  }),
};

const deletionBody = `<section class="sec"><h2>What happens</h2><p>After ownership verification, MORT creates an auditable request to remove the account and ordinary profile data. Narrow safety, fraud, dispute, security, evidence-preservation, payment, contractual, and legal records may be retained with restricted access when legitimately necessary.</p></section><section id="request-panel" class="glass form-panel"><h2>1. Verify account ownership</h2><form id="deletion-link-form" novalidate><div class="field"><label for="email">Account email</label><input id="email" name="email" type="email" autocomplete="email" required></div><button class="btn" type="submit">Send private sign-in link</button></form><p id="link-result" class="result" role="status" aria-live="polite"></p></section><section id="confirmed-panel" class="glass form-panel" hidden><h2>2. Submit deletion request</h2><p>You are signed in for this request. MORT will not require a support conversation first.</p><button id="submit-deletion" class="btn" type="button">Request account deletion</button><button id="sign-out" class="btn secondary" type="button">Sign out</button><p id="deletion-result" class="result" role="status" aria-live="polite"></p></section><section class="sec"><h2>Use the app</h2><p>Open Settings, Account, then Delete account. Reinstallation is not required.</p></section><section class="sec"><h2>Privacy</h2><p>The email-link form always gives a generic public response and does not reveal whether an account exists.</p></section>`;
pages['account-deletion/index.html'] = page({
  route: '/account-deletion/',
  title: 'Delete your MORT account',
  description: 'Request account deletion without reinstalling the app.',
  body: deletionBody,
  scripts: '<script src="/assets/supabase.js"></script><script src="/assets/public-config.js"></script><script src="/assets/account-deletion.js"></script>',
});

for (const [relative, content] of Object.entries(pages)) write(relative, content);
write('assets/supabase.js', readFileSync(supabaseBrowserBundle, 'utf8'));
write(
  'assets/public-config.js',
  `window.MORT_PUBLIC_CONFIG = Object.freeze(${JSON.stringify({
    supabaseUrl: supabase.url,
    supabaseAnonKey: supabase.key,
  })});`,
);
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
    } finally {
      result.textContent = 'If that email can receive a MORT sign-in link, check its inbox. This page never confirms whether an account exists.';
      form.reset();
      form.querySelector('button').disabled = false;
    }
  });
  submit.addEventListener('click', async () => {
    submit.disabled = true;
    deletionResult.textContent = 'Submitting your verified request...';
    const { data, error } = await client.rpc('request_account_deletion', { p_source: 'web' });
    deletionResult.textContent = !error && data?.ok === true
      ? 'Deletion request submitted. Current status: ' + data.request.status.replaceAll('_', ' ') + '.'
      : data?.code === 'recent_reauthentication_required'
        ? 'The private link expired. Sign out and request a new link.'
        : 'The request could not be submitted. Try again later or use the in-app deletion control.';
    submit.disabled = false;
  });
  signOut.addEventListener('click', async () => { await client.auth.signOut(); await showSession(); });
  client.auth.onAuthStateChange(() => { void showSession(); });
  void showSession();
}
`);

write(
  'release-status.json',
  JSON.stringify(
    {
      generatedAt: new Date().toISOString(),
      projectRef: 'rakjydmgwwgtdislanbt',
      packageStatus: 'built',
      deploymentReady,
      missingConfiguration: missingConfig,
      requiredRoutes: routes.map(([route]) => route),
      legalApprovalClaimed: false,
      publicDeploymentClaimed: true,
      legalPackageRevision: '2026-10-08-protective-terms-privacy-arbitration',
    },
    null,
    2,
  ),
);
write('_headers', `
/*
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: no-referrer
  Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()
  Content-Security-Policy: default-src 'self'; script-src 'self'; connect-src 'self' https://rakjydmgwwgtdislanbt.supabase.co; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data:; font-src 'self' data: https://fonts.gstatic.com; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'; worker-src 'none'; upgrade-insecure-requests
`);
write('_redirects', '/* /index.html 404');
write('app-ads.txt', 'google.com, pub-9883419411387958, DIRECT, f08c47fec0942fa0');
write(
  '../netlify.toml',
  `[build]\n  publish = "public"\n  command = "node ../scripts/build-public-legal-site.mjs"\n`,
);
write(
  'vercel.json',
  JSON.stringify(
    {
      headers: [
        {
          source: '/(.*)',
          headers: [
            { key: 'X-Content-Type-Options', value: 'nosniff' },
            { key: 'X-Frame-Options', value: 'DENY' },
            { key: 'Referrer-Policy', value: 'no-referrer' },
            { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), payment=()' },
            {
              key: 'Content-Security-Policy',
              value: "default-src 'self'; script-src 'self'; connect-src 'self' https://rakjydmgwwgtdislanbt.supabase.co; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data:; font-src 'self' data: https://fonts.gstatic.com; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'; worker-src 'none'; upgrade-insecure-requests",
            },
          ],
        },
      ],
    },
    null,
    2,
  ),
);

process.stdout.write(
  `Built MORT public legal/support package with ${routes.length} routes. Deployment ready: ${deploymentReady}.\n`,
);
