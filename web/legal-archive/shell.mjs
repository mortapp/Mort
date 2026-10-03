const escape = (value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

export function renderArchive({ title, description, body, scripts = '', routes, publisher, supportEmail, effectiveDate, websiteUrl, blocker }) {
  const home = title === 'Legal and safety center';
  const headings = [];
  const anchored = body.replace(/<h2>(.*?)<\/h2>/g, (_, label) => {
    const id = label.toLowerCase().replace(/<[^>]*>/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
    headings.push({ id, label });
    return `<h2 id="${id}">${label}</h2>`;
  });
  const links = routes.slice(1).map(([href, label]) => `<a href="${href}">${escape(label)}<span aria-hidden="true">→</span></a>`).join('');
  const contents = home
    ? `<section class="intro"><h2>Clear information about MORT</h2><p>MORT is a 13+ service for local work coordination. Jobs, messaging, private locations, contracts, and active work require server-approved account eligibility.</p></section><nav class="document-index" id="documents" aria-label="Legal and safety documents">${links}</nav>`
    : `<div class="reading-layout"><aside class="contents"><p class="eyebrow">On this page</p><nav aria-label="Document sections">${headings.map(({ id, label }) => `<a href="#${id}">${label}</a>`).join('')}</nav><a class="all-records" href="/#documents">All documents</a></aside><article class="document">${anchored}</article></div>`;
  return `<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="theme-color" content="#ffffff"><meta name="description" content="${escape(description)}"><title>${escape(title)} | MORT</title><link rel="icon" type="image/svg+xml" href="/assets/favicon.svg"><link rel="stylesheet" href="/assets/archive.css"></head>
<body>
<a class="skip" href="#content">Skip to content</a>
<header class="topbar"><a class="brand" href="/" aria-label="MORT legal and safety home">MORT<span>Legal &amp; safety</span></a><a class="back" href="https://mortapp.org">Return to MORT</a></header>
<main id="content" tabindex="-1"><section class="page-heading"><p class="eyebrow">MORT / Legal &amp; safety</p><h1>${escape(title)}</h1><p class="lede">${escape(description)}</p><p class="draft">Draft — pending qualified legal review</p></section><div class="reading-shell">${blocker}<div class="notice"><strong>Current limits:</strong> MORT is a 13+ local-work coordination service with account eligibility restrictions. It does not guarantee identity, safety, jobs, or payment; it does not process real-world job payments; and identity verification is not currently available.</div>${contents}</div></main>
<footer><a class="brand" href="/">MORT</a><p>Publisher: ${publisher} · Effective: ${effectiveDate}</p><p>Support: <a href="mailto:${supportEmail}">${supportEmail}</a> · Website: <a href="${websiteUrl}">${websiteUrl}</a></p><p>Draft — pending qualified legal review. This is public information, not legal advice.</p><nav aria-label="Footer">${routes.slice(1).map(([href, label]) => `<a href="${href}">${escape(label)}</a>`).join('')}</nav></footer>
${scripts}
</body></html>`;
}
