import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const output = resolve(root, 'web', 'public');
const legalTheme = resolve(root, 'web', 'legal-theme');
const legalSourceDir = resolve(root, 'docs', 'legal', 'source-of-truth');
const supabaseBrowserBundle = resolve(root, 'node_modules', '@supabase', 'supabase-js', 'dist', 'umd', 'supabase.js');
const REVISION = '2026-10-28-counsel-approved-core-docs-v3';

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
function markdownInline(value) {
  let html = escapeHtml(value);
  html = html.replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');
  html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  html = html.replace(/(^|[^*])\*([^*\n]+)\*(?!\*)/g, '$1<em>$2</em>');
  return html;
}

function markdownTableCells(line) {
  return line.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((cell) => cell.trim());
}

function markdownTableDivider(line) {
  const cells = markdownTableCells(line);
  return cells.length > 1 && cells.every((cell) => /^:?-{3,}:?$/.test(cell));
}

function markdownBlockStart(line, next = '') {
  return /^#{1,6}\s/.test(line)
    || /^\s*```/.test(line)
    || /^\s*[-*]\s+/.test(line)
    || /^\s*\d+\.\s+/.test(line)
    || /^\s*>/.test(line)
    || /^\s*(---|___|\*\*\*)\s*$/.test(line)
    || (line.includes('|') && markdownTableDivider(next));
}

function renderLegalMarkdown(markdown) {
  const lines = markdown.replace(/\r\n/g, '\n').replace(/^# [^\n]*\n/, '').split('\n');
  const output = [];
  let index = 0;
  while (index < lines.length) {
    const line = lines[index];
    if (!line.trim()) { index++; continue; }
    const heading = line.match(/^(#{1,6})\s+(.+)$/);
    if (heading) {
      const level = heading[1].length;
      output.push(`<h${level}>${markdownInline(heading[2])}</h${level}>`);
      index++;
      continue;
    }
    if (/^\s*```/.test(line)) {
      index++;
      const code = [];
      while (index < lines.length && !/^\s*```/.test(lines[index])) code.push(lines[index++]);
      if (index < lines.length) index++;
      output.push(`<pre><code>${escapeHtml(code.join('\n'))}</code></pre>`);
      continue;
    }
    if (index + 1 < lines.length && line.includes('|') && markdownTableDivider(lines[index + 1])) {
      const headers = markdownTableCells(line);
      index += 2;
      const rows = [];
      while (index < lines.length && lines[index].includes('|') && lines[index].trim()) rows.push(markdownTableCells(lines[index++]));
      const head = headers.map((cell) => `<th scope="col">${markdownInline(cell)}</th>`).join('');
      const body = rows.map((row) => `<tr>${headers.map((_, column) => `<td>${markdownInline(row[column] || '')}</td>`).join('')}</tr>`).join('');
      output.push(`<div class="legal-table-scroll"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`);
      continue;
    }
    if (/^\s*(---|___|\*\*\*)\s*$/.test(line)) { output.push('<hr>'); index++; continue; }
    if (/^\s*>/.test(line)) {
      const quote = [];
      while (index < lines.length && /^\s*>/.test(lines[index])) quote.push(lines[index++].replace(/^\s*>\s?/, ''));
      output.push(`<blockquote>${quote.map((part) => `<p>${markdownInline(part)}</p>`).join('')}</blockquote>`);
      continue;
    }
    if (/^\s*[-*]\s+/.test(line)) {
      const items = [];
      while (index < lines.length && /^\s*[-*]\s+/.test(lines[index])) items.push(`<li>${markdownInline(lines[index++].replace(/^\s*[-*]\s+/, ''))}</li>`);
      output.push(`<ul>${items.join('')}</ul>`);
      continue;
    }
    if (/^\s*\d+\.\s+/.test(line)) {
      const items = [];
      while (index < lines.length && /^\s*\d+\.\s+/.test(lines[index])) items.push(`<li>${markdownInline(lines[index++].replace(/^\s*\d+\.\s+/, ''))}</li>`);
      output.push(`<ol>${items.join('')}</ol>`);
      continue;
    }
    const paragraph = [line];
    index++;
    while (index < lines.length && lines[index].trim() && !markdownBlockStart(lines[index], lines[index + 1] || '')) paragraph.push(lines[index++]);
    output.push(`<p>${paragraph.map((part) => markdownInline(part.trim())).join(' ')}</p>`);
  }
  return output.join('\n');
}

function approvedLegalSource(filename) {
  const path = resolve(legalSourceDir, filename);
  if (!existsSync(path)) throw new Error(`Approved legal source is missing: ${filename}`);
  return renderLegalMarkdown(readFileSync(path, 'utf8'));
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

function page({ route, title, description, body, scripts = '', status = 'draft', version = '', documentEffectiveDate = '' }) {
  const statusLabel = status === 'published'
    ? `Counsel-approved · Version ${version} · Effective ${documentEffectiveDate} · United States`
    : status === 'mixed'
      ? 'Four core documents published · supplementary materials may remain under review'
      : 'Draft — pending qualified legal review';
  const statusClass = status === 'draft' ? 'draft' : 'status';
  const effectiveFooter = status === 'published' ? documentEffectiveDate : status === 'mixed' ? 'Core documents: October 2026' : effectiveDate;
  const footerNote = status === 'published'
    ? `Published counsel-approved version ${version}. This approval applies to this document version only; it does not mean every MORT feature is available or release-ready.`
    : status === 'mixed'
      ? 'The Master Terms, Privacy Policy, Safety Rules, and Community Guidelines are published. Other supplementary legal materials are separate and may require their own review.'
      : 'Draft — pending qualified legal review. This is public information, not legal advice.';
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="theme-color" content="#02040a"><meta name="description" content="${escapeHtml(description)}"><title>${escapeHtml(title)} | MORT</title><link rel="icon" href="/mort-mark.svg" type="image/svg+xml"><link rel="stylesheet" href="/assets/legal.css"></head>
<body><a class="skip" href="#content">Skip to content</a><canvas id="legal-sky" aria-hidden="true"></canvas><div class="veil" aria-hidden="true"></div>
<header class="topbar"><a class="brand" href="/"><img src="/mort-mark.svg" width="28" height="28" alt="">MORT <small>Legal &amp; safety</small></a><span class="sp"></span><span class="${statusClass}">${escapeHtml(statusLabel)}</span><a class="back" href="https://mortapp.org">&larr; Back to MORT</a></header>
<div class="wrap"><aside class="side"><div class="lbl">Legal &amp; safety</div><nav aria-label="Legal and support">${navFor(route)}</nav></aside><main id="content" class="content"><div class="eyebrow">MORT Legal &amp; Safety · United States</div><h1>${escapeHtml(title)}</h1><p class="tagline">${escapeHtml(description)}</p>${blocker}<div class="callout"><b>Important:</b> MORT is a 13+ local-work marketplace and safety platform. Feature and job eligibility can vary by age, role, jurisdiction, school status, verification state, account status, app version, and provider readiness. Verification and safety tools reduce risk but do not guarantee identity, safety, job quality, payment, or legal compliance.</div>${body}</main></div>
<footer class="foot"><div class="row"><span><b>MORT</b> &nbsp;·&nbsp; Publisher: ${publisher}</span><span>Support: ${supportEmail}</span><span>Effective: ${escapeHtml(effectiveFooter)}</span><span>Website: ${websiteUrl}</span></div><div class="row" style="margin-top:8px"><span>${escapeHtml(footerNote)} State-specific provisions and mandatory rights remain protected.</span></div></footer>${scripts}<script src="/assets/atmosphere.js"></script></body></html>`;
}

const termsBody = approvedLegalSource('MORT_Master_Terms_V3.md');

const privacyBody = approvedLegalSource('MORT_Privacy_Policy.md');
const safetyBody = approvedLegalSource('MORT_Safety_Rules.md');
const communityBody = approvedLegalSource('MORT_Community_Guidelines.md');

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
  'privacy/index.html': page({ route: '/privacy/', title: 'Privacy Policy', description: routeSummaries['/privacy/'], body: privacyBody, status: 'published', version: 'MORT-PRIVACY-2026-10', documentEffectiveDate: 'October 2026' }),
  'terms/index.html': page({ route: '/terms/', title: 'Master Terms of Service', description: 'Published Master Terms of Service, version MORT-LEGAL-2026-V3.', body: termsBody, status: 'published', version: 'MORT-LEGAL-2026-V3', documentEffectiveDate: 'October 2026' }),
  'dispute-resolution/index.html': page({ route: '/dispute-resolution/', title: 'Arbitration & Dispute Resolution', description: routeSummaries['/dispute-resolution/'], body: disputeBody }),
  'us-state-law-addendum/index.html': page({ route: '/us-state-law-addendum/', title: 'U.S. State Law Addendum', description: routeSummaries['/us-state-law-addendum/'], body: stateBody }),
  'guardian-terms/index.html': page({ route: '/guardian-terms/', title: 'Parent & Guardian Terms', description: routeSummaries['/guardian-terms/'], body: guardianBody }),
  'verification-privacy-notice/index.html': page({ route: '/verification-privacy-notice/', title: 'Verification Privacy Notice', description: routeSummaries['/verification-privacy-notice/'], body: verificationBody }),
  'paid-services/index.html': page({ route: '/paid-services/', title: 'Paid Services Terms', description: routeSummaries['/paid-services/'], body: paidBody }),
  'terms-of-use/index.html': page({ route: '/terms-of-use/', title: 'Master Terms of Service', description: 'Legacy URL for the published Master Terms of Service, version MORT-LEGAL-2026-V3.', body: termsBody, status: 'published', version: 'MORT-LEGAL-2026-V3', documentEffectiveDate: 'October 2026' }),
  'community-guidelines/index.html': page({ route: '/community-guidelines/', title: 'Community Guidelines', description: 'Published Community Guidelines, version MORT-COMMUNITY-2026-10.', body: communityBody, status: 'published', version: 'MORT-COMMUNITY-2026-10', documentEffectiveDate: 'October 2026' }),
  'safety/index.html': page({ route: '/safety/', title: 'Safety Rules', description: 'Published Safety Rules, version MORT-SAFETY-2026-10.', body: safetyBody, status: 'published', version: 'MORT-SAFETY-2026-10', documentEffectiveDate: 'October 2026' }),
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
pages['index.html'] = page({ route: '/', title: 'Legal and safety center', description: 'MORT legal, privacy, safety, verification, payments, state-law, guardian, and support information for the United States.', status: 'mixed', body: `<section class="glass"><h2>Core legal documents published · October 2026</h2><p>The Master Terms of Service (MORT-LEGAL-2026-V3), Privacy Policy (MORT-PRIVACY-2026-10), Safety Rules (MORT-SAFETY-2026-10), and Community Guidelines (MORT-COMMUNITY-2026-10) have been approved for operational implementation and deployment. Additional supplementary legal pages on this site are separate and may require their own review. Publication does not mean every marketplace feature is activated or release-ready.</p></section><div class="cards">${indexCards}</div>` });

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
  approvedDocuments: [
    { key: 'master_terms_of_service', version: 'MORT-LEGAL-2026-V3' },
    { key: 'privacy_policy', version: 'MORT-PRIVACY-2026-10' },
    { key: 'safety_rules', version: 'MORT-SAFETY-2026-10' },
    { key: 'community_guidelines', version: 'MORT-COMMUNITY-2026-10' },
  ],
  legalApprovalScope: 'Four core documents approved; supplementary legal pages are not included in that approval.',
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
