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
assert(pubspec.includes('purchases_flutter:'), 'Native RevenueCat dependency is missing.');
assert(!source.includes('com.android.vending.BILLING'), 'App manifest should not declare Billing outside the SDK merge.');
for (const removed of ['com.google.android.gms.permission.AD_ID','ACCESS_ADSERVICES_AD_ID']) {
  const explicitlyRemoved = new RegExp(`${removed.replaceAll('.', '\\.')}[^>]+tools:node="remove"`).test(source);
  assert(
    explicitlyRemoved || (merged !== '' && !merged.includes(removed)),
    `${removed} is neither explicitly removed nor absent from the final AAB.`,
  );
}
assert(pubspec.includes('google_mobile_ads:'), 'Native AdMob dependency is missing.');
if (existsSync(report)) {
  for (const forbidden of ['ACCESS_BACKGROUND_LOCATION','com.google.android.gms.permission.AD_ID']) {
    assert(!merged.includes(forbidden), `Final AAB contains forbidden permission: ${forbidden}`);
  }
}
assert(source.includes('android.permission.WAKE_LOCK'), 'FCM wake-lock capability is missing.');
pass(scope, 'Native SDK inventory is explicit; background, media, and ad ID permissions are absent; FCM wake lock is retained');
