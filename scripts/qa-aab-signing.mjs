import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { assert, pass, read, root } from './play-release-qa-helpers.mjs';

const scope = 'qa-aab-signing';
const bundle = resolve(root, 'build/play/mort-closed-test.aab');
const report = resolve(root, 'build/play/reports/aab-verification.txt');
assert(existsSync(bundle) && existsSync(report), 'Verified AAB/report is missing.');
const text = read('build/play/reports/aab-verification.txt');
assert(text.includes('AAB_SIGNATURE=PASS'), 'AAB signature did not pass.');
assert(text.includes('DEBUG_CERTIFICATE=REJECTED'), 'Debug certificate was not explicitly rejected.');
assert(text.includes('PACKAGE_ID=com.mortapp.mobile') && text.includes('TARGET_SDK=36'), 'AAB identity/SDK report mismatch.');
pass(scope, 'AAB signer matches the MORT upload certificate and debug signing is rejected');
