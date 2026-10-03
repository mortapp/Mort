import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const publicRoot = resolve(import.meta.dirname, '../public');
const routes = ['', 'privacy', 'terms', 'terms-of-use', 'community-guidelines', 'safety', 'child-safety-standards', 'prohibited-jobs', 'payment-disputes', 'account-deletion', 'support', 'contact', 'accessibility'];

test('all generated legal routes retain readable content and no old animation bundle', () => {
  for (const route of routes) {
    const html = readFileSync(resolve(publicRoot, route, 'index.html'), 'utf8');
    assert.match(html, /<main id="content"/);
    assert.match(html, /<h1>[^<]+<\/h1>/);
    assert.match(html, /Draft — pending qualified legal review/);
    assert.match(html, /href="\/privacy\/"/);
    assert.match(html, /href="\/assets\/favicon\.svg"/);
    assert.doesNotMatch(html, /archive-canvas|assets\/archive\.js/);
  }
  const deletion = readFileSync(resolve(publicRoot, 'account-deletion/index.html'), 'utf8');
  assert.match(deletion, /id="deletion-link-form"/);
  assert.match(deletion, /assets\/account-deletion\.js/);
  assert.equal(existsSync(resolve(publicRoot, 'assets/archive.js')), false);
  assert.equal(existsSync(resolve(publicRoot, 'assets/site.css')), false);
});
