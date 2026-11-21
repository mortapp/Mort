import { createHash } from 'node:crypto';
import { createReadStream, existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scope = 'qa-aab-signing';

export async function assertClosedTestAabEvidence(bundle, reportText) {
  const expected = {
    AAB_SIGNATURE: 'PASS',
    DEBUG_CERTIFICATE: 'REJECTED',
    PACKAGE_ID: 'com.mortapp.mobile',
    TARGET_SDK: '36',
    RELEASE_STAGE: 'closed_test',
    NO_ADS_MANIFEST_POLICY: 'PASS',
  };
  const lines = reportText.trim().split(/\r?\n/);
  for (const [key, value] of Object.entries(expected)) {
    const entries = lines.filter((line) => line.startsWith(`${key}=`));
    if (entries.length !== 1 || entries[0] !== `${key}=${value}`) {
      throw new Error(`Expected ${key}=${value} in the closed-test AAB verification report.`);
    }
  }
  const entries = lines.filter((line) => line.startsWith('SHA256='));
  if (entries.length !== 1 || !/^SHA256=[0-9a-fA-F]{64}$/.test(entries[0])) {
    throw new Error('The closed-test AAB verification report needs exactly one valid SHA-256.');
  }
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(bundle)) hash.update(chunk);
  if (hash.digest('hex') !== entries[0].slice('SHA256='.length).toLowerCase()) {
    throw new Error('The AAB does not match the verification report. Rerun verify-play-aab.ps1 on this exact bundle.');
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = resolve(import.meta.dirname, '..');
  const pubspec = readFileSync(resolve(root, 'flutter_mort/pubspec.yaml'), 'utf8');
  const version = pubspec.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$/m);
  if (!version) throw new Error('Flutter version could not be read.');
  const bundle = process.argv[2]
    ? resolve(process.argv[2])
    : resolve(root, `build/play/mort-closed-test-${version[1]}-${version[2]}.aab`);
  const report = resolve(root, 'build/play/reports/aab-verification.txt');
  if (!existsSync(bundle) || !existsSync(report)) throw new Error('Verified AAB/report is missing.');
  await assertClosedTestAabEvidence(bundle, readFileSync(report, 'utf8'));
  process.stdout.write(`[${scope}] PASS: This exact AAB matches the closed-test signature and no-ads report.\n`);
}
