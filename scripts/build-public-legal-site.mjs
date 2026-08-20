import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const output = resolve(root, 'web', 'public');
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
const missingConfig = requiredConfigNames.filter((name) => !publicConfig[name]);
const deploymentReady = missingConfig.length === 0;

rmSync(output, { recursive: true, force: true });
if (!existsSync(supabaseBrowserBundle)) {
  throw new Error('The pinned local Supabase browser bundle is missing. Run pnpm install first.');
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
  let url = '';
  let key = '';
  try {
    for (const raw of readFileSync(envPath, 'utf8').split(/\r?\n/)) {
      const match = raw.match(/^\s*([^#=]+?)\s*=\s*(.*?)\s*$/);
      if (!match) continue;
      const name = match[1];
      const value = match[2].replace(/^['"]|['"]$/g, '');
      if (name === 'EXPO_PUBLIC_SUPABASE_URL') url = value;
      if (name === 'EXPO_PUBLIC_SUPABASE_ANON_KEY') key = value;
    }
  } catch {
    // Account deletion remains visibly unavailable until public config exists.
  }
  const expectedUrl = 'https://rakjydmgwwgtdislanbt.supabase.co';
  if (url && url !== expectedUrl) {
    throw new Error('Public legal site points to the wrong Supabase project.');
  }
  if (key) {
    try {
      const payload = JSON.parse(
        Buffer.from(key.split('.')[1], 'base64url').toString('utf8'),
      );
      if (payload.role !== 'anon') {
        throw new Error('Only the Supabase anon key may be published.');
      }
    } catch (error) {
      if (error instanceof SyntaxError) {
        throw new Error('The configured Supabase public key is not a valid JWT.');
      }
      throw error;
    }
  }
  return { url: url || expectedUrl, key };
}

const routes = [
  ['/', 'Legal and safety center'],
  ['/privacy/', 'Privacy'],
  ['/terms/', 'Terms'],
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

const nav = routes
  .slice(1)
  .map(([href, label]) => `<a href="${href}">${label}</a>`)
  .join('');
const publisher = display(
  'MORT_PUBLIC_PUBLISHER_NAME',
  'Publisher identity pending - deployment blocked',
);
const supportEmail = display(
  'MORT_PUBLIC_SUPPORT_EMAIL',
  'Support contact pending - deployment blocked',
);
const privacyEmail = display(
  'MORT_PUBLIC_PRIVACY_EMAIL',
  'Privacy contact pending - deployment blocked',
);
const childSafetyEmail = display(
  'MORT_PUBLIC_CHILD_SAFETY_EMAIL',
  'Child-safety contact pending - deployment blocked',
);
const websiteUrl = display(
  'MORT_PUBLIC_WEBSITE_URL',
  'Public website URL pending - deployment blocked',
);
const effectiveDate = display(
  'MORT_PUBLIC_EFFECTIVE_DATE',
  'Effective date pending - deployment blocked',
);
const blocker = deploymentReady
  ? ''
  : `<div class="blocker" role="status"><strong>Release blocker:</strong> This preview package is not authorized for public deployment. Required publisher and contact configuration is incomplete.</div>`;

function page({ title, description, body, scripts = '' }) {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
  <meta name="theme-color" content="#08110d">
  <meta name="description" content="${escapeHtml(description)}">
  <title>${escapeHtml(title)} | MORT</title>
  <link rel="stylesheet" href="/assets/site.css">
</head>
<body>
  <a class="skip" href="#content">Skip to content</a>
  <header><a class="brand" href="/">MORT <span>Closed pilot</span></a><nav aria-label="Legal and support">${nav}</nav></header>
  <main id="content">
    <p class="status">Published - closed-pilot draft, pending qualified legal review</p>
    <h1>${escapeHtml(title)}</h1>
    <p class="lede">${escapeHtml(description)}</p>
    ${blocker}
    <div class="notice"><strong>Current limits:</strong> MORT is a restricted 13+ pilot. It does not guarantee identity, safety, jobs, or payment; it does not process payments; and real identity-document collection is disabled.</div>
    ${body}
  </main>
  <footer><p><strong>MORT</strong> | Publisher: ${publisher}</p><p>Support: ${supportEmail} | Effective: ${effectiveDate}</p><p>Website: ${websiteUrl}</p></footer>
  ${scripts}
</body>
</html>`;
}

write('assets/site.css', `
:root{color-scheme:light dark;--bg:#08110d;--panel:#111c16;--line:#34463b;--text:#f5fbf7;--muted:#bfd0c5;--accent:#67ed92;--warn:#ffd166;--danger:#ff9098;font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--bg);color:var(--text);line-height:1.65}a{color:var(--accent)}a:focus-visible,button:focus-visible,input:focus-visible{outline:3px solid var(--warn);outline-offset:3px}.skip{position:fixed;left:12px;top:-80px;z-index:10;background:var(--text);color:var(--bg);padding:10px}.skip:focus{top:12px}header{padding:14px max(18px,calc((100vw - 1040px)/2));background:#08110df5;border-bottom:1px solid var(--line)}.brand{display:inline-flex;gap:10px;align-items:center;color:var(--text);font-weight:850;text-decoration:none}.brand span,.status{display:inline-block;padding:3px 8px;border:1px solid var(--warn);border-radius:6px;color:var(--warn);font-size:.75rem;font-weight:750;text-transform:uppercase}nav{display:flex;flex-wrap:wrap;gap:8px 14px;padding-top:12px}nav a{color:var(--muted);font-size:.9rem;text-decoration:none}nav a:hover{color:var(--accent)}main,footer{width:min(100% - 36px,880px);margin-inline:auto}main{padding:46px 0 70px}h1{font-size:clamp(2rem,6vw,3.5rem);line-height:1.08;margin:14px 0 16px;letter-spacing:0}h2{margin:36px 0 10px;font-size:1.4rem}h3{margin:24px 0 8px;font-size:1.1rem}.lede{font-size:1.15rem;color:var(--muted);max-width:720px}.notice,.panel,.blocker{border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:18px;margin:24px 0}.notice{border-left:4px solid var(--warn)}.blocker{border-left:4px solid var(--danger);color:#ffe6e8}li{margin:.45rem 0}table{border-collapse:collapse;width:100%;display:block;overflow:auto}th,td{padding:10px;border:1px solid var(--line);text-align:left;vertical-align:top}th{background:var(--panel)}label{display:block;font-weight:700;margin:14px 0 6px}input{width:100%;max-width:520px;padding:13px;border:1px solid var(--line);border-radius:6px;background:#0d1711;color:var(--text);font:inherit}button{margin:14px 8px 0 0;padding:12px 16px;border:0;border-radius:6px;background:var(--accent);color:#061008;font:inherit;font-weight:800;cursor:pointer}button.secondary{background:transparent;color:var(--text);border:1px solid var(--line)}button:disabled{opacity:.55;cursor:not-allowed}.result{min-height:1.5em;margin-top:14px;color:var(--muted)}footer{border-top:1px solid var(--line);padding:24px 0 48px;color:var(--muted);font-size:.9rem;overflow-wrap:anywhere}@media(max-width:600px){main{padding-top:32px}.notice,.panel,.blocker{padding:15px}h1{font-size:2.2rem}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
`);

const pages = {
  'index.html': page({
    title: 'Legal and safety center',
    description: 'Public privacy, safety, support, accessibility, and account-control information for the MORT closed pilot.',
    body: `<section class="panel"><h2>What MORT is today</h2><p>MORT is a controlled 13+ pilot for local work coordination. Public accounts can learn about the mission and safety model, but jobs, participant messaging, private locations, contracts, and active-job workflows require server-approved pilot enrollment.</p><ul>${routes.slice(1).map(([href, label]) => `<li><a href="${href}">${label}</a></li>`).join('')}</ul></section>`,
  }),
  'privacy/index.html': page({
    title: 'Privacy policy',
    description: 'How the MORT pilot collects, uses, protects, retains, and deletes information.',
    body: `<h2>Scope</h2><p>This policy covers the MORT app, hosted Supabase backend, and public support pages. Accounts are restricted to people age 13 or older.</p><h2>Information handled</h2><ul><li>Account ID, email, private date of birth, age band, role, profile name, and optional profile image.</li><li>Jobs, applications, contracts, job-context messages, reviews, reports, blocks, proofs, support requests, and work history.</li><li>Approximate area and optional foreground location when a user invokes a location feature. Background location is not collected.</li><li>Optional Guardian Mode and Support Circle links, security events, session data, rate-limit data, and diagnostics.</li><li>Payment preferences and obligation records. MORT does not hold, transfer, or guarantee money.</li></ul><h2>Disabled collection</h2><p>Real government-ID images, face templates, provider identity verification, advertising, and in-app billing are disabled in this release.</p><h2>Use and sharing</h2><p>Data is used for authentication, pilot eligibility, job workflows, safety, moderation, support, security, and legal compliance. Supabase provides hosted infrastructure. MORT does not sell personal information. Future SDK activation requires a new code and Data Safety review.</p><h2>Retention and deletion</h2><p>Ordinary account data is removed through the deletion workflow. Narrow safety, fraud, dispute, audit, evidence-preservation, and legal records may be retained with restricted access when legitimately necessary. See <a href="/account-deletion/">account deletion</a>.</p><h2>Teen privacy</h2><p>A minor's exact birth date, exact age, school, housing status, residential address, private messages, and precise live location are not public participant-directory fields.</p><h2>Contact</h2><p>Privacy contact: ${privacyEmail}</p>`,
  }),
  'terms/index.html': page({
    title: 'Terms',
    description: 'Core service terms for the restricted MORT closed-pilot service.',
    body: `<h2>Eligibility and access</h2><p>Users must be at least 13, use their own account, accept current agreements, and follow role and jurisdiction rules. Downloading MORT does not grant marketplace eligibility.</p><h2>Service limits</h2><p>MORT provides coordination tools, not employment, legal, tax, insurance, emergency, background-check, or payment services. Users remain responsible for lawful work, wages, supervision, tools, transportation, and taxes.</p><h2>Enforcement</h2><p>MORT may remove content, restrict accounts, preserve narrow evidence, and refer serious safety matters to trained adults or lawful authorities. Appeals do not automatically restore access.</p><p>These terms require adult publisher and qualified legal review before broader release.</p>`,
  }),
  'terms-of-use/index.html': page({
    title: 'Terms of use',
    description: 'Rules for using MORT accounts, jobs, messages, and pilot workflows.',
    body: `<h2>Acceptable use</h2><p>Use MORT only for lawful, age-appropriate, job-related activity. Do not impersonate others, evade blocks, scrape participant data, expose private addresses, pressure users off-platform, or misuse reporting tools.</p><h2>Messaging</h2><p>Messaging is job-contextual and subject to eligibility, block, restriction, rate-limit, and safety checks. Automated scanning can miss harmful content and is not a safety guarantee.</p><h2>Guardian Mode</h2><p>Guardian Mode is optional. It does not create universal legal consent, continuous monitoring, or emergency response.</p><h2>Account controls</h2><p>Users may manage privacy, sessions, reports, blocks, support, and account deletion. Continued use after a material terms change may require fresh acceptance.</p>`,
  }),
  'community-guidelines/index.html': page({
    title: 'Community guidelines',
    description: 'Behavior and content standards for MORT participants and organizations.',
    body: `<h2>Be job-focused</h2><p>Keep posts and conversations relevant to a legitimate work opportunity. Use accurate scope, schedule, supervision, location type, and payment-preference information.</p><h2>Protect minors</h2><p>No grooming, romantic or sexual adult-minor interaction, sexual solicitation, trafficking, sexual images, private minor directory, anonymous chat, or retaliation for reports.</p><h2>Respect boundaries</h2><p>No harassment, hate, discrimination, threats, doxxing, fraud, spam, block evasion, coercion, unsafe off-platform pressure, or deceptive verification claims.</p><h2>Report concerns</h2><p>Use report and block controls. Do not place private incident evidence in ordinary messages. Call local emergency services for immediate danger.</p>`,
  }),
  'safety/index.html': page({
    title: 'Safety center',
    description: 'Reporting, blocking, job-context, and real-world safety guidance for MORT.',
    body: `<h2>Immediate danger</h2><p>MORT is not an emergency service and is not continuously monitored. Leave an unsafe situation and contact local emergency services.</p><h2>Before work</h2><ul><li>Review scope, people present, location type, transportation, tools, and payment preference.</li><li>Use general areas until an authorized stage and never post a home address publicly.</li><li>Decline work that is sexual, isolated, illegal, dangerous, deceptive, or materially different from the listing.</li></ul><h2>During work</h2><p>Use the Mutual Safety Agreement, arrival and completion checks, job-context messages, and Safety Center. A Safety Ping may fail to deliver and never replaces emergency services.</p><h2>Contact</h2><p>Child-safety contact: ${childSafetyEmail}</p>`,
  }),
  'child-safety-standards/index.html': page({
    title: 'Child safety standards',
    description: 'MORT standards against child sexual abuse, exploitation, grooming, trafficking, and solicitation.',
    body: `<h2>Zero tolerance</h2><p>MORT prohibits CSAM, child sexual abuse and exploitation (CSAE), grooming, sextortion, trafficking, sexual solicitation, sexual jobs, romantic or sexual adult-minor interaction, requests for sexual images, sexual off-platform pressure, and evasion after blocking.</p><h2>Reporting and enforcement</h2><p>Users can report supported profiles, jobs, messages, and conduct and can block accounts. Reports are access restricted. MORT may block content, restrict accounts, preserve narrow lawful evidence, prevent contact, and escalate to trained adults.</p><h2>Evidence boundaries</h2><p>Never ask a child to resend sexual material. Do not email, download, forward, or place suspected CSAM in ordinary tickets. Authorized adults follow applicable reporting and preservation law.</p><h2>Child-safety contact</h2><p>${childSafetyEmail}</p><p>MORT is not an emergency service.</p>`,
  }),
  'prohibited-jobs/index.html': page({
    title: 'Prohibited jobs',
    description: 'Work categories and conditions that are not allowed in the MORT pilot.',
    body: `<h2>Always prohibited</h2><ul><li>Sexual, romantic, escort, modeling-with-undressing, massage, trafficking, or exploitative services.</li><li>Illegal activity, weapons, controlled substances, gambling, fraud, theft, surveillance, or evasion of authorities.</li><li>Age-restricted equipment, hazardous chemicals, roofing, demolition, heavy machinery, driving, or other unlawful youth work.</li><li>Unknown private-bedroom work, overnight stays, secret locations, requests to hide the job, or isolation designed to bypass safety controls.</li><li>Unpaid trial work presented as paid work, deceptive compensation, or requests for money, gift cards, bank credentials, or account access.</li></ul><h2>Review</h2><p>Jobs may be rejected, paused, or removed. Pilot eligibility never overrides labor, licensing, wage, safety, or supervision law.</p>`,
  }),
  'payment-disputes/index.html': page({
    title: 'Payment disputes',
    description: 'How MORT records payment obligations and disagreements without processing money.',
    body: `<h2>No payment processing</h2><p>MORT records agreed payment terms, preferences, completion assertions, and status. It does not hold funds, provide escrow, guarantee payment, collect cards, or decide criminal or civil guilt.</p><h2>Disagreement workflow</h2><p>Participants may confirm, partially dispute, or dispute completion and may report nonpayment. Each party can provide job-context facts. Access is restricted and anti-retaliation controls apply.</p><h2>Outside help</h2><p>MORT cannot provide legal advice or collection services. Participants may need a parent, trusted adult, labor agency, court, or qualified lawyer depending on age and jurisdiction.</p>`,
  }),
  'support/index.html': page({
    title: 'Support',
    description: 'Account, privacy, safety, and pilot support routes for MORT users and reviewers.',
    body: `<h2>Account-linked help</h2><p>Signed-in users should use the in-app Support Center so requests carry authorized account context.</p><h2>Other routes</h2><p>Delete an account through <a href="/account-deletion/">account deletion</a>. Review safety guidance in the <a href="/safety/">Safety Center</a>. For urgent danger, contact local emergency services.</p><h2>Support contact</h2><p>${supportEmail}</p>`,
  }),
  'contact/index.html': page({
    title: 'Contact',
    description: 'Public contact points for MORT support, privacy, and child safety.',
    body: `<h2>Publisher</h2><p>${publisher}</p><h2>Support</h2><p>${supportEmail}</p><h2>Privacy</h2><p>${privacyEmail}</p><h2>Child safety</h2><p>${childSafetyEmail}</p><p>Do not send suspected CSAM by email. Contact emergency services for immediate danger.</p>`,
  }),
  'accessibility/index.html': page({
    title: 'Accessibility',
    description: 'Accessibility commitments, supported controls, and feedback for MORT.',
    body: `<h2>Current support</h2><p>MORT is designed for screen readers, scalable text, keyboard navigation on web, visible focus, dark mode, reduced motion, descriptive labels, and permission-denial alternatives. Physical TalkBack and device testing remain required before release.</p><h2>Alternatives</h2><p>Location features include approximate and manual-area paths. Safety and account controls must not depend on color alone. Support can help with an accessible route but cannot bypass identity, eligibility, or safety rules.</p><h2>Feedback</h2><p>Report accessibility barriers to ${supportEmail}. Include the device, Android version, page, and what you expected, without sending passwords or sensitive incident evidence.</p>`,
  }),
};

const deletionBody = `<h2>What happens</h2><p>After ownership verification, MORT creates an auditable request to remove the account and ordinary profile data. Narrow safety, fraud, dispute, security, evidence-preservation, and legal records may be retained with restricted access when legitimately necessary.</p><div id="request-panel" class="panel"><h2>1. Verify account ownership</h2><form id="deletion-link-form" novalidate><label for="email">Account email</label><input id="email" name="email" type="email" autocomplete="email" required><button type="submit">Send private sign-in link</button></form><p id="link-result" class="result" role="status" aria-live="polite"></p></div><div id="confirmed-panel" class="panel" hidden><h2>2. Submit deletion request</h2><p>You are signed in for this request. MORT will not require a support conversation first.</p><button id="submit-deletion" type="button">Request account deletion</button><button id="sign-out" class="secondary" type="button">Sign out</button><p id="deletion-result" class="result" role="status" aria-live="polite"></p></div><h2>Use the app</h2><p>Open Settings, Account, then Delete account. Reinstallation is not required.</p><h2>Privacy</h2><p>The email-link form always gives a generic public response and does not reveal whether an account exists.</p>`;
pages['account-deletion/index.html'] = page({
  title: 'Delete your MORT account',
  description: 'Request account deletion without reinstalling the app.',
  body: deletionBody,
  scripts: '<script src="/assets/supabase.js"></script><script src="/assets/public-config.js"></script><script src="/assets/account-deletion.js"></script>',
});

for (const [relative, content] of Object.entries(pages)) write(relative, content);
write('assets/supabase.js', readFileSync(supabaseBrowserBundle, 'utf8'));

const supabase = readSupabasePublicConfig();
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
      publicDeploymentClaimed: false,
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
  Content-Security-Policy: default-src 'self'; script-src 'self'; connect-src 'self' https://rakjydmgwwgtdislanbt.supabase.co; style-src 'self'; img-src 'self' data:; font-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'; worker-src 'none'; upgrade-insecure-requests
`);
write('_redirects', '/* /index.html 404');
// Real, confirmed AdMob publisher ID (pub-9883419411387958), standard
// AdMob app-ads.txt authorized-seller line -- not a placeholder.
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
            {
              key: 'Permissions-Policy',
              value: 'camera=(), microphone=(), geolocation=(), payment=()',
            },
            {
              key: 'Content-Security-Policy',
              value:
                "default-src 'self'; script-src 'self'; connect-src 'self' https://rakjydmgwwgtdislanbt.supabase.co; style-src 'self'; img-src 'self' data:; font-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'; worker-src 'none'; upgrade-insecure-requests",
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
