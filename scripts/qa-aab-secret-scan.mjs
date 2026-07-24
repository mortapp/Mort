import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { randomBytes } from 'node:crypto';
import { assert, pass, root } from './play-release-qa-helpers.mjs';

const scope = 'qa-aab-secret-scan';
const bundle = resolve(root, 'build/play/mort-closed-test.aab');
const apk = resolve(root, 'build/play/mort-play-closed-test-qa.apk');
assert(existsSync(bundle), 'Closed-test AAB does not exist.');
assert(existsSync(apk), 'Closed-test QA APK does not exist.');

const secretNames = [
  'SUPABASE_SERVICE_ROLE_KEY','SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD',
  'MORT_UPLOAD_STORE_PASSWORD','MORT_UPLOAD_KEY_PASSWORD','REVENUECAT_V1_SECRET_API_KEY',
  'REVENUECAT_V2_SECRET_API_KEY',
  'REVENUECAT_WEBHOOK_AUTH_HEADER','SEND_PUSH_INVOKE_SECRET',
];
const secrets = secretNames.map((name) => process.env[name]).filter((value) => value && value.length >= 8).map((value) => Buffer.from(value));

function files(directory) {
  return readdirSync(directory).flatMap((name) => {
    const path = join(directory, name);
    return statSync(path).isDirectory() ? files(path) : [path];
  });
}

let scannedEntries = 0;
for (const artifact of [
  { label: 'AAB', path: bundle },
  { label: 'APK', path: apk },
]) {
  const work = join(
    tmpdir(),
    `mort-${artifact.label.toLowerCase()}-scan-${randomBytes(6).toString('hex')}`,
  );
  mkdirSync(work, { recursive: true });
  try {
    execFileSync('jar', ['xf', artifact.path], {
      cwd: work,
      stdio: 'ignore',
    });
    const extracted = files(work);
    scannedEntries += extracted.length;
    for (const path of extracted) {
      const data = readFileSync(path);
      for (const secret of secrets) {
        assert(
          data.indexOf(secret) === -1,
          `Sensitive environment value detected in ${artifact.label} entry ${path.slice(work.length + 1)}.`,
        );
      }
    }
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

pass(
  scope,
  `scanned ${scannedEntries} extracted AAB/APK entries against ${secrets.length} available sensitive values`,
);
