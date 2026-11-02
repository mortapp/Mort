#!/usr/bin/env node
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { basename, join } from 'node:path';

const root = new URL('../supabase-production/', import.meta.url);
const manifest = JSON.parse(await readFile(new URL('migration-history.json', root), 'utf8'));
const migrationDir = new URL('migrations/', root);
const files = (await readdir(migrationDir)).filter((name) => name.endsWith('.sql')).sort();
const sha256 = (text) => createHash('sha256').update(text, 'utf8').digest('hex');
const normalizeSql = (sql) => sql
  .replace(/^\s*--.*$/gm, '')
  .replace(/\s+/g, ' ')
  .trim();

assert.equal(manifest.migration_count, 73);
assert.equal(manifest.migrations.length, 73);
assert.equal(files.length, 73);
for (let i = 0; i < files.length; i += 1) {
  const match = /^([0-9]{14})_(.+)\.sql$/.exec(files[i]);
  assert.ok(match, `invalid migration filename: ${files[i]}`);
  assert.equal(manifest.migrations[i].version, match[1], `manifest order/version mismatch: ${files[i]}`);
  assert.equal(manifest.migrations[i].name, match[2], `manifest name mismatch: ${files[i]}`);
}

const exactMaskSource = await readFile(new URL('migrations/20261102113314_guardian_id_response_mask_production.sql', root), 'utf8');
const exactMaskHash = sha256(exactMaskSource);
assert.equal(exactMaskHash, '96ad143a1c066d3496ca492774c810a9bc196e629f2c7fa2bf908459c4392efa');
assert.equal(manifest.migrations.find((x) => x.version === '20261102113314').sha256, exactMaskHash);

const directSelectLedger = await readFile(new URL('recovered-ledger-sources/20261102040639_restrict_job_application_direct_select.sql', root), 'utf8');
const directSelectLocal = await readFile(new URL('migrations/20261102040639_restrict_job_application_direct_select.sql', root), 'utf8');
const directSelectHash = sha256(directSelectLedger);
assert.equal(directSelectHash, 'd816da845f1c71643a0d577b9629b98b3e8db9c0ed4c3667e8a4e7db7a60cf6d');
assert.equal(manifest.migrations.find((x) => x.version === '20261102040639').sha256, directSelectHash);
assert.equal(normalizeSql(directSelectLedger), normalizeSql(directSelectLocal), 'existing migration executable SQL differs from production ledger source');

console.log(`[qa-production-migration-recovery] PASS: ${files.length} ordered files match ${manifest.migration_count}-entry manifest`);
console.log(`[qa-production-migration-recovery] PASS: 20261102040639 ledger SHA-256 ${directSelectHash}; executable SQL matches existing migration`);
console.log(`[qa-production-migration-recovery] PASS: 20261102113314 exact-source SHA-256 ${exactMaskHash}`);
