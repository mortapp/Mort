import { assert, pass, read } from './play-release-qa-helpers.mjs';
import { getReleaseStatusError } from './release-profile-server-contract.mjs';

const scope = 'qa-play-release-mode';
const pubspec = read('flutter_mort/pubspec.yaml');
const gradle = read('flutter_mort/android/app/build.gradle.kts');
const build = read('scripts/build-play-aab.ps1');
const consoleBuild = read('scripts/build-play-console-aab.ps1');
const profileBuild = read('scripts/build-closed-test-aab.ps1');
const commonBuild = read('scripts/android-release-profile-common.ps1');
const profileMatrix = JSON.parse(read('config/mort-release-profiles.json'));
const reviewerProfile = profileMatrix.profiles.reviewer_demo;
const prelaunchProfile = profileMatrix.profiles.production_prelaunch;
const version = pubspec.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)$/m);
assert(version, 'Flutter version source is missing or invalid.');
assert(Number(version[2]) > 90, 'Play versionCode must be greater than 90.');
assert(gradle.includes('applicationId = "com.mortapp.mobile"'), 'Package ID mismatch.');
assert(gradle.includes('targetSdk = 36') && gradle.includes('minSdk = 24'), 'SDK levels mismatch.');
assert(gradle.includes('Release signing is required') && !gradle.includes('signingConfigs.getByName("debug")'), 'Release signing does not fail closed.');
assert(profileBuild.includes('-ReleaseProfile reviewer_demo'), 'Play build does not select the reviewer/demo profile.');
assert(reviewerProfile.releaseStage === 'closed_test', 'Reviewer profile is not a closed test.');
assert(reviewerProfile.operationalMode === 'closed_pilot', 'Reviewer profile is not bound to the closed pilot.');
for (const flag of ['publicMarketplaceEnabled','identityVerificationEnabled','marketplacePaymentsEnabled','iapEnabled','adsEnabled']) {
  assert(reviewerProfile[flag] === false, `Reviewer profile must disable ${flag}.`);
}
assert(reviewerProfile.reviewerModeEnabled === true, 'Reviewer routes are not explicitly isolated to reviewer/demo.');
assert(build.includes('build-play-console-aab.ps1'), 'Play wrapper must delegate to the console AAB builder.');
assert(consoleBuild.includes('build-standard-closed-test-aab.ps1'), 'Console wrapper must delegate to the standardized signed closed-test AAB builder.');
assert(commonBuild.includes('read-mobile-version.mjs'), 'Build does not consume the authoritative version source.');
assert(prelaunchProfile, 'production_prelaunch profile is required.');
assert(prelaunchProfile.releaseStage === 'production_public', 'prelaunch must use the production server stage.');
assert(prelaunchProfile.operationalMode === 'production_prelaunch', 'prelaunch operational mode mismatch.');
for (const flag of [
  'publicMarketplaceEnabled', 'marketplacePaymentsEnabled', 'identityVerificationEnabled',
  'remotePushEnabled', 'crashReportingEnabled', 'chatbotAiEnabled', 'adsEnabled',
  'iapEnabled', 'productionActivationApproved', 'googleAuthEnabled',
]) {
  assert(prelaunchProfile[flag] === false, `Production prelaunch must disable ${flag}.`);
}
assert(prelaunchProfile.paymentProviderMode === 'disabled', 'Prelaunch must keep payment-provider mode disabled.');
assert(commonBuild.includes("$ReleaseProfile -eq 'production_prelaunch'"), 'Shared build gate is missing prelaunch isolation.');
assert(commonBuild.includes('Production prelaunch requires owner-approved legal versions.'), 'Production prelaunch must reject draft legal versions before building.');
const releaseWrapper = read('scripts/build-android-release.ps1');
assert(releaseWrapper.includes("'production_prelaunch' {"), 'Release dispatcher must expose the explicit prelaunch profile.');
assert(releaseWrapper.includes("'production' {"), 'Public production profile must remain a separate dispatch.');
assert(read('scripts/build-production-public-aab.ps1').includes('BLOCKED-EXTERNAL'), 'Public production must remain approval-gated.');
assert(read('scripts/build-production-prelaunch-aab.ps1').includes('-ReleaseProfile production_prelaunch'), 'Prelaunch AAB wrapper missing.');
assert(read('flutter_mort/lib/core/config/app_config.dart').includes('releaseProfile == MortReleaseProfile.productionPrelaunch'), 'Runtime release validation must enforce prelaunch controls.');

const safePrelaunchStatus = {
  release_mode: 'production_public',
  maintenance_mode: false,
  public_marketplace_enabled: false,
  real_document_collection: false,
};
assert(getReleaseStatusError('production_prelaunch', safePrelaunchStatus) === null, 'Production prelaunch status should pass only with controls closed.');
assert(getReleaseStatusError('production_prelaunch', { ...safePrelaunchStatus, public_marketplace_enabled: true }) !== null, 'Prelaunch must reject marketplace activation.');
assert(getReleaseStatusError('production_prelaunch', { ...safePrelaunchStatus, real_document_collection: true }) !== null, 'Prelaunch must reject document collection.');
assert(getReleaseStatusError('production_prelaunch', { ...safePrelaunchStatus, maintenance_mode: true }) !== null, 'Prelaunch must reject maintenance mode.');
assert(getReleaseStatusError('production', safePrelaunchStatus) !== null, 'Public production must still require server activation.');

const androidManifest = read('flutter_mort/android/app/src/main/AndroidManifest.xml').replaceAll('\r\n', '\n');
for (const component of [
  'com.reactnativestripesdk.StripeConnectDeepLinkInterceptorActivity',
  'com.stripe.android.financialconnections.FinancialConnectionsSheetRedirectActivity',
  'com.stripe.android.financialconnections.lite.FinancialConnectionsSheetLiteRedirectActivity',
  'com.stripe.android.link.LinkRedirectHandlerActivity',
  'com.stripe.android.payments.StripeBrowserProxyReturnActivity',
]) {
  assert(androidManifest.includes(`android:name="${component}"\n            tools:node="remove" />`), `Disabled payment callback must be removed: ${component}.`);
}
const aabVerifier = read('scripts/verify-play-aab.ps1');
assert(aabVerifier.includes('unexpected exported component'), 'AAB verifier must continue rejecting unexpected exported components.');
assert(aabVerifier.includes('android\\.permission\\.BIND_JOB_SERVICE'), 'AndroidX job service must remain system-permission protected.');
assert(aabVerifier.includes('android\\.permission\\.DUMP'), 'Diagnostics receiver must remain protected by DUMP permission.');

pass(scope, `version ${version[1]}+${version[2]}, package, SDK, closed production prelaunch controls, fail-closed signing, and reviewer/demo profile are fixed`);
