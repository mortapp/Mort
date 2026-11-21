import { rejects } from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { assertClosedTestAabEvidence } from '../qa-aab-signing.mjs';

const fixture = 'synthetic AAB checksum fixture\n';
const sha256 = createHash('sha256').update(fixture).digest('hex').toUpperCase();
const report = [
  'AAB_SIGNATURE=PASS',
  'DEBUG_CERTIFICATE=REJECTED',
  'PACKAGE_ID=com.mortapp.mobile',
  'TARGET_SDK=36',
  'RELEASE_STAGE=closed_test',
  'NO_ADS_MANIFEST_POLICY=PASS',
  `SHA256=${sha256}`,
].join('\r\n');

async function withBundle(content, run) {
  const directory = await mkdtemp(join(tmpdir(), 'mort-aab-report-test-'));
  try {
    const path = join(directory, 'fixture.aab');
    await writeFile(path, content);
    await run(path);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}

test('accepts a matching report including PowerShell line endings and uppercase SHA-256', () =>
  withBundle(fixture, (path) => assertClosedTestAabEvidence(path, `\uFEFF${report}\r\n`)));

test('rejects a report for different bundle bytes', () =>
  withBundle('different artifact', (path) =>
    rejects(assertClosedTestAabEvidence(path, report), /does not match/)));

test('rejects signing evidence without the no-ads manifest result', () =>
  withBundle(fixture, (path) =>
    rejects(assertClosedTestAabEvidence(path, report.replace('NO_ADS_MANIFEST_POLICY=PASS\r\n', '')), /NO_ADS_MANIFEST_POLICY/)));

test('rejects a production report for the closed test', () =>
  withBundle(fixture, (path) =>
    rejects(assertClosedTestAabEvidence(path, report.replace('closed_test', 'production_pilot')), /RELEASE_STAGE/)));

test('rejects duplicate or malformed digests', () =>
  withBundle(fixture, async (path) => {
    await rejects(assertClosedTestAabEvidence(path, `${report}\r\nSHA256=${sha256}`), /exactly one valid/);
    await rejects(assertClosedTestAabEvidence(path, report.replace(sha256, 'invalid')), /exactly one valid/);
  }));
