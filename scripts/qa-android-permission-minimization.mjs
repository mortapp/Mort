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
assert(
  /com\.android\.vending\.BILLING[^>]+\/>/.test(source) &&
    !/com\.android\.vending\.BILLING[^>]+tools:node="remove"/.test(source),
  'Google Play Billing must be declared for the compiled, runtime-gated purchase flow.',
);
for (const removed of ['com.google.android.gms.permission.AD_ID','ACCESS_ADSERVICES_AD_ID','WAKE_LOCK']) {
  assert(new RegExp(`${removed.replaceAll('.', '\\.')}[^>]+tools:node="remove"`).test(source), `${removed} is not explicitly removed.`);
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
  for (const forbidden of ['ACCESS_BACKGROUND_LOCATION','com.google.android.gms.permission.AD_ID','WAKE_LOCK']) {
    assert(!merged.includes(forbidden), `Final AAB contains forbidden permission: ${forbidden}`);
  }
  assert(merged.includes('com.android.vending.BILLING'), 'Final AAB is missing Google Play Billing permission.');
  assert(
    !merged.includes('com.google.android.gms.ads.MobileAdsInitProvider'),
    'Final AAB still contains the disabled AdMob auto-init provider.',
  );
}
pass(scope, 'Billing is present while background/media/ad/wake-lock permissions and AdMob auto-start remain absent');
