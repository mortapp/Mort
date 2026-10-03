import test from 'node:test';
import assert from 'node:assert/strict';
import { renderArchive } from './shell.mjs';

const base = { publisher: 'MORT', supportEmail: 'support@example.com', effectiveDate: '2026-08-29', websiteUrl: 'https://mortapp.org', blocker: '' };

test('classic legal layout retains semantic text, anchors and deletion scripts', () => {
  const html = renderArchive({ ...base, title: 'Privacy', description: 'Original description', body: '<h2>Keep this heading</h2><p>Original legal text.</p>', scripts: '<script src="/assets/account-deletion.js"></script>', routes: [['/', 'Overview'], ['/privacy/', 'Privacy']] });
  assert.match(html, /Original legal text\./);
  assert.match(html, /id="keep-this-heading"/);
  assert.match(html, /class="document"/);
  assert.match(html, /account-deletion.js/);
  assert.match(html, /class="skip"/);
  assert.doesNotMatch(html, /archive-canvas|archive\.js|Pause atmosphere/);
});

test('public index links to each document without decorative canvas', () => {
  const html = renderArchive({ ...base, title: 'Legal and safety center', description: 'Public information', body: '', routes: [['/', 'Overview'], ['/privacy/', 'Privacy'], ['/account-deletion/', 'Delete account']] });
  assert.match(html, /class="document-index"/);
  assert.match(html, /href="\/privacy\/"/);
  assert.match(html, /href="\/account-deletion\/"/);
  assert.doesNotMatch(html, /archive-canvas|archive\.js/);
});
