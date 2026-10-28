import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-public-production-release-path';
const builder = read('scripts/build-production-public-aab.ps1');
assert(
  !builder.includes('BLOCKED-EXTERNAL'),
  'Public production AAB builder is still an unconditional external blocker.',
);
assert(
  builder.includes('android-release-profile-common.ps1'),
  'Public production AAB builder does not use the signed, verified common build path.',
);
assert(
  builder.includes("-ReleaseStage 'production_public'") ||
    builder.includes('-ReleaseStage production_public'),
  'Public production AAB builder does not select production_public.',
);
assert(/-RemotePushEnabled\s+\$false/.test(builder), 'Public production build still enables Firebase-only remote push.');
assert(/-CrashReportingEnabled\s+\$true/.test(builder), 'Public production build does not enable Sentry crash reporting.');

const workflow = read('.github/workflows/mort-public-production-aab.yml');
assert(workflow.includes('environment: Production'), 'Public build is not bound to the protected Production environment.');
assert(workflow.includes('build-android-release.ps1') && workflow.includes('production_public'), 'Workflow does not use the public-production AAB builder.');
assert(workflow.includes('actions/upload-artifact@'), 'Workflow does not preserve the verified AAB artifact.');
assert(workflow.includes('*.aab') && !workflow.includes('*.apk'), 'Public workflow must package only the Play AAB.');
assert(workflow.includes('flutter analyze --no-pub'), 'Production workflow does not analyze the Flutter app.');
assert(workflow.includes('flutter test --no-pub'), 'Production workflow does not run Flutter tests.');
assert(!/closed[-_ ]test|reviewer_demo|PLAY_REVIEW_MODE_ENABLED=true/i.test(workflow), 'Public workflow contains a closed-test or reviewer path.');
assert(!/SUPABASE_SERVICE_ROLE_KEY|SUPABASE_ACCESS_TOKEN|SUPABASE_DB_PASSWORD/i.test(workflow), 'Public workflow injects privileged Supabase credentials.');
assert(!/r0adkll\/upload-google-play|publish.*play|upload.*play/i.test(workflow), 'Public workflow must not publish to Google Play.');

const profile = JSON.parse(read('config/mort-release-profiles.json')).profiles.production;
const commonBuild = read('scripts/android-release-profile-common.ps1');
const aabVerifier = read('scripts/verify-play-aab.ps1');
assert(profile.releaseStage === 'production_public', 'Production profile has the wrong release stage.');
assert(profile.publicMarketplaceEnabled === true, 'Production profile does not enable the public marketplace.');
assert(profile.productionActivationApproved === true, 'Owner-approved public production activation is not recorded.');
assert(profile.remotePushEnabled === false, 'Production profile still requires the Firebase-only push path.');
assert(!aabVerifier.includes('FlutterFirebaseMessagingReceiver'), 'AAB verifier still allows Firebase messaging components.');
assert(commonBuild.includes('Public production requires approved legal document versions.'), 'Production builder does not reject legal placeholders.');
assert(!/FIREBASE_[A-Z0-9_]+:/.test(workflow), 'Production workflow still supplies Firebase configuration.');
for (const field of ['SENTRY_DSN']) {
  assert(commonBuild.includes(`${field} =`), `Public build does not pass ${field} to Flutter.`);
  assert(workflow.includes(`${field}:`), `Production environment does not supply ${field}.`);
}
pass(scope, 'public-only signed AAB build path uses fail-closed release validation and never publishes');
