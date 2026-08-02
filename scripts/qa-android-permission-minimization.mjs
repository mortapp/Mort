import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { assert, pass, read, root } from './play-release-qa-helpers.mjs';

const scope = 'qa-android-permission-minimization';
const source = read('flutter_mort/android/app/src/main/AndroidManifest.xml');
const pubspec = read('flutter_mort/pubspec.yaml');
const report = resolve(root, 'build/play/reports/bundle-manifest.xml');
const merged = existsSync(report) ? read('build/play/reports/bundle-manifest.xml') : '';
for (const forbidden of ['ACCESS_BACKGROUND_LOCATION','READ_MEDIA_IMAGES','READ_EXTERNAL_STORAGE','WRITE_EXTERNAL_STORAGE']) {
  assert(!source.includes(forbidden), `Forbidden permission remains: ${forbidden}`);
}
assert(!source.includes('com.android.vending.BILLING'), 'Google Play Billing must be absent from the free pilot.');
assert(!pubspec.includes('in_app_purchase:'), 'in_app_purchase remains in the free pilot dependency graph.');
for (const removed of ['com.google.android.gms.permission.AD_ID','ACCESS_ADSERVICES_AD_ID']) {
  const explicitlyRemoved = new RegExp(`${removed.replaceAll('.', '\\.')}[^>]+tools:node="remove"`).test(source);
  assert(
    explicitlyRemoved || (merged !== '' && !merged.includes(removed)),
    `${removed} is neither explicitly removed nor absent from the final AAB.`,
  );
}
for (const component of [
  'com.google.android.gms.ads.MobileAdsInitProvider',
  'com.google.android.gms.ads.AdActivity',
  'com.google.android.gms.ads.AdService',
]) {
  const explicitlyRemoved = new RegExp(`${component.replaceAll('.', '\\.')}[^>]+tools:node="remove"`).test(source);
  assert(
    explicitlyRemoved ||
      (!pubspec.includes('google_mobile_ads:') && merged !== '' && !merged.includes(component)),
    `Disabled AdMob component is neither explicitly removed nor absent from dependencies and the final AAB: ${component}`,
  );
}
if (existsSync(report)) {
  for (const forbidden of ['ACCESS_BACKGROUND_LOCATION','com.google.android.gms.permission.AD_ID']) {
    assert(!merged.includes(forbidden), `Final AAB contains forbidden permission: ${forbidden}`);
  }
  assert(!merged.includes('com.android.vending.BILLING'), 'Final AAB unexpectedly contains Google Play Billing.');
  assert(
    !merged.includes('com.google.android.gms.ads.MobileAdsInitProvider'),
    'Final AAB still contains the disabled AdMob auto-init provider.',
  );
}
assert(source.includes('android.permission.WAKE_LOCK'), 'FCM wake-lock capability is missing.');
pass(scope, 'Billing, background/media/ad permissions and AdMob auto-start remain absent; FCM wake lock is retained');
