import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { assert, pass, read, root } from './play-release-qa-helpers.mjs';

const scope = 'qa-child-safety-standards';
const html = read('web/public/child-safety-standards/index.html').toLowerCase();
for (const term of ['csam','csae','grooming','sexual solicitation','sextortion','trafficking','report','block','child-safety contact']) {
  assert(html.includes(term), `Published standards omit ${term}.`);
}
for (const file of ['docs/operations/MORT_CHILD_SAFETY_CONTACT_PROCESS.md','docs/operations/MORT_CSAM_RESPONSE_AND_ESCALATION.md','docs/operations/MORT_CSAE_ENFORCEMENT_STANDARD.md','docs/operations/MORT_MISSING_MINOR_ESCALATION.md']) {
  assert(existsSync(resolve(root, file)), `Missing ${file}.`);
}
pass(scope, 'public standards and trained-adult escalation documents cover required CSAE controls');
